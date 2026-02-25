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

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Note icon
                noteIcon

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title row
                    HStack(alignment: .center, spacing: 6) {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(appAccentColor)
                        }

                        Text(note.displayTitle)
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        NoteSyncBadge(isSynced: note.isSynced)
                    }

                    // Preview text
                    if !note.contentPlainText.isEmpty {
                        Text(note.previewContent)
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    // Date
                    Text(note.formattedDate)
                        .font(.appCaption)
                        .foregroundColor(.textMuted)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
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
            .tint(appAccentColor)
        }
        .contextMenu {
            contextMenuContent
        }
    }

    // MARK: - Note Icon

    private var noteIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(appAccentColor.opacity(0.15))
                .frame(width: 48, height: 48)

            Image(systemName: "note.text")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(appAccentColor)
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

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "note.text")
                    .font(.system(size: 14))
                    .foregroundColor(appAccentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.displayTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Text(note.firstLine)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(note.formattedDate)
                    .font(.system(size: 12))
                    .foregroundColor(.textMuted)
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
                let note = LocalNote(title: "Gift Ideas for Mom")
                note.isPinned = true
                note.setPlainTextContent("Thinking about getting her a nice scarf this year. Maybe also a cookbook she mentioned.")
                return note
            }()
        )

        NoteRowView(
            note: {
                let note = LocalNote(title: "Grocery List")
                note.setPlainTextContent("☐ Milk\n☐ Eggs\n☐ Bread")
                return note
            }()
        )

        NoteRowView(
            note: {
                let note = LocalNote(title: "")
                note.setPlainTextContent("Quick note without a title")
                return note
            }()
        )
    }
    .listStyle(.plain)
}
