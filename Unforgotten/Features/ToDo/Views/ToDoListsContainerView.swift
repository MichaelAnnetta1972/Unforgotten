//
//  ToDoListsContainerView.swift
//  Unforgotten
//
//  Container for To Do Lists - uses iPhone view for both platforms
//  iPad layout is handled by iPadRootView with the Home sidebar
//

import SwiftUI

/// Container for To Do Lists
/// Returns the iPhone ToDoListsView for both platforms
struct ToDoListsContainerView: View {
    @EnvironmentObject var appState: AppState

    let openAddSheetOnAppear: Bool

    init(openAddSheetOnAppear: Bool = false) {
        self.openAddSheetOnAppear = openAddSheetOnAppear
    }

    var body: some View {
        ToDoListsView(openAddSheetOnAppear: openAddSheetOnAppear)
    }
}

// MARK: - To Do List Row View (for iPad sidebar - kept for potential reuse)
struct ToDoListRowView: View {
    let list: ToDoList
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(list.title)
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)
                .lineLimit(1)

            HStack(spacing: 8) {
                if let type = list.listType {
                    Text(type)
                        .font(.appCaptionSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(appAccentColor.opacity(0.8))
                        .cornerRadius(4)
                }

                let itemCount = list.items.count
                let completedCount = list.items.filter { $0.isCompleted }.count

                Text("\(completedCount)/\(itemCount) items")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
