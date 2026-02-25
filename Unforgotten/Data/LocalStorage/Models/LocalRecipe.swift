import SwiftUI
import SwiftData

// MARK: - Local Recipe Model
/// SwiftData model for Recipe, stored locally for offline support
@Model
final class LocalRecipe {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var name: String
    var websiteUrl: String?
    var imageUrl: String?
    var mealType: String?
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
        websiteUrl: String? = nil,
        imageUrl: String? = nil,
        mealType: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.name = name
        self.websiteUrl = websiteUrl
        self.imageUrl = imageUrl
        self.mealType = mealType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: Recipe) {
        self.init(
            id: remote.id,
            accountId: remote.accountId,
            name: remote.name,
            websiteUrl: remote.websiteUrl,
            imageUrl: remote.imageUrl,
            mealType: remote.mealType?.rawValue,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> Recipe {
        Recipe(
            id: id,
            accountId: accountId,
            name: name,
            websiteUrl: websiteUrl,
            imageUrl: imageUrl,
            mealType: mealType.flatMap { MealType(rawValue: $0) },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: Recipe) {
        self.accountId = remote.accountId
        self.name = remote.name
        self.websiteUrl = remote.websiteUrl
        self.imageUrl = remote.imageUrl
        self.mealType = remote.mealType?.rawValue
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
