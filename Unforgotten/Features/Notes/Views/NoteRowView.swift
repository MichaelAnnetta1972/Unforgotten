import SwiftUI
import SwiftData

// MARK: - Note Row View
/// List row component for displaying a note preview
struct NoteRowView: View {
    let note: LocalNote
    var onTap: () -> Void = {}
    var onDelete: () -> Void = {}
    var onTogglePin: () -> Void = {}
    var onDuplicate: (() -> Void)?
    var onChangeTheme: ((NoteTheme) -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Theme icon
                themeIcon

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title row
                    HStack(alignment: .center, spacing: 6) {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(note.noteTheme.accentColor)
                        }

                        Text(note.displayTitle)
                            .font(NoteTypography.listRowTitle)
                            .foregroundColor(.notePrimaryText)
                            .lineLimit(1)

                        Spacer()

                        NoteSyncBadge(isSynced: note.isSynced)
                    }

                    // Preview text
                    if !note.contentPlainText.isEmpty {
                        Text(note.previewContent)
                            .font(NoteTypography.listRowPreview)
                            .foregroundColor(.noteSecondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    // Date
                    Text(note.formattedDate)
                        .font(NoteTypography.listRowDate)
                        .foregroundColor(.noteTertiaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, NoteSpacing.listRowVertical)
            .padding(.horizontal, NoteSpacing.listRowPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onTogglePin()
            } label: {
                Label(
                    note.isPinned ? "Unpin" : "Pin",
                    systemImage: note.isPinned ? "pin.slash" : "pin"
                )
            }
            .tint(note.noteTheme.accentColor)
        }
        .contextMenu {
            contextMenuContent
        }
    }

    // MARK: - Theme Icon

    private var themeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(note.noteTheme.accentColor.opacity(0.15))
                .frame(width: 48, height: 48)

            Image(systemName: note.noteTheme.icon)
                .font(.system(size: NoteSpacing.themeIconSize, weight: .medium))
                .foregroundColor(note.noteTheme.accentColor)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            onTogglePin()
        } label: {
            Label(
                note.isPinned ? "Unpin" : "Pin to Top",
                systemImage: note.isPinned ? "pin.slash" : "pin"
            )
        }

        if let onDuplicate = onDuplicate {
            Button {
                onDuplicate()
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
        }

        if let onChangeTheme = onChangeTheme {
            Menu {
                ForEach(NoteTheme.allCases) { theme in
                    Button {
                        onChangeTheme(theme)
                    } label: {
                        Label(theme.displayName, systemImage: theme.icon)
                    }
                }
            } label: {
                Label("Change Theme", systemImage: "paintpalette")
            }
        }

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Compact Note Row (for search results)
struct CompactNoteRowView: View {
    let note: LocalNote
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: note.noteTheme.icon)
                    .font(.system(size: 14))
                    .foregroundColor(note.noteTheme.accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.displayTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.notePrimaryText)
                        .lineLimit(1)

                    Text(note.firstLine)
                        .font(.system(size: 13))
                        .foregroundColor(.noteSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Text(note.formattedDate)
                    .font(.system(size: 12))
                    .foregroundColor(.noteTertiaryText)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview("Note Row View") {
    List {
        NoteRowView(
            note: {
                let note = LocalNote(title: "Gift Ideas for Mom", theme: .festive)
                note.isPinned = true
                note.setPlainTextContent("Thinking about getting her a nice scarf this year. Maybe also a cookbook she mentioned.")
                return note
            }()
        )

        NoteRowView(
            note: {
                let note = LocalNote(title: "Grocery List", theme: .shopping)
                note.setPlainTextContent("☐ Milk\n☐ Eggs\n☐ Bread")
                return note
            }()
        )

        NoteRowView(
            note: {
                let note = LocalNote(title: "", theme: .standard)
                note.setPlainTextContent("Quick note without a title")
                return note
            }()
        )
    }
    .listStyle(.plain)
}
