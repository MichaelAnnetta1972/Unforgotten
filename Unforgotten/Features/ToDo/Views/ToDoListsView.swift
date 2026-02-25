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
    @State private var showUpgradePrompt = false
    @State private var newlyCreatedList: ToDoList?
    @State private var listContentHeight: CGFloat = 0
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

                        Menu {
                            Button {
                                selectedType = nil
                            } label: {
                                if selectedType == nil {
                                    Label("All", systemImage: "checkmark")
                                } else {
                                    Text("All")
                                }
                            }

                            ForEach(viewModel.availableFilterTypes, id: \.self) { typeName in
                                Button {
                                    selectedType = typeName
                                } label: {
                                    if selectedType == typeName {
                                        Label(typeName, systemImage: "checkmark")
                                    } else {
                                        Text(typeName)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: selectedType != nil ? "tag.fill" : "tag")
                                .font(.system(size: 20))
                                .foregroundColor(selectedType != nil ? appAccentColor : .textSecondary)
                                .frame(width: 44, height: 44)
                                .background(Color.cardBackground)
                                .cornerRadius(AppDimensions.cardCornerRadius)
                        }
                        .tint(appAccentColor)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)

                    // Lists
                    if !filteredLists.isEmpty {
                        List {
                            ForEach(filteredLists) { list in
                                ZStack {
                                    NavigationLink(destination: ToDoListDetailView(list: list)) {
                                        EmptyView()
                                    }
                                    .opacity(0)

                                    ToDoListCard(list: list)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteList(list)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: AppDimensions.cardSpacing / 2, leading: AppDimensions.screenPadding, bottom: AppDimensions.cardSpacing / 2, trailing: AppDimensions.screenPadding))
                            }
                        }
                        .listStyle(.plain)
                        .scrollDisabled(true)
                        .scrollContentBackground(.hidden)
                        .frame(height: listContentHeight)
                        .onChange(of: filteredLists.count) { _, count in
                            let rowHeight: CGFloat = 80
                            let spacing: CGFloat = AppDimensions.cardSpacing
                            listContentHeight = CGFloat(count) * (rowHeight + spacing)
                        }
                        .onAppear {
                            let rowHeight: CGFloat = 80
                            let spacing: CGFloat = AppDimensions.cardSpacing
                            listContentHeight = CGFloat(filteredLists.count) * (rowHeight + spacing)
                        }
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

        }
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showingAddList) {
            AddToDoListSheet(viewModel: viewModel) { createdList in
                newlyCreatedList = createdList
            }
            .environmentObject(appState)
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
        .refreshable {
            await viewModel.loadData(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .todosDidChange)) { _ in
            Task { await viewModel.loadData(appState: appState) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            Task { await viewModel.loadData(appState: appState) }
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

            if let selectedType {
                // Filtered empty state (no lists match filter)
                Text("No \(selectedType) lists")
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

