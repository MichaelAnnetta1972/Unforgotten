import Foundation
import Supabase

// MARK: - Profile Sharing Preferences Repository Protocol
protocol ProfileSharingPreferencesRepositoryProtocol {
    func getPreferences(profileId: UUID) async throws -> [ProfileSharingPreference]
    func getPreferences(profileId: UUID, targetUserId: UUID) async throws -> [ProfileSharingPreference]
    func getPreference(profileId: UUID, category: SharingCategoryKey) async throws -> ProfileSharingPreference?
    func getPreference(profileId: UUID, category: SharingCategoryKey, targetUserId: UUID) async throws -> ProfileSharingPreference?
    func isShared(profileId: UUID, category: SharingCategoryKey) async throws -> Bool
    func isShared(profileId: UUID, category: SharingCategoryKey, targetUserId: UUID) async throws -> Bool
    func updatePreference(profileId: UUID, category: SharingCategoryKey, isShared: Bool) async throws
    func updatePreference(profileId: UUID, category: SharingCategoryKey, isShared: Bool, targetUserId: UUID) async throws
}

// MARK: - Profile Sharing Preferences Repository Implementation
final class ProfileSharingPreferencesRepository: ProfileSharingPreferencesRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Get All Preferences for Profile
    func getPreferences(profileId: UUID) async throws -> [ProfileSharingPreference] {
        let preferences: [ProfileSharingPreference] = try await supabase
            .from(TableName.profileSharingPreferences)
            .select()
            .eq("profile_id", value: profileId)
            .execute()
            .value
        return preferences
    }

    // MARK: - Get Preferences for Profile + Target User
    func getPreferences(profileId: UUID, targetUserId: UUID) async throws -> [ProfileSharingPreference] {
        let preferences: [ProfileSharingPreference] = try await supabase
            .from(TableName.profileSharingPreferences)
            .select()
            .eq("profile_id", value: profileId)
            .eq("target_user_id", value: targetUserId)
            .execute()
            .value
        return preferences
    }

    // MARK: - Get Single Preference
    func getPreference(profileId: UUID, category: SharingCategoryKey) async throws -> ProfileSharingPreference? {
        let preferences: [ProfileSharingPreference] = try await supabase
            .from(TableName.profileSharingPreferences)
            .select()
            .eq("profile_id", value: profileId)
            .eq("category", value: category.rawValue)
            .limit(1)
            .execute()
            .value
        return preferences.first
    }

    // MARK: - Get Single Preference (per-user)
    func getPreference(profileId: UUID, category: SharingCategoryKey, targetUserId: UUID) async throws -> ProfileSharingPreference? {
        let preferences: [ProfileSharingPreference] = try await supabase
            .from(TableName.profileSharingPreferences)
            .select()
            .eq("profile_id", value: profileId)
            .eq("category", value: category.rawValue)
            .eq("target_user_id", value: targetUserId)
            .limit(1)
            .execute()
            .value
        return preferences.first
    }

    // MARK: - Check if Category is Shared
    func isShared(profileId: UUID, category: SharingCategoryKey) async throws -> Bool {
        let preference = try await getPreference(profileId: profileId, category: category)
        // Default is shared (true) if no preference row exists
        return preference?.isShared ?? true
    }

    // MARK: - Check if Category is Shared (per-user)
    func isShared(profileId: UUID, category: SharingCategoryKey, targetUserId: UUID) async throws -> Bool {
        let preference = try await getPreference(profileId: profileId, category: category, targetUserId: targetUserId)
        // Default is shared (true) if no preference row exists
        return preference?.isShared ?? true
    }

    // MARK: - Update Sharing Preference (legacy - applies to all connections)
    func updatePreference(profileId: UUID, category: SharingCategoryKey, isShared: Bool) async throws {
        _ = try await supabase.rpc(
            "update_sharing_preference",
            params: [
                "p_profile_id": profileId.uuidString,
                "p_category": category.rawValue,
                "p_is_shared": String(isShared)
            ]
        ).execute()
    }

    // MARK: - Update Sharing Preference (per-user)
    func updatePreference(profileId: UUID, category: SharingCategoryKey, isShared: Bool, targetUserId: UUID) async throws {
        _ = try await supabase.rpc(
            "update_sharing_preference",
            params: [
                "p_profile_id": profileId.uuidString,
                "p_category": category.rawValue,
                "p_is_shared": String(isShared),
                "p_target_user_id": targetUserId.uuidString
            ]
        ).execute()
    }
}
