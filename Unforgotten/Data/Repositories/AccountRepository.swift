import Foundation
import Supabase

// MARK: - Account with Role (for multi-account support)
struct AccountWithRole: Identifiable, Equatable {
    let account: Account
    let role: MemberRole
    let isOwner: Bool

    var id: UUID { account.id }
    var displayName: String { account.displayName }
}

// MARK: - Account Repository Protocol
protocol AccountRepositoryProtocol {
    func createAccount(displayName: String) async throws -> Account
    func getAccount(id: UUID) async throws -> Account
    func getCurrentUserAccount() async throws -> Account?
    func getAllUserAccounts() async throws -> [AccountWithRole]
    func updateAccount(_ account: Account) async throws -> Account
    func deleteAccount(id: UUID) async throws

    // Members
    func getAccountMembers(accountId: UUID) async throws -> [AccountMember]
    func getAccountMembersWithUsers(accountId: UUID) async throws -> [AccountMemberWithUser]
    func addMember(accountId: UUID, userId: UUID, role: MemberRole) async throws -> AccountMember
    func updateMemberRole(memberId: UUID, role: MemberRole) async throws -> AccountMember
    func removeMember(memberId: UUID) async throws
    func getCurrentUserRole(accountId: UUID) async throws -> MemberRole?
    func getAccountMember(accountId: UUID, userId: UUID) async throws -> AccountMember?
}

// MARK: - Account Repository Implementation
final class AccountRepository: AccountRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Create Account
    func createAccount(displayName: String) async throws -> Account {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let newAccount = AccountInsert(
            ownerUserId: userId,
            displayName: displayName
        )
        
        let account: Account = try await supabase
            .from(TableName.accounts)
            .insert(newAccount)
            .select()
            .single()
            .execute()
            .value
        
        // Also create account member entry for owner
        _ = try await addMember(accountId: account.id, userId: userId, role: .owner)
        
        return account
    }
    
    // MARK: - Get Account
    func getAccount(id: UUID) async throws -> Account {
        let account: Account = try await supabase
            .from(TableName.accounts)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        
        return account
    }
    
    // MARK: - Get Current User's Account
    func getCurrentUserAccount() async throws -> Account? {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        // Find account where user is a member
        let members: [AccountMember] = try await supabase
            .from(TableName.accountMembers)
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        guard let member = members.first else {
            return nil
        }

        return try await getAccount(id: member.accountId)
    }

    // MARK: - Get All User's Accounts
    /// Returns all accounts the current user has access to, with their role in each
    func getAllUserAccounts() async throws -> [AccountWithRole] {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        // Get all memberships for this user
        let members: [AccountMember] = try await supabase
            .from(TableName.accountMembers)
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        // Fetch account details for each membership
        var accountsWithRoles: [AccountWithRole] = []
        for member in members {
            let account = try await getAccount(id: member.accountId)
            let isOwner = account.ownerUserId == userId
            accountsWithRoles.append(AccountWithRole(
                account: account,
                role: member.role,
                isOwner: isOwner
            ))
        }

        // Sort: owned accounts first, then by display name
        return accountsWithRoles.sorted { first, second in
            if first.isOwner != second.isOwner {
                return first.isOwner
            }
            return first.displayName.localizedCaseInsensitiveCompare(second.displayName) == .orderedAscending
        }
    }
    
    // MARK: - Update Account
    func updateAccount(_ account: Account) async throws -> Account {
        let update = AccountUpdate(
            displayName: account.displayName
        )

        let updated: Account = try await supabase
            .from(TableName.accounts)
            .update(update)
            .eq("id", value: account.id)
            .select()
            .single()
            .execute()
            .value
        
        return updated
    }
    
    // MARK: - Delete Account
    func deleteAccount(id: UUID) async throws {
        try await supabase
            .from(TableName.accounts)
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Get Account Members
    func getAccountMembers(accountId: UUID) async throws -> [AccountMember] {
        let members: [AccountMember] = try await supabase
            .from(TableName.accountMembers)
            .select()
            .eq("account_id", value: accountId)
            .execute()
            .value

        return members
    }

    // MARK: - Get Account Members With User Details
    func getAccountMembersWithUsers(accountId: UUID) async throws -> [AccountMemberWithUser] {
        let members = try await getAccountMembers(accountId: accountId)

        var membersWithUsers: [AccountMemberWithUser] = []
        for member in members {
            // Fetch user details from app_users table
            let users: [AppUser] = try await supabase
                .from(TableName.appUsers)
                .select()
                .eq("id", value: member.userId)
                .execute()
                .value

            if let user = users.first {
                membersWithUsers.append(AccountMemberWithUser(member: member, user: user))
            }
        }

        // Sort by display name
        return membersWithUsers.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - Add Member
    func addMember(accountId: UUID, userId: UUID, role: MemberRole) async throws -> AccountMember {
        let newMember = AccountMemberInsert(
            accountId: accountId,
            userId: userId,
            role: role
        )
        
        let member: AccountMember = try await supabase
            .from(TableName.accountMembers)
            .insert(newMember)
            .select()
            .single()
            .execute()
            .value
        
        return member
    }
    
    // MARK: - Update Member Role
    func updateMemberRole(memberId: UUID, role: MemberRole) async throws -> AccountMember {
        let update = AccountMemberUpdate(role: role)
        
        let member: AccountMember = try await supabase
            .from(TableName.accountMembers)
            .update(update)
            .eq("id", value: memberId)
            .select()
            .single()
            .execute()
            .value
        
        return member
    }
    
    // MARK: - Remove Member
    func removeMember(memberId: UUID) async throws {
        try await supabase
            .from(TableName.accountMembers)
            .delete()
            .eq("id", value: memberId)
            .execute()
    }
    
    // MARK: - Get Current User's Role
    func getCurrentUserRole(accountId: UUID) async throws -> MemberRole? {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }
        
        let members: [AccountMember] = try await supabase
            .from(TableName.accountMembers)
            .select()
            .eq("account_id", value: accountId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return members.first?.role
    }

    // MARK: - Get Account Member by User ID
    func getAccountMember(accountId: UUID, userId: UUID) async throws -> AccountMember? {
        let members: [AccountMember] = try await supabase
            .from(TableName.accountMembers)
            .select()
            .eq("account_id", value: accountId)
            .eq("user_id", value: userId)
            .execute()
            .value

        return members.first
    }
}

// MARK: - Insert/Update Types
private struct AccountInsert: Encodable {
    let ownerUserId: UUID
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case ownerUserId = "owner_user_id"
        case displayName = "display_name"
    }
}

private struct AccountUpdate: Encodable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
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

private struct AccountMemberUpdate: Encodable {
    let role: MemberRole
}
