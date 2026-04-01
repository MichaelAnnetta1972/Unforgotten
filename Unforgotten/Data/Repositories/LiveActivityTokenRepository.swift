import Foundation
import Supabase

/// Manages Live Activity push tokens in Supabase.
/// Stores both per-activity push tokens and the push-to-start token.
/// The push-to-start token is used by the server to remotely START
/// a new Live Activity via APNs (iOS 17.2+).
final class LiveActivityTokenRepository {
    static let shared = LiveActivityTokenRepository()

    private let supabase = SupabaseManager.shared.client

    private init() {}

    /// Register or update a per-activity Live Activity push token
    func registerToken(_ token: String) async {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            #if DEBUG
            print("🔑 Cannot register LA token: not authenticated")
            #endif
            return
        }

        do {
            try await supabase
                .from(TableName.liveActivityTokens)
                .upsert(
                    LATokenInsert(userId: userId, token: token, tokenType: "activity"),
                    onConflict: "user_id,token"
                )
                .execute()

            #if DEBUG
            print("🔑 Live Activity token registered for user \(userId.uuidString.prefix(8))")
            #endif
        } catch {
            #if DEBUG
            print("🔑 Failed to register LA token: \(error)")
            #endif
        }
    }

    /// Register or update the push-to-start token for the current user.
    /// There is only one push-to-start token per Activity type per device,
    /// so we replace any existing push-to-start token for this user.
    func registerPushToStartToken(_ token: String) async {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            #if DEBUG
            print("🔑 Cannot register push-to-start token: not authenticated")
            #endif
            return
        }

        do {
            // Remove any existing push-to-start tokens for this user
            try await supabase
                .from(TableName.liveActivityTokens)
                .delete()
                .eq("user_id", value: userId)
                .eq("token_type", value: "push_to_start")
                .execute()

            // Insert the new push-to-start token
            try await supabase
                .from(TableName.liveActivityTokens)
                .insert(
                    LATokenInsert(userId: userId, token: token, tokenType: "push_to_start")
                )
                .execute()

            #if DEBUG
            print("🔑 Push-to-start token registered for user \(userId.uuidString.prefix(8))")
            #endif
        } catch {
            #if DEBUG
            print("🔑 Failed to register push-to-start token: \(error)")
            #endif
        }
    }

    /// Remove all Live Activity tokens for the current user (e.g., on sign out)
    func removeAllTokens() async {
        guard let userId = await SupabaseManager.shared.currentUserId else { return }

        do {
            try await supabase
                .from(TableName.liveActivityTokens)
                .delete()
                .eq("user_id", value: userId)
                .execute()

            #if DEBUG
            print("🔑 All LA tokens removed for user")
            #endif
        } catch {
            #if DEBUG
            print("🔑 Failed to remove LA tokens: \(error)")
            #endif
        }
    }
}

// MARK: - Insert Model

private struct LATokenInsert: Encodable {
    let userId: UUID
    let token: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
        case tokenType = "token_type"
    }
}
