//
//  ToDoListsView.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import SwiftUI

struct ToDoListsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ToDoListsViewModel()
    @State private var searchText = ""
    @State private var selectedType: String? = nil  // nil means "All"
    @State private var showingAddList = false
    @State private var showingTypeFilter = false
    @State private var showUpgradePrompt = false
    @State private var newlyCreatedList: ToDoList?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let openAddSheetOnAppear: Bool

    /// Check if we're in iPad mode (regular size class)
    private var isiPad: Bool {
        horizontalSizeClass == .regular
    }

    /// Check if user can add more to-do lists
    private var canAddList: Bool {
        PremiumLimitsManager.shared.canCreateToDoList(
            appState: appState,
            currentCount: viewModel.lists.count
        )
    }

    init(openAddSheetOnAppear: Bool = false) {
        self.openAddSheetOnAppear = openAddSheetOnAppear
    }

    var filteredLists: [ToDoList] {
        var lists = viewModel.lists

        // Filter by type
        if let type = selectedType {
            lists = lists.filter { $0.listType == type }
        }

        // Filter by search
        if !searchText.isEmpty {
            lists = lists.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        return lists
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    CustomizableHeaderView(
                        pageIdentifier: .todoLists,
                        title: "To Do Lists",
                        showBackButton: true,
                        backAction: { dismiss() },
                        showAddButton: true,
                        addAction: {
                            if canAddList {
                                showingAddList = true
                            } else {
                                showUpgradePrompt = true
                            }
                        }
                    )

                    VStack(spacing: AppDimensions.cardSpacing) {

                    // Search Field with Type Filter Icon
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.textSecondary)

                            TextField("Search lists", text: $searchText)
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                        }
                        .padding(AppDimensions.cardPadding)
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)

                        Button(action: { showingTypeFilter = true }) {
                            Image(systemName: selectedType != nil ? "tag.fill" : "tag")
                                .font(.system(size: 20))
                                .foregroundColor(selectedType != nil ? appAccentColor : .textSecondary)
                                .frame(width: 44, height: 44)
                                .background(Color.cardBackground)
                                .cornerRadius(AppDimensions.cardCornerRadius)
                        }
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)

                    // Lists
                    if !filteredLists.isEmpty {
                        LazyVStack(spacing: AppDimensions.cardSpacing) {
                            ForEach(filteredLists) { list in
                                NavigationLink(destination: ToDoListDetailView(list: list)) {
                                    ToDoListCard(list: list)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteList(list)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)
                    }

                    // Empty state
                    if filteredLists.isEmpty && !viewModel.isLoading {
                        emptyStateView
                    }

                    // Premium limit reached banner
                    if !viewModel.lists.isEmpty && !canAddList {
                        PremiumFeatureLockBanner(
                            feature: .todoLists,
                            onUpgrade: { showUpgradePrompt = true }
                        )
                        .padding(.horizontal, AppDimensions.screenPadding)
                    }

                    Spacer().frame(height: 100)
                    }
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Type filter overlay when modal is shown
            if showingTypeFilter {
                ZStack {
                    Color.cardBackgroundLight.opacity(0.9)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingTypeFilter = false
                            }
                        }

                    TypeFilterSheetOverlay(
                        types: viewModel.listTypes,
                        selectedType: $selectedType,
                        viewModel: viewModel,
                        isShowing: showingTypeFilter,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingTypeFilter = false
                            }
                        }
                    )
                }
                .zIndex(10)
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showingAddList) {
            AddToDoListSheet(viewModel: viewModel) { createdList in
                newlyCreatedList = createdList
            }
        }
        .sidePanel(isPresented: $showUpgradePrompt) {
            UpgradeView()
        }
        .task {
            await viewModel.loadData(appState: appState)
            // Check if we should show the add sheet after data is loaded
            if openAddSheetOnAppear {
                // Check premium limit before showing add sheet
                if canAddList {
                    showingAddList = true
                } else {
                    showUpgradePrompt = true
                }
            }
        }
        .background(
            NavigationLink(
                destination: newlyCreatedList.map { ToDoListDetailView(list: $0, isNewList: true) },
                isActive: Binding(
                    get: { newlyCreatedList != nil },
                    set: { if !$0 { newlyCreatedList = nil } }
                )
            ) {
                EmptyView()
            }
        )
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.textSecondary)

            if selectedType != nil {
                // Filtered empty state (no lists match filter)
                Text("No \(selectedType!) lists")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                Text("Try selecting a different filter")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                // No lists at all
                Text("No To Do Lists")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                // Info card
                infoCard
                    .padding(.horizontal, 16)

                Button {
                    if canAddList {
                        showingAddList = true
                    } else {
                        showUpgradePrompt = true
                    }
                } label: {
                    Text("Add List")
                        .font(.appBodyMedium)
                        .foregroundColor(.black)
                        .frame(width: isiPad ? 200 : nil)
                        .padding(.horizontal, isiPad ? 0 : 24)
                        .padding(.vertical, 14)
                        .background(appAccentColor)
                        .cornerRadius(AppDimensions.buttonCornerRadius)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: isiPad ? 400 : .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Info Card
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(appAccentColor)

                Text("How To Do Lists Work")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "list.bullet", text: "Create lists to organise tasks by category or project")
                infoRow(icon: "checkmark.circle", text: "Mark items as complete to track your progress")
                infoRow(icon: "tag", text: "Use types to filter and find lists quickly")
            }
        }
        .padding()
        .background(appAccentColor.opacity(0.2))
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
                .frame(width: 18)

            Text(text)
                .font(.appCaption)
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Type Filter Sheet Overlay
private struct TypeFilterSheetOverlay: View {
    let types: [ToDoListType]
    @Binding var selectedType: String?
    @ObservedObject var viewModel: ToDoListsViewModel
    let isShowing: Bool
    let onDismiss: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    @State private var typeToDelete: ToDoListType?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Filter by Type")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            .padding(.top, AppDimensions.cardPadding)
            .padding(.horizontal, AppDimensions.cardPadding)

            VStack(spacing: 8) {
                // All option
                Button {
                    selectedType = nil
                    onDismiss()
                } label: {
                    HStack {
                        Text("All")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        if selectedType == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(appAccentColor)
                        }
                    }
                    .padding(AppDimensions.cardPadding)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Type options
                ForEach(types) { type in
                    HStack(spacing: 0) {
                        Button {
                            selectedType = type.name
                            onDismiss()
                        } label: {
                            HStack {
                                Text(type.name)
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                if selectedType == type.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(appAccentColor)
                                }
                            }
                        }

                        Button {
                            typeToDelete = type
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.leading, AppDimensions.cardPadding)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 250)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .shadow(color: .black.opacity(0.3), radius: 12, y: 8)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .alert("Delete Type", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let type = typeToDelete {
                    deleteType(type)
                }
            }
        } message: {
            if let type = typeToDelete {
                Text("Are you sure you want to delete the type '\(type.name)'? This will not delete any lists.")
            }
        }
    }

    private func deleteType(_ type: ToDoListType) {
        Task {
            await viewModel.deleteType(type)
            // If the deleted type was selected, clear the filter
            if selectedType == type.name {
                selectedType = nil
            }
        }
    }
}
