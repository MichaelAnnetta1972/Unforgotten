import SwiftUI

// MARK: - Filter Chip Bar
/// Horizontal scrolling filter bar for themes
struct NoteFilterChipBar: View {
    @Binding var selectedTheme: NoteTheme?
    var noteCounts: [NoteTheme: Int] = [:]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" filter chip
                NoteFilterChip(
                    title: "All",
                    icon: "note.text",
                    isSelected: selectedTheme == nil,
                    count: noteCounts.values.reduce(0, +)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTheme = nil
                    }
                }

                // Theme filter chips
                ForEach(NoteTheme.allCases) { theme in
                    NoteFilterChip(
                        title: theme.displayName,
                        icon: theme.icon,
                        isSelected: selectedTheme == theme,
                        accentColor: theme.accentColor,
                        count: noteCounts[theme] ?? 0
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if selectedTheme == theme {
                                selectedTheme = nil
                            } else {
                                selectedTheme = theme
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, NoteSpacing.listRowPadding)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Note Filter Chip
struct NoteFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var accentColor: Color = .blue
    var count: Int = 0
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))

                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? .white.opacity(0.3) : Color.noteSecondaryBackground)
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .notePrimaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? accentColor : Color.noteSecondaryBackground)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel("\(title), \(count) notes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview
#Preview("Filter Chip Bar") {
    struct PreviewWrapper: View {
        @State private var selectedTheme: NoteTheme?

        var body: some View {
            VStack(spacing: 20) {
                NoteFilterChipBar(
                    selectedTheme: $selectedTheme,
                    noteCounts: [
                        .standard: 5,
                        .festive: 3,
                        .work: 2,
                        .holidays: 1,
                        .shopping: 4,
                        .family: 2
                    ]
                )

                if let theme = selectedTheme {
                    Text("Filtering by: \(theme.displayName)")
                        .foregroundColor(theme.accentColor)
                } else {
                    Text("Showing all notes")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    return PreviewWrapper()
}
