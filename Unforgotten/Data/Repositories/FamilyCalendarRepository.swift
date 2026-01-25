import Foundation
import Supabase

// MARK: - Family Calendar Repository Protocol
protocol FamilyCalendarRepositoryProtocol {
    // Share management
    func createShare(accountId: UUID, eventType: CalendarEventType, eventId: UUID, memberUserIds: [UUID]) async throws -> FamilyCalendarShare
    func updateShareMembers(shareId: UUID, memberUserIds: [UUID]) async throws
    func deleteShare(shareId: UUID) async throws
    func deleteShareForEvent(eventType: CalendarEventType, eventId: UUID) async throws

    // Queries
    func getShareForEvent(eventType: CalendarEventType, eventId: UUID) async throws -> FamilyCalendarShare?
    func getMembersForShare(shareId: UUID) async throws -> [FamilyCalendarShareMember]
    func getSharedEventIdsForUser(accountId: UUID) async throws -> (appointmentIds: Set<UUID>, countdownIds: Set<UUID>)
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
    func deleteShareForEvent(eventType: CalendarEventType, eventId: UUID) async throws {
        try await supabase
            .from(TableName.familyCalendarShares)
            .delete()
            .eq("event_type", value: eventType.rawValue)
            .eq("event_id", value: eventId)
            .execute()
    }

    // MARK: - Get Share for Event
    func getShareForEvent(eventType: CalendarEventType, eventId: UUID) async throws -> FamilyCalendarShare? {
        let shares: [FamilyCalendarShare] = try await supabase
            .from(TableName.familyCalendarShares)
            .select()
            .eq("event_type", value: eventType.rawValue)
            .eq("event_id", value: eventId)
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
    /// Returns the IDs of appointments and countdowns that the current user can see in the family calendar
    func getSharedEventIdsForUser(accountId: UUID) async throws -> (appointmentIds: Set<UUID>, countdownIds: Set<UUID>) {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        // Get all shares for this account
        let shares = try await getAllSharesForAccount(accountId: accountId)

        var visibleAppointmentIds = Set<UUID>()
        var visibleCountdownIds = Set<UUID>()

        for share in shares {
            // User can see the event if they created the share OR they're in the members list
            var canSee = share.sharedByUserId == userId

            if !canSee {
                let members = try await getMembersForShare(shareId: share.id)
                canSee = members.contains { $0.memberUserId == userId }
            }

            if canSee {
                switch share.eventType {
                case .appointment:
                    visibleAppointmentIds.insert(share.eventId)
                case .countdown:
                    visibleCountdownIds.insert(share.eventId)
                }
            }
        }

        return (visibleAppointmentIds, visibleCountdownIds)
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

private struct FamilyCalendarShareMemberInsert: Encodable {
    let shareId: UUID
    let memberUserId: UUID

    enum CodingKeys: String, CodingKey {
        case shareId = "share_id"
        case memberUserId = "member_user_id"
    }
}
