import Foundation
import Supabase

// MARK: - Countdown Repository Protocol
protocol CountdownRepositoryProtocol {
    func getCountdowns(accountId: UUID) async throws -> [Countdown]
    func getUpcomingCountdowns(accountId: UUID, days: Int) async throws -> [Countdown]
    func getCountdown(id: UUID) async throws -> Countdown
    func getCountdownsByIds(_ ids: [UUID]) async throws -> [Countdown]
    func getSharedCountdowns() async throws -> [Countdown]
    func createCountdown(_ countdown: CountdownInsert) async throws -> Countdown
    func updateCountdown(_ countdown: Countdown) async throws -> Countdown
    func deleteCountdown(id: UUID) async throws
    func getCountdownsByGroupId(_ groupId: UUID) async throws -> [Countdown]
    func deleteCountdownsByGroupId(_ groupId: UUID) async throws
    func updateCountdownGroupFields(_ groupId: UUID, update: CountdownGroupUpdate) async throws -> [Countdown]
}

// MARK: - Countdown Repository Implementation
final class CountdownRepository: CountdownRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Get All Countdowns
    func getCountdowns(accountId: UUID) async throws -> [Countdown] {
        let countdowns: [Countdown] = try await supabase
            .from(TableName.countdowns)
            .select()
            .eq("account_id", value: accountId)
            .order("date")
            .execute()
            .value

        return countdowns
    }

    // MARK: - Get Upcoming Countdowns
    func getUpcomingCountdowns(accountId: UUID, days: Int = 365) async throws -> [Countdown] {
        let today = Calendar.current.startOfDay(for: Date())
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: today)!

        // Format dates as yyyy-MM-dd to match PostgreSQL date column format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let todayString = dateFormatter.string(from: today)
        let futureDateString = dateFormatter.string(from: futureDate)

        let countdowns: [Countdown] = try await supabase
            .from(TableName.countdowns)
            .select()
            .eq("account_id", value: accountId)
            .gte("date", value: todayString)
            .lte("date", value: futureDateString)
            .order("date")
            .execute()
            .value

        // Also fetch recurring countdowns (they should always be shown)
        let recurringCountdowns: [Countdown] = try await supabase
            .from(TableName.countdowns)
            .select()
            .eq("account_id", value: accountId)
            .eq("is_recurring", value: true)
            .execute()
            .value

        // Combine and deduplicate
        var allCountdowns = countdowns
        for recurring in recurringCountdowns {
            if !allCountdowns.contains(where: { $0.id == recurring.id }) {
                allCountdowns.append(recurring)
            }
        }

        // Sort by next occurrence
        return allCountdowns.sorted { $0.daysUntilNextOccurrence < $1.daysUntilNextOccurrence }
    }

    // MARK: - Get Single Countdown
    func getCountdown(id: UUID) async throws -> Countdown {
        let countdown: Countdown = try await supabase
            .from(TableName.countdowns)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value

        return countdown
    }

    // MARK: - Get Countdowns By IDs
    func getCountdownsByIds(_ ids: [UUID]) async throws -> [Countdown] {
        guard !ids.isEmpty else { return [] }

        let countdowns: [Countdown] = try await supabase
            .from(TableName.countdowns)
            .select()
            .in("id", values: ids.map { $0.uuidString })
            .order("date")
            .execute()
            .value

        return countdowns
    }

    // MARK: - Get Shared Countdowns (via RPC)
    /// Fetches countdowns shared with the current user via SECURITY DEFINER function.
    /// Bypasses RLS on the countdowns table to enable cross-account reads.
    func getSharedCountdowns() async throws -> [Countdown] {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let countdowns: [Countdown] = try await supabase
            .rpc("get_shared_countdowns", params: ["p_user_id": userId.uuidString])
            .execute()
            .value

        return countdowns
    }

    // MARK: - Create Countdown
    func createCountdown(_ countdown: CountdownInsert) async throws -> Countdown {
        let created: Countdown = try await supabase
            .from(TableName.countdowns)
            .insert(countdown)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    // MARK: - Update Countdown
    func updateCountdown(_ countdown: Countdown) async throws -> Countdown {
        let update = CountdownUpdate(
            title: countdown.title,
            subtitle: countdown.subtitle,
            date: countdown.date,
            endDate: countdown.endDate,
            hasTime: countdown.hasTime,
            type: countdown.type,
            customType: countdown.customType,
            notes: countdown.notes,
            imageUrl: countdown.imageUrl,
            groupId: countdown.groupId,
            reminderOffsetMinutes: countdown.reminderOffsetMinutes,
            isRecurring: countdown.isRecurring
        )

        let updated: Countdown = try await supabase
            .from(TableName.countdowns)
            .update(update)
            .eq("id", value: countdown.id)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    // MARK: - Delete Countdown
    func deleteCountdown(id: UUID) async throws {
        try await supabase
            .from(TableName.countdowns)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Get Countdowns by Group ID
    func getCountdownsByGroupId(_ groupId: UUID) async throws -> [Countdown] {
        let countdowns: [Countdown] = try await supabase
            .from(TableName.countdowns)
            .select()
            .eq("group_id", value: groupId)
            .order("date")
            .execute()
            .value

        return countdowns
    }

    // MARK: - Delete Countdowns by Group ID
    func deleteCountdownsByGroupId(_ groupId: UUID) async throws {
        try await supabase
            .from(TableName.countdowns)
            .delete()
            .eq("group_id", value: groupId)
            .execute()
    }

    // MARK: - Update Group Fields
    func updateCountdownGroupFields(_ groupId: UUID, update: CountdownGroupUpdate) async throws -> [Countdown] {
        try await supabase
            .from(TableName.countdowns)
            .update(update)
            .eq("group_id", value: groupId)
            .execute()

        return try await getCountdownsByGroupId(groupId)
    }
}

// MARK: - Countdown Insert Type
struct CountdownInsert: Encodable {
    let accountId: UUID
    let title: String
    let subtitle: String?
    let date: Date
    let endDate: Date?
    let hasTime: Bool
    let type: CountdownType
    let customType: String?
    let notes: String?
    let imageUrl: String?
    let groupId: UUID?
    let reminderOffsetMinutes: Int?
    let isRecurring: Bool

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case title
        case subtitle
        case date
        case endDate = "end_date"
        case hasTime = "has_time"
        case type
        case customType = "custom_type"
        case notes
        case imageUrl = "image_url"
        case groupId = "group_id"
        case reminderOffsetMinutes = "reminder_offset_minutes"
        case isRecurring = "is_recurring"
    }

    init(
        accountId: UUID,
        title: String,
        subtitle: String? = nil,
        date: Date,
        endDate: Date? = nil,
        hasTime: Bool = false,
        type: CountdownType = .countdown,
        customType: String? = nil,
        notes: String? = nil,
        imageUrl: String? = nil,
        groupId: UUID? = nil,
        reminderOffsetMinutes: Int? = nil,
        isRecurring: Bool = false
    ) {
        self.accountId = accountId
        self.title = title
        self.subtitle = subtitle
        self.date = date
        self.endDate = endDate
        self.hasTime = hasTime
        self.type = type
        self.customType = customType
        self.notes = notes
        self.imageUrl = imageUrl
        self.groupId = groupId
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.isRecurring = isRecurring
    }

    // Custom encoding to handle date fields for PostgreSQL timestamptz
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        try container.encode(dateFormatter.string(from: date), forKey: .date)

        if let endDate = endDate {
            try container.encode(dateFormatter.string(from: endDate), forKey: .endDate)
        } else {
            try container.encodeNil(forKey: .endDate)
        }

        try container.encode(hasTime, forKey: .hasTime)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(customType, forKey: .customType)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try container.encodeIfPresent(reminderOffsetMinutes, forKey: .reminderOffsetMinutes)
        try container.encode(isRecurring, forKey: .isRecurring)
    }
}

// MARK: - Countdown Update Type
private struct CountdownUpdate: Encodable {
    let title: String
    let subtitle: String?
    let date: Date
    let endDate: Date?
    let hasTime: Bool
    let type: CountdownType
    let customType: String?
    let notes: String?
    let imageUrl: String?
    let groupId: UUID?
    let reminderOffsetMinutes: Int?
    let isRecurring: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case date
        case endDate = "end_date"
        case hasTime = "has_time"
        case type
        case customType = "custom_type"
        case notes
        case imageUrl = "image_url"
        case groupId = "group_id"
        case reminderOffsetMinutes = "reminder_offset_minutes"
        case isRecurring = "is_recurring"
    }

    // Custom encoding to handle date fields for PostgreSQL timestamptz
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        try container.encode(dateFormatter.string(from: date), forKey: .date)

        if let endDate = endDate {
            try container.encode(dateFormatter.string(from: endDate), forKey: .endDate)
        } else {
            try container.encodeNil(forKey: .endDate)
        }

        try container.encode(hasTime, forKey: .hasTime)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(customType, forKey: .customType)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try container.encodeIfPresent(reminderOffsetMinutes, forKey: .reminderOffsetMinutes)
        try container.encode(isRecurring, forKey: .isRecurring)
    }
}

// MARK: - Countdown Group Update Type
struct CountdownGroupUpdate: Encodable {
    let title: String
    let hasTime: Bool
    let type: CountdownType
    let customType: String?
    let notes: String?
    let imageUrl: String?
    let reminderOffsetMinutes: Int?
    let isRecurring: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case hasTime = "has_time"
        case type
        case customType = "custom_type"
        case notes
        case imageUrl = "image_url"
        case reminderOffsetMinutes = "reminder_offset_minutes"
        case isRecurring = "is_recurring"
    }
}
