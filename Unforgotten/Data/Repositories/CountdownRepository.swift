import Foundation
import Supabase

// MARK: - Countdown Repository Protocol
protocol CountdownRepositoryProtocol {
    func getCountdowns(accountId: UUID) async throws -> [Countdown]
    func getUpcomingCountdowns(accountId: UUID, days: Int) async throws -> [Countdown]
    func getCountdown(id: UUID) async throws -> Countdown
    func createCountdown(_ countdown: CountdownInsert) async throws -> Countdown
    func updateCountdown(_ countdown: Countdown) async throws -> Countdown
    func deleteCountdown(id: UUID) async throws
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
            date: countdown.date,
            type: countdown.type,
            customType: countdown.customType,
            notes: countdown.notes,
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
}

// MARK: - Countdown Insert Type
struct CountdownInsert: Encodable {
    let accountId: UUID
    let title: String
    let date: Date
    let type: CountdownType
    let customType: String?
    let notes: String?
    let reminderOffsetMinutes: Int?
    let isRecurring: Bool

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case title
        case date
        case type
        case customType = "custom_type"
        case notes
        case reminderOffsetMinutes = "reminder_offset_minutes"
        case isRecurring = "is_recurring"
    }

    init(
        accountId: UUID,
        title: String,
        date: Date,
        type: CountdownType = .countdown,
        customType: String? = nil,
        notes: String? = nil,
        reminderOffsetMinutes: Int? = nil,
        isRecurring: Bool = false
    ) {
        self.accountId = accountId
        self.title = title
        self.date = date
        self.type = type
        self.customType = customType
        self.notes = notes
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.isRecurring = isRecurring
    }

    // Custom encoding to handle date field for PostgreSQL
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(title, forKey: .title)

        // Encode date as yyyy-MM-dd string for PostgreSQL date column
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = dateFormatter.string(from: date)
        try container.encode(dateString, forKey: .date)

        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(customType, forKey: .customType)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(reminderOffsetMinutes, forKey: .reminderOffsetMinutes)
        try container.encode(isRecurring, forKey: .isRecurring)
    }
}

// MARK: - Countdown Update Type
private struct CountdownUpdate: Encodable {
    let title: String
    let date: Date
    let type: CountdownType
    let customType: String?
    let notes: String?
    let reminderOffsetMinutes: Int?
    let isRecurring: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case date
        case type
        case customType = "custom_type"
        case notes
        case reminderOffsetMinutes = "reminder_offset_minutes"
        case isRecurring = "is_recurring"
    }

    // Custom encoding to handle date field for PostgreSQL
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)

        // Encode date as yyyy-MM-dd string for PostgreSQL date column
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = dateFormatter.string(from: date)
        try container.encode(dateString, forKey: .date)

        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(customType, forKey: .customType)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(reminderOffsetMinutes, forKey: .reminderOffsetMinutes)
        try container.encode(isRecurring, forKey: .isRecurring)
    }
}
