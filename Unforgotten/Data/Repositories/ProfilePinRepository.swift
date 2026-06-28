import Foundation
import Supabase

// MARK: - Profile Pin Repository Protocol
protocol ProfilePinRepositoryProtocol {
    /// Returns the profile IDs that the currently signed-in user has pinned.
    func getPinnedProfileIds() async throws -> Set<UUID>

    /// Pins a profile for the currently signed-in user. No-op if already pinned.
    func pin(profileId: UUID) async throws

    /// Unpins a profile for the currently signed-in user. No-op if not pinned.
    func unpin(profileId: UUID) async throws
}

// MARK: - Profile Pin Repository Implementation
final class ProfilePinRepository: ProfilePinRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Get Pinned Profile IDs
    func getPinnedProfileIds() async throws -> Set<UUID> {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let pins: [ProfilePin] = try await supabase
            .from(TableName.profilePins)
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        return Set(pins.map { $0.profileId })
    }

    // MARK: - Pin
    func pin(profileId: UUID) async throws {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let insert = ProfilePinInsert(userId: userId, profileId: profileId)

        // Use upsert so re-pinning an already-pinned profile is a no-op rather than an error
        try await supabase
            .from(TableName.profilePins)
            .upsert(insert, onConflict: "user_id,profile_id")
            .execute()
    }

    // MARK: - Unpin
    func unpin(profileId: UUID) async throws {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        try await supabase
            .from(TableName.profilePins)
            .delete()
            .eq("user_id", value: userId)
            .eq("profile_id", value: profileId)
            .execute()
    }
}

// MARK: - Insert Type
private struct ProfilePinInsert: Encodable {
    let userId: UUID
    let profileId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case profileId = "profile_id"
    }
}
