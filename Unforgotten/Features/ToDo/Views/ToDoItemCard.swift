//
//  ToDoItemCard.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import SwiftUI

struct ToDoItemCard: View {
    let item: ToDoItem
    @Binding var focusedItemId: UUID?
    let onToggle: () -> Void
    let onTextChange: (String) -> Void
    let onDelete: () -> Void

    @State private var itemText: String
    @State private var checkboxScale: CGFloat = 1.0
    @State private var showCheckmark: Bool
    @FocusState private var isTextFieldFocused: Bool

    init(
        item: ToDoItem,
        focusedItemId: Binding<UUID?>,
        onToggle: @escaping () -> Void,
        onTextChange: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self._focusedItemId = focusedItemId
        self.onToggle = onToggle
        self.onTextChange = onTextChange
        self.onDelete = onDelete
        self._itemText = State(initialValue: item.text)
        self._showCheckmark = State(initialValue: item.isCompleted)
    }

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Animated Checkbox
            Button(action: animatedToggle) {
                ZStack {
                    // Border/Background
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(showCheckmark ? appAccentColor : Color.textSecondary.opacity(0.5), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    // Fill when checked
                    RoundedRectangle(cornerRadius: 5)
                        .fill(showCheckmark ? appAccentColor : Color.clear)
                        .frame(width: 20, height: 20)

                    // Checkmark
                    if showCheckmark {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(checkboxScale)
            }
            .buttonStyle(PlainButtonStyle())

            // Text Field (multi-line)
            TextField("Enter item", text: $itemText, axis: .vertical)
                .font(.appBody)
                .foregroundColor(showCheckmark ? .textSecondary : .textPrimary)
                .strikethrough(showCheckmark, color: .textSecondary)
                .lineLimit(1...5)
                .focused($isTextFieldFocused)
                .onChange(of: itemText) { _, newValue in
                    onTextChange(newValue)
                }

            // Show X to dismiss keyboard when focused, or delete icon when not
            if isTextFieldFocused {
                Button(action: { isTextFieldFocused = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.textSecondary)
                        .frame(width: 32)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .onChange(of: item.text) { _, newValue in
            if itemText != newValue {
                itemText = newValue
            }
        }
        .onChange(of: item.isCompleted) { _, newValue in
            // Sync local state when item changes externally
            if showCheckmark != newValue {
                showCheckmark = newValue
            }
        }
        .onChange(of: isTextFieldFocused) { _, isFocused in
            if isFocused {
                focusedItemId = item.id
            } else if focusedItemId == item.id {
                focusedItemId = nil
            }
        }
    }

    private func animatedToggle() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // Animate the checkbox scale down
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            checkboxScale = 0.8
        }

        // After a short delay, animate scale up and toggle the checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                checkboxScale = 1.15
                showCheckmark.toggle()
            }
        }

        // Return to normal scale
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                checkboxScale = 1.0
            }
        }

        // Delay the actual data update to allow animation to be seen before resorting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onToggle()
        }
    }
}
