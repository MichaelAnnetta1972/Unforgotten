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
    @State private var showingTypeSelector = false
    @State private var newTypeName = ""
    @State private var newItemText = ""
    @State private var showKeyboardToolbar = false
    @State private var showDeleteConfirmation = false
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
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showingTypeSelector = true
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
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showingTypeSelector = true
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
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(Color.appBackground)
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

            // Type selector overlay when modal is shown
            if showingTypeSelector {
                ZStack {
                    Color.cardBackgroundLight.opacity(0.9)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingTypeSelector = false
                            }
                        }

                    TypeSelectorSheetOverlay(
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
                        },
                        isShowing: showingTypeSelector
                    )
                }
                .zIndex(5)
                .transition(.opacity)
                .onDisappear {
                    viewModel.saveType()
                }
            }

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

// MARK: - Type Selector Sheet Overlay
private struct TypeSelectorSheetOverlay: View {
    let types: [ToDoListType]
    @Binding var selectedType: String?
    let onAddNewType: () -> Void
    let onDeleteType: (ToDoListType) -> Void
    let onDismiss: () -> Void
    let isShowing: Bool
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
