import Foundation
import Supabase

// MARK: - Family Calendar Repository Protocol
protocol FamilyCalendarRepositoryProtocol {
    // Share management
    func createShare(accountId: UUID, eventType: CalendarEventType, eventId: UUID, memberUserIds: [UUID]) async throws -> FamilyCalendarShare
    func updateShareMembers(shareId: UUID, memberUserIds: [UUID]) async throws
    func deleteShare(shareId: UUID) async throws
    func deleteShareForEvent(eventType: CalendarEventType, eventId: UUID) async throws
    func removeSelfFromShare(eventType: CalendarEventType, eventId: UUID) async throws

    // Re-sharing
    func canReShareEvent(eventType: CalendarEventType, eventId: UUID) async throws -> Bool
    func reShareEvent(accountId: UUID, eventType: CalendarEventType, eventId: UUID, memberUserIds: [UUID]) async throws -> FamilyCalendarShare
    func getReShareForEvent(eventType: CalendarEventType, eventId: UUID) async throws -> FamilyCalendarShare?

    // Queries
    func getShareForEvent(eventType: CalendarEventType, eventId: UUID) async throws -> FamilyCalendarShare?
    func getMembersForShare(shareId: UUID) async throws -> [FamilyCalendarShareMember]
    func getSharedEventIdsForUser(accountId: UUID) async throws -> (appointmentIds: Set<UUID>, countdownIds: Set<UUID>)
    func getSharesVisibleToUser() async throws -> [FamilyCalendarShare]
    func getAllSharesForAccount(accountId: UUID) async throws -> [FamilyCalendarShare]
}

// MARK: - Family Calendar Repository Implementation
final class FamilyCalendarRepository: FamilyCalendarRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Create Share
    func createShare(accountId: UUID, eventType: CalendarEventType, eventId: UUID, memberUserIds: [UUID]) async throws -> FamilyCalendarShare {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let insert = FamilyCalendarShareInsert(
            accountId: accountId,
            eventType: eventType.rawValue,
            eventId: eventId,
            sharedByUserId: userId
        )

        let share: FamilyCalendarShare = try await supabase
            .from(TableName.familyCalendarShares)
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        // Add members
        if !memberUserIds.isEmpty {
            let memberInserts = memberUserIds.map { memberId in
                FamilyCalendarShareMemberInsert(shareId: share.id, memberUserId: memberId)
            }

            try await supabase
                .from(TableName.familyCalendarShareMembers)
                .insert(memberInserts)
                .execute()
        }

        return share
    }

    // MARK: - Update Share Members
    func updateShareMembers(shareId: UUID, memberUserIds: [UUID]) async throws {
        // Delete existing members
        try await supabase
            .from(TableName.familyCalendarShareMembers)
            .delete()
            .eq("share_id", value: shareId)
            .execute()

        // Add new members
        if !memberUserIds.isEmpty {
            let memberInserts = memberUserIds.map { memberId in
                FamilyCalendarShareMemberInsert(shareId: shareId, memberUserId: memberId)
            }

            try await supabase
                .from(TableName.familyCalendarShareMembers)
                .insert(memberInserts)
                .execute()
        }
    }

    // MARK: - Delete Share
    func deleteShare(shareId: UUID) async throws {
        // Members will be cascade deleted due to FK constraint
        try await supabase
            .from(TableName.familyCalendarShares)
            .delete()
            .eq("id", value: shareId)
            .execute()
    }

    // MARK: - Delete Share for Event
    /// Deletes only the ORIGINAL share for an event, leaving any re-shares untouched.
    /// Re-shares will be cleaned up by the DB cascade when the source share is removed.
    func deleteShareForEvent(eventType: CalendarEventType, eventId: UUID) async throws {
        try await supabase
            .from(TableName.familyCalendarShares)
            .delete()
            .eq("event_type", value: eventType.rawValue)
            .eq("event_id", value: eventId)
            .is("source_share_id", value: nil)
            .execute()
    }

    // MARK: - Remove Self from Share
    /// Removes the current user from a share's member list, effectively "unsubscribing" from a shared event.
    func removeSelfFromShare(eventType: CalendarEventType, eventId: UUID) async throws {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        // Find the share for this event
        guard let share = try await getShareForEvent(eventType: eventType, eventId: eventId) else {
            return
        }

        // Delete the member record for the current user
        try await supabase
            .from(TableName.familyCalendarShareMembers)
            .delete()
            .eq("share_id", value: share.id)
            .eq("member_user_id", value: userId)
            .execute()
    }

    // MARK: - Can Re-Share Event
    /// Checks if the current user can re-share an event (must be a direct recipient of an original share)
    func canReShareEvent(eventType: CalendarEventType, eventId: UUID) async throws -> Bool {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let result: Bool = try await supabase
            .rpc("can_reshare_event", params: [
                "p_user_id": userId.uuidString,
                "p_event_type": eventType.rawValue,
                "p_event_id": eventId.uuidString
            ])
            .execute()
            .value

        return result
    }

    // MARK: - Re-Share Event
    /// Creates a re-share: a new share record referencing the original share, with the current user as sharer
    func reShareEvent(accountId: UUID, eventType: CalendarEventType, eventId: UUID, memberUserIds: [UUID]) async throws -> FamilyCalendarShare {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        // Get the source share ID (the original share that granted us access)
        let sourceShareId: UUID = try await supabase
            .rpc("get_source_share_id", params: [
                "p_user_id": userId.uuidString,
                "p_event_type": eventType.rawValue,
                "p_event_id": eventId.uuidString
            ])
            .execute()
            .value

        let insert = FamilyCalendarReShareInsert(
            accountId: accountId,
            eventType: eventType.rawValue,
            eventId: eventId,
            sharedByUserId: userId,
            sourceShareId: sourceShareId
        )

        let share: FamilyCalendarShare = try await supabase
            .from(TableName.familyCalendarShares)
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        // Add members
        if !memberUserIds.isEmpty {
            let memberInserts = memberUserIds.map { memberId in
                FamilyCalendarShareMemberInsert(shareId: share.id, memberUserId: memberId)
            }

            try await supabase
                .from(TableName.familyCalendarShareMembers)
                .insert(memberInserts)
                .execute()
        }

        return share
    }

    // MARK: - Get Re-Share for Event
    /// Gets the current user's re-share for a specific event (if they have re-shared it)
    func getReShareForEvent(eventType: CalendarEventType, eventId: UUID) async throws -> FamilyCalendarShare? {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let shares: [FamilyCalendarShare] = try await supabase
            .from(TableName.familyCalendarShares)
            .select()
            .eq("event_type", value: eventType.rawValue)
            .eq("event_id", value: eventId.uuidString)
            .eq("shared_by_user_id", value: userId.uuidString)
            .not("source_share_id", operator: .is, value: "null")
            .execute()
            .value

        return shares.first
    }

    // MARK: - Get Share for Event
    /// Returns the ORIGINAL share for an event (source_share_id IS NULL).
    /// Since re-sharing was introduced, multiple share rows can exist for one event:
    /// one original and any number of re-shares. The edit view always wants the original.
    func getShareForEvent(eventType: CalendarEventType, eventId: UUID) async throws -> FamilyCalendarShare? {
        let shares: [FamilyCalendarShare] = try await supabase
            .from(TableName.familyCalendarShares)
            .select()
            .eq("event_type", value: eventType.rawValue)
            .eq("event_id", value: eventId)
            .is("source_share_id", value: nil)
            .execute()
            .value

        return shares.first
    }

    // MARK: - Get Members for Share
    func getMembersForShare(shareId: UUID) async throws -> [FamilyCalendarShareMember] {
        let members: [FamilyCalendarShareMember] = try await supabase
            .from(TableName.familyCalendarShareMembers)
            .select()
            .eq("share_id", value: shareId)
            .execute()
            .value

        return members
    }

    // MARK: - Get Shared Event IDs for User
    /// Returns the IDs of appointments and countdowns that the current user can see in the family calendar.
    /// Uses the get_shared_event_ids SECURITY DEFINER function to bypass RLS and reliably find
    /// cross-account shared events.
    func getSharedEventIdsForUser(accountId: UUID) async throws -> (appointmentIds: Set<UUID>, countdownIds: Set<UUID>) {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        // Use the SECURITY DEFINER RPC function to get shared event IDs
        // This bypasses RLS on family_calendar_share_members, avoiding potential policy issues
        let sharedCountdownIds = try await fetchSharedEventIds(userId: userId, eventType: "countdown")
        let sharedAppointmentIds = try await fetchSharedEventIds(userId: userId, eventType: "appointment")

        // Also include events from shares the user created (own shares)
        let ownShares: [FamilyCalendarShare] = try await supabase
            .from(TableName.familyCalendarShares)
            .select()
            .eq("shared_by_user_id", value: userId)
            .execute()
            .value

        var visibleAppointmentIds = Set(sharedAppointmentIds)
        var visibleCountdownIds = Set(sharedCountdownIds)

        for share in ownShares {
            switch share.eventType {
            case .appointment:
                visibleAppointmentIds.insert(share.eventId)
            case .countdown:
                visibleCountdownIds.insert(share.eventId)
            case .todoList:
                break // To-do list shares are handled separately
            }
        }

        return (visibleAppointmentIds, visibleCountdownIds)
    }

    // MARK: - Get Shares Visible to User
    /// Returns all shares that the current user can see: shares from their own account
    /// plus shares from other accounts where they are listed as a member.
    /// Uses the get_shared_event_ids SECURITY DEFINER function for cross-account shares
    /// to bypass RLS issues on family_calendar_share_members.
    func getSharesVisibleToUser() async throws -> [FamilyCalendarShare] {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        // 1. Get shares the user created (from their own account)
        let ownShares: [FamilyCalendarShare] = try await supabase
            .from(TableName.familyCalendarShares)
            .select()
            .eq("shared_by_user_id", value: userId)
            .execute()
            .value

        // 2. Get event IDs shared WITH this user using SECURITY DEFINER RPC
        // This bypasses RLS on family_calendar_share_members
        let sharedCountdownIds = try await fetchSharedEventIds(userId: userId, eventType: "countdown")
        let sharedAppointmentIds = try await fetchSharedEventIds(userId: userId, eventType: "appointment")

        // 3. Fetch share objects for the shared events (using the "is_share_member" RLS policy on shares table)
        let allSharedEventIds = sharedCountdownIds + sharedAppointmentIds
        var memberShares: [FamilyCalendarShare] = []
        if !allSharedEventIds.isEmpty {
            memberShares = try await supabase
                .from(TableName.familyCalendarShares)
                .select()
                .in("event_id", values: allSharedEventIds.map { $0.uuidString })
                .execute()
                .value
        }

        // 4. Combine and deduplicate
        let ownShareIds = Set(ownShares.map { $0.id })
        let uniqueMemberShares = memberShares.filter { !ownShareIds.contains($0.id) }

        return ownShares + uniqueMemberShares
    }

    // MARK: - Get All Shares for Account
    func getAllSharesForAccount(accountId: UUID) async throws -> [FamilyCalendarShare] {
        let shares: [FamilyCalendarShare] = try await supabase
            .from(TableName.familyCalendarShares)
            .select()
            .eq("account_id", value: accountId)
            .execute()
            .value

        return shares
    }
}

// MARK: - RPC Helpers

extension FamilyCalendarRepository {
    /// Calls the get_shared_event_ids SECURITY DEFINER function and parses the UUID results.
    /// Handles multiple PostgREST response formats for SETOF UUID.
    fileprivate func fetchSharedEventIds(userId: UUID, eventType: String) async throws -> [UUID] {
        let response = try await supabase
            .rpc("get_shared_event_ids", params: ["p_user_id": userId.uuidString, "p_event_type": eventType])
            .execute()

        let data = response.data

        #if DEBUG
        let rawString = String(data: data, encoding: .utf8) ?? "nil"
        print("[RPC] get_shared_event_ids(\(eventType)) for \(userId.uuidString.prefix(8)): \(rawString)")
        #endif

        guard !data.isEmpty else { return [] }

        // Try parsing the JSON to determine the format
        let json = try JSONSerialization.jsonObject(with: data)

        // Format 1: Array of strings ["uuid1", "uuid2", ...]
        if let strings = json as? [String] {
            return strings.compactMap { UUID(uuidString: $0) }
        }

        // Format 2: Array of objects [{"get_shared_event_ids": "uuid"}, ...]
        if let objects = json as? [[String: Any]] {
            return objects.compactMap { dict in
                if let uuidString = dict["get_shared_event_ids"] as? String {
                    return UUID(uuidString: uuidString)
                }
                // Try first value of any key
                if let first = dict.values.first as? String {
                    return UUID(uuidString: first)
                }
                return nil
            }
        }

        #if DEBUG
        print("[RPC] Unknown format for \(eventType): \(type(of: json))")
        #endif

        return []
    }
}

// MARK: - Insert Types
private struct FamilyCalendarShareInsert: Encodable {
    let accountId: UUID
    let eventType: String
    let eventId: UUID
    let sharedByUserId: UUID

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case eventType = "event_type"
        case eventId = "event_id"
        case sharedByUserId = "shared_by_user_id"
    }
}

private struct FamilyCalendarReShareInsert: Encodable {
    let accountId: UUID
    let eventType: String
    let eventId: UUID
    let sharedByUserId: UUID
    let sourceShareId: UUID

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case eventType = "event_type"
        case eventId = "event_id"
        case sharedByUserId = "shared_by_user_id"
        case sourceShareId = "source_share_id"
    }
}

private struct FamilyCalendarShareMemberInsert: Encodable {
    let shareId: UUID
    let memberUserId: UUID

    enum CodingKeys: String, CodingKey {
        case shareId = "share_id"
        case memberUserId = "member_user_id"
    }
}
