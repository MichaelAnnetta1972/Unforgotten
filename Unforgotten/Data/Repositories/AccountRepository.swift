import Foundation
import Supabase

// MARK: - Account Repository Protocol
protocol AccountRepositoryProtocol {
    func createAccount(displayName: String, timezone: String?) async throws -> Account
    func getAccount(id: UUID) async throws -> Account
    func getCurrentUserAccount() async throws -> Account?
    func updateAccount(_ account: Account) async throws -> Account
    func deleteAccount(id: UUID) async throws
    
    // Members
    func getAccountMembers(accountId: UUID) async throws -> [AccountMember]
    func addMember(accountId: UUID, userId: UUID, role: MemberRole) async throws -> AccountMember
    func updateMemberRole(memberId: UUID, role: MemberRole) async throws -> AccountMember
    func removeMember(memberId: UUID) async throws
    func getCurrentUserRole(accountId: UUID) async throws -> MemberRole?
}

// MARK: - Account Repository Implementation
final class AccountRepository: AccountRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Create Account
    func createAccount(displayName: String, timezone: String? = nil) async throws -> Account {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }
        
        let newAccount = AccountInsert(
            ownerUserId: userId,
            displayName: displayName,
            timezone: timezone ?? TimeZone.current.identifier
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
    
    // MARK: - Update Account
    func updateAccount(_ account: Account) async throws -> Account {
        let update = AccountUpdate(
            displayName: account.displayName,
            timezone: account.timezone
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
}

// MARK: - Insert/Update Types
private struct AccountInsert: Encodable {
    let ownerUserId: UUID
    let displayName: String
    let timezone: String?
    
    enum CodingKeys: String, CodingKey {
        case ownerUserId = "owner_user_id"
        case displayName = "display_name"
        case timezone
    }
}

private struct AccountUpdate: Encodable {
    let displayName: String
    let timezone: String?
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case timezone
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
