//
//  ToDoListDetailView.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import SwiftUI

struct ToDoListDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ToDoListDetailViewModel
    @State private var showingAddType = false
    @State private var showingDeleteTypeConfirmation = false
    @State private var typeToDelete: ToDoListType?
    @State private var newTypeName = ""
    @State private var newItemText = ""
    @State private var showKeyboardToolbar = false
    @State private var showDeleteConfirmation = false
    @State private var showingDueDatePicker = false
    @State private var focusedItemId: UUID?
    @State private var showFamilySharingSheet = false
    @State private var showReShareSheet = false
    @FocusState private var newItemFocused: Bool
    @FocusState private var titleFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(HeaderStyleManager.self) private var headerStyleManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Check if we're on iPad (regular size class)
    private var isiPad: Bool {
        horizontalSizeClass == .regular
    }

    let isNewList: Bool

    init(list: ToDoList, isNewList: Bool = false) {
        _viewModel = StateObject(wrappedValue: ToDoListDetailViewModel(list: list))
        self.isNewList = isNewList
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
                            Button(action: { dismiss() }) {
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
                                Text("LIST TITLE")
                                    .font(.appCaption)
                                    .foregroundColor(appAccentColor)

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
                                    .tint(appAccentColor)
                                }
                            }

                            HStack(alignment: .top, spacing: 12) {
                                TextField("Enter title", text: $viewModel.listTitle, axis: .vertical)
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(1...5)
                                    .multilineTextAlignment(.leading)
                                    .focused($titleFieldFocused)
                                    .onChange(of: viewModel.listTitle) { _, _ in
                                        viewModel.saveTitle()
                                    }

                                HStack(spacing: 16) {
                                    Menu {
                                        typeMenuContent
                                    } label: {
                                        Image(systemName: viewModel.selectedType != nil ? "tag.fill" : "tag")
                                            .font(.system(size: 20))
                                            .foregroundColor(viewModel.selectedType != nil ? appAccentColor : .textSecondary)
                                    }
                                    .tint(appAccentColor)
                                }
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(Color.appBackground)
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
                            .background(Color.appBackground)
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
                                .background(Color.appBackground)
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
                        Text("ITEMS")
                            .font(.appCaption)
                            .foregroundColor(appAccentColor)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: AppDimensions.cardSpacing / 2, leading: AppDimensions.screenPadding, bottom: 0, trailing: AppDimensions.screenPadding))

                        ForEach(viewModel.sortedItems) { item in
                            ToDoItemCard(
                                item: item,
                                focusedItemId: $focusedItemId,
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        viewModel.toggleItem(item)
                                    }
                                },
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
                        .animation(.easeInOut(duration: 0.3), value: viewModel.sortedItems.map { $0.id })

                        // iPad inline add button - placed after items to avoid overlap with bottom nav
                        if isiPad && !showKeyboardToolbar {
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
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: AppDimensions.screenPadding, bottom: 0, trailing: AppDimensions.screenPadding))
                        }
                    }

                    // Bottom spacer
                    Spacer().frame(height: isiPad ? 150 : 300)
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

            // Floating add button (iPhone only) or keyboard toolbar
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
                    // On iPad with keyboard, ensure toolbar is at least 200pt from bottom
                    .padding(.bottom, isiPad ? 200 : 0)
                } else if !isiPad {
                    // iPhone floating button only - iPad uses inline button
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
        .navigationBarHidden(true)
        .hideBottomNavBar()
        .alert("Add New Type", isPresented: $showingAddType) {
            TextField("Type name", text: $newTypeName)
            Button("Cancel", role: .cancel) { newTypeName = "" }
            Button("Add") {
                viewModel.addNewType(name: newTypeName)
                newTypeName = ""
            }
        }
        .alert("Delete Type", isPresented: $showingDeleteTypeConfirmation) {
            Button("Cancel", role: .cancel) { typeToDelete = nil }
            Button("Delete", role: .destructive) {
                if let type = typeToDelete {
                    Task { await viewModel.deleteType(type) }
                    typeToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(typeToDelete?.name ?? "")'?")
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
        .refreshable {
            await viewModel.loadData(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .todosDidChange)) { _ in
            Task { await viewModel.loadData(appState: appState) }
        }
        .onAppear {
            // Auto-focus title field for newly created lists
            if isNewList {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    titleFieldFocused = true
                }
            }
        }
        .onDisappear {
            // Auto-delete new lists that were left empty
            if isNewList && viewModel.listTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.items.isEmpty {
                Task {
                    await viewModel.deleteList()
                }
            }
        }
    }

    private func addNewItem() {
        guard !newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        viewModel.addNewItemWithText(newItemText)
        newItemText = ""
        // Keep focus on the input field
        newItemFocused = true
    }

    private func deleteList() {
        Task {
            await viewModel.deleteList()
            dismiss()
        }
    }

    // MARK: - Sharing Info Banner
    @ViewBuilder
    private var sharingInfoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 16))
                .foregroundColor(appAccentColor)

            if viewModel.isSharedWithMe {
                if let name = viewModel.sharedByDisplayName {
                    Text("Shared by \(name)")
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                } else {
                    Text("Shared with you")
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                }
            } else if viewModel.shareToFamily && !viewModel.sharedWithDisplayNames.isEmpty {
                Text("Shared with \(viewModel.sharedWithDisplayNames.joined(separator: ", "))")
                    .font(.appBody)
                    .foregroundColor(.textPrimary)
            }

            Spacer()
        }
        .padding(AppDimensions.cardPadding)
        .background(appAccentColor.opacity(0.15))
        .cornerRadius(AppDimensions.cardCornerRadius)
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
            .background(Color.appBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Type Menu Content
    @ViewBuilder
    private var typeMenuContent: some View {
        Button {
            viewModel.selectedType = nil
            viewModel.saveType()
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
                viewModel.saveType()
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
            Menu {
                ForEach(viewModel.availableTypes) { type in
                    Button(role: .destructive) {
                        typeToDelete = type
                        showingDeleteTypeConfirmation = true
                    } label: {
                        Label(type.name, systemImage: "trash")
                    }
                }
            } label: {
                Label("Delete a Type", systemImage: "trash")
            }
        }
    }
}

// MARK: - Keyboard Toolbar View
struct KeyboardToolbarView: View {
    @Binding var text: String
    let placeholder: String
    var isFocused: FocusState<Bool>.Binding
    let accentColor: Color
    let onSubmit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 32)
            }

            TextField(placeholder, text: $text)
                .font(.appBody)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, AppDimensions.cardPadding)
                .padding(.vertical, 12)
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.buttonCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                        .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                )
                .focused(isFocused)
                .onSubmit(onSubmit)

            Button(action: onSubmit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : accentColor)
                    .clipShape(Circle())
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, AppDimensions.screenPadding)
        .padding(.vertical, 8)
        .background(Color.appBackground.opacity(0.95))
        .shadow(color: .black.opacity(0.1), radius: 4, y: -2)
    }
}

