import Foundation
import Supabase

// MARK: - App User Model
/// Represents a user in the app_users table with admin/complimentary status
struct AppUser: Codable, Identifiable, Equatable {
    let id: UUID
    let email: String
    var isAppAdmin: Bool
    var hasComplimentaryAccess: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case isAppAdmin = "is_app_admin"
        case hasComplimentaryAccess = "has_complimentary_access"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - App User Repository Protocol
protocol AppUserRepositoryProtocol {
    func getAllUsers() async throws -> [AppUser]
    func searchUsers(query: String) async throws -> [AppUser]
    func getUser(id: UUID) async throws -> AppUser?
    func getUserByEmail(email: String) async throws -> AppUser?
    func setAppAdmin(userId: UUID, isAdmin: Bool) async throws -> AppUser
    func setComplimentaryAccess(userId: UUID, hasAccess: Bool) async throws -> AppUser
    func ensureUserExists(userId: UUID, email: String) async throws -> AppUser
}

// MARK: - App User Repository Implementation
final class AppUserRepository: AppUserRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Get All Users
    func getAllUsers() async throws -> [AppUser] {
        let users: [AppUser] = try await supabase
            .from(TableName.appUsers)
            .select()
            .order("email", ascending: true)
            .execute()
            .value

        return users
    }

    // MARK: - Search Users
    func searchUsers(query: String) async throws -> [AppUser] {
        let users: [AppUser] = try await supabase
            .from(TableName.appUsers)
            .select()
            .ilike("email", pattern: "%\(query)%")
            .order("email", ascending: true)
            .execute()
            .value

        return users
    }

    // MARK: - Get User by ID
    func getUser(id: UUID) async throws -> AppUser? {
        let users: [AppUser] = try await supabase
            .from(TableName.appUsers)
            .select()
            .eq("id", value: id)
            .execute()
            .value

        return users.first
    }

    // MARK: - Get User by Email
    func getUserByEmail(email: String) async throws -> AppUser? {
        let users: [AppUser] = try await supabase
            .from(TableName.appUsers)
            .select()
            .eq("email", value: email.lowercased())
            .execute()
            .value

        return users.first
    }

    // MARK: - Set App Admin Status
    func setAppAdmin(userId: UUID, isAdmin: Bool) async throws -> AppUser {
        let update = AppUserAdminUpdate(isAppAdmin: isAdmin)

        let user: AppUser = try await supabase
            .from(TableName.appUsers)
            .update(update)
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value

        return user
    }

    // MARK: - Set Complimentary Access
    func setComplimentaryAccess(userId: UUID, hasAccess: Bool) async throws -> AppUser {
        let update = AppUserComplimentaryUpdate(hasComplimentaryAccess: hasAccess)

        let user: AppUser = try await supabase
            .from(TableName.appUsers)
            .update(update)
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value

        return user
    }

    // MARK: - Ensure User Exists
    /// Creates or updates a user record when they authenticate
    func ensureUserExists(userId: UUID, email: String) async throws -> AppUser {
        // Check if user already exists
        if let existingUser = try await getUser(id: userId) {
            return existingUser
        }

        // Create new user record
        let newUser = AppUserInsert(
            id: userId,
            email: email.lowercased(),
            isAppAdmin: AppAdminService.shared.isAppAdmin(email: email),
            hasComplimentaryAccess: false
        )

        let user: AppUser = try await supabase
            .from(TableName.appUsers)
            .insert(newUser)
            .select()
            .single()
            .execute()
            .value

        return user
    }
}

// MARK: - Insert/Update Types
private struct AppUserInsert: Encodable {
    let id: UUID
    let email: String
    let isAppAdmin: Bool
    let hasComplimentaryAccess: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case isAppAdmin = "is_app_admin"
        case hasComplimentaryAccess = "has_complimentary_access"
    }
}

private struct AppUserAdminUpdate: Encodable {
    let isAppAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case isAppAdmin = "is_app_admin"
    }
}

private struct AppUserComplimentaryUpdate: Encodable {
    let hasComplimentaryAccess: Bool

    enum CodingKeys: String, CodingKey {
        case hasComplimentaryAccess = "has_complimentary_access"
    }
}
