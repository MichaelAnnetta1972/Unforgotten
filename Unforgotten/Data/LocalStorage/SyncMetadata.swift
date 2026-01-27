import SwiftUI
import SwiftData

// MARK: - Sync Metadata Model
/// Tracks the last sync timestamp for each entity type per account
@Model
final class SyncMetadata {
    // MARK: - Properties
    var id: UUID
    var accountId: UUID
    var entityType: String
    var lastSyncedAt: Date?
    var lastServerTimestamp: Date?  // For incremental sync

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        entityType: String,
        lastSyncedAt: Date? = nil,
        lastServerTimestamp: Date? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.entityType = entityType
        self.lastSyncedAt = lastSyncedAt
        self.lastServerTimestamp = lastServerTimestamp
    }

    // MARK: - Update Methods

    /// Update the last sync timestamp
    func updateSyncTimestamp() {
        lastSyncedAt = Date()
    }

    /// Update the last server timestamp (for incremental sync)
    func updateServerTimestamp(_ timestamp: Date) {
        lastServerTimestamp = timestamp
    }

    // MARK: - Entity Types
    static let allEntityTypes: [String] = [
        "account",
        "accountMember",
        "profile",
        "profileDetail",
        "profileConnection",
        "medication",
        "medicationSchedule",
        "medicationLog",
        "appointment",
        "usefulContact",
        "toDoList",
        "toDoItem",
        "countdown",
        "stickyReminder",
        "moodEntry",
        "importantAccount"
    ]

    // MARK: - Convenience Methods

    /// Create metadata entries for all entity types for a given account
    static func createAllForAccount(accountId: UUID) -> [SyncMetadata] {
        allEntityTypes.map { entityType in
            SyncMetadata(accountId: accountId, entityType: entityType)
        }
    }
}
