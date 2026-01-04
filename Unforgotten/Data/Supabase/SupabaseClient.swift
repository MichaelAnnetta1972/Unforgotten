import Foundation
import Supabase

// MARK: - Supabase Configuration
enum SupabaseConfig {
    // Credentials loaded from AppConfiguration (Info.plist / xcconfig / environment)
    static var projectURL: URL { AppConfiguration.supabaseURL }
    static var anonKey: String { AppConfiguration.supabaseAnonKey }

    // Storage bucket names
    static let profilePhotosBucket = "profile-photos"
    static let medicationPhotosBucket = "medication-photos"

    // Image upload limits
    static let maxImageSizeBytes = 5 * 1024 * 1024 // 5MB
    static let maxImageDimension: CGFloat = 800
}

// MARK: - Supabase Client
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        // Custom decoder to handle all Supabase date formats
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Format 1: ISO8601 with microseconds and timezone (e.g., "2025-12-01T02:44:46.421048+00:00")
            let iso8601WithMicroseconds = DateFormatter()
            iso8601WithMicroseconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
            iso8601WithMicroseconds.locale = Locale(identifier: "en_US_POSIX")
            iso8601WithMicroseconds.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = iso8601WithMicroseconds.date(from: dateString) {
                return date
            }

            // Format 2: ISO8601 with milliseconds (e.g., "2024-01-01T10:00:00.123Z")
            let iso8601WithMilliseconds = DateFormatter()
            iso8601WithMilliseconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            iso8601WithMilliseconds.locale = Locale(identifier: "en_US_POSIX")
            iso8601WithMilliseconds.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = iso8601WithMilliseconds.date(from: dateString) {
                return date
            }

            // Format 3: Standard ISO8601 (e.g., "2024-01-01T10:00:00Z")
            let iso8601Formatter = ISO8601DateFormatter()
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Format 4: Date-only (e.g., "1947-07-31")
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = dateOnlyFormatter.date(from: dateString) {
                return date
            }

            // Format 5: Time-only (e.g., "04:00:00" from PostgreSQL time column)
            // Convert to today's date with the specified time using local timezone
            // This ensures the time displayed matches what the user originally entered
            if dateString.range(of: "^\\d{2}:\\d{2}:\\d{2}$", options: .regularExpression) != nil {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let components = dateString.split(separator: ":").compactMap { Int($0) }

                if components.count == 3 {
                    var dateComponents = calendar.dateComponents([.year, .month, .day], from: today)
                    dateComponents.hour = components[0]
                    dateComponents.minute = components[1]
                    dateComponents.second = components[2]
                    // Use local timezone for time-only values so display matches what user entered
                    dateComponents.timeZone = TimeZone.current

                    if let date = calendar.date(from: dateComponents) {
                        return date
                    }
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date from: \(dateString)"
            )
        }

        // Custom encoder for sending dates to Supabase
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        client = SupabaseClient(
            supabaseURL: SupabaseConfig.projectURL,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(
                    encoder: encoder,
                    decoder: decoder
                )
            )
        )
    }
    
    // MARK: - Auth Helpers
    var currentUser: User? {
        get async {
            do {
                let session = try await client.auth.session
                print("🔐 Session found for user: \(session.user.id)")
                return session.user
            } catch {
                print("🔐 No session found: \(error)")
                return nil
            }
        }
    }

    var currentUserId: UUID? {
        get async {
            await currentUser?.id
        }
    }
    
    var isAuthenticated: Bool {
        get async {
            await currentUser != nil
        }
    }
    
    // MARK: - Session Management
    func getSession() async throws -> Session? {
        try await client.auth.session
    }
    
    func refreshSession() async throws {
        _ = try await client.auth.refreshSession()
    }
}

// MARK: - Database Table Names
enum TableName {
    static let accounts = "accounts"
    static let accountMembers = "account_members"
    static let accountInvitations = "account_invitations"
    static let profiles = "profiles"
    static let profileDetails = "profile_details"
    static let profileConnections = "profile_connections"
    static let medications = "medications"
    static let medicationSchedules = "medication_schedules"
    static let medicationLogs = "medication_logs"
    static let appointments = "appointments"
    static let usefulContacts = "useful_contacts"
    static let moodEntries = "mood_entries"
    static let notes = "notes"
    static let todoLists = "todo_lists"
    static let todoItems = "todo_items"
    static let todoListTypes = "todo_list_types"
    static let importantAccounts = "important_accounts"
    static let stickyReminders = "sticky_reminders"
    static let appUsers = "app_users"
    static let userPreferences = "user_preferences"
}

// MARK: - Supabase Error
enum SupabaseError: LocalizedError {
    case notAuthenticated
    case noAccount
    case unauthorized
    case notFound
    case invalidData
    case uploadFailed
    case networkError(Error)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to sign in to continue."
        case .noAccount:
            return "No account found. Please complete setup."
        case .unauthorized:
            return "You don't have permission to perform this action."
        case .notFound:
            return "The requested item was not found."
        case .invalidData:
            return "Invalid data received from server."
        case .uploadFailed:
            return "Failed to upload file."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "An error occurred: \(error.localizedDescription)"
        }
    }
}
