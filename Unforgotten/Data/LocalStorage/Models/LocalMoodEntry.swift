import SwiftUI
import SwiftData

// MARK: - Local Mood Entry Model
/// SwiftData model for MoodEntry, stored locally for offline support
@Model
final class LocalMoodEntry {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var userId: UUID
    var date: Date
    var rating: Int
    var note: String?
    var createdAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        userId: UUID,
        date: Date = Date(),
        rating: Int,
        note: String? = nil,
        createdAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.userId = userId
        self.date = date
        self.rating = rating
        self.note = note
        self.createdAt = createdAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: MoodEntry) {
        self.init(
            id: remote.id,
            accountId: remote.accountId,
            userId: remote.userId,
            date: remote.date,
            rating: remote.rating,
            note: remote.note,
            createdAt: remote.createdAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> MoodEntry {
        MoodEntry(
            id: id,
            accountId: accountId,
            userId: userId,
            date: date,
            rating: rating,
            note: note,
            createdAt: createdAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: MoodEntry) {
        self.accountId = remote.accountId
        self.userId = remote.userId
        self.date = remote.date
        self.rating = remote.rating
        self.note = remote.note
        self.createdAt = remote.createdAt
        self.isSynced = true
    }

    // MARK: - Sync Helpers
    func markAsModified() {
        self.isSynced = false
    }
}
