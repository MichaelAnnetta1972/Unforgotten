//
//  iPadToDoListViews.swift
//  Unforgotten
//
//  iPad-specific views for To Do Lists feature
//

import SwiftUI

// MARK: - iPad To Do Lists View (Uses full-screen overlay for detail)
struct iPadToDoListsView: View {
    @ObservedObject var viewModel: ToDoListsViewModel
    @EnvironmentObject var appState: AppState
    @State private var selectedList: ToDoList?
    @State private var showingAddList = false
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadViewToDoListAction) private var iPadViewToDoListAction
    @Environment(\.iPadAddToDoListAction) private var iPadAddToDoListAction

    var body: some View {
        iPadToDoListsListView(
            selectedList: $selectedList,
            viewModel: viewModel,
            onAddList: {
                // Use iPad root-level action for full-screen overlay
                if let addAction = iPadAddToDoListAction {
                    addAction()
                } else {
                    showingAddList = true
                }
            },
            useNavigationLinks: false,
            onListSelected: { list in
                // Use the full-screen overlay action if available
                if let viewAction = iPadViewToDoListAction {
                    viewAction(list)
                    // Don't keep local selection when using full-screen overlay
                    selectedList = nil
                } else {
                    selectedList = list
                }
            }
        )
        .background(Color.appBackgroundLight)
        .navigationBarHidden(true)
        // Only show local side panel when iPad action is not available
        .sidePanel(isPresented: iPadAddToDoListAction == nil ? $showingAddList : .constant(false)) {
            AddToDoListSheet(viewModel: viewModel, onDismiss: { showingAddList = false }) { createdList in
                // Select and show the newly created list using full-screen overlay
                if let viewAction = iPadViewToDoListAction {
                    viewAction(createdList)
                    // Don't keep local selection when using full-screen overlay
                    selectedList = nil
                } else {
                    selectedList = createdList
                }
            }
        }
    }
}

// MARK: - iPad To Do Lists List View
/// The list view for iPad that notifies when a list is selected
struct iPadToDoListsListView: View {
    @Binding var selectedList: ToDoList?
    @ObservedObject var viewModel: ToDoListsViewModel
    var onAddList: () -> Void
    var useNavigationLinks: Bool = false
    var onListSelected: ((ToDoList) -> Void)? = nil
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedType: String? = nil
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.iPadToDoListFilterBinding) private var iPadToDoListFilterBinding

    /// Returns the active type filter (iPad root-level binding or local state)
    private var activeTypeFilter: String? {
        iPadToDoListFilterBinding?.wrappedValue ?? selectedType
    }

    var filteredLists: [ToDoList] {
        var lists = viewModel.lists

        // Filter by type (use active filter which could be iPad or local)
        if let type = activeTypeFilter {
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
                        showBackButton: false,
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction,
                        showAddButton: true,
                        addAction: onAddList
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
                                    iPadToDoListFilterBinding?.wrappedValue = nil
                                } label: {
                                    if activeTypeFilter == nil {
                                        Label("All", systemImage: "checkmark")
                                    } else {
                                        Text("All")
                                    }
                                }

                                ForEach(viewModel.availableFilterTypes, id: \.self) { typeName in
                                    Button {
                                        selectedType = typeName
                                        iPadToDoListFilterBinding?.wrappedValue = typeName
                                    } label: {
                                        if activeTypeFilter == typeName {
                                            Label(typeName, systemImage: "checkmark")
                                        } else {
                                            Text(typeName)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: activeTypeFilter != nil ? "tag.fill" : "tag")
                                    .font(.system(size: 20))
                                    .foregroundColor(activeTypeFilter != nil ? appAccentColor : .textSecondary)
                                    .frame(width: 44, height: 44)
                                    .background(Color.cardBackground)
                                    .cornerRadius(AppDimensions.cardCornerRadius)
                            }
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)

                        // Lists or Empty State
                        if filteredLists.isEmpty && !viewModel.isLoading {
                            toDoListsEmptyStateView
                        } else {
                            LazyVStack(spacing: AppDimensions.cardSpacing) {
                                ForEach(filteredLists) { list in
                                    if useNavigationLinks {
                                        // Portrait mode: Use NavigationLink for standard push transition
                                        NavigationLink(destination: ToDoListDetailView(list: list)) {
                                            ToDoListCard(list: list, isSelected: false)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        // Use button to show in floating panel
                                        Button {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                selectedList = list
                                                onListSelected?(list)
                                            }
                                        } label: {
                                            ToDoListCard(list: list, isSelected: selectedList?.id == list.id)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
            .ignoresSafeArea(edges: .top)

        }
        .task {
            await viewModel.loadData(appState: appState)
        }
    }

    // MARK: - Empty State
    private var toDoListsEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.textSecondary)

            if let activeTypeFilter {
                // Filtered empty state (no lists match filter)
                Text("No \(activeTypeFilter) lists")
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
                toDoListsInfoCard
                    .padding(.horizontal, 16)

                Button {
                    onAddList()
                } label: {
                    Text("Add List")
                        .font(.appBodyMedium)
                        .foregroundColor(.black)
                        .frame(width: 200)
                        .padding(.vertical, 14)
                        .background(appAccentColor)
                        .cornerRadius(AppDimensions.buttonCornerRadius)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: 400)
        .padding(.vertical, 60)
    }

    // MARK: - Info Card
    private var toDoListsInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(appAccentColor)

                Text("How To Do Lists Work")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                toDoListsInfoRow(icon: "list.bullet", text: "Create lists to organise tasks by category or project")
                toDoListsInfoRow(icon: "checkmark.circle", text: "Mark items as complete to track your progress")
                toDoListsInfoRow(icon: "tag", text: "Use types to filter and find lists quickly")
            }
        }
        .padding()
        .background(appAccentColor.opacity(0.2))
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    private func toDoListsInfoRow(icon: String, text: String) -> some View {
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

// MARK: - iPad To Do List Detail View
/// Customized detail view for iPad split panel with close button
struct iPadToDoListDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ToDoListDetailViewModel
    @State private var showingAddType = false
    @State private var newTypeName = ""
    @State private var newItemText = ""
    @State private var showKeyboardToolbar = false
    @State private var showDeleteConfirmation = false
    @State private var typeToDelete: ToDoListType?
    @State private var showDeleteTypeConfirmation = false
    @State private var focusedItemId: UUID?
    @FocusState private var newItemFocused: Bool
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(HeaderStyleManager.self) private var headerStyleManager

    let list: ToDoList
    let onClose: () -> Void
    var onDelete: (() -> Void)?

    init(list: ToDoList, onClose: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ToDoListDetailViewModel(list: list))
        self.list = list
        self.onClose = onClose
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Close button row
                        HStack {
                            Spacer()
                            Button(action: onClose) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.textSecondary)
                                    .frame(width: 40, height: 40)
                                    .background(Color.cardBackground)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)
                        .padding(.top, AppDimensions.screenPadding)

                        // Title Edit Field with Type Icon and Delete Button
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("List Title")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                Spacer()

                                if let type = viewModel.selectedType {
                                    Menu {
                                        typeMenuContent
                                    } label: {
                                        Text(type)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(appAccentColor)
                                            .cornerRadius(6)
                                    }
                                }
                            }

                            HStack(spacing: 12) {
                                TextField("Enter title", text: $viewModel.listTitle)
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                    .onChange(of: viewModel.listTitle) { _, _ in
                                        viewModel.saveTitle()
                                    }

                                Menu {
                                    typeMenuContent
                                } label: {
                                    Image(systemName: viewModel.selectedType != nil ? "tag.fill" : "tag")
                                        .font(.system(size: 20))
                                        .foregroundColor(viewModel.selectedType != nil ? appAccentColor : .textSecondary)
                                }

                                Button(action: { showDeleteConfirmation = true }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 18))
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(Color.cardBackground)
                            .cornerRadius(AppDimensions.cardCornerRadius)
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)

                        // To Do Items
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Items")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, AppDimensions.screenPadding)

                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.sortedItems) { item in
                                    ToDoItemCard(
                                        item: item,
                                        focusedItemId: $focusedItemId,
                                        onToggle: { viewModel.toggleItem(item) },
                                        onTextChange: { newText in
                                            viewModel.updateItemText(item, text: newText)
                                        },
                                        onDelete: { viewModel.deleteItem(item) }
                                    )
                                    .padding(.horizontal, AppDimensions.screenPadding)
                                    .id(item.id)
                                }
                            }
                        }

                        Spacer().frame(height: 300)
                    }
                }
                .scrollIndicators(.hidden)
                .onChange(of: focusedItemId) { _, newValue in
                    if let itemId = newValue {
                        withAnimation {
                            proxy.scrollTo(itemId, anchor: .center)
                        }
                    }
                }
            }

            // Floating add button or keyboard toolbar
            VStack {
                Spacer()

                if showKeyboardToolbar {
                    KeyboardToolbarView(
                        text: $newItemText,
                        placeholder: "Add new item...",
                        isFocused: $newItemFocused,
                        accentColor: appAccentColor,
                        onSubmit: {
                            addNewItem()
                        },
                        onDismiss: {
                            showKeyboardToolbar = false
                            newItemFocused = false
                        }
                    )
                } else {
                    HStack {
                        Spacer()
                        Button(action: {
                            showKeyboardToolbar = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                newItemFocused = true
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(appAccentColor)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                        .padding(.trailing, AppDimensions.screenPadding)
                        .padding(.bottom, 30)
                    }
                }
            }
            .zIndex(2)

        }
        .alert("Add New Type", isPresented: $showingAddType) {
            TextField("Type name", text: $newTypeName)
            Button("Cancel", role: .cancel) { newTypeName = "" }
            Button("Add") {
                viewModel.addNewType(name: newTypeName)
                newTypeName = ""
            }
        }
        .alert("Delete List", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteList()
            }
        } message: {
            Text("Are you sure you want to delete '\(viewModel.listTitle)'? This will also delete all items in the list.")
        }
        .alert("Delete Type", isPresented: $showDeleteTypeConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let type = typeToDelete {
                    Task {
                        await viewModel.deleteType(type)
                    }
                }
            }
        } message: {
            if let type = typeToDelete {
                Text("Are you sure you want to delete the type '\(type.name)'? This will not delete any lists.")
            }
        }
        .task {
            await viewModel.loadData(appState: appState)
        }
        .onChange(of: viewModel.selectedType) { _, _ in
            viewModel.saveType()
        }
    }

    // MARK: - Type Menu Content

    @ViewBuilder
    private var typeMenuContent: some View {
        Button {
            viewModel.selectedType = nil
        } label: {
            if viewModel.selectedType == nil {
                Label("None", systemImage: "checkmark")
            } else {
                Text("None")
            }
        }

        ForEach(viewModel.availableTypes) { type in
            Button {
                viewModel.selectedType = type.name
            } label: {
                if viewModel.selectedType == type.name {
                    Label(type.name, systemImage: "checkmark")
                } else {
                    Text(type.name)
                }
            }
        }

        Divider()

        Button {
            showingAddType = true
        } label: {
            Label("Add New Type", systemImage: "plus")
        }

        if !viewModel.availableTypes.isEmpty {
            Menu("Delete Type") {
                ForEach(viewModel.availableTypes) { type in
                    Button(role: .destructive) {
                        typeToDelete = type
                        showDeleteTypeConfirmation = true
                    } label: {
                        Label(type.name, systemImage: "trash")
                    }
                }
            }
        }
    }

    private func addNewItem() {
        guard !newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        viewModel.addNewItemWithText(newItemText)
        newItemText = ""
        newItemFocused = true
    }

    private func deleteList() {
        Task {
            await viewModel.deleteList()
            onDelete?()
            onClose()
        }
    }
}

