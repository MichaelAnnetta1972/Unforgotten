import Foundation
import Supabase

/// Manages Live Activity push tokens in Supabase.
/// These tokens allow the server to send Live Activity updates via APNs.
final class LiveActivityTokenRepository {
    static let shared = LiveActivityTokenRepository()

    private let supabase = SupabaseManager.shared.client

    private init() {}

    /// Register or update the Live Activity push token for the current user
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
                    LATokenInsert(userId: userId, token: token),
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

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
    }
}
