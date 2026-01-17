//
//  AddToDoListSheet.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import SwiftUI

struct AddToDoListSheet: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: ToDoListsViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    var onDismiss: (() -> Void)? = nil
    var onCreate: (ToDoList) -> Void

    @State private var title = ""
    @State private var selectedType: String? = nil
    @State private var showingTypeSelector = false
    @State private var showingAddType = false
    @State private var newTypeName = ""
    @State private var errorMessage: String?
    @FocusState private var titleFieldFocused: Bool

    /// Check if user can add more to-do lists
    private var canAddList: Bool {
        PremiumLimitsManager.shared.canCreateToDoList(
            appState: appState,
            currentCount: viewModel.lists.count
        )
    }

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    // Custom header with icons
                    HStack {
                        Button {
                            dismissView()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.5))
                                )
                        }

                        Spacer()

                        Text("New To Do List")
                            .font(.headline)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        Button {
                            createList()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 48, height: 48)
                                .background(
                                    Circle()
                                        .fill(title.isEmpty ? Color.gray.opacity(0.3) : appAccentColor)
                                )
                        }
                        .disabled(title.isEmpty)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.vertical, 16)

                    // Content
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Title Field with Type Icon
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("List Title")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                Spacer()

                                if let type = selectedType {
                                    Text(type)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(appAccentColor)
                                        .cornerRadius(6)
                                }
                            }

                            TextField("Enter title", text: $title, axis: .vertical)
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .lineLimit(1...5)
                                .focused($titleFieldFocused)
                                .padding(AppDimensions.cardPadding)
                                .background(Color.cardBackground)
                                .cornerRadius(AppDimensions.cardCornerRadius)
                        }

                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(AppDimensions.screenPadding)

                    Spacer()
                }
                .background(Color.clear)
                .navigationBarHidden(true)
                .alert("Add New Type", isPresented: $showingAddType) {
                    TextField("Type name", text: $newTypeName)
                    Button("Cancel", role: .cancel) { newTypeName = "" }
                    Button("Add") {
                        viewModel.addNewType(name: newTypeName)
                        newTypeName = ""
                    }
                }
                .onAppear {
                    // Auto-focus title field when sheet appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        titleFieldFocused = true
                    }
                }
            }

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
                        types: viewModel.listTypes,
                        selectedType: $selectedType,
                        onAddNewType: { showingAddType = true },
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
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.clear, for: .navigationBar)
        .containerBackground(.clear, for: .navigation)
    }

    private func createList() {
        // Validate premium limit before creating
        guard canAddList else {
            errorMessage = "Free plan is limited to \(PremiumLimitsManager.FreeTierLimits.todoLists) to-do lists. Upgrade to Premium for unlimited lists."
            return
        }

        Task {
            let newList = await viewModel.createListAsync(title: title, type: selectedType)
            dismissView()
            if let list = newList {
                onCreate(list)
            }
        }
    }
}

// MARK: - Type Selector Sheet Overlay
private struct TypeSelectorSheetOverlay: View {
    let types: [ToDoListType]
    @Binding var selectedType: String?
    let onAddNewType: () -> Void
    let onDismiss: () -> Void
    let isShowing: Bool
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

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

                // Type options
                ForEach(types) { type in
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
    }
}
