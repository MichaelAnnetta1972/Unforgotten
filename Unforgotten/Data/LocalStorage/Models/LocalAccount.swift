import SwiftUI
import SwiftData

// MARK: - Local Account Model
/// SwiftData model for Account, stored locally for offline support
@Model
final class LocalAccount {
    // MARK: - Core Properties
    var id: UUID
    var ownerUserId: UUID
    var displayName: String
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        ownerUserId: UUID,
        displayName: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: Account) {
        self.init(
            id: remote.id,
            ownerUserId: remote.ownerUserId,
            displayName: remote.displayName,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> Account {
        Account(
            id: id,
            ownerUserId: ownerUserId,
            displayName: displayName,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: Account) {
        self.ownerUserId = remote.ownerUserId
        self.displayName = remote.displayName
        self.createdAt = remote.createdAt
        self.updatedAt = remote.updatedAt
        self.isSynced = true
    }

    // MARK: - Sync Helpers
    func markAsModified() {
        self.updatedAt = Date()
        self.isSynced = false
    }
}
