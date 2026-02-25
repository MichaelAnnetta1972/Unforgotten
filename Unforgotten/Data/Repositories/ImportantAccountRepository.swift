import Foundation
import Supabase

// MARK: - Important Account Repository Protocol
protocol ImportantAccountRepositoryProtocol {
    func getAccounts(profileId: UUID) async throws -> [ImportantAccount]
    func getSharedAccounts(syncedProfileId: UUID) async throws -> [ImportantAccount]
    func getAccount(id: UUID) async throws -> ImportantAccount?
    func createAccount(_ account: ImportantAccountInsert) async throws -> ImportantAccount
    func updateAccount(_ account: ImportantAccount) async throws -> ImportantAccount
    func deleteAccount(id: UUID) async throws
}

// MARK: - Important Account Repository Implementation
final class ImportantAccountRepository: ImportantAccountRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Get Accounts for Profile
    func getAccounts(profileId: UUID) async throws -> [ImportantAccount] {
        let accounts: [ImportantAccount] = try await supabase
            .from(TableName.importantAccounts)
            .select()
            .eq("profile_id", value: profileId)
            .order("account_name")
            .execute()
            .value

        return accounts
    }

    // MARK: - Get Shared Accounts (for synced profiles)
    /// Fetches important accounts from the source profile via RPC,
    /// respecting sharing preferences for the current user.
    func getSharedAccounts(syncedProfileId: UUID) async throws -> [ImportantAccount] {
        let accounts: [ImportantAccount] = try await supabase
            .rpc("get_shared_important_accounts", params: ["p_synced_profile_id": syncedProfileId.uuidString])
            .execute()
            .value

        return accounts
    }

    // MARK: - Get Single Account
    func getAccount(id: UUID) async throws -> ImportantAccount? {
        let accounts: [ImportantAccount] = try await supabase
            .from(TableName.importantAccounts)
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value

        return accounts.first
    }

    // MARK: - Create Account
    func createAccount(_ account: ImportantAccountInsert) async throws -> ImportantAccount {
        let created: ImportantAccount = try await supabase
            .from(TableName.importantAccounts)
            .insert(account)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    // MARK: - Update Account
    func updateAccount(_ account: ImportantAccount) async throws -> ImportantAccount {
        let update = ImportantAccountUpdate(
            accountName: account.accountName,
            websiteURL: account.websiteURL,
            username: account.username,
            emailAddress: account.emailAddress,
            phoneNumber: account.phoneNumber,
            securityQuestionHint: account.securityQuestionHint,
            recoveryHint: account.recoveryHint,
            notes: account.notes,
            category: account.category,
            imageUrl: account.imageUrl
        )

        let updated: ImportantAccount = try await supabase
            .from(TableName.importantAccounts)
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
            .from(TableName.importantAccounts)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Insert Type
struct ImportantAccountInsert: Encodable {
    let id: UUID?
    let profileId: UUID
    let accountName: String
    let websiteURL: String?
    let username: String?
    let emailAddress: String?
    let phoneNumber: String?
    let securityQuestionHint: String?
    let recoveryHint: String?
    let notes: String?
    let category: AccountCategory?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case accountName = "account_name"
        case websiteURL = "website_url"
        case username
        case emailAddress = "email_address"
        case phoneNumber = "phone_number"
        case securityQuestionHint = "security_question_hint"
        case recoveryHint = "recovery_hint"
        case notes
        case category
        case imageUrl = "image_url"
    }

    init(
        id: UUID? = nil,
        profileId: UUID,
        accountName: String,
        websiteURL: String? = nil,
        username: String? = nil,
        emailAddress: String? = nil,
        phoneNumber: String? = nil,
        securityQuestionHint: String? = nil,
        recoveryHint: String? = nil,
        notes: String? = nil,
        category: AccountCategory? = nil,
        imageUrl: String? = nil
    ) {
        self.id = id
        self.profileId = profileId
        self.accountName = accountName
        self.websiteURL = websiteURL
        self.username = username
        self.emailAddress = emailAddress
        self.phoneNumber = phoneNumber
        self.securityQuestionHint = securityQuestionHint
        self.recoveryHint = recoveryHint
        self.notes = notes
        self.category = category
        self.imageUrl = imageUrl
    }
}

// MARK: - Update Type
private struct ImportantAccountUpdate: Encodable {
    let accountName: String
    let websiteURL: String?
    let username: String?
    let emailAddress: String?
    let phoneNumber: String?
    let securityQuestionHint: String?
    let recoveryHint: String?
    let notes: String?
    let category: AccountCategory?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case accountName = "account_name"
        case websiteURL = "website_url"
        case username
        case emailAddress = "email_address"
        case phoneNumber = "phone_number"
        case securityQuestionHint = "security_question_hint"
        case recoveryHint = "recovery_hint"
        case notes
        case category
        case imageUrl = "image_url"
    }
}
