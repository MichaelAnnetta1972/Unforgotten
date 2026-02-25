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
    @FocusState private var newItemFocused: Bool
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
                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Close button row
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
                                    .tint(appAccentColor)
                                }
                            }

                            HStack(alignment: .top, spacing: 12) {
                                TextField("Enter title", text: $viewModel.listTitle, axis: .vertical)
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(1...5)
                                    .multilineTextAlignment(.leading)
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

                                    Button(action: { showDeleteConfirmation = true }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 18))
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(Color.appBackground)
                            .cornerRadius(AppDimensions.cardCornerRadius)
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)

                        // Due Date
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Due Date")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

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
                                        .foregroundColor(.accentYellow)
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
                                        onToggle: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                viewModel.toggleItem(item)
                                            }
                                        },
                                        onTextChange: { newText in
                                            viewModel.updateItemText(item, text: newText)
                                        },
                                        onDelete: { viewModel.deleteItem(item) }
                                    )
                                    .padding(.horizontal, AppDimensions.screenPadding)
                                    .id(item.id)
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
                                    .padding(.horizontal, AppDimensions.screenPadding)
                                    .padding(.top, 8)
                                }
                            }
                        }

                        Spacer().frame(height: isiPad ? 150 : 300)
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
            // Only auto-focus for newly created lists
            if isNewList {
                showKeyboardToolbar = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    newItemFocused = true
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
                .cornerRadius(AppDimensions.cardCornerRadius)
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

