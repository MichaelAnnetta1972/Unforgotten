//
//  HighlightedItemOverlay.swift
//  Unforgotten
//
//  Created on 2025-12-19
//

import SwiftUI

struct HighlightedItemOverlay: View {
    let item: ToDoItem
    let frame: CGRect
    let onToggle: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var menuScale: CGFloat = 0.8
    @State private var menuOpacity: Double = 0
    @State private var menuHeight: CGFloat = 0

    private let menuWidth: CGFloat = 200

    var body: some View {
        GeometryReader { geometry in
            let overlayFrame = geometry.frame(in: .global)
            let panelSize = geometry.size
            let adaptiveScreenPadding = AppDimensions.screenPadding(for: horizontalSizeClass)
            let cardWidth = panelSize.width - (adaptiveScreenPadding * 2)
            // Convert global Y to local Y
            let localCardMinY = frame.minY - overlayFrame.minY
            let localCardMaxY = frame.maxY - overlayFrame.minY
            let localCardY = localCardMinY + frame.height / 2
            let menuYPosition = calculateMenuYPosition(localCardMinY: localCardMinY, localCardMaxY: localCardMaxY, screenHeight: panelSize.height)

            ZStack(alignment: .topLeading) {
                // Dark overlay
                Color.cardBackgroundLight.opacity(0.9)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onDismiss()
                    }

                // Highlighted card at captured position
                ToDoItemHighlightedCard(
                    item: item,
                    onToggle: onToggle
                )
                .frame(width: cardWidth, height: frame.height)
                .position(
                    x: panelSize.width / 2,
                    y: localCardY
                )
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)

                // Options menu - positioned above or below card based on available space
                VStack(spacing: 0) {
                    if let moveUp = onMoveUp {
                        Button(action: {
                            moveUp()
                            onDismiss()
                        }) {
                            HStack {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16))
                                    .foregroundColor(.textPrimary)
                                    .frame(width: 24)
                                Text("Move Up")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, AppDimensions.cardPadding)
                            .padding(.vertical, 16)
                            .background(Color.cardBackground)
                        }

                        Divider()
                            .background(Color.textSecondary.opacity(0.2))
                    }

                    if let moveDown = onMoveDown {
                        Button(action: {
                            moveDown()
                            onDismiss()
                        }) {
                            HStack {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 16))
                                    .foregroundColor(.textPrimary)
                                    .frame(width: 24)
                                Text("Move Down")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, AppDimensions.cardPadding)
                            .padding(.vertical, 16)
                            .background(Color.cardBackground)
                        }

                        Divider()
                            .background(Color.textSecondary.opacity(0.2))
                    }

                    Button(action: {
                        onDelete()
                        onDismiss()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("Delete")
                                .font(.appBody)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal, AppDimensions.cardPadding)
                        .padding(.vertical, 16)
                        .background(Color.cardBackground)
                    }

                    Divider()
                        .background(Color.textSecondary.opacity(0.2))

                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "xmark")
                                .font(.system(size: 16))
                                .foregroundColor(.textSecondary)
                                .frame(width: 24)
                            Text("Cancel")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, AppDimensions.cardPadding)
                        .padding(.vertical, 16)
                        .background(Color.cardBackground)
                    }
                }
                .frame(width: menuWidth)
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                .scaleEffect(menuScale)
                .opacity(menuOpacity)
                .position(
                    x: panelSize.width - menuWidth / 2 - adaptiveScreenPadding,
                    y: menuYPosition
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                menuScale = 1.0
                menuOpacity = 1.0
            }
        }
    }

    private func calculateMenuYPosition(localCardMinY: CGFloat, localCardMaxY: CGFloat, screenHeight: CGFloat) -> CGFloat {
        // Estimate menu height based on number of buttons
        var estimatedMenuHeight: CGFloat = 52 * 2 // Delete and Cancel buttons always present
        if onMoveUp != nil {
            estimatedMenuHeight += 52
        }
        if onMoveDown != nil {
            estimatedMenuHeight += 52
        }

        let menuGap: CGFloat = 12
        let topSafeArea: CGFloat = 60 // Account for header/safe area

        // Try to position above the card first
        let aboveCardY = localCardMinY - menuGap - (estimatedMenuHeight / 2)

        // Check if there's enough room above
        if aboveCardY - (estimatedMenuHeight / 2) > topSafeArea {
            return aboveCardY
        } else {
            // Not enough room above, position below
            return localCardMaxY + menuGap + (estimatedMenuHeight / 2)
        }
    }
}

// Card component for the highlighted overlay
struct ToDoItemHighlightedCard: View {
    let item: ToDoItem
    let onToggle: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        HStack(spacing: 12) {
            // Animated Checkbox
            Button(action: onToggle) {
                ZStack {
                    // Border/Background
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(item.isCompleted ? Color.accentYellow : Color.textSecondary.opacity(0.5), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    // Fill when checked
                    RoundedRectangle(cornerRadius: 5)
                        .fill(item.isCompleted ? Color.accentYellow : Color.clear)
                        .frame(width: 20, height: 20)

                    // Checkmark
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Text (not editable in overlay)
            Text(item.text.isEmpty ? "Enter item" : item.text)
                .font(.appBody)
                .foregroundColor(item.isCompleted ? .textSecondary : .textPrimary)
                .strikethrough(item.isCompleted, color: .textSecondary)

            Spacer()

            // Ellipsis icon to match original card
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)
                .frame(width: 44, height: 44)
        }
        .padding(AppDimensions.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .fill(Color.cardBackground)
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(appAccentColor, lineWidth: 3)
            }
        )
    }
}
