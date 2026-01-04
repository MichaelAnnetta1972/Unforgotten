import Foundation
import Supabase

// MARK: - Sticky Reminder Repository Protocol
protocol StickyReminderRepositoryProtocol {
    func getReminders(accountId: UUID) async throws -> [StickyReminder]
    func getActiveReminders(accountId: UUID) async throws -> [StickyReminder]
    func getReminder(id: UUID) async throws -> StickyReminder
    func createReminder(_ reminder: StickyReminderInsert) async throws -> StickyReminder
    func updateReminder(_ reminder: StickyReminder) async throws -> StickyReminder
    func dismissReminder(id: UUID) async throws -> StickyReminder
    func reactivateReminder(id: UUID) async throws -> StickyReminder
    func deleteReminder(id: UUID) async throws
    func updateSortOrders(_ updates: [SortOrderUpdate]) async throws
}

// MARK: - Sticky Reminder Repository Implementation
final class StickyReminderRepository: StickyReminderRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Get All Reminders
    func getReminders(accountId: UUID) async throws -> [StickyReminder] {
        let reminders: [StickyReminder] = try await supabase
            .from(TableName.stickyReminders)
            .select()
            .eq("account_id", value: accountId)
            .order("sort_order")
            .order("trigger_time")
            .execute()
            .value

        return reminders
    }

    // MARK: - Get Active Reminders (not dismissed)
    func getActiveReminders(accountId: UUID) async throws -> [StickyReminder] {
        let reminders: [StickyReminder] = try await supabase
            .from(TableName.stickyReminders)
            .select()
            .eq("account_id", value: accountId)
            .eq("is_active", value: true)
            .eq("is_dismissed", value: false)
            .order("trigger_time")
            .execute()
            .value

        return reminders
    }

    // MARK: - Get Single Reminder
    func getReminder(id: UUID) async throws -> StickyReminder {
        let reminder: StickyReminder = try await supabase
            .from(TableName.stickyReminders)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value

        return reminder
    }

    // MARK: - Create Reminder
    func createReminder(_ reminder: StickyReminderInsert) async throws -> StickyReminder {
        let created: StickyReminder = try await supabase
            .from(TableName.stickyReminders)
            .insert(reminder)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    // MARK: - Update Reminder
    func updateReminder(_ reminder: StickyReminder) async throws -> StickyReminder {
        let update = StickyReminderUpdate(
            title: reminder.title,
            message: reminder.message,
            triggerTime: reminder.triggerTime,
            repeatInterval: reminder.repeatInterval,
            isActive: reminder.isActive,
            isDismissed: reminder.isDismissed
        )

        let updated: StickyReminder = try await supabase
            .from(TableName.stickyReminders)
            .update(update)
            .eq("id", value: reminder.id)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    // MARK: - Dismiss Reminder
    func dismissReminder(id: UUID) async throws -> StickyReminder {
        let update = StickyReminderDismissUpdate(isDismissed: true)

        let updated: StickyReminder = try await supabase
            .from(TableName.stickyReminders)
            .update(update)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    // MARK: - Reactivate Reminder
    func reactivateReminder(id: UUID) async throws -> StickyReminder {
        let update = StickyReminderReactivateUpdate(
            isDismissed: false,
            triggerTime: Date()
        )

        let updated: StickyReminder = try await supabase
            .from(TableName.stickyReminders)
            .update(update)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    // MARK: - Delete Reminder
    func deleteReminder(id: UUID) async throws {
        try await supabase
            .from(TableName.stickyReminders)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Update Sort Orders
    func updateSortOrders(_ updates: [SortOrderUpdate]) async throws {
        for update in updates {
            try await supabase
                .from(TableName.stickyReminders)
                .update(["sort_order": update.sortOrder])
                .eq("id", value: update.id)
                .execute()
        }
    }
}

// MARK: - Sticky Reminder Insert Type
struct StickyReminderInsert: Encodable {
    let accountId: UUID
    let title: String
    let message: String?
    let triggerTime: Date
    let repeatInterval: StickyReminderInterval
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case title
        case message
        case triggerTime = "trigger_time"
        case repeatInterval = "repeat_interval"
        case isActive = "is_active"
    }

    init(
        accountId: UUID,
        title: String,
        message: String? = nil,
        triggerTime: Date,
        repeatInterval: StickyReminderInterval = .everyHour,
        isActive: Bool = true
    ) {
        self.accountId = accountId
        self.title = title
        self.message = message
        self.triggerTime = triggerTime
        self.repeatInterval = repeatInterval
        self.isActive = isActive
    }
}

// MARK: - Sticky Reminder Update Type
private struct StickyReminderUpdate: Encodable {
    let title: String
    let message: String?
    let triggerTime: Date
    let repeatInterval: StickyReminderInterval
    let isActive: Bool
    let isDismissed: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case message
        case triggerTime = "trigger_time"
        case repeatInterval = "repeat_interval"
        case isActive = "is_active"
        case isDismissed = "is_dismissed"
    }
}

// MARK: - Sticky Reminder Dismiss Update
private struct StickyReminderDismissUpdate: Encodable {
    let isDismissed: Bool

    enum CodingKeys: String, CodingKey {
        case isDismissed = "is_dismissed"
    }
}

// MARK: - Sticky Reminder Reactivate Update
private struct StickyReminderReactivateUpdate: Encodable {
    let isDismissed: Bool
    let triggerTime: Date

    enum CodingKeys: String, CodingKey {
        case isDismissed = "is_dismissed"
        case triggerTime = "trigger_time"
    }
}
