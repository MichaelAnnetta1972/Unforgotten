import Foundation
import Supabase
import Realtime

/// Service that manages Supabase Realtime subscriptions for cross-device data synchronization
@MainActor
final class RealtimeSyncService: ObservableObject {
    static let shared = RealtimeSyncService()

    private let supabase = SupabaseManager.shared.client
    private var appointmentsChannel: RealtimeChannelV2?
    private var stickyRemindersChannel: RealtimeChannelV2?
    private var changeListenerTask: Task<Void, Never>?
    private var stickyReminderListenerTask: Task<Void, Never>?
    private var currentAccountId: UUID?

    private init() {}

    // MARK: - Public API

    /// Start listening for changes on the specified account
    func startListening(accountId: UUID) async {
        // Don't restart if already listening to the same account
        guard currentAccountId != accountId else { return }

        // Stop any existing subscriptions
        await stopListening()

        currentAccountId = accountId

        // Subscribe to appointments table changes for this account
        await subscribeToAppointments(accountId: accountId)

        // Subscribe to sticky reminders table changes for this account
        await subscribeToStickyReminders(accountId: accountId)

        print("📡 RealtimeSyncService: Started listening for account \(accountId)")
    }

    /// Stop all realtime subscriptions
    func stopListening() async {
        changeListenerTask?.cancel()
        changeListenerTask = nil

        stickyReminderListenerTask?.cancel()
        stickyReminderListenerTask = nil

        if let channel = appointmentsChannel {
            await supabase.realtimeV2.removeChannel(channel)
            appointmentsChannel = nil
        }

        if let channel = stickyRemindersChannel {
            await supabase.realtimeV2.removeChannel(channel)
            stickyRemindersChannel = nil
        }

        currentAccountId = nil
        print("📡 RealtimeSyncService: Stopped listening")
    }

    // MARK: - Private Subscriptions

    private func subscribeToAppointments(accountId: UUID) async {
        let channel = supabase.channel("appointments_\(accountId.uuidString)")

        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: TableName.appointments,
            filter: "account_id=eq.\(accountId.uuidString)"
        )

        await channel.subscribe()
        appointmentsChannel = channel

        // Listen for changes in a detached task
        changeListenerTask = Task { [weak self] in
            for await change in changeStream {
                guard !Task.isCancelled else { break }
                await self?.handleAppointmentChange(change)
            }
        }
    }

    private func handleAppointmentChange(_ change: AnyAction) async {
        print("📡 RealtimeSyncService: Received appointment change")

        switch change {
        case .insert(let action):
            // New appointment created on another device
            print("📡 RealtimeSyncService: INSERT detected")
            NotificationCenter.default.post(
                name: .appointmentsDidChange,
                object: nil,
                userInfo: [
                    NotificationUserInfoKey.action: AppointmentChangeAction.created
                ]
            )

        case .update(let action):
            // Appointment updated on another device - try to decode and pass the data
            print("📡 RealtimeSyncService: UPDATE detected")
            if let appointment = decodeAppointment(from: action.record) {
                NotificationCenter.default.post(
                    name: .appointmentsDidChange,
                    object: nil,
                    userInfo: [
                        NotificationUserInfoKey.appointmentId: appointment.id,
                        NotificationUserInfoKey.action: AppointmentChangeAction.updated,
                        NotificationUserInfoKey.appointment: appointment
                    ]
                )
            } else {
                // Couldn't decode, just trigger a refresh
                NotificationCenter.default.post(
                    name: .appointmentsDidChange,
                    object: nil,
                    userInfo: [
                        NotificationUserInfoKey.action: AppointmentChangeAction.updated
                    ]
                )
            }

        case .delete(let action):
            // Appointment deleted on another device
            print("📡 RealtimeSyncService: DELETE detected")
            if let idValue = action.oldRecord["id"],
               let idString = extractStringValue(from: idValue),
               let appointmentId = UUID(uuidString: idString) {
                NotificationCenter.default.post(
                    name: .appointmentsDidChange,
                    object: nil,
                    userInfo: [
                        NotificationUserInfoKey.appointmentId: appointmentId,
                        NotificationUserInfoKey.action: AppointmentChangeAction.deleted
                    ]
                )
            } else {
                // Couldn't get ID, just trigger a refresh
                NotificationCenter.default.post(
                    name: .appointmentsDidChange,
                    object: nil,
                    userInfo: [
                        NotificationUserInfoKey.action: AppointmentChangeAction.deleted
                    ]
                )
            }
        }
    }

    /// Extract string value from AnyJSON
    private func extractStringValue(from json: AnyJSON) -> String? {
        switch json {
        case .string(let value):
            return value
        default:
            return nil
        }
    }

    /// Decode an Appointment from a Realtime record
    private func decodeAppointment(from record: [String: AnyJSON]) -> Appointment? {
        do {
            // Convert the record to JSON data and decode
            let jsonData = try JSONEncoder().encode(record)
            let decoder = JSONDecoder()

            // Use the same date decoding strategy as SupabaseManager
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Date-only format (e.g., "2024-01-15")
                let dateOnlyFormatter = DateFormatter()
                dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
                dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = dateOnlyFormatter.date(from: dateString) {
                    return date
                }

                // ISO8601 with microseconds
                let iso8601WithMicroseconds = DateFormatter()
                iso8601WithMicroseconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
                iso8601WithMicroseconds.locale = Locale(identifier: "en_US_POSIX")
                iso8601WithMicroseconds.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = iso8601WithMicroseconds.date(from: dateString) {
                    return date
                }

                // Standard ISO8601
                let iso8601Formatter = ISO8601DateFormatter()
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }

                // Time-only format
                if dateString.range(of: "^\\d{2}:\\d{2}:\\d{2}$", options: .regularExpression) != nil {
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    let components = dateString.split(separator: ":").compactMap { Int($0) }
                    if components.count == 3 {
                        var dateComponents = calendar.dateComponents([.year, .month, .day], from: today)
                        dateComponents.hour = components[0]
                        dateComponents.minute = components[1]
                        dateComponents.second = components[2]
                        dateComponents.timeZone = TimeZone.current
                        if let date = calendar.date(from: dateComponents) {
                            return date
                        }
                    }
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date from: \(dateString)"
                )
            }

            return try decoder.decode(Appointment.self, from: jsonData)
        } catch {
            print("📡 RealtimeSyncService: Failed to decode appointment: \(error)")
            return nil
        }
    }

    // MARK: - Sticky Reminders Subscription

    private func subscribeToStickyReminders(accountId: UUID) async {
        let channel = supabase.channel("sticky_reminders_\(accountId.uuidString)")

        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: TableName.stickyReminders,
            filter: "account_id=eq.\(accountId.uuidString)"
        )

        await channel.subscribe()
        stickyRemindersChannel = channel

        // Listen for changes in a detached task
        stickyReminderListenerTask = Task { [weak self] in
            for await change in changeStream {
                guard !Task.isCancelled else { break }
                await self?.handleStickyReminderChange(change)
            }
        }
    }

    private func handleStickyReminderChange(_ change: AnyAction) async {
        print("📡 RealtimeSyncService: Received sticky reminder change")

        switch change {
        case .insert(let action):
            print("📡 RealtimeSyncService: Sticky reminder INSERT detected")

            // Try to decode the reminder and schedule local notification
            if let reminder = decodeStickyReminder(from: action.record) {
                print("📡 RealtimeSyncService: Scheduling notification for new reminder: \(reminder.title)")
                await NotificationService.shared.scheduleStickyReminder(reminder: reminder)
            }

            NotificationCenter.default.post(
                name: .stickyRemindersDidChange,
                object: nil,
                userInfo: ["action": StickyReminderChangeAction.created]
            )

        case .update(let action):
            print("📡 RealtimeSyncService: Sticky reminder UPDATE detected")
            var userInfo: [String: Any] = ["action": StickyReminderChangeAction.updated]

            // Try to decode the updated reminder and reschedule local notification
            if let reminder = decodeStickyReminder(from: action.record) {
                userInfo["reminderId"] = reminder.id

                if reminder.isActive && !reminder.isDismissed {
                    print("📡 RealtimeSyncService: Rescheduling notification for updated reminder: \(reminder.title)")
                    await NotificationService.shared.scheduleStickyReminder(reminder: reminder)
                } else {
                    print("📡 RealtimeSyncService: Cancelling notification for dismissed/inactive reminder: \(reminder.title)")
                    await NotificationService.shared.cancelStickyReminder(reminderId: reminder.id)
                }
            } else if let idValue = action.record["id"],
                      let idString = extractStringValue(from: idValue),
                      let reminderId = UUID(uuidString: idString) {
                userInfo["reminderId"] = reminderId
            }

            NotificationCenter.default.post(
                name: .stickyRemindersDidChange,
                object: nil,
                userInfo: userInfo
            )

        case .delete(let action):
            print("📡 RealtimeSyncService: Sticky reminder DELETE detected")
            var userInfo: [String: Any] = ["action": StickyReminderChangeAction.deleted]

            // Cancel the local notification for the deleted reminder
            if let idValue = action.oldRecord["id"],
               let idString = extractStringValue(from: idValue),
               let reminderId = UUID(uuidString: idString) {
                userInfo["reminderId"] = reminderId
                print("📡 RealtimeSyncService: Cancelling notification for deleted reminder: \(reminderId)")
                await NotificationService.shared.cancelStickyReminder(reminderId: reminderId)
            }

            NotificationCenter.default.post(
                name: .stickyRemindersDidChange,
                object: nil,
                userInfo: userInfo
            )
        }
    }

    /// Decode a StickyReminder from a Realtime record
    private func decodeStickyReminder(from record: [String: AnyJSON]) -> StickyReminder? {
        do {
            // Convert the record to JSON data and decode
            let jsonData = try JSONEncoder().encode(record)
            let decoder = JSONDecoder()

            // Use the same date decoding strategy as SupabaseManager
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Date-only format (e.g., "2024-01-15")
                let dateOnlyFormatter = DateFormatter()
                dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
                dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = dateOnlyFormatter.date(from: dateString) {
                    return date
                }

                // ISO8601 with microseconds
                let iso8601WithMicroseconds = DateFormatter()
                iso8601WithMicroseconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
                iso8601WithMicroseconds.locale = Locale(identifier: "en_US_POSIX")
                iso8601WithMicroseconds.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = iso8601WithMicroseconds.date(from: dateString) {
                    return date
                }

                // ISO8601 without timezone (Supabase default)
                let iso8601NoTZ = DateFormatter()
                iso8601NoTZ.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                iso8601NoTZ.locale = Locale(identifier: "en_US_POSIX")
                iso8601NoTZ.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = iso8601NoTZ.date(from: dateString) {
                    return date
                }

                // Standard ISO8601
                let iso8601Formatter = ISO8601DateFormatter()
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date from: \(dateString)"
                )
            }

            return try decoder.decode(StickyReminder.self, from: jsonData)
        } catch {
            print("📡 RealtimeSyncService: Failed to decode sticky reminder: \(error)")
            return nil
        }
    }
}

// MARK: - Sticky Reminder Change Action
enum StickyReminderChangeAction: String {
    case created
    case updated
    case deleted
}
