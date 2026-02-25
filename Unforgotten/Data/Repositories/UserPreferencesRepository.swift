import Foundation

// MARK: - User Preferences Model
/// Represents user appearance preferences stored in Supabase
struct UserPreferencesRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let accountId: UUID
    var headerStyleId: String
    var accentColorIndex: Int
    var hasCustomAccentColor: Bool
    var featureVisibility: [String: Bool]
    var featureOrder: [String]
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case accountId = "account_id"
        case headerStyleId = "header_style_id"
        case accentColorIndex = "accent_color_index"
        case hasCustomAccentColor = "has_custom_accent_color"
        case featureVisibility = "feature_visibility"
        case featureOrder = "feature_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        accountId = try container.decode(UUID.self, forKey: .accountId)
        headerStyleId = try container.decode(String.self, forKey: .headerStyleId)
        accentColorIndex = try container.decode(Int.self, forKey: .accentColorIndex)
        hasCustomAccentColor = try container.decode(Bool.self, forKey: .hasCustomAccentColor)
        featureVisibility = try container.decode([String: Bool].self, forKey: .featureVisibility)
        featureOrder = try container.decodeIfPresent([String].self, forKey: .featureOrder) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// MARK: - Insert/Update Structs
private struct UserPreferencesInsert: Codable {
    let userId: UUID
    let accountId: UUID
    let headerStyleId: String
    let accentColorIndex: Int
    let hasCustomAccentColor: Bool
    let featureVisibility: [String: Bool]
    let featureOrder: [String]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case accountId = "account_id"
        case headerStyleId = "header_style_id"
        case accentColorIndex = "accent_color_index"
        case hasCustomAccentColor = "has_custom_accent_color"
        case featureVisibility = "feature_visibility"
        case featureOrder = "feature_order"
    }
}

private struct UserPreferencesUpdate: Codable {
    let headerStyleId: String
    let accentColorIndex: Int
    let hasCustomAccentColor: Bool
    let featureVisibility: [String: Bool]
    let featureOrder: [String]

    enum CodingKeys: String, CodingKey {
        case headerStyleId = "header_style_id"
        case accentColorIndex = "accent_color_index"
        case hasCustomAccentColor = "has_custom_accent_color"
        case featureVisibility = "feature_visibility"
        case featureOrder = "feature_order"
    }
}

// MARK: - User Preferences Repository
/// Repository for syncing user appearance preferences with Supabase
final class UserPreferencesRepository {
    private let client = SupabaseManager.shared.client

    // MARK: - Fetch Preferences

    /// Get preferences for a specific user and account
    func getPreferences(userId: UUID, accountId: UUID) async throws -> UserPreferencesRecord? {
        let response: [UserPreferencesRecord] = try await client
            .from(TableName.userPreferences)
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("account_id", value: accountId.uuidString)
            .execute()
            .value

        return response.first
    }

    /// Get all preferences for a user (across all accounts)
    func getAllPreferencesForUser(userId: UUID) async throws -> [UserPreferencesRecord] {
        return try await client
            .from(TableName.userPreferences)
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
    }

    // MARK: - Create Preferences

    /// Create new preferences record
    func createPreferences(
        userId: UUID,
        accountId: UUID,
        headerStyleId: String,
        accentColorIndex: Int,
        hasCustomAccentColor: Bool,
        featureVisibility: [String: Bool],
        featureOrder: [String]
    ) async throws -> UserPreferencesRecord {
        let insert = UserPreferencesInsert(
            userId: userId,
            accountId: accountId,
            headerStyleId: headerStyleId,
            accentColorIndex: accentColorIndex,
            hasCustomAccentColor: hasCustomAccentColor,
            featureVisibility: featureVisibility,
            featureOrder: featureOrder
        )

        let response: [UserPreferencesRecord] = try await client
            .from(TableName.userPreferences)
            .insert(insert)
            .select()
            .execute()
            .value

        guard let record = response.first else {
            throw SupabaseError.invalidData
        }

        return record
    }

    // MARK: - Update Preferences

    /// Update existing preferences record
    func updatePreferences(
        userId: UUID,
        accountId: UUID,
        headerStyleId: String,
        accentColorIndex: Int,
        hasCustomAccentColor: Bool,
        featureVisibility: [String: Bool],
        featureOrder: [String]
    ) async throws -> UserPreferencesRecord {
        let update = UserPreferencesUpdate(
            headerStyleId: headerStyleId,
            accentColorIndex: accentColorIndex,
            hasCustomAccentColor: hasCustomAccentColor,
            featureVisibility: featureVisibility,
            featureOrder: featureOrder
        )

        let response: [UserPreferencesRecord] = try await client
            .from(TableName.userPreferences)
            .update(update)
            .eq("user_id", value: userId.uuidString)
            .eq("account_id", value: accountId.uuidString)
            .select()
            .execute()
            .value

        guard let record = response.first else {
            throw SupabaseError.notFound
        }

        return record
    }

    // MARK: - Upsert (Create or Update)

    /// Create or update preferences - uses Supabase upsert
    func upsertPreferences(
        userId: UUID,
        accountId: UUID,
        headerStyleId: String,
        accentColorIndex: Int,
        hasCustomAccentColor: Bool,
        featureVisibility: [String: Bool],
        featureOrder: [String]
    ) async throws -> UserPreferencesRecord {
        // First try to get existing
        if let existing = try await getPreferences(userId: userId, accountId: accountId) {
            // Update existing
            return try await updatePreferences(
                userId: userId,
                accountId: accountId,
                headerStyleId: headerStyleId,
                accentColorIndex: accentColorIndex,
                hasCustomAccentColor: hasCustomAccentColor,
                featureVisibility: featureVisibility,
                featureOrder: featureOrder
            )
        } else {
            // Create new
            return try await createPreferences(
                userId: userId,
                accountId: accountId,
                headerStyleId: headerStyleId,
                accentColorIndex: accentColorIndex,
                hasCustomAccentColor: hasCustomAccentColor,
                featureVisibility: featureVisibility,
                featureOrder: featureOrder
            )
        }
    }

    // MARK: - Delete Preferences

    /// Delete preferences for a user and account
    func deletePreferences(userId: UUID, accountId: UUID) async throws {
        try await client
            .from(TableName.userPreferences)
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("account_id", value: accountId.uuidString)
            .execute()
    }
}
