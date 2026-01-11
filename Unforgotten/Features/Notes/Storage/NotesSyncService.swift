import SwiftUI
import SwiftData

// MARK: - Notes Sync Service Protocol
/// Protocol defining sync operations for notes
protocol NotesSyncServiceProtocol {
    /// Sync a single note to Supabase (with debounce)
    func sync(_ note: LocalNote) async throws

    /// Sync a single note immediately without debounce (for use when view is disappearing)
    func syncImmediately(_ note: LocalNote) async throws

    /// Sync all pending notes
    func syncPendingNotes(_ notes: [LocalNote]) async throws

    /// Fetch remote changes since last sync for a specific account
    func fetchRemoteChanges(since: Date?, accountId: UUID) async throws -> [RemoteNote]

    /// Delete a note from remote
    func deleteRemote(id: String) async throws

    /// Current sync status
    var status: SyncServiceStatus { get }
}

// MARK: - Sync Service Status
enum SyncServiceStatus: Equatable {
    case idle
    case syncing(progress: Double)
    case completed(syncedCount: Int)
    case failed(error: String)

    var isActive: Bool {
        if case .syncing = self { return true }
        return false
    }
}

// MARK: - Remote Note DTO
/// Data transfer object for notes from Supabase
struct RemoteNote: Codable, Identifiable {
    let id: String
    let accountId: UUID
    let userId: String
    let localId: UUID
    let title: String
    let content: String?
    let contentPlainText: String
    let theme: String
    let isPinned: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case userId = "user_id"
        case localId = "local_id"
        case title
        case content
        case contentPlainText = "content_plain_text"
        case theme
        case isPinned = "is_pinned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    /// Get content as Data (Base64 decoded)
    var contentData: Data? {
        guard let content = content else { return nil }
        return Data(base64Encoded: content)
    }
}

// MARK: - Note Insert DTO (for Supabase)
struct RemoteNoteInsert: Encodable {
    let accountId: UUID
    let userId: String
    let localId: UUID
    let title: String
    let content: String?
    let contentPlainText: String
    let theme: String
    let isPinned: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case userId = "user_id"
        case localId = "local_id"
        case title
        case content
        case contentPlainText = "content_plain_text"
        case theme
        case isPinned = "is_pinned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from note: LocalNote, userId: String) throws {
        guard let accountId = note.accountId else {
            throw NotesSyncError.missingAccountId
        }
        self.accountId = accountId
        self.userId = userId
        self.localId = note.id
        self.title = note.title
        self.content = note.content.isEmpty ? nil : note.content.base64EncodedString()
        self.contentPlainText = note.contentPlainText
        self.theme = note.theme
        self.isPinned = note.isPinned
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
    }
}

// MARK: - Notes Sync Error
enum NotesSyncError: LocalizedError {
    case missingAccountId
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .missingAccountId:
            return "Note is missing account ID and cannot be synced"
        case .notAuthenticated:
            return "User is not authenticated"
        }
    }
}

// MARK: - Note Update DTO (for Supabase)
struct RemoteNoteUpdate: Encodable {
    let title: String
    let content: String?
    let contentPlainText: String
    let theme: String
    let isPinned: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case title
        case content
        case contentPlainText = "content_plain_text"
        case theme
        case isPinned = "is_pinned"
        case updatedAt = "updated_at"
    }

    init(from note: LocalNote) {
        self.title = note.title
        self.content = note.content.isEmpty ? nil : note.content.base64EncodedString()
        self.contentPlainText = note.contentPlainText
        self.theme = note.theme
        self.isPinned = note.isPinned
        self.updatedAt = note.updatedAt
    }
}

// MARK: - Notes Sync Service Implementation
/// Handles syncing notes between SwiftData and Supabase
@MainActor
final class NotesSyncService: ObservableObject, NotesSyncServiceProtocol {
    // MARK: - Properties

    @Published private(set) var status: SyncServiceStatus = .idle
    @Published private(set) var lastSyncDate: Date?

    private let supabase = SupabaseManager.shared.client
    private let tableName = "notes"

    // Debounce timer for batching sync requests
    private var syncDebounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.5

    // MARK: - Sync Operations

    /// Cancel any pending sync operations
    func cancelPendingSync() {
        syncDebounceTask?.cancel()
        syncDebounceTask = nil
    }

    /// Sync a single note to Supabase (with debounce for typing)
    func sync(_ note: LocalNote) async throws {
        // Cancel any pending debounced sync
        syncDebounceTask?.cancel()

        // Capture note data immediately on main actor before debounce
        // This prevents accessing SwiftData model after view dismissal
        let remoteId = note.supabaseId
        let noteId = note.id

        // Get userId now while we're on main actor
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw NotesSyncError.notAuthenticated
        }

        // Create DTOs now while note is still valid
        let updateDTO: RemoteNoteUpdate?
        let insertDTO: RemoteNoteInsert?

        if remoteId != nil {
            updateDTO = RemoteNoteUpdate(from: note)
            insertDTO = nil
        } else {
            updateDTO = nil
            insertDTO = try RemoteNoteInsert(from: note, userId: userId.uuidString)
        }

        // Start new debounced sync with captured data
        // NOTE: We don't update the local note's supabaseId here to avoid
        // accessing the SwiftData model after view dismissal (causes freeze).
        // The supabaseId will be synced on next fetch via mergeRemoteNotes.
        syncDebounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            do {
                try await performSyncWithoutCallback(
                    noteId: noteId,
                    remoteId: remoteId,
                    updateDTO: updateDTO,
                    insertDTO: insertDTO
                )
            } catch {
                #if DEBUG
                print("Sync error: \(error)")
                #endif
            }
        }
    }

    /// Sync a single note immediately without debounce (for use when view is disappearing)
    func syncImmediately(_ note: LocalNote) async throws {
        // Cancel any pending debounced sync since we're doing an immediate sync
        syncDebounceTask?.cancel()

        // Capture note data immediately on main actor
        let remoteId = note.supabaseId
        let noteId = note.id

        // Get userId now while we're on main actor
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw NotesSyncError.notAuthenticated
        }

        // Create DTOs now while note is still valid
        let updateDTO: RemoteNoteUpdate?
        let insertDTO: RemoteNoteInsert?

        if remoteId != nil {
            updateDTO = RemoteNoteUpdate(from: note)
            insertDTO = nil
        } else {
            updateDTO = nil
            insertDTO = try RemoteNoteInsert(from: note, userId: userId.uuidString)
        }

        // Perform sync immediately without debounce
        try await performSyncWithoutCallback(
            noteId: noteId,
            remoteId: remoteId,
            updateDTO: updateDTO,
            insertDTO: insertDTO
        )
    }

    /// Performs sync without callback - safe for use when note view may be dismissed
    private func performSyncWithoutCallback(
        noteId: UUID,
        remoteId: String?,
        updateDTO: RemoteNoteUpdate?,
        insertDTO: RemoteNoteInsert?
    ) async throws {
        // Check for cancellation before starting
        guard !Task.isCancelled else { return }

        status = .syncing(progress: 0.5)

        if let remoteId = remoteId, let update = updateDTO {
            // Update existing note
            try await supabase
                .from(tableName)
                .update(update)
                .eq("id", value: remoteId)
                .execute()
        } else if let insert = insertDTO {
            // Insert new note - supabaseId will be synced on next fetch
            try await supabase
                .from(tableName)
                .insert(insert)
                .execute()
        }

        // Check for cancellation before updating status
        guard !Task.isCancelled else { return }

        status = .completed(syncedCount: 1)
        lastSyncDate = Date()

        // Reset status after a delay
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            if case .completed = self?.status {
                self?.status = .idle
            }
        }
    }

    /// Sync all pending notes
    func syncPendingNotes(_ notes: [LocalNote]) async throws {
        let pendingNotes = notes.filter { !$0.isSynced }
        guard !pendingNotes.isEmpty else {
            status = .idle
            return
        }

        // Get userId once for all notes
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw NotesSyncError.notAuthenticated
        }

        status = .syncing(progress: 0)
        var syncedCount = 0

        for (index, note) in pendingNotes.enumerated() {
            let progress = Double(index) / Double(pendingNotes.count)
            status = .syncing(progress: progress)

            // Capture note data immediately
            let remoteId = note.supabaseId
            let noteId = note.id

            let updateDTO: RemoteNoteUpdate?
            let insertDTO: RemoteNoteInsert?

            if remoteId != nil {
                updateDTO = RemoteNoteUpdate(from: note)
                insertDTO = nil
            } else {
                updateDTO = nil
                insertDTO = try RemoteNoteInsert(from: note, userId: userId.uuidString)
            }

            // Use the safe sync method that doesn't hold note references
            try await performSyncWithoutCallback(
                noteId: noteId,
                remoteId: remoteId,
                updateDTO: updateDTO,
                insertDTO: insertDTO
            )
            syncedCount += 1
        }

        status = .completed(syncedCount: syncedCount)
        lastSyncDate = Date()

        // Reset status after a delay
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if case .completed = status {
                status = .idle
            }
        }
    }

    /// Fetch remote changes since last sync for a specific account
    func fetchRemoteChanges(since: Date?, accountId: UUID) async throws -> [RemoteNote] {
        // Always fetch all notes for the account to ensure full sync
        // The merge logic handles duplicates via last-write-wins
        let notes: [RemoteNote] = try await supabase
            .from(tableName)
            .select()
            .eq("account_id", value: accountId)
            .is("deleted_at", value: nil)
            .order("updated_at", ascending: false)
            .execute()
            .value

        return notes
    }

    /// Delete a note from remote
    func deleteRemote(id: String) async throws {
        // Soft delete by setting deleted_at
        try await supabase
            .from(tableName)
            .update(["deleted_at": Date().ISO8601Format()])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Merge Logic

    /// Merge remote notes into local storage (last-write-wins)
    func mergeRemoteNotes(_ remoteNotes: [RemoteNote], into context: ModelContext) async throws {
        for remote in remoteNotes {
            // Skip deleted notes
            if remote.deletedAt != nil { continue }

            // Find local note by local_id
            let descriptor = FetchDescriptor<LocalNote>(
                predicate: #Predicate { $0.id == remote.localId }
            )

            let localNotes = try context.fetch(descriptor)

            if let local = localNotes.first {
                // Compare timestamps - last write wins
                if remote.updatedAt > local.updatedAt {
                    local.title = remote.title
                    local.content = remote.contentData ?? Data()
                    local.contentPlainText = remote.contentPlainText
                    local.theme = remote.theme
                    local.isPinned = remote.isPinned
                    local.updatedAt = remote.updatedAt
                    local.accountId = remote.accountId
                    local.markAsSynced(remoteId: remote.id)
                }
            } else {
                // Create new local note from remote
                let newNote = LocalNote(
                    title: remote.title,
                    theme: NoteTheme(rawValue: remote.theme) ?? .standard,
                    accountId: remote.accountId
                )
                newNote.id = remote.localId
                newNote.content = remote.contentData ?? Data()
                newNote.contentPlainText = remote.contentPlainText
                newNote.isPinned = remote.isPinned
                newNote.createdAt = remote.createdAt
                newNote.updatedAt = remote.updatedAt
                newNote.markAsSynced(remoteId: remote.id)
                context.insert(newNote)
            }
        }

        try context.save()
    }
}

// MARK: - Mock Sync Service (for previews)
final class MockNotesSyncService: NotesSyncServiceProtocol {
    var status: SyncServiceStatus = .idle

    func sync(_ note: LocalNote) async throws {
        // Simulate sync delay
        try await Task.sleep(nanoseconds: 500_000_000)
        note.isSynced = true
    }

    func syncImmediately(_ note: LocalNote) async throws {
        // Immediate sync for mock - same as regular sync but no delay
        note.isSynced = true
    }

    func syncPendingNotes(_ notes: [LocalNote]) async throws {
        for note in notes {
            try await sync(note)
        }
    }

    func fetchRemoteChanges(since: Date?, accountId: UUID) async throws -> [RemoteNote] {
        return []
    }

    func deleteRemote(id: String) async throws {
        // No-op for mock
    }
}
