import Foundation
import Supabase

// MARK: - Profile Sync Repository Protocol
protocol ProfileSyncRepositoryProtocol {
    /// Get all active profile syncs for a user (both as inviter and acceptor)
    func getSyncsForUser(userId: UUID) async throws -> [ProfileSync]

    /// Get a specific profile sync by ID
    func getSyncById(id: UUID) async throws -> ProfileSync?

    /// Get the profile sync associated with a synced profile
    func getSyncForProfile(profileId: UUID) async throws -> ProfileSync?

    /// Sever a profile sync connection
    func severSync(syncId: UUID) async throws

    /// Get all profile detail syncs for a sync connection
    func getSyncedDetails(syncConnectionId: UUID) async throws -> [ProfileDetailSync]

    /// Check if a profile detail is a synced copy
    func isDetailSynced(detailId: UUID) async throws -> Bool

    /// Get all synced detail IDs for a profile (returns set of detail IDs that are synced copies)
    func getSyncedDetailIds(for profileId: UUID) async throws -> Set<UUID>
}

// MARK: - Profile Sync Repository Implementation
final class ProfileSyncRepository: ProfileSyncRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Get Syncs For User

    func getSyncsForUser(userId: UUID) async throws -> [ProfileSync] {
        let syncs: [ProfileSync] = try await supabase
            .from(TableName.profileSyncs)
            .select()
            .or("inviter_user_id.eq.\(userId),acceptor_user_id.eq.\(userId)")
            .eq("status", value: "active")
            .order("created_at", ascending: false)
            .execute()
            .value

        return syncs
    }

    // MARK: - Get Sync By ID

    func getSyncById(id: UUID) async throws -> ProfileSync? {
        let syncs: [ProfileSync] = try await supabase
            .from(TableName.profileSyncs)
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value

        return syncs.first
    }

    // MARK: - Get Sync For Profile

    func getSyncForProfile(profileId: UUID) async throws -> ProfileSync? {
        // First check if this profile is a synced profile (has sync_connection_id)
        let profiles: [Profile] = try await supabase
            .from(TableName.profiles)
            .select()
            .eq("id", value: profileId)
            .limit(1)
            .execute()
            .value

        guard let profile = profiles.first, let syncConnectionId = profile.syncConnectionId else {
            return nil
        }

        return try await getSyncById(id: syncConnectionId)
    }

    // MARK: - Sever Sync

    func severSync(syncId: UUID) async throws {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        // Call the RPC function to sever the sync
        _ = try await supabase.rpc(
            "sever_profile_sync",
            params: [
                "p_sync_id": syncId.uuidString,
                "p_user_id": userId.uuidString
            ]
        ).execute()
    }

    // MARK: - Get Synced Details

    func getSyncedDetails(syncConnectionId: UUID) async throws -> [ProfileDetailSync] {
        let details: [ProfileDetailSync] = try await supabase
            .from(TableName.profileDetailSyncs)
            .select()
            .eq("sync_connection_id", value: syncConnectionId)
            .execute()
            .value

        return details
    }

    // MARK: - Is Detail Synced

    func isDetailSynced(detailId: UUID) async throws -> Bool {
        // Check if this detail exists as a synced_detail_id in profile_detail_syncs
        // with an active sync connection
        let count: Int = try await supabase
            .from(TableName.profileDetailSyncs)
            .select("id", head: true, count: .exact)
            .eq("synced_detail_id", value: detailId)
            .execute()
            .count ?? 0

        return count > 0
    }

    // MARK: - Get Source Detail Info

    /// Get the source detail ID for a synced detail
    func getSourceDetailId(for syncedDetailId: UUID) async throws -> UUID? {
        let syncs: [ProfileDetailSync] = try await supabase
            .from(TableName.profileDetailSyncs)
            .select()
            .eq("synced_detail_id", value: syncedDetailId)
            .limit(1)
            .execute()
            .value

        return syncs.first?.sourceDetailId
    }

    // MARK: - Get Synced Detail IDs for Profile

    func getSyncedDetailIds(for profileId: UUID) async throws -> Set<UUID> {
        // First get the profile to check if it has a sync connection
        let profiles: [Profile] = try await supabase
            .from(TableName.profiles)
            .select()
            .eq("id", value: profileId)
            .limit(1)
            .execute()
            .value

        guard let profile = profiles.first,
              let syncConnectionId = profile.syncConnectionId else {
            return []
        }

        // Get all profile_detail_syncs for this sync connection
        // where the synced_detail belongs to this profile
        let detailSyncs: [ProfileDetailSync] = try await supabase
            .from(TableName.profileDetailSyncs)
            .select()
            .eq("sync_connection_id", value: syncConnectionId)
            .execute()
            .value

        // Get all detail IDs for this profile to filter the syncs
        let profileDetails: [ProfileDetail] = try await supabase
            .from(TableName.profileDetails)
            .select()
            .eq("profile_id", value: profileId)
            .execute()
            .value

        let profileDetailIds = Set(profileDetails.map { $0.id })

        // Return only the synced detail IDs that belong to this profile
        return Set(detailSyncs.compactMap { sync in
            profileDetailIds.contains(sync.syncedDetailId) ? sync.syncedDetailId : nil
        })
    }
}

// MARK: - Helper Methods
extension ProfileSyncRepository {
    /// Get all synced profile IDs for a user (profiles synced TO their account from others)
    func getSyncedProfileIds(for userId: UUID, in accountId: UUID) async throws -> [UUID] {
        let syncs = try await getSyncsForUser(userId: userId)

        return syncs.compactMap { sync in
            // If user is the inviter, get the synced profile created in their account
            if sync.isInviter(userId) {
                return sync.inviterSyncedProfileId
            }
            // If user is the acceptor, get the synced profile created in their account
            else if sync.isAcceptor(userId) {
                return sync.acceptorSyncedProfileId
            }
            return nil
        }
    }

    /// Get the connected user's info for a synced profile
    func getConnectedUserInfo(for syncedProfileId: UUID) async throws -> (userId: UUID, sourceProfileId: UUID)? {
        guard let sync = try await getSyncForProfile(profileId: syncedProfileId) else {
            return nil
        }

        // Determine which side of the sync this profile is on
        if sync.inviterSyncedProfileId == syncedProfileId {
            // This is in the inviter's account, so the source is the acceptor
            guard let sourceProfileId = sync.acceptorSourceProfileId else { return nil }
            return (sync.acceptorUserId, sourceProfileId)
        } else if sync.acceptorSyncedProfileId == syncedProfileId {
            // This is in the acceptor's account, so the source is the inviter
            return (sync.inviterUserId, sync.inviterSourceProfileId)
        }

        return nil
    }
}
