//
//  ToDoListCard.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import SwiftUI

struct ToDoListCard: View {
    let list: ToDoList
    var isSelected: Bool = false
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon - rounded square like Notes list
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(appAccentColor.opacity(isSelected ? 0.3 : 0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(appAccentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(list.title)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(list.listType ?? "Other")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Progress pill
            //Text(list.progressText)
            //    .font(.appCaption)
            //    .foregroundColor(.textSecondary)
            //    .padding(.horizontal, 12)
            //    .padding(.vertical, 6)
            //    .background(Color.cardBackgroundSoft)
            //    .cornerRadius(12)

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(.textSecondary)
        }
        .padding(AppDimensions.cardPadding)
        .background(isSelected ? appAccentColor.opacity(0.1) : Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                .stroke(isSelected ? appAccentColor : Color.clear, lineWidth: 2)
        )
    }
}
