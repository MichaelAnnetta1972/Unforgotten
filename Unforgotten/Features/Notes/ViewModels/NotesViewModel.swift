import SwiftUI
import SwiftData
import Combine

// MARK: - Notes View Model
/// Manages notes business logic and state
@MainActor
final class NotesViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var selectedTheme: NoteTheme?
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var error: String?

    // Editing state
    @Published var editingNote: LocalNote?
    @Published var isCreatingNote = false

    // MARK: - Sync Service

    let syncService = NotesSyncService()

    // MARK: - Computed Properties

    /// Filter predicate based on selected theme and search text
    var filterPredicate: Predicate<LocalNote>? {
        if let theme = selectedTheme {
            let themeValue = theme.rawValue
            if !searchText.isEmpty {
                return #Predicate<LocalNote> { note in
                    note.theme == themeValue &&
                    (note.title.localizedStandardContains(searchText) ||
                     note.contentPlainText.localizedStandardContains(searchText))
                }
            } else {
                return #Predicate<LocalNote> { note in
                    note.theme == themeValue
                }
            }
        } else if !searchText.isEmpty {
            return #Predicate<LocalNote> { note in
                note.title.localizedStandardContains(searchText) ||
                note.contentPlainText.localizedStandardContains(searchText)
            }
        }
        return nil
    }

    // MARK: - Note Operations

    /// Create a new note
    func createNote(in context: ModelContext, accountId: UUID? = nil) -> LocalNote {
        let note = LocalNote(title: "", theme: .standard, accountId: accountId)
        context.insert(note)
        return note
    }

    /// Delete a note
    func deleteNote(_ note: LocalNote, in context: ModelContext) async {
        // Delete from remote if synced
        if let remoteId = note.supabaseId {
            do {
                try await syncService.deleteRemote(id: remoteId)
            } catch {
                #if DEBUG
                print("Failed to delete remote note: \(error)")
                #endif
            }
        }

        // Delete locally
        context.delete(note)

        do {
            try context.save()
        } catch {
            self.error = "Failed to delete note: \(error.localizedDescription)"
        }
    }

    /// Duplicate a note
    func duplicateNote(_ note: LocalNote, in context: ModelContext) -> LocalNote {
        let duplicate = LocalNote(
            title: note.title + " (Copy)",
            theme: note.noteTheme,
            accountId: note.accountId
        )
        duplicate.content = note.content
        duplicate.contentPlainText = note.contentPlainText
        duplicate.isPinned = false

        context.insert(duplicate)

        do {
            try context.save()
        } catch {
            self.error = "Failed to duplicate note: \(error.localizedDescription)"
        }

        return duplicate
    }

    /// Toggle pin status
    func togglePin(_ note: LocalNote, in context: ModelContext) {
        note.isPinned.toggle()
        note.markAsModified()

        do {
            try context.save()
            // Queue sync
            Task {
                try? await syncService.sync(note)
            }
        } catch {
            self.error = "Failed to update note: \(error.localizedDescription)"
        }
    }

    /// Update note theme
    func updateTheme(_ theme: NoteTheme, for note: LocalNote, in context: ModelContext) {
        note.noteTheme = theme
        note.markAsModified()

        do {
            try context.save()
            Task {
                try? await syncService.sync(note)
            }
        } catch {
            self.error = "Failed to update theme: \(error.localizedDescription)"
        }
    }

    /// Save note changes with debouncing
    func saveNote(_ note: LocalNote, in context: ModelContext) {
        note.markAsModified()

        do {
            try context.save()
            // Queue sync (debounced in sync service)
            Task {
                try? await syncService.sync(note)
            }
        } catch {
            self.error = "Failed to save note: \(error.localizedDescription)"
        }
    }

    // MARK: - Sync Operations

    /// Sync all pending notes
    func syncAll(notes: [LocalNote]) async {
        isLoading = true
        do {
            try await syncService.syncPendingNotes(notes)
        } catch {
            self.error = "Sync failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Fetch and merge remote changes
    func fetchRemoteChanges(in context: ModelContext, accountId: UUID) async {
        isLoading = true
        do {
            let remoteNotes = try await syncService.fetchRemoteChanges(since: syncService.lastSyncDate, accountId: accountId)
            try await syncService.mergeRemoteNotes(remoteNotes, into: context)
        } catch {
            self.error = "Failed to fetch changes: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }
}

// MARK: - Notes Sort Options
enum NotesSortOption: String, CaseIterable {
    case dateModified = "Date Modified"
    case dateCreated = "Date Created"
    case title = "Title"
}
