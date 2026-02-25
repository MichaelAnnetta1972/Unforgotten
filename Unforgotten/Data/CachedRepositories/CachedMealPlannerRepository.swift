import SwiftUI
import SwiftData

// MARK: - Cached Meal Planner Repository
/// Provides offline-first access to Recipe and PlannedMeal data with background sync
@MainActor
final class CachedMealPlannerRepository {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let remoteRepository: MealPlannerRepository
    private let syncEngine: SyncEngine
    private let networkMonitor: NetworkMonitor

    // MARK: - Initialization
    init(modelContext: ModelContext, remoteRepository: MealPlannerRepository, syncEngine: SyncEngine, networkMonitor: NetworkMonitor = .shared) {
        self.modelContext = modelContext
        self.remoteRepository = remoteRepository
        self.syncEngine = syncEngine
        self.networkMonitor = networkMonitor
    }

    // MARK: - Recipe Read Operations

    /// Force refresh recipes from remote server and update local cache
    func refreshRecipesFromRemote(accountId: UUID) async throws -> [Recipe] {
        guard networkMonitor.isConnected else {
            return try await getRecipes(accountId: accountId)
        }

        let remoteRecipes = try await remoteRepository.getRecipes(accountId: accountId)

        for remote in remoteRecipes {
            let remoteId = remote.id
            let existingDescriptor = FetchDescriptor<LocalRecipe>(
                predicate: #Predicate { $0.id == remoteId }
            )

            if let existing = try modelContext.fetch(existingDescriptor).first {
                existing.update(from: remote)
            } else {
                let local = LocalRecipe(from: remote)
                modelContext.insert(local)
            }
        }

        // Remove locally cached items that no longer exist on server
        let remoteIds = Set(remoteRecipes.map { $0.id })
        let localDescriptor = FetchDescriptor<LocalRecipe>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted }
        )
        let localRecipes = try modelContext.fetch(localDescriptor)

        for local in localRecipes {
            if !remoteIds.contains(local.id) && local.isSynced {
                modelContext.delete(local)
            }
        }

        try? modelContext.save()
        return remoteRecipes
    }

    /// Get all recipes for an account, falling back to network if cache is empty
    func getRecipes(accountId: UUID) async throws -> [Recipe] {
        let descriptor = FetchDescriptor<LocalRecipe>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalRecipe>(\.name)]
        )

        let localRecipes = try modelContext.fetch(descriptor)

        if localRecipes.isEmpty && networkMonitor.isConnected {
            let remoteRecipes = try await remoteRepository.getRecipes(accountId: accountId)
            for remote in remoteRecipes {
                let remoteId = remote.id
                let existingDescriptor = FetchDescriptor<LocalRecipe>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                if try modelContext.fetch(existingDescriptor).isEmpty {
                    let local = LocalRecipe(from: remote)
                    modelContext.insert(local)
                }
            }
            try? modelContext.save()
            return remoteRecipes
        }

        return localRecipes.map { (local: LocalRecipe) in local.toRemote() }
    }

    // MARK: - Recipe Write Operations

    /// Create a new recipe
    func createRecipe(accountId: UUID, name: String, websiteUrl: String? = nil, imageUrl: String? = nil, mealType: MealType? = nil) async throws -> Recipe {
        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let insert = RecipeInsert(id: UUID(), accountId: accountId, name: name, websiteUrl: websiteUrl, imageUrl: imageUrl, mealType: mealType)
                let remote = try await remoteRepository.createRecipe(insert)
                let local = LocalRecipe(from: remote)
                modelContext.insert(local)
                try? modelContext.save()
                return remote
            } catch {
                print("[CachedMealPlannerRepo] Remote createRecipe failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: create locally and queue for sync
        let local = LocalRecipe(
            id: UUID(),
            accountId: accountId,
            name: name,
            websiteUrl: websiteUrl,
            imageUrl: imageUrl,
            mealType: mealType?.rawValue,
            isSynced: false
        )
        modelContext.insert(local)

        syncEngine.queueChange(
            entityType: "recipe",
            entityId: local.id,
            accountId: accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update a recipe
    func updateRecipe(_ recipe: Recipe) async throws -> Recipe {
        let recipeId = recipe.id
        let descriptor = FetchDescriptor<LocalRecipe>(
            predicate: #Predicate { $0.id == recipeId }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        local.name = recipe.name
        local.websiteUrl = recipe.websiteUrl
        local.imageUrl = recipe.imageUrl
        local.mealType = recipe.mealType?.rawValue
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let updated = try await remoteRepository.updateRecipe(recipe)
                local.isSynced = true
                try modelContext.save()
                return updated
            } catch {
                print("[CachedMealPlannerRepo] Remote updateRecipe failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "recipe",
            entityId: recipe.id,
            accountId: recipe.accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Delete a recipe
    func deleteRecipe(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalRecipe>(
            predicate: #Predicate { $0.id == id }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        local.locallyDeleted = true
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.deleteRecipe(id: id)
                local.isSynced = true
                try modelContext.save()
                return
            } catch {
                print("[CachedMealPlannerRepo] Remote deleteRecipe failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "recipe",
            entityId: id,
            accountId: local.accountId,
            changeType: .delete
        )

        try modelContext.save()
    }

    // MARK: - Planned Meal Read Operations

    /// Force refresh planned meals from remote server and update local cache
    func refreshPlannedMealsFromRemote(accountId: UUID) async throws -> [PlannedMeal] {
        guard networkMonitor.isConnected else {
            return try await getPlannedMeals(accountId: accountId)
        }

        let remoteMeals = try await remoteRepository.getPlannedMeals(accountId: accountId)

        for remote in remoteMeals {
            let remoteId = remote.id
            let existingDescriptor = FetchDescriptor<LocalPlannedMeal>(
                predicate: #Predicate { $0.id == remoteId }
            )

            if let existing = try modelContext.fetch(existingDescriptor).first {
                existing.update(from: remote)
            } else {
                let local = LocalPlannedMeal(from: remote)
                modelContext.insert(local)
            }
        }

        // Remove locally cached items that no longer exist on server
        let remoteIds = Set(remoteMeals.map { $0.id })
        let localDescriptor = FetchDescriptor<LocalPlannedMeal>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted }
        )
        let localMeals = try modelContext.fetch(localDescriptor)

        for local in localMeals {
            if !remoteIds.contains(local.id) && local.isSynced {
                modelContext.delete(local)
            }
        }

        try? modelContext.save()
        return remoteMeals
    }

    /// Get all planned meals for an account
    func getPlannedMeals(accountId: UUID) async throws -> [PlannedMeal] {
        let descriptor = FetchDescriptor<LocalPlannedMeal>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalPlannedMeal>(\.date)]
        )

        let localMeals = try modelContext.fetch(descriptor)

        if localMeals.isEmpty && networkMonitor.isConnected {
            let remoteMeals = try await remoteRepository.getPlannedMeals(accountId: accountId)
            for remote in remoteMeals {
                let remoteId = remote.id
                let existingDescriptor = FetchDescriptor<LocalPlannedMeal>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                if try modelContext.fetch(existingDescriptor).isEmpty {
                    let local = LocalPlannedMeal(from: remote)
                    modelContext.insert(local)
                }
            }
            try? modelContext.save()
            return remoteMeals
        }

        return localMeals.map { (local: LocalPlannedMeal) in local.toRemote() }
    }

    /// Get planned meals for a specific week
    func getPlannedMealsForWeek(accountId: UUID, weekStart: Date) async throws -> [PlannedMeal] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: weekStart)
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else {
            return []
        }

        let descriptor = FetchDescriptor<LocalPlannedMeal>(
            predicate: #Predicate {
                $0.accountId == accountId &&
                !$0.locallyDeleted &&
                $0.date >= start &&
                $0.date < end
            },
            sortBy: [SortDescriptor<LocalPlannedMeal>(\.date)]
        )

        let localMeals = try modelContext.fetch(descriptor)

        // Enrich with recipe names
        var meals = localMeals.map { (local: LocalPlannedMeal) in local.toRemote() }
        let recipes = try await getRecipes(accountId: accountId)
        let recipeMap = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0.name) })

        for i in meals.indices {
            meals[i].recipeName = recipeMap[meals[i].recipeId]
        }

        return meals
    }

    // MARK: - Planned Meal Write Operations

    /// Create a new planned meal
    func createPlannedMeal(accountId: UUID, recipeId: UUID, date: Date, mealType: MealType, notes: String? = nil, recipeName: String? = nil) async throws -> PlannedMeal {
        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let insert = PlannedMealInsert(
                    id: UUID(),
                    accountId: accountId,
                    recipeId: recipeId,
                    date: Calendar.current.startOfDay(for: date),
                    mealType: mealType,
                    notes: notes
                )
                let remote = try await remoteRepository.createPlannedMeal(insert)
                let local = LocalPlannedMeal(from: remote)
                local.recipeName = recipeName
                modelContext.insert(local)
                try? modelContext.save()
                return remote
            } catch {
                print("[CachedMealPlannerRepo] Remote createPlannedMeal failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: create locally and queue for sync
        let local = LocalPlannedMeal(
            id: UUID(),
            accountId: accountId,
            recipeId: recipeId,
            date: Calendar.current.startOfDay(for: date),
            mealType: mealType.rawValue,
            notes: notes,
            recipeName: recipeName,
            isSynced: false
        )
        modelContext.insert(local)

        syncEngine.queueChange(
            entityType: "plannedMeal",
            entityId: local.id,
            accountId: accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update a planned meal
    func updatePlannedMeal(_ meal: PlannedMeal) async throws -> PlannedMeal {
        let mealId = meal.id
        let descriptor = FetchDescriptor<LocalPlannedMeal>(
            predicate: #Predicate { $0.id == mealId }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        local.recipeId = meal.recipeId
        local.date = Calendar.current.startOfDay(for: meal.date)
        local.mealType = meal.mealType.rawValue
        local.notes = meal.notes
        local.recipeName = meal.recipeName
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let updated = try await remoteRepository.updatePlannedMeal(meal)
                local.isSynced = true
                try modelContext.save()
                return updated
            } catch {
                print("[CachedMealPlannerRepo] Remote updatePlannedMeal failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "plannedMeal",
            entityId: meal.id,
            accountId: meal.accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Delete a planned meal
    func deletePlannedMeal(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalPlannedMeal>(
            predicate: #Predicate { $0.id == id }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        local.locallyDeleted = true
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.deletePlannedMeal(id: id)
                local.isSynced = true
                try modelContext.save()
                return
            } catch {
                print("[CachedMealPlannerRepo] Remote deletePlannedMeal failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "plannedMeal",
            entityId: id,
            accountId: local.accountId,
            changeType: .delete
        )

        try modelContext.save()
    }
}
