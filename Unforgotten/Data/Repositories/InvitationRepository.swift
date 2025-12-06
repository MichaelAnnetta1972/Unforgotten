import Foundation
import Supabase

// MARK: - Invitation Repository Protocol
protocol InvitationRepositoryProtocol {
    func getInvitations(accountId: UUID) async throws -> [AccountInvitation]
    func getInvitationByCode(_ code: String) async throws -> AccountInvitation?
    func getInvitationsForEmail(_ email: String) async throws -> [AccountInvitation]
    func createInvitation(accountId: UUID, email: String, role: MemberRole, invitedBy: UUID) async throws -> AccountInvitation
    func revokeInvitation(id: UUID) async throws
    func acceptInvitation(invitation: AccountInvitation, userId: UUID) async throws
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
    func createInvitation(accountId: UUID, email: String, role: MemberRole, invitedBy: UUID) async throws -> AccountInvitation {
        let inviteCode = generateInviteCode()

        let insert = InvitationInsert(
            accountId: accountId,
            email: email.lowercased().trimmingCharacters(in: .whitespaces),
            role: role,
            inviteCode: inviteCode,
            invitedBy: invitedBy
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
        let update = InvitationStatusUpdate(status: .revoked)

        try await supabase
            .from(TableName.accountInvitations)
            .update(update)
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Accept Invitation
    /// Accepts an invitation and adds the user as an account member
    func acceptInvitation(invitation: AccountInvitation, userId: UUID) async throws {
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

        // Then mark the invitation as accepted
        let update = InvitationAcceptUpdate(
            status: .accepted,
            acceptedAt: Date()
        )

        try await supabase
            .from(TableName.accountInvitations)
            .update(update)
            .eq("id", value: invitation.id)
            .execute()
    }

    // MARK: - Generate Invite Code
    private func generateInviteCode() -> String {
        // Generate a 6-character alphanumeric code (excluding confusing characters)
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // No I, O, 0, 1
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

// MARK: - Insert/Update Types
private struct InvitationInsert: Encodable {
    let accountId: UUID
    let email: String
    let role: MemberRole
    let inviteCode: String
    let invitedBy: UUID

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case email
        case role
        case inviteCode = "invite_code"
        case invitedBy = "invited_by"
    }
}

private struct InvitationStatusUpdate: Encodable {
    let status: InvitationStatus
}

private struct InvitationAcceptUpdate: Encodable {
    let status: InvitationStatus
    let acceptedAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case acceptedAt = "accepted_at"
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
