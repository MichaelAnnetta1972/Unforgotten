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
    @State private var isCreatingList = false
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
                    createAndNavigateToNewList()
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
    }

    private func createAndNavigateToNewList() {
        guard !isCreatingList else { return }
        isCreatingList = true
        Task {
            let newList = await viewModel.createListAsync(title: "", type: nil, dueDate: nil)
            isCreatingList = false
            if let createdList = newList {
                if let viewAction = iPadViewToDoListAction {
                    viewAction(createdList)
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
            // Image(systemName: "checklist")
            //     .font(.system(size: 60))
            //     .foregroundColor(.textSecondary)

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
    @State private var showingDueDatePicker = false
    @State private var focusedItemId: UUID?
    @State private var showFamilySharingSheet = false
    @State private var showReShareSheet = false
    @FocusState private var newItemFocused: Bool
    @FocusState private var titleFieldFocused: Bool
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
                List {
                    // Close button row
                    Section {
                        HStack {
                            Spacer()
                            Button(action: onClose) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.textSecondary)
                                    .frame(width: 40, height: 40)
                                    .background(Color.cardBackground)
                                    .clipShape(Circle())
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: AppDimensions.screenPadding, leading: AppDimensions.screenPadding, bottom: 0, trailing: AppDimensions.screenPadding))
                    }

                    // Title Edit Field with Type Icon and Delete Button
                    Section {
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
                                    .focused($titleFieldFocused)
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
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(Color.cardBackground)
                            .cornerRadius(AppDimensions.cardCornerRadius)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: AppDimensions.cardSpacing / 2, leading: AppDimensions.screenPadding, bottom: AppDimensions.cardSpacing / 2, trailing: AppDimensions.screenPadding))
                    }

                    // Due Date
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DUE DATE")
                                .font(.appCaption)
                                .foregroundColor(appAccentColor)

                            HStack {
                                if let date = viewModel.dueDate {
                                    Text(date, style: .date)
                                        .font(.appBody)
                                        .foregroundColor(.textPrimary)

                                    Spacer()

                                    Button {
                                        viewModel.dueDate = nil
                                        viewModel.saveDueDate()
                                        showingDueDatePicker = false
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.textSecondary)
                                    }
                                } else {
                                    Text("No due date")
                                        .font(.appBody)
                                        .foregroundColor(.textSecondary)

                                    Spacer()
                                }

                                Button {
                                    showingDueDatePicker.toggle()
                                } label: {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 20))
                                        .foregroundColor(viewModel.dueDate != nil ? appAccentColor : .textSecondary)
                                }
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(Color.cardBackground)
                            .cornerRadius(AppDimensions.cardCornerRadius)

                            if showingDueDatePicker {
                                VStack(spacing: 0) {
                                    Text((viewModel.dueDate ?? Date()).formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                                        .font(.appBodyMedium)
                                        .foregroundColor(appAccentColor)
                                        .padding(.top, 12)

                                    DatePicker("", selection: Binding(
                                        get: { viewModel.dueDate ?? Date() },
                                        set: { newDate in
                                            viewModel.dueDate = newDate
                                            viewModel.saveDueDate()
                                        }
                                    ), displayedComponents: .date)
                                    .datePickerStyle(.wheel)
                                    .colorScheme(.dark)
                                    .tint(appAccentColor)
                                }
                                .padding(AppDimensions.cardPadding)
                                .background(Color.cardBackground)
                                .cornerRadius(AppDimensions.cardCornerRadius)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: AppDimensions.cardSpacing / 2, leading: AppDimensions.screenPadding, bottom: AppDimensions.cardSpacing / 2, trailing: AppDimensions.screenPadding))
                    }

                    // Sharing Info Header (shown when shared by someone or shared with others)
                    if viewModel.isSharedWithMe || viewModel.shareToFamily {
                        Section {
                            sharingInfoBanner
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: AppDimensions.cardSpacing / 2, leading: AppDimensions.screenPadding, bottom: AppDimensions.cardSpacing / 2, trailing: AppDimensions.screenPadding))
                        }
                    }

                    // Family Sharing (only for list owner, not for shared-with-me lists)
                    if !viewModel.isSharedWithMe && appState.hasFamilyAccess {
                        Section {
                            familySharingSection
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: AppDimensions.cardSpacing / 2, leading: AppDimensions.screenPadding, bottom: AppDimensions.cardSpacing / 2, trailing: AppDimensions.screenPadding))
                        }

                        if let sharingError = viewModel.sharingError {
                            Section {
                                Text(sharingError)
                                    .font(.appCaption)
                                    .foregroundColor(.medicalRed)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 0, leading: AppDimensions.screenPadding, bottom: AppDimensions.cardSpacing / 2, trailing: AppDimensions.screenPadding))
                            }
                        }
                    }

                    // Re-share section (for lists shared with me, if eligible)
                    if viewModel.isSharedWithMe && viewModel.canReShare && appState.hasFamilyAccess {
                        Section {
                            reShareSection
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: AppDimensions.cardSpacing / 2, leading: AppDimensions.screenPadding, bottom: AppDimensions.cardSpacing / 2, trailing: AppDimensions.screenPadding))
                        }
                    }

                    // To Do Items
                    Section {
                        Text("Items")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: AppDimensions.cardSpacing / 2, leading: AppDimensions.screenPadding, bottom: 0, trailing: AppDimensions.screenPadding))

                        ForEach(viewModel.sortedItems) { item in
                            ToDoItemCard(
                                item: item,
                                focusedItemId: $focusedItemId,
                                onToggle: { viewModel.toggleItem(item) },
                                onTextChange: { newText in
                                    viewModel.updateItemText(item, text: newText)
                                }
                            )
                            .id(item.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteItem(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.medicalRed)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: AppDimensions.cardSpacing / 2, leading: AppDimensions.screenPadding, bottom: AppDimensions.cardSpacing / 2, trailing: AppDimensions.screenPadding))
                        }
                    }

                    // Bottom spacer
                    Spacer().frame(height: 300)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
        .sheet(isPresented: $showFamilySharingSheet) {
            FamilySharingSheet(
                isEnabled: $viewModel.shareToFamily,
                selectedMemberIds: $viewModel.selectedMemberIds,
                onDismiss: {
                    showFamilySharingSheet = false
                    Task { await viewModel.saveSharing(appState: appState) }
                }
            )
            .environmentObject(appState)
        }
        .sheet(isPresented: $showReShareSheet) {
            FamilySharingSheet(
                isEnabled: $viewModel.reShareEnabled,
                selectedMemberIds: $viewModel.reShareMemberIds,
                onDismiss: {
                    showReShareSheet = false
                    Task { await viewModel.saveReSharing(appState: appState) }
                }
            )
            .environmentObject(appState)
            .presentationDetents([.medium, .large])
        }
        .task {
            await viewModel.loadData(appState: appState)
        }
        .onAppear {
            // Auto-focus title field for newly created lists (empty title)
            if list.title.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    titleFieldFocused = true
                }
            }
        }
        .onChange(of: viewModel.selectedType) { _, _ in
            viewModel.saveType()
        }
    }

    // MARK: - Sharing Info Banner
    @ViewBuilder
    private var sharingInfoBanner: some View {
        if viewModel.isSharedWithMe {
            HStack(spacing: 10) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(appAccentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Shared with you")
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    if let name = viewModel.sharedByDisplayName {
                        Text("by \(name)")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(AppDimensions.cardPadding)
            .background(appAccentColor.opacity(0.15))
            .cornerRadius(AppDimensions.cardCornerRadius)
        } else if viewModel.shareToFamily && !viewModel.sharedWithDisplayNames.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(appAccentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Shared with family")
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    Text(viewModel.sharedWithDisplayNames.joined(separator: ", "))
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(AppDimensions.cardPadding)
            .background(appAccentColor.opacity(0.15))
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }

    // MARK: - Family Sharing Section
    @ViewBuilder
    private var familySharingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FAMILY SHARING")
                .font(.appCaption)
                .foregroundColor(appAccentColor)

            Button {
                showFamilySharingSheet = true
            } label: {
                HStack {
                    Image(systemName: "person.2")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.shareToFamily ? appAccentColor : .textSecondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.shareToFamily ? "Shared" : "Share with Family")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        if viewModel.shareToFamily && !viewModel.sharedWithDisplayNames.isEmpty {
                            Text(viewModel.sharedWithDisplayNames.joined(separator: ", "))
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                                .lineLimit(1)
                        } else if !viewModel.shareToFamily {
                            Text("Let family members view and edit this list")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .padding(AppDimensions.cardPadding)
                .background(Color.appBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Re-Share Section
    @ViewBuilder
    private var reShareSection: some View {
        Button {
            showReShareSheet = true
        } label: {
            HStack {
                Image(systemName: "person.2")
                    .font(.system(size: 18))
                    .foregroundColor(viewModel.hasReShared ? appAccentColor : .textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.hasReShared ? "Shared with My Family" : "Share with My Family")
                        .font(.appBody)
                        .foregroundColor(.textPrimary)

                    if viewModel.hasReShared && !viewModel.reShareMemberNames.isEmpty {
                        Text(viewModel.reShareMemberNames.joined(separator: ", "))
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    } else if !viewModel.hasReShared {
                        Text("Share this list with your own family members")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
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

