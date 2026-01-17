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
    @State private var showingTypeFilter = false
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.iPadToDoListFilterAction) private var iPadToDoListFilterAction
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

                            Button(action: {
                                // Use iPad root-level filter action for full-screen overlay
                                if let filterAction = iPadToDoListFilterAction {
                                    filterAction()
                                } else {
                                    showingTypeFilter = true
                                }
                            }) {
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

            // Type filter overlay when modal is shown (only when iPad action is not available)
            if showingTypeFilter && iPadToDoListFilterAction == nil {
                ZStack {
                    Color.cardBackground.opacity(0.8)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingTypeFilter = false
                            }
                        }

                    iPadToDoListFilterOverlay(
                        types: viewModel.availableFilterTypes,
                        selectedType: $selectedType,
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

            if activeTypeFilter != nil {
                // Filtered empty state (no lists match filter)
                Text("No \(activeTypeFilter!) lists")
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

// MARK: - iPad Type Filter Overlay
struct iPadToDoListFilterOverlay: View {
    let types: [String]
    @Binding var selectedType: String?
    let onDismiss: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var offsetX: CGFloat = 320
    @State private var opacity: Double = 0

    private let panelWidth: CGFloat = 300

    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()

                VStack(spacing: 16) {
                    HStack {
                        Text("Filter by Type")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        Spacer()

                        // Close button
                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding(.top, AppDimensions.cardPadding)
                    .padding(.horizontal, AppDimensions.cardPadding)

                    ScrollView {
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

                            // Type options (derived from existing lists)
                            ForEach(types, id: \.self) { typeName in
                                Button {
                                    selectedType = typeName
                                    onDismiss()
                                } label: {
                                    HStack {
                                        Text(typeName)
                                            .font(.appBody)
                                            .foregroundColor(.textPrimary)
                                        Spacer()
                                        if selectedType == typeName {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(appAccentColor)
                                        }
                                    }
                                    .padding(AppDimensions.cardPadding)
                                    .background(Color.cardBackgroundSoft)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .frame(maxHeight: geometry.size.height - 120) // Fit content with screen-based max
                }
                .frame(width: panelWidth)
                .fixedSize(horizontal: false, vertical: true) // Fit content height
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius))
                .shadow(color: .black.opacity(0.3), radius: 12, x: -4, y: 0)
                .offset(x: offsetX)
                .opacity(opacity)
                .padding(.vertical, 40)
                .padding(.trailing, 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                offsetX = 0
                opacity = 1.0
            }
        }
    }
}

// MARK: - iPad To Do List Detail View
/// Customized detail view for iPad split panel with close button
struct iPadToDoListDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ToDoListDetailViewModel
    @State private var showingAddType = false
    @State private var showingTypeSelector = false
    @State private var newTypeName = ""
    @State private var newItemText = ""
    @State private var showKeyboardToolbar = false
    @State private var showDeleteConfirmation = false
    @State private var focusedItemId: UUID?
    @FocusState private var newItemFocused: Bool
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(HeaderStyleManager.self) private var headerStyleManager
    @Environment(\.iPadToDoDetailTypeSelectorAction) private var iPadToDoDetailTypeSelectorAction

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
                                    Button(action: {
                                        // Use root-level action for full-screen overlay
                                        if let typeSelectorAction = iPadToDoDetailTypeSelectorAction {
                                            typeSelectorAction(viewModel, $viewModel.selectedType, { showingAddType = true })
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                showingTypeSelector = true
                                            }
                                        }
                                    }) {
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

                                Button(action: {
                                    // Use root-level action for full-screen overlay
                                    if let typeSelectorAction = iPadToDoDetailTypeSelectorAction {
                                        typeSelectorAction(viewModel, $viewModel.selectedType, { showingAddType = true })
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showingTypeSelector = true
                                        }
                                    }
                                }) {
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

            // Type selector overlay (only when root-level action is not available)
            if showingTypeSelector && iPadToDoDetailTypeSelectorAction == nil {
                ZStack {
                    Color.appBackground.opacity(0.9)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingTypeSelector = false
                            }
                        }

                    iPadTypeSelectorOverlay(
                        types: viewModel.availableTypes,
                        selectedType: $viewModel.selectedType,
                        onAddNewType: { showingAddType = true },
                        onDeleteType: { type in
                            Task {
                                await viewModel.deleteType(type)
                            }
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingTypeSelector = false
                            }
                        }
                    )
                }
                .zIndex(5)
                .transition(.opacity)
                .onDisappear {
                    viewModel.saveType()
                }
            }

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
        .task {
            await viewModel.loadData(appState: appState)
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

// MARK: - iPad Type Selector Overlay
struct iPadTypeSelectorOverlay: View {
    let types: [ToDoListType]
    @Binding var selectedType: String?
    let onAddNewType: () -> Void
    let onDeleteType: (ToDoListType) -> Void
    let onDismiss: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    @State private var typeToDelete: ToDoListType?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Select Type")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
                Button {
                    onAddNewType()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(appAccentColor)
                }
            }
            .padding(.top, AppDimensions.cardPadding)
            .padding(.horizontal, AppDimensions.cardPadding)

            ScrollView {
                VStack(spacing: 8) {
                    // None option
                    Button {
                        selectedType = nil
                        onDismiss()
                    } label: {
                        HStack {
                            Text("None")
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

                    // Type options with delete button
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
                            .buttonStyle(.plain)

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
            .frame(maxHeight: 300)
        }
        .frame(width: 280)
        .background(Color.appBackground)
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
                    onDeleteType(type)
                }
            }
        } message: {
            if let type = typeToDelete {
                Text("Are you sure you want to delete the type '\(type.name)'? This will not delete any lists.")
            }
        }
    }
}

// MARK: - iPad ToDo Detail Type Selector Overlay (Full-screen, slide-in from right)
struct iPadToDoDetailTypeSelectorOverlay: View {
    @ObservedObject var viewModel: ToDoListDetailViewModel
    @Binding var selectedType: String?
    let onAddNewType: () -> Void
    let onDismiss: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var offsetX: CGFloat = 320
    @State private var opacity: Double = 0
    @State private var typeToDelete: ToDoListType?
    @State private var showDeleteConfirmation = false

    private let panelWidth: CGFloat = 320

    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()

                VStack(spacing: 16) {
                    HStack {
                        Text("Select Type")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        Spacer()

                        Button {
                            onAddNewType()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(appAccentColor)
                        }

                        // Close button
                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding(.top, AppDimensions.cardPadding)
                    .padding(.horizontal, AppDimensions.cardPadding)

                    ScrollView {
                        VStack(spacing: 8) {
                            // None option
                            Button {
                                selectedType = nil
                                onDismiss()
                            } label: {
                                HStack {
                                    Text("None")
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

                            // Type options with delete button
                            ForEach(viewModel.availableTypes) { type in
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
                                    .buttonStyle(.plain)

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
                    .frame(maxHeight: geometry.size.height - 120) // Fit content with screen-based max
                }
                .frame(width: panelWidth)
                .fixedSize(horizontal: false, vertical: true) // Fit content height
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius))
                .shadow(color: .black.opacity(0.3), radius: 12, x: -4, y: 0)
                .offset(x: offsetX)
                .opacity(opacity)
                .padding(.vertical, 40)
                .padding(.trailing, 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                offsetX = 0
                opacity = 1.0
            }
        }
        .alert("Delete Type", isPresented: $showDeleteConfirmation) {
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
    }
}
