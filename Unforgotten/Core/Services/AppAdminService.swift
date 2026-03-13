import Foundation

// MARK: - App Admin Service
/// Service to check if the current user is an app-level admin
/// Admin status is determined by the `is_app_admin` flag in the `app_users` database table.
final class AppAdminService {
    static let shared = AppAdminService()

    private init() {}

    /// Check if the given email is an app admin
    /// Admin status is now managed via the database (app_users.is_app_admin).
    /// This method always returns false — use the database flag instead.
    func isAppAdmin(email: String?) -> Bool {
        return false
    }

    /// Check if the current authenticated user is an app admin
    /// Admin status is now managed via the database (app_users.is_app_admin).
    /// This method always returns false — use AppState.isAppAdmin instead.
    func isCurrentUserAppAdmin() async -> Bool {
        return false
    }
}
