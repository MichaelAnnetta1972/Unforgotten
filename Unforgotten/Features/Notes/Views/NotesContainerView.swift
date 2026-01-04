import SwiftUI
import SwiftData

// MARK: - Notes Container View
/// Container for Notes - uses iPhone view for both platforms
/// iPad layout is handled by iPadRootView with the Home sidebar
struct NotesContainerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NotesListView()
    }
}

// MARK: - iPad Notes View
struct iPadNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    @Query(sort: \LocalNote.updatedAt, order: .reverse)
    private var allNotes: [LocalNote]

    // Sync service for Supabase sync
    @StateObject private var syncService = NotesSyncService()

    @State private var selectedNote: LocalNote?
    @State private var searchText = ""
    @State private var filterTheme: NoteTheme?

    private var displayedNotes: [LocalNote] {
        var notes = allNotes

        // Filter by account
        if let accountId = appState.currentAccount?.id {
            notes = notes.filter { $0.accountId == accountId }
        }

        // Filter by theme
        if let theme = filterTheme {
            notes = notes.filter { $0.theme == theme.rawValue }
        }

        // Filter by search
        if !searchText.isEmpty {
            notes = notes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.contentPlainText.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort: pinned first, then by date
        return notes.sorted { first, second in
            if first.isPinned != second.isPinned {
                return first.isPinned
            }
            return first.updatedAt > second.updatedAt
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left pane - Notes list
            VStack(spacing: 0) {
                // Search and filter bar
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.textSecondary)
                        TextField("Search notes", text: $searchText)
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.cardBackground)
                    .cornerRadius(10)

                    Menu {
                        Button {
                            filterTheme = nil
                        } label: {
                            Label("All Themes", systemImage: filterTheme == nil ? "checkmark" : "")
                        }

                        Divider()

                        ForEach(NoteTheme.allCases, id: \.self) { theme in
                            Button {
                                filterTheme = theme
                            } label: {
                                Label(theme.displayName, systemImage: filterTheme == theme ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: filterTheme != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundColor(filterTheme != nil ? appAccentColor : .textSecondary)
                            .frame(width: 44, height: 44)
                            .background(Color.cardBackground)
                            .cornerRadius(10)
                    }

                    Button {
                        createNewNote()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(appAccentColor)
                            .cornerRadius(10)
                    }
                }
                .padding(16)

                // Notes list
                if displayedNotes.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "note.text")
                            .font(.system(size: 40))
                            .foregroundColor(.textSecondary)
                        Text(allNotes.isEmpty ? "No notes yet" : "No matching notes")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(displayedNotes) { note in
                                iPadNoteRowView(
                                    note: note,
                                    isSelected: selectedNote?.id == note.id,
                                    onSelect: { selectedNote = note },
                                    onDelete: { deleteNote(note) },
                                    onTogglePin: { note.isPinned.toggle() }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .frame(width: 320)
            .background(Color.appBackground)

            // Divider
            Rectangle()
                .fill(Color.cardBackgroundLight)
                .frame(width: 1)

            // Right pane - Note editor
            if let note = selectedNote {
                NoteEditorView(
                    note: note,
                    isNewNote: false,
                    onDelete: {
                        deleteNote(note)
                        selectedNote = nil
                    },
                    onSave: { }
                )
                .id(note.id)
            } else {
                VStack {
                    Spacer()
                    ContentUnavailableView(
                        "Select a Note",
                        systemImage: "note.text",
                        description: Text("Choose a note to view or edit")
                    )
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color.appBackground)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Fetch remote changes on appear
            await fetchRemoteChanges()
            // Sync any pending local notes
            await syncPendingNotes()
        }
    }

    private func createNewNote() {
        let note = LocalNote(
            title: "",
            theme: .standard,
            accountId: appState.currentAccount?.id
        )
        modelContext.insert(note)
        selectedNote = note
        // Don't sync immediately - the NoteEditorView will sync when the user
        // makes changes and navigates away or explicitly saves
    }

    private func deleteNote(_ note: LocalNote) {
        // Delete from Supabase if synced
        if let remoteId = note.supabaseId {
            Task {
                try? await syncService.deleteRemote(id: remoteId)
            }
        }
        modelContext.delete(note)
        if selectedNote?.id == note.id {
            selectedNote = nil
        }
    }

    private func fetchRemoteChanges() async {
        guard let accountId = appState.currentAccount?.id else {
            print("No current account for syncing notes")
            return
        }

        do {
            let remoteNotes = try await syncService.fetchRemoteChanges(since: syncService.lastSyncDate, accountId: accountId)
            if !remoteNotes.isEmpty {
                try await syncService.mergeRemoteNotes(remoteNotes, into: modelContext)
            }
        } catch {
            print("Failed to fetch remote notes: \(error)")
        }
    }

    private func syncPendingNotes() async {
        let pendingNotes = allNotes.filter { !$0.isSynced }
        if !pendingNotes.isEmpty {
            do {
                try await syncService.syncPendingNotes(pendingNotes)
            } catch {
                print("Failed to sync pending notes: \(error)")
            }
        }
    }
}

// MARK: - iPad Note Row View
struct iPadNoteRowView: View {
    @Bindable var note: LocalNote
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Theme color indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(note.noteTheme.accentColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(appAccentColor)
                        }

                        Text(note.displayTitle)
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                    }

                    Text(note.previewContent)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)

                    HStack {
                        Text(note.noteTheme.displayName)
                            .font(.appCaptionSmall)
                            .foregroundColor(note.noteTheme.accentColor)

                        Spacer()

                        Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.appCaptionSmall)
                            .foregroundColor(.textMuted)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(isSelected ? appAccentColor.opacity(0.15) : Color.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? appAccentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .contextMenu {
            Button {
                onTogglePin()
            } label: {
                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Notes Feature Entry Point
/// Main entry point for the Notes feature
/// Note: On iPad, the modelContainer is provided by iPadRootView at the root level
/// On iPhone, this view provides the container
struct NotesFeatureView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Check if we're in iPad mode (regular size class)
    private var isiPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        if isiPad {
            // iPad: Use shared container from iPadRootView
            NotesContainerView()
        } else {
            // iPhone: Create local container
            NotesContainerView()
                .modelContainer(for: LocalNote.self)
        }
    }
}

// MARK: - Notes Navigation Destination
/// Wrapper for navigation to notes from the main app
struct NotesNavigationDestination: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NotesFeatureView()
            .navigationBarHidden(true)
    }
}

// MARK: - Add Note Sheet
/// Standalone sheet for creating a new note from anywhere in the app
struct AddNoteSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let accountId: UUID?
    var onDismiss: (() -> Void)? = nil

    @State private var note: LocalNote?

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        ZStack {
            if let note = note {
                NoteEditorView(
                    note: note,
                    isNewNote: true,
                    onDelete: {
                        // Delete and dismiss
                        if let noteToDelete = self.note {
                            modelContext.delete(noteToDelete)
                        }
                        dismissView()
                    },
                    onSave: {
                        // Insert into context when saved
                        if let noteToSave = self.note {
                            modelContext.insert(noteToSave)
                        }
                        dismissView()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .onAppear {
                        // Create a new note (not inserted into context yet)
                        note = LocalNote(title: "", theme: .standard, accountId: accountId)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .scrollContentBackground(.hidden)
        .containerBackground(.clear, for: .navigation)
        .modelContainer(for: LocalNote.self)
    }
}

// MARK: - Preview
#Preview("Notes Container - iPhone") {
    let container = try! NotesContainerConfiguration.createPreviewContainer()

    return NotesContainerView()
        .modelContainer(container)
        .environmentObject(AppState())
        .onAppear {
            let context = container.mainContext
            _ = LocalNote.sampleNotes(in: context)
        }
}

#Preview("Notes Feature View") {
    NotesFeatureView()
        .environmentObject(AppState())
}
