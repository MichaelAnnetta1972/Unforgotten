//
//  TypeFilterChips.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import SwiftUI

struct TypeFilterChips: View {
    let types: [ToDoListType]
    @Binding var selectedType: String?
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                ToDoFilterChip(
                    label: "All",
                    isSelected: selectedType == nil,
                    accentColor: appAccentColor,
                    action: { selectedType = nil }
                )

                // Type chips
                ForEach(types) { type in
                    ToDoFilterChip(
                        label: type.name,
                        isSelected: selectedType == type.name,
                        accentColor: appAccentColor,
                        action: { selectedType = type.name }
                    )
                }
            }
        }
    }
}

struct ToDoFilterChip: View {
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
        }
    }
}
