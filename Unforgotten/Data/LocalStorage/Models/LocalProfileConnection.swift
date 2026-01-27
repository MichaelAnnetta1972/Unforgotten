import SwiftUI
import SwiftData

// MARK: - Local Profile Connection Model
/// SwiftData model for ProfileConnection, stored locally for offline support
@Model
final class LocalProfileConnection {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var fromProfileId: UUID
    var toProfileId: UUID
    var relationshipType: String  // Store as raw value
    var createdAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        fromProfileId: UUID,
        toProfileId: UUID,
        relationshipType: String,
        createdAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.fromProfileId = fromProfileId
        self.toProfileId = toProfileId
        self.relationshipType = relationshipType
        self.createdAt = createdAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: ProfileConnection) {
        self.init(
            id: remote.id,
            accountId: remote.accountId,
            fromProfileId: remote.fromProfileId,
            toProfileId: remote.toProfileId,
            relationshipType: remote.relationshipType.rawValue,
            createdAt: remote.createdAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> ProfileConnection {
        ProfileConnection(
            id: id,
            accountId: accountId,
            fromProfileId: fromProfileId,
            toProfileId: toProfileId,
            relationshipType: ConnectionType(rawValue: relationshipType) ?? .other,
            createdAt: createdAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: ProfileConnection) {
        self.accountId = remote.accountId
        self.fromProfileId = remote.fromProfileId
        self.toProfileId = remote.toProfileId
        self.relationshipType = remote.relationshipType.rawValue
        self.createdAt = remote.createdAt
        self.isSynced = true
    }

    // MARK: - Computed Properties
    var connectionType: ConnectionType {
        get { ConnectionType(rawValue: relationshipType) ?? .other }
        set { relationshipType = newValue.rawValue }
    }
}
