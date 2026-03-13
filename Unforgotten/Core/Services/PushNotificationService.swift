import Foundation
import Supabase

// MARK: - Push Notification Service
/// Sends push notifications to other users via Supabase Edge Functions
final class PushNotificationService {
    static let shared = PushNotificationService()

    private let supabase = SupabaseManager.shared.client

    private init() {}

    /// Send a push notification to family members when an event is shared with them
    func sendShareNotification(
        eventType: CalendarEventType,
        eventId: UUID,
        eventTitle: String,
        sharedByName: String,
        memberUserIds: [UUID]
    ) async {
        guard !memberUserIds.isEmpty else {
            #if DEBUG
            print("📲 No member user IDs, skipping notification")
            #endif
            return
        }

        #if DEBUG
        print("📲 Sending share notification for \(eventType.rawValue) \(eventId) to \(memberUserIds.count) members: \(memberUserIds)")
        #endif

        do {
            let payload = ShareNotificationPayload(
                eventType: eventType.rawValue,
                eventId: eventId.uuidString,
                eventTitle: eventTitle,
                sharedByName: sharedByName,
                memberUserIds: memberUserIds.map { $0.uuidString }
            )

            try await supabase.functions.invoke(
                "send-share-notification",
                options: FunctionInvokeOptions(body: payload)
            )

            #if DEBUG
            print("📲 Share notification sent successfully for \(eventType.rawValue) \(eventId) to \(memberUserIds.count) members")
            #endif
        } catch {
            // Don't throw — push notification failure shouldn't block the sharing flow
            #if DEBUG
            print("📲 Failed to send share notification: \(error)")
            print("📲 Error details: \(String(describing: error))")
            #endif
        }
    }
    /// Send a push notification when a user's role is changed
    func sendRoleChangeNotification(
        targetUserId: UUID,
        newRole: MemberRole,
        accountName: String,
        changedByName: String
    ) async {
        #if DEBUG
        print("📲 Sending role change notification to user \(targetUserId): \(newRole.rawValue)")
        #endif

        do {
            let payload = RoleChangePayload(
                targetUserId: targetUserId.uuidString,
                newRole: newRole.rawValue,
                accountName: accountName,
                changedByName: changedByName
            )

            try await supabase.functions.invoke(
                "send-role-change-notification",
                options: FunctionInvokeOptions(body: payload)
            )

            #if DEBUG
            print("📲 Role change notification sent successfully")
            #endif
        } catch {
            #if DEBUG
            print("📲 Failed to send role change notification: \(error)")
            #endif
        }
    }
}

// MARK: - Payload Models
private struct ShareNotificationPayload: Encodable {
    let eventType: String
    let eventId: String
    let eventTitle: String
    let sharedByName: String
    let memberUserIds: [String]

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case eventId = "event_id"
        case eventTitle = "event_title"
        case sharedByName = "shared_by_name"
        case memberUserIds = "member_user_ids"
    }
}

private struct RoleChangePayload: Encodable {
    let targetUserId: String
    let newRole: String
    let accountName: String
    let changedByName: String

    enum CodingKeys: String, CodingKey {
        case targetUserId = "target_user_id"
        case newRole = "new_role"
        case accountName = "account_name"
        case changedByName = "changed_by_name"
    }
}
