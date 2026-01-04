//
//  TypeSelectorChips.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import SwiftUI

struct TypeSelectorChips: View {
    let types: [ToDoListType]
    @Binding var selectedType: String?
    let onTypeSelected: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "None" option
                SelectableChip(
                    label: "None",
                    isSelected: selectedType == nil,
                    accentColor: appAccentColor,
                    action: {
                        selectedType = nil
                        onTypeSelected()
                    }
                )

                // Type chips
                ForEach(types) { type in
                    SelectableChip(
                        label: type.name,
                        isSelected: selectedType == type.name,
                        accentColor: appAccentColor,
                        action: {
                            selectedType = type.name
                            onTypeSelected()
                        }
                    )
                }
            }
        }
    }
}

struct SelectableChip: View {
    let label: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.appCaption)
                .foregroundColor(isSelected ? .white : .textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? accentColor : Color.cardBackground)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.textSecondary.opacity(0.3), lineWidth: 1)
                )
        }
    }
}
