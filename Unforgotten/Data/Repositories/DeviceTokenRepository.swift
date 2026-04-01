import Foundation
import Supabase

// MARK: - Device Token Repository
/// Manages APNs device tokens in Supabase for push notification delivery
final class DeviceTokenRepository {
    static let shared = DeviceTokenRepository()

    private let supabase = SupabaseManager.shared.client
    private let tableName = "device_tokens"

    private init() {}

    /// Register or update the device token for the current user.
    /// Always persists the token locally so it can be retried on subsequent launches.
    func registerToken(_ token: String) async {
        // Always save the latest token locally so we can retry on next launch
        LatestDeviceToken.save(token)
        // Clean up legacy pending token key
        UserDefaults.standard.removeObject(forKey: "unforgotten_pending_device_token")

        guard let userId = await SupabaseManager.shared.currentUserId else {
            #if DEBUG
            print("📲 Cannot register token: not authenticated")
            #endif
            return
        }

        do {
            // Upsert: insert or update if the user+token combo already exists
            try await supabase
                .from(tableName)
                .upsert(
                    DeviceTokenInsert(userId: userId, token: token, environment: APNsEnvironment.current),
                    onConflict: "user_id,token"
                )
                .execute()

            #if DEBUG
            print("📲 Device token registered for user \(userId.uuidString.prefix(8))")
            #endif
        } catch {
            #if DEBUG
            print("📲 Failed to register device token: \(error)")
            #endif
        }
    }

    /// Remove a specific device token (e.g., on sign out)
    func removeToken(_ token: String) async {
        guard let userId = await SupabaseManager.shared.currentUserId else { return }

        do {
            try await supabase
                .from(tableName)
                .delete()
                .eq("user_id", value: userId)
                .eq("token", value: token)
                .execute()

            #if DEBUG
            print("📲 Device token removed")
            #endif
        } catch {
            #if DEBUG
            print("📲 Failed to remove device token: \(error)")
            #endif
        }
    }

    /// Remove all device tokens for the current user (e.g., on sign out)
    func removeAllTokens() async {
        guard let userId = await SupabaseManager.shared.currentUserId else { return }

        do {
            try await supabase
                .from(tableName)
                .delete()
                .eq("user_id", value: userId)
                .execute()

            #if DEBUG
            print("📲 All device tokens removed for user")
            #endif
        } catch {
            #if DEBUG
            print("📲 Failed to remove device tokens: \(error)")
            #endif
        }
    }

    /// Ensure the latest device token is registered in Supabase.
    /// Called after authentication succeeds on every app launch.
    /// Accepts userId directly to avoid redundant session checks.
    func ensureTokenRegistered(userId: UUID) async {
        // Try latest token first, fall back to legacy pending token key
        let token = LatestDeviceToken.load()
            ?? UserDefaults.standard.string(forKey: "unforgotten_pending_device_token")
        guard let token else {
            #if DEBUG
            print("📲 ensureTokenRegistered: No device token found in local storage — push notifications will not work. Are you running on a physical device?")
            #endif
            return
        }
        // Save under the new key for future launches
        LatestDeviceToken.save(token)
        #if DEBUG
        print("📲 ensureTokenRegistered: Registering token \(token.prefix(8))... for user \(userId.uuidString.prefix(8))...")
        #endif

        do {
            try await supabase
                .from(tableName)
                .upsert(
                    DeviceTokenInsert(userId: userId, token: token, environment: APNsEnvironment.current),
                    onConflict: "user_id,token"
                )
                .execute()

            #if DEBUG
            print("📲 Device token ensured for user \(userId.uuidString.prefix(8))")
            #endif
        } catch {
            #if DEBUG
            print("📲 Failed to ensure device token: \(error)")
            #endif
        }
    }
}

// MARK: - APNs Environment Detection
enum APNsEnvironment {
    /// Returns "sandbox" for debug/Xcode builds, "production" for TestFlight/App Store
    static var current: String {
        #if DEBUG
        return "sandbox"
        #else
        // Check for embedded.mobileprovision which exists in dev/ad-hoc builds but not App Store
        if Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil {
            // TestFlight or ad-hoc — both use production APNs
            return "production"
        }
        return "production"
        #endif
    }
}

// MARK: - Insert Model
private struct DeviceTokenInsert: Encodable {
    let userId: UUID
    let token: String
    let platform: String = "ios"
    let environment: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
        case platform
        case environment
    }
}

// MARK: - Latest Device Token Storage
/// Persists the latest APNs device token so it can be re-registered
/// on every app launch after authentication succeeds.
enum LatestDeviceToken {
    private static let key = "unforgotten_latest_device_token"

    static func save(_ token: String) {
        UserDefaults.standard.set(token, forKey: key)
    }

    static func load() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
