import Foundation
import Supabase

// MARK: - Invitation Repository Protocol
protocol InvitationRepositoryProtocol {
    func getInvitations(accountId: UUID) async throws -> [AccountInvitation]
    func getInvitationByCode(_ code: String) async throws -> AccountInvitation?
    func getInvitationsForEmail(_ email: String) async throws -> [AccountInvitation]
    func createInvitation(accountId: UUID, email: String, role: MemberRole, invitedBy: UUID, sharingPreferences: [SharingCategoryKey: Bool]) async throws -> AccountInvitation
    func acceptInvitationWithSync(invitation: AccountInvitation, userId: UUID, acceptorProfileId: UUID?, acceptorAccountId: UUID?, existingProfileId: UUID?) async throws -> ProfileSyncResult
    func revokeInvitation(id: UUID) async throws
    func acceptInvitation(invitation: AccountInvitation, userId: UUID) async throws
    func getAccountNameForInvitation(code: String) async throws -> String?
}

// MARK: - Protocol defaults
extension InvitationRepositoryProtocol {
    func createInvitation(accountId: UUID, email: String, invitedBy: UUID, sharingPreferences: [SharingCategoryKey: Bool] = [:]) async throws -> AccountInvitation {
        try await createInvitation(accountId: accountId, email: email, role: .viewer, invitedBy: invitedBy, sharingPreferences: sharingPreferences)
    }
}

// MARK: - Invitation Repository Implementation
final class InvitationRepository: InvitationRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Get Invitations for Account
    func getInvitations(accountId: UUID) async throws -> [AccountInvitation] {
        let invitations: [AccountInvitation] = try await supabase
            .from(TableName.accountInvitations)
            .select()
            .eq("account_id", value: accountId)
            .order("created_at", ascending: false)
            .execute()
            .value

        return invitations
    }

    // MARK: - Get Invitation by Code
    func getInvitationByCode(_ code: String) async throws -> AccountInvitation? {
        let invitations: [AccountInvitation] = try await supabase
            .from(TableName.accountInvitations)
            .select()
            .eq("invite_code", value: code.uppercased())
            .limit(1)
            .execute()
            .value

        return invitations.first
    }

    // MARK: - Get Invitations for Email
    func getInvitationsForEmail(_ email: String) async throws -> [AccountInvitation] {
        let invitations: [AccountInvitation] = try await supabase
            .from(TableName.accountInvitations)
            .select()
            .eq("email", value: email.lowercased())
            .eq("status", value: InvitationStatus.pending.rawValue)
            .execute()
            .value

        // Filter out expired invitations
        return invitations.filter { $0.isActive }
    }

    // MARK: - Create Invitation
    func createInvitation(
        accountId: UUID,
        email: String,
        role: MemberRole = .viewer,
        invitedBy: UUID,
        sharingPreferences: [SharingCategoryKey: Bool] = [:]
    ) async throws -> AccountInvitation {
        let inviteCode = generateInviteCode()

        let insert = InvitationInsert(
            accountId: accountId,
            email: email.lowercased().trimmingCharacters(in: .whitespaces),
            role: role,
            inviteCode: inviteCode,
            invitedBy: invitedBy,
            sharingProfileFields: sharingPreferences[.profileFields] ?? true,
            sharingMedical: sharingPreferences[.medical] ?? true,
            sharingGiftIdea: sharingPreferences[.giftIdea] ?? true,
            sharingClothing: sharingPreferences[.clothing] ?? true,
            sharingHobby: sharingPreferences[.hobby] ?? true,
            sharingActivityIdea: sharingPreferences[.activityIdea] ?? true,
            sharingImportantAccounts: sharingPreferences[.importantAccounts] ?? false
        )

        let invitation: AccountInvitation = try await supabase
            .from(TableName.accountInvitations)
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return invitation
    }

    // MARK: - Revoke Invitation
    func revokeInvitation(id: UUID) async throws {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        // Use RPC to revoke and clean up any partial acceptance data
        do {
            _ = try await supabase.rpc(
                "revoke_invitation_with_cleanup",
                params: [
                    "p_invitation_id": id.uuidString,
                    "p_user_id": userId.uuidString
                ]
            ).execute()
        } catch {
            #if DEBUG
            print("RPC revoke_invitation_with_cleanup failed: \(error). Falling back to status update.")
            #endif
            // Fallback: just update the status directly
            let update = InvitationStatusUpdate(status: .revoked)
            try await supabase
                .from(TableName.accountInvitations)
                .update(update)
                .eq("id", value: id)
                .execute()
        }
    }

    // MARK: - Accept Invitation
    /// Accepts an invitation and adds the user as an account member
    /// Uses an RPC function to bypass RLS restrictions
    func acceptInvitation(invitation: AccountInvitation, userId: UUID) async throws {
        // Try using the RPC function first (preferred - handles everything atomically)
        do {
            try await supabase.rpc(
                "accept_invitation",
                params: [
                    "p_invitation_id": invitation.id.uuidString,
                    "p_user_id": userId.uuidString
                ]
            ).execute()
            return
        } catch {
            // RPC not available, fall back to direct database operations
            #if DEBUG
            print("RPC accept_invitation failed: \(error). Falling back to direct operations.")
            #endif
        }

        // Fallback: Direct database operations (may fail due to RLS)
        // First, add the user as an account member
        let memberInsert = AccountMemberInsert(
            accountId: invitation.accountId,
            userId: userId,
            role: invitation.role
        )

        try await supabase
            .from(TableName.accountMembers)
            .insert(memberInsert)
            .execute()

        // Then mark the invitation as accepted with the user who accepted it
        // Try with acceptedBy first, fall back to without if column doesn't exist
        do {
            let update = InvitationAcceptUpdate(
                status: .accepted,
                acceptedAt: Date(),
                acceptedBy: userId
            )

            try await supabase
                .from(TableName.accountInvitations)
                .update(update)
                .eq("id", value: invitation.id)
                .execute()
        } catch {
            // If the full update fails (possibly due to missing accepted_by column),
            // try updating just the status and acceptedAt
            #if DEBUG
            print("Full invitation update failed: \(error). Trying fallback update.")
            #endif
            let fallbackUpdate = InvitationStatusUpdateWithDate(
                status: .accepted,
                acceptedAt: Date()
            )

            try await supabase
                .from(TableName.accountInvitations)
                .update(fallbackUpdate)
                .eq("id", value: invitation.id)
                .execute()
        }
    }

    // MARK: - Accept Invitation With Profile Sync
    /// Accepts an invitation with automatic profile syncing between connected users
    /// - Parameters:
    ///   - invitation: The invitation to accept
    ///   - userId: The ID of the user accepting the invitation
    ///   - acceptorProfileId: Optional ID of the acceptor's primary profile (for bidirectional sync)
    ///   - acceptorAccountId: Optional ID of the acceptor's account (ensures correct profile placement)
    ///   - existingProfileId: Optional ID of an existing profile in the inviter's account to link to (duplicate detection)
    /// - Returns: The result of the profile sync operation
    func acceptInvitationWithSync(
        invitation: AccountInvitation,
        userId: UUID,
        acceptorProfileId: UUID?,
        acceptorAccountId: UUID?,
        existingProfileId: UUID? = nil
    ) async throws -> ProfileSyncResult {
        // Build params dictionary - handle optional parameters
        var params: [String: String] = [
            "p_invitation_id": invitation.id.uuidString,
            "p_user_id": userId.uuidString
        ]

        if let profileId = acceptorProfileId {
            params["p_acceptor_profile_id"] = profileId.uuidString
        }

        if let accountId = acceptorAccountId {
            params["p_acceptor_account_id"] = accountId.uuidString
        }

        if let existingId = existingProfileId {
            params["p_existing_profile_id"] = existingId.uuidString
        }

        #if DEBUG
        print("📡 RPC accept_invitation_with_sync params:")
        print("📡   p_invitation_id: \(invitation.id.uuidString)")
        print("📡   p_user_id: \(userId.uuidString)")
        print("📡   p_acceptor_profile_id: \(acceptorProfileId?.uuidString ?? "not provided")")
        print("📡   p_acceptor_account_id: \(acceptorAccountId?.uuidString ?? "not provided")")
        print("📡   p_existing_profile_id: \(existingProfileId?.uuidString ?? "not provided")")
        #endif

        // Call the RPC function that handles invitation acceptance + profile sync atomically
        let result: ProfileSyncResult = try await supabase.rpc(
            "accept_invitation_with_sync",
            params: params
        ).execute().value

        #if DEBUG
        print("📡 RPC accept_invitation_with_sync response:")
        print("📡   success: \(result.success)")
        print("📡   sync_id: \(result.syncId?.uuidString ?? "nil")")
        print("📡   inviter_synced_profile_id: \(result.inviterSyncedProfileId?.uuidString ?? "nil")")
        print("📡   acceptor_synced_profile_id: \(result.acceptorSyncedProfileId?.uuidString ?? "nil")")
        print("📡   debug: \(result.debug ?? "none")")
        #endif

        return result
    }

    // MARK: - Get Account Name for Invitation
    /// Fetches the account display name for an invitation code via RPC (bypasses RLS)
    func getAccountNameForInvitation(code: String) async throws -> String? {
        struct AccountNameResult: Codable {
            let success: Bool
            let displayName: String?
            let error: String?

            enum CodingKeys: String, CodingKey {
                case success
                case displayName = "display_name"
                case error
            }
        }

        let result: AccountNameResult = try await supabase.rpc(
            "get_account_name_for_invitation",
            params: ["p_invite_code": code.uppercased()]
        ).execute().value

        return result.success ? result.displayName : nil
    }

    // MARK: - Generate Invite Code
    private func generateInviteCode() -> String {
        // Generate a 6-character alphanumeric code (excluding confusing characters)
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // No I, O, 0, 1
        return String((0..<6).compactMap { _ in characters.randomElement() })
    }
}

// MARK: - Insert/Update Types
private struct InvitationInsert: Encodable {
    let accountId: UUID
    let email: String
    let role: MemberRole
    let inviteCode: String
    let invitedBy: UUID
    let sharingProfileFields: Bool
    let sharingMedical: Bool
    let sharingGiftIdea: Bool
    let sharingClothing: Bool
    let sharingHobby: Bool
    let sharingActivityIdea: Bool
    let sharingImportantAccounts: Bool

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case email
        case role
        case inviteCode = "invite_code"
        case invitedBy = "invited_by"
        case sharingProfileFields = "sharing_profile_fields"
        case sharingMedical = "sharing_medical"
        case sharingGiftIdea = "sharing_gift_idea"
        case sharingClothing = "sharing_clothing"
        case sharingHobby = "sharing_hobby"
        case sharingActivityIdea = "sharing_activity_idea"
        case sharingImportantAccounts = "sharing_important_accounts"
    }
}

private struct InvitationStatusUpdate: Encodable {
    let status: InvitationStatus
}

private struct InvitationStatusUpdateWithDate: Encodable {
    let status: InvitationStatus
    let acceptedAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case acceptedAt = "accepted_at"
    }
}

private struct InvitationAcceptUpdate: Encodable {
    let status: InvitationStatus
    let acceptedAt: Date
    let acceptedBy: UUID

    enum CodingKeys: String, CodingKey {
        case status
        case acceptedAt = "accepted_at"
        case acceptedBy = "accepted_by"
    }
}

private struct AccountMemberInsert: Encodable {
    let accountId: UUID
    let userId: UUID
    let role: MemberRole

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case userId = "user_id"
        case role
    }
}
