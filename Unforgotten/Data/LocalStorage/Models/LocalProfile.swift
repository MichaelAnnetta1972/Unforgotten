import SwiftUI
import SwiftData

// MARK: - Local Profile Model
/// SwiftData model for Profile, stored locally for offline support
@Model
final class LocalProfile {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var type: String  // Store as raw value
    var fullName: String
    var preferredName: String?
    var relationship: String?
    var connectedToProfileId: UUID?
    var includeInFamilyTree: Bool
    var birthday: Date?
    var isDeceased: Bool
    var dateOfDeath: Date?
    var address: String?
    var phone: String?
    var email: String?
    var notes: String?
    var isFavourite: Bool
    var linkedUserId: UUID?
    var photoUrl: String?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Profile Sync Properties (for connected profiles)
    var sourceUserId: UUID?
    var syncedFields: [String]?
    var isLocalOnly: Bool
    var syncConnectionId: UUID?

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        type: String,
        fullName: String,
        preferredName: String? = nil,
        relationship: String? = nil,
        connectedToProfileId: UUID? = nil,
        includeInFamilyTree: Bool = true,
        birthday: Date? = nil,
        isDeceased: Bool = false,
        dateOfDeath: Date? = nil,
        address: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        notes: String? = nil,
        isFavourite: Bool = false,
        linkedUserId: UUID? = nil,
        photoUrl: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceUserId: UUID? = nil,
        syncedFields: [String]? = nil,
        isLocalOnly: Bool = false,
        syncConnectionId: UUID? = nil,
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.type = type
        self.fullName = fullName
        self.preferredName = preferredName
        self.relationship = relationship
        self.connectedToProfileId = connectedToProfileId
        self.includeInFamilyTree = includeInFamilyTree
        self.birthday = birthday
        self.isDeceased = isDeceased
        self.dateOfDeath = dateOfDeath
        self.address = address
        self.phone = phone
        self.email = email
        self.notes = notes
        self.isFavourite = isFavourite
        self.linkedUserId = linkedUserId
        self.photoUrl = photoUrl
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceUserId = sourceUserId
        self.syncedFields = syncedFields
        self.isLocalOnly = isLocalOnly
        self.syncConnectionId = syncConnectionId
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: Profile) {
        self.init(
            id: remote.id,
            accountId: remote.accountId,
            type: remote.type.rawValue,
            fullName: remote.fullName,
            preferredName: remote.preferredName,
            relationship: remote.relationship,
            connectedToProfileId: remote.connectedToProfileId,
            includeInFamilyTree: remote.includeInFamilyTree,
            birthday: remote.birthday,
            isDeceased: remote.isDeceased,
            dateOfDeath: remote.dateOfDeath,
            address: remote.address,
            phone: remote.phone,
            email: remote.email,
            notes: remote.notes,
            isFavourite: remote.isFavourite,
            linkedUserId: remote.linkedUserId,
            photoUrl: remote.photoUrl,
            sortOrder: remote.sortOrder,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            sourceUserId: remote.sourceUserId,
            syncedFields: remote.syncedFields,
            isLocalOnly: remote.isLocalOnly,
            syncConnectionId: remote.syncConnectionId,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> Profile {
        Profile(
            id: id,
            accountId: accountId,
            type: ProfileType(rawValue: type) ?? .other,
            fullName: fullName,
            preferredName: preferredName,
            relationship: relationship,
            connectedToProfileId: connectedToProfileId,
            includeInFamilyTree: includeInFamilyTree,
            birthday: birthday,
            isDeceased: isDeceased,
            dateOfDeath: dateOfDeath,
            address: address,
            phone: phone,
            email: email,
            notes: notes,
            isFavourite: isFavourite,
            linkedUserId: linkedUserId,
            photoUrl: photoUrl,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sourceUserId: sourceUserId,
            syncedFields: syncedFields,
            isLocalOnly: isLocalOnly,
            syncConnectionId: syncConnectionId
        )
    }

    // MARK: - Update from Remote
    func update(from remote: Profile) {
        self.accountId = remote.accountId
        self.type = remote.type.rawValue
        self.fullName = remote.fullName
        self.preferredName = remote.preferredName
        self.relationship = remote.relationship
        self.connectedToProfileId = remote.connectedToProfileId
        self.includeInFamilyTree = remote.includeInFamilyTree
        self.birthday = remote.birthday
        self.isDeceased = remote.isDeceased
        self.dateOfDeath = remote.dateOfDeath
        self.address = remote.address
        self.phone = remote.phone
        self.email = remote.email
        self.notes = remote.notes
        self.isFavourite = remote.isFavourite
        self.linkedUserId = remote.linkedUserId
        self.photoUrl = remote.photoUrl
        self.sortOrder = remote.sortOrder
        self.createdAt = remote.createdAt
        self.updatedAt = remote.updatedAt
        self.sourceUserId = remote.sourceUserId
        self.syncedFields = remote.syncedFields
        self.isLocalOnly = remote.isLocalOnly
        self.syncConnectionId = remote.syncConnectionId
        self.isSynced = true
    }

    // MARK: - Sync Helpers
    func markAsModified() {
        self.updatedAt = Date()
        self.isSynced = false
    }

    // MARK: - Computed Properties
    var profileType: ProfileType {
        get { ProfileType(rawValue: type) ?? .other }
        set { type = newValue.rawValue }
    }

    var displayName: String {
        preferredName ?? fullName
    }
}
