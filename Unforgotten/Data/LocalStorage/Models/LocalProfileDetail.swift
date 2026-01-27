import SwiftUI
import SwiftData

// MARK: - Local Profile Detail Model
/// SwiftData model for ProfileDetail, stored locally for offline support
@Model
final class LocalProfileDetail {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var profileId: UUID
    var category: String  // Store as raw value
    var label: String
    var value: String
    var status: String?
    var occasion: String?
    var metadata: Data?  // Store as JSON data
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        profileId: UUID,
        category: String,
        label: String,
        value: String,
        status: String? = nil,
        occasion: String? = nil,
        metadata: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.profileId = profileId
        self.category = category
        self.label = label
        self.value = value
        self.status = status
        self.occasion = occasion
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: ProfileDetail) {
        let metadataData: Data?
        if let metadata = remote.metadata {
            metadataData = try? JSONEncoder().encode(metadata)
        } else {
            metadataData = nil
        }

        self.init(
            id: remote.id,
            accountId: remote.accountId,
            profileId: remote.profileId,
            category: remote.category.rawValue,
            label: remote.label,
            value: remote.value,
            status: remote.status,
            occasion: remote.occasion,
            metadata: metadataData,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> ProfileDetail {
        var metadataDict: [String: String]?
        if let metadata = metadata {
            metadataDict = try? JSONDecoder().decode([String: String].self, from: metadata)
        }

        return ProfileDetail(
            id: id,
            accountId: accountId,
            profileId: profileId,
            category: DetailCategory(rawValue: category) ?? .note,
            label: label,
            value: value,
            status: status,
            occasion: occasion,
            metadata: metadataDict,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: ProfileDetail) {
        self.accountId = remote.accountId
        self.profileId = remote.profileId
        self.category = remote.category.rawValue
        self.label = remote.label
        self.value = remote.value
        self.status = remote.status
        self.occasion = remote.occasion
        if let metadata = remote.metadata {
            self.metadata = try? JSONEncoder().encode(metadata)
        } else {
            self.metadata = nil
        }
        self.createdAt = remote.createdAt
        self.updatedAt = remote.updatedAt
        self.isSynced = true
    }

    // MARK: - Sync Helpers
    func markAsModified() {
        self.updatedAt = Date()
        self.isSynced = false
    }

    // MARK: - Computed Properties
    var detailCategory: DetailCategory {
        get { DetailCategory(rawValue: category) ?? .note }
        set { category = newValue.rawValue }
    }
}
