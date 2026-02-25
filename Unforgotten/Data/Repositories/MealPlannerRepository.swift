import Foundation
import Supabase

// MARK: - Meal Planner Repository Protocol
protocol MealPlannerRepositoryProtocol {
    // Recipes
    func getRecipes(accountId: UUID) async throws -> [Recipe]
    func createRecipe(_ recipe: RecipeInsert) async throws -> Recipe
    func updateRecipe(_ recipe: Recipe) async throws -> Recipe
    func deleteRecipe(id: UUID) async throws

    // Planned Meals
    func getPlannedMeals(accountId: UUID) async throws -> [PlannedMeal]
    func getPlannedMealsForDateRange(accountId: UUID, startDate: Date, endDate: Date) async throws -> [PlannedMeal]
    func createPlannedMeal(_ meal: PlannedMealInsert) async throws -> PlannedMeal
    func updatePlannedMeal(_ meal: PlannedMeal) async throws -> PlannedMeal
    func deletePlannedMeal(id: UUID) async throws
}

// MARK: - Meal Planner Repository Implementation
final class MealPlannerRepository: MealPlannerRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Recipes

    func getRecipes(accountId: UUID) async throws -> [Recipe] {
        let recipes: [Recipe] = try await supabase
            .from(TableName.recipes)
            .select()
            .eq("account_id", value: accountId)
            .order("name")
            .execute()
            .value

        return recipes
    }

    func createRecipe(_ recipe: RecipeInsert) async throws -> Recipe {
        let created: Recipe = try await supabase
            .from(TableName.recipes)
            .insert(recipe)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    func updateRecipe(_ recipe: Recipe) async throws -> Recipe {
        let update = RecipeUpdate(name: recipe.name, websiteUrl: recipe.websiteUrl, imageUrl: recipe.imageUrl, mealType: recipe.mealType)

        let updated: Recipe = try await supabase
            .from(TableName.recipes)
            .update(update)
            .eq("id", value: recipe.id)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    func deleteRecipe(id: UUID) async throws {
        try await supabase
            .from(TableName.recipes)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Planned Meals

    func getPlannedMeals(accountId: UUID) async throws -> [PlannedMeal] {
        let meals: [PlannedMeal] = try await supabase
            .from(TableName.plannedMeals)
            .select()
            .eq("account_id", value: accountId)
            .order("date")
            .execute()
            .value

        return meals
    }

    func getPlannedMealsForDateRange(accountId: UUID, startDate: Date, endDate: Date) async throws -> [PlannedMeal] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let startString = dateFormatter.string(from: startDate)
        let endString = dateFormatter.string(from: endDate)

        let meals: [PlannedMeal] = try await supabase
            .from(TableName.plannedMeals)
            .select()
            .eq("account_id", value: accountId)
            .gte("date", value: startString)
            .lte("date", value: endString)
            .order("date")
            .execute()
            .value

        return meals
    }

    func createPlannedMeal(_ meal: PlannedMealInsert) async throws -> PlannedMeal {
        let created: PlannedMeal = try await supabase
            .from(TableName.plannedMeals)
            .insert(meal)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    func updatePlannedMeal(_ meal: PlannedMeal) async throws -> PlannedMeal {
        let update = PlannedMealUpdate(
            recipeId: meal.recipeId,
            date: meal.date,
            mealType: meal.mealType,
            notes: meal.notes
        )

        let updated: PlannedMeal = try await supabase
            .from(TableName.plannedMeals)
            .update(update)
            .eq("id", value: meal.id)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    func deletePlannedMeal(id: UUID) async throws {
        try await supabase
            .from(TableName.plannedMeals)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Recipe Update
private struct RecipeUpdate: Encodable {
    let name: String
    let websiteUrl: String?
    let imageUrl: String?
    let mealType: MealType?

    enum CodingKeys: String, CodingKey {
        case name
        case websiteUrl = "website_url"
        case imageUrl = "image_url"
        case mealType = "meal_type"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(websiteUrl, forKey: .websiteUrl)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(mealType, forKey: .mealType)
    }
}

// MARK: - Planned Meal Update
private struct PlannedMealUpdate: Encodable {
    let recipeId: UUID
    let date: Date
    let mealType: MealType
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case date
        case mealType = "meal_type"
        case notes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recipeId, forKey: .recipeId)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        try container.encode(dateFormatter.string(from: date), forKey: .date)

        try container.encode(mealType, forKey: .mealType)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}
