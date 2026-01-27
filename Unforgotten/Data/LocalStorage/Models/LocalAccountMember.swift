import SwiftUI
import SwiftData

// MARK: - Local Account Member Model
/// SwiftData model for AccountMember, stored locally for offline support
@Model
final class LocalAccountMember {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var userId: UUID
    var role: String  // Store as raw value
    var createdAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        userId: UUID,
        role: String,
        createdAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.userId = userId
        self.role = role
        self.createdAt = createdAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: AccountMember) {
        self.init(
            id: remote.id,
            accountId: remote.accountId,
            userId: remote.userId,
            role: remote.role.rawValue,
            createdAt: remote.createdAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> AccountMember {
        AccountMember(
            id: id,
            accountId: accountId,
            userId: userId,
            role: MemberRole(rawValue: role) ?? .viewer,
            createdAt: createdAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: AccountMember) {
        self.accountId = remote.accountId
        self.userId = remote.userId
        self.role = remote.role.rawValue
        self.createdAt = remote.createdAt
        self.isSynced = true
    }

    // MARK: - Computed Properties
    var memberRole: MemberRole {
        get { MemberRole(rawValue: role) ?? .viewer }
        set { role = newValue.rawValue }
    }
}
