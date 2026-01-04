import Foundation

// MARK: - App Admin Service
/// Service to check if the current user is an app-level admin
/// App admins have access to administrative features across all users
final class AppAdminService {
    static let shared = AppAdminService()

    /// Hardcoded list of app admin email addresses
    private let appAdminEmails: Set<String> = [
        "michael@bbad.com.au"
    ]

    private init() {}

    /// Check if the given email is an app admin
    func isAppAdmin(email: String?) -> Bool {
        guard let email = email?.lowercased() else { return false }
        return appAdminEmails.contains(email)
    }

    /// Check if the current authenticated user is an app admin
    func isCurrentUserAppAdmin() async -> Bool {
        guard let user = await SupabaseManager.shared.currentUser,
              let email = user.email else {
            return false
        }
        return isAppAdmin(email: email)
    }
}
