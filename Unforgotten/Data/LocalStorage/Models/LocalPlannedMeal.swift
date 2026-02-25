import SwiftUI
import SwiftData

// MARK: - Local Planned Meal Model
/// SwiftData model for PlannedMeal, stored locally for offline support
@Model
final class LocalPlannedMeal {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var recipeId: UUID
    var date: Date
    var mealType: String // Store as raw value
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    // Denormalized for display
    var recipeName: String?

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        recipeId: UUID,
        date: Date,
        mealType: String = "breakfast",
        notes: String? = nil,
        recipeName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.recipeId = recipeId
        self.date = date
        self.mealType = mealType
        self.notes = notes
        self.recipeName = recipeName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: PlannedMeal) {
        self.init(
            id: remote.id,
            accountId: remote.accountId,
            recipeId: remote.recipeId,
            date: remote.date,
            mealType: remote.mealType.rawValue,
            notes: remote.notes,
            recipeName: remote.recipeName,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> PlannedMeal {
        PlannedMeal(
            id: id,
            accountId: accountId,
            recipeId: recipeId,
            date: date,
            mealType: MealType(rawValue: mealType) ?? .breakfast,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            recipeName: recipeName
        )
    }

    // MARK: - Update from Remote
    func update(from remote: PlannedMeal) {
        self.accountId = remote.accountId
        self.recipeId = remote.recipeId
        self.date = remote.date
        self.mealType = remote.mealType.rawValue
        self.notes = remote.notes
        self.recipeName = remote.recipeName
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
    var mealTypeEnum: MealType {
        get { MealType(rawValue: mealType) ?? .breakfast }
        set { mealType = newValue.rawValue }
    }
}
