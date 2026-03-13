import Foundation
import Supabase

// MARK: - Device Token Repository
/// Manages APNs device tokens in Supabase for push notification delivery
final class DeviceTokenRepository {
    static let shared = DeviceTokenRepository()

    private let supabase = SupabaseManager.shared.client
    private let tableName = "device_tokens"

    private init() {}

    /// Register or update the device token for the current user
    func registerToken(_ token: String) async {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            #if DEBUG
            print("📲 Cannot register token: not authenticated")
            #endif
            // Store token for later registration after auth
            PendingDeviceToken.save(token)
            return
        }

        do {
            // Upsert: insert or update if the user+token combo already exists
            try await supabase
                .from(tableName)
                .upsert(
                    DeviceTokenInsert(userId: userId, token: token),
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

    /// Register any pending token that was saved before authentication
    func registerPendingToken() async {
        guard let token = PendingDeviceToken.load() else { return }
        PendingDeviceToken.clear()
        await registerToken(token)
    }
}

// MARK: - Insert Model
private struct DeviceTokenInsert: Encodable {
    let userId: UUID
    let token: String
    let platform: String = "ios"

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
        case platform
    }
}

// MARK: - Pending Token Storage
/// Stores the device token temporarily when received before authentication
enum PendingDeviceToken {
    private static let key = "unforgotten_pending_device_token"

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
