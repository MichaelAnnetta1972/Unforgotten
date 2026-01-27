import SwiftUI
import SwiftData

// MARK: - Local Useful Contact Model
/// SwiftData model for UsefulContact, stored locally for offline support
@Model
final class LocalUsefulContact {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var name: String
    var category: String  // Store as raw value
    var companyName: String?
    var phone: String?
    var email: String?
    var website: String?
    var address: String?
    var notes: String?
    var isFavourite: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        name: String,
        category: String,
        companyName: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        isFavourite: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.name = name
        self.category = category
        self.companyName = companyName
        self.phone = phone
        self.email = email
        self.website = website
        self.address = address
        self.notes = notes
        self.isFavourite = isFavourite
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: UsefulContact) {
        self.init(
            id: remote.id,
            accountId: remote.accountId,
            name: remote.name,
            category: remote.category.rawValue,
            companyName: remote.companyName,
            phone: remote.phone,
            email: remote.email,
            website: remote.website,
            address: remote.address,
            notes: remote.notes,
            isFavourite: remote.isFavourite,
            sortOrder: remote.sortOrder,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> UsefulContact {
        UsefulContact(
            id: id,
            accountId: accountId,
            name: name,
            category: ContactCategory(rawValue: category) ?? .other,
            companyName: companyName,
            phone: phone,
            email: email,
            website: website,
            address: address,
            notes: notes,
            isFavourite: isFavourite,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: UsefulContact) {
        self.accountId = remote.accountId
        self.name = remote.name
        self.category = remote.category.rawValue
        self.companyName = remote.companyName
        self.phone = remote.phone
        self.email = remote.email
        self.website = remote.website
        self.address = remote.address
        self.notes = remote.notes
        self.isFavourite = remote.isFavourite
        self.sortOrder = remote.sortOrder
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
    var contactCategory: ContactCategory {
        get { ContactCategory(rawValue: category) ?? .other }
        set { category = newValue.rawValue }
    }
}
