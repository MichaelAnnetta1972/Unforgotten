import Foundation
import UIKit
import UserNotifications

// MARK: - Notification Action Identifiers
enum NotificationAction: String {
    case takeMedication = "TAKE_MEDICATION"
    case snoozeMedication = "SNOOZE_MEDICATION"
    case viewAppointment = "VIEW_APPOINTMENT"
    case dismissStickyReminder = "DISMISS_STICKY_REMINDER"
}

// MARK: - Notification Category Identifiers
enum NotificationCategory: String {
    case medicationReminder = "MEDICATION_REMINDER"
    case appointmentReminder = "APPOINTMENT_REMINDER"
    case birthdayReminder = "BIRTHDAY_REMINDER"
    case stickyReminder = "STICKY_REMINDER"
    case morningBriefing = "MORNING_BRIEFING"
}

// MARK: - Notification Handler Protocol
protocol NotificationHandlerDelegate: AnyObject {
    func handleMedicationTaken(medicationId: UUID, scheduledTime: Date) async
    func handleMedicationSnooze(medicationId: UUID, medicationName: String, doseDescription: String?) async
    func handleAppointmentView(appointmentId: UUID)
    func handleBirthdayView(profileId: UUID)
    func handleStickyReminderDismiss(reminderId: UUID) async
    func handleStickyReminderTapped(reminderId: UUID)
}

// MARK: - Notification Preferences Keys
enum NotificationPreferenceKey {
    static let allowNotifications = "unforgotten_allow_notifications"
    static let hideNotificationPreviews = "unforgotten_hide_notification_previews"
    static let dailySummaryEnabled = "unforgotten_daily_summary_enabled"
}

// MARK: - Notification Service
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    weak var delegate: NotificationHandlerDelegate?

    // Store pending notification data when delegate isn't ready yet
    var pendingAppointmentId: UUID?
    var pendingProfileId: UUID?
    var pendingStickyReminderId: UUID?

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    // MARK: - Notification Preferences

    /// Whether notifications are allowed by the user (in-app setting)
    var allowNotifications: Bool {
        get {
            // Default to true if key has never been set (e.g. first launch or granted during onboarding)
            if UserDefaults.standard.object(forKey: NotificationPreferenceKey.allowNotifications) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: NotificationPreferenceKey.allowNotifications)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: NotificationPreferenceKey.allowNotifications)
            if !newValue {
                // When disabled, remove all pending notifications
                removeAllPendingNotifications()
                notificationCenter.removeAllDeliveredNotifications()
            }
        }
    }

    /// Whether notification previews should be hidden (show generic text instead of details)
    var hideNotificationPreviews: Bool {
        get { UserDefaults.standard.bool(forKey: NotificationPreferenceKey.hideNotificationPreviews) }
        set { UserDefaults.standard.set(newValue, forKey: NotificationPreferenceKey.hideNotificationPreviews) }
    }

    /// Whether the daily summary notification at 2:00 AM is enabled
    var dailySummaryEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: NotificationPreferenceKey.dailySummaryEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: NotificationPreferenceKey.dailySummaryEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: NotificationPreferenceKey.dailySummaryEnabled)
            if !newValue {
                cancelDailySummary()
            }
        }
    }

    /// Check and transfer any pending notification IDs to the delegate
    func processPendingNotifications() {
        guard let delegate = delegate else { return }

        if let appointmentId = pendingAppointmentId {
            pendingAppointmentId = nil
            delegate.handleAppointmentView(appointmentId: appointmentId)
        }

        if let profileId = pendingProfileId {
            pendingProfileId = nil
            delegate.handleBirthdayView(profileId: profileId)
        }

        if let reminderId = pendingStickyReminderId {
            pendingStickyReminderId = nil
            delegate.handleStickyReminderTapped(reminderId: reminderId)
        }
    }

    /// Checks if notifications are allowed (both system permission and in-app setting)
    private func isNotificationAllowed() async -> Bool {
        guard allowNotifications else { return false }
        let status = await checkPermissionStatus()
        return status == .authorized
    }

    /// Applies hide-preview setting to notification content
    /// Also adds a flag to userInfo so the content extension can detect it
    private func applyHidePreviewIfNeeded(_ content: UNMutableNotificationContent, fallbackBody: String) {
        // Always pass the flag so the content extension knows whether to hide previews
        var info = content.userInfo
        info["hidePreview"] = hideNotificationPreviews
        content.userInfo = info

        if hideNotificationPreviews {
            content.title = "Unforgotten"
            content.subtitle = ""
            content.body = fallbackBody
        }
    }

    // MARK: - Permission

    /// Request notification permission from the user
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            #if DEBUG
            print("Notification permission error: \(error)")
            #endif
            return false
        }
    }

    /// Check current notification authorization status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Medication Reminders

    /// Schedule a medication reminder
    func scheduleMedicationReminder(
        medicationId: UUID,
        medicationName: String,
        scheduledTime: Date,
        doseDescription: String?
    ) async {
        guard await isNotificationAllowed() else {
            #if DEBUG
            print("📱 Notifications not allowed, skipping medication reminder")
            #endif
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Time to take your medication"
        content.subtitle = "Press and hold for more details"
        if let doseDescription {
            content.body = "\(medicationName) - \(doseDescription)"
        } else {
            content.body = medicationName
        }
        applyHidePreviewIfNeeded(content, fallbackBody: "You have things to do today. Open the Unforgotten app to get started.")
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.medicationReminder.rawValue
        content.userInfo = [
            "medicationId": medicationId.uuidString,
            "medicationName": medicationName,
            "doseDescription": doseDescription ?? "",
            "scheduledTime": scheduledTime.ISO8601Format()
        ]

        // Create trigger for the specific time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: scheduledTime)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let identifier = "medication-\(medicationId.uuidString)-\(components.hour ?? 0)-\(components.minute ?? 0)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            #if DEBUG
            print("📱 Scheduled medication reminder for \(medicationName) at \(components.hour ?? 0):\(components.minute ?? 0)")
            #endif
        } catch {
            #if DEBUG
            print("Failed to schedule medication reminder: \(error)")
            #endif
        }
    }

    /// Cancel all reminders for a medication
    func cancelMedicationReminders(medicationId: UUID) {
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiers = requests
                .filter { $0.identifier.starts(with: "medication-\(medicationId.uuidString)") }
                .map { $0.identifier }

            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    // MARK: - Appointment Reminders

    /// Schedule an appointment reminder
    func scheduleAppointmentReminder(
        appointmentId: UUID,
        title: String,
        appointmentDate: Date,
        appointmentTime: Date?,
        location: String?,
        reminderMinutesBefore: Int
    ) async {
        guard await isNotificationAllowed() else {
            #if DEBUG
            print("📱 Notifications not allowed, skipping appointment reminder")
            #endif
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Appointment"
        content.subtitle = "Press and hold for more details"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.appointmentReminder.rawValue
        // Build body text
        var bodyParts: [String] = [title]
        if let location = location {
            bodyParts.append("at \(location)")
        }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        var timeString = ""
        if let time = appointmentTime {
            timeString = timeFormatter.string(from: time)
            bodyParts.append("at \(timeString)")
        }

        content.body = bodyParts.joined(separator: " ")
        content.userInfo = [
            "appointmentId": appointmentId.uuidString,
            "appointmentTitle": title,
            "appointmentLocation": location ?? "",
            "appointmentTime": timeString
        ]
        applyHidePreviewIfNeeded(content, fallbackBody: "You have things to do today. Open the Unforgotten app to get started.")

        // Calculate reminder time
        var reminderDate: Date
        if let time = appointmentTime {
            // Combine date and time
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: appointmentDate)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute

            if let combined = calendar.date(from: components) {
                reminderDate = combined.addingTimeInterval(-Double(reminderMinutesBefore * 60))
            } else {
                reminderDate = appointmentDate.addingTimeInterval(-Double(reminderMinutesBefore * 60))
            }
        } else {
            // Use start of day if no time specified
            reminderDate = Calendar.current.startOfDay(for: appointmentDate)
                .addingTimeInterval(-Double(reminderMinutesBefore * 60))
        }

        // Only schedule if in the future
        guard reminderDate > Date() else { return }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: reminderDate.timeIntervalSinceNow,
            repeats: false
        )

        let identifier = "appointment-\(appointmentId.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            #if DEBUG
            print("📱 Scheduled appointment reminder for '\(title)' at \(reminderDate)")
            #endif
        } catch {
            #if DEBUG
            print("Failed to schedule appointment reminder: \(error)")
            #endif
        }
    }

    /// Cancel reminder for an appointment
    func cancelAppointmentReminder(appointmentId: UUID) {
        let identifier = "appointment-\(appointmentId.uuidString)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Birthday Reminders

    /// Schedule birthday reminders (day before and day of)
    func scheduleBirthdayReminder(
        profileId: UUID,
        name: String,
        birthday: Date
    ) async {
        guard await isNotificationAllowed() else {
            #if DEBUG
            print("📱 Notifications not allowed, skipping birthday reminder")
            #endif
            return
        }

        let calendar = Calendar.current

        // MARK: Day Before Notification
        let dayBeforeContent = UNMutableNotificationContent()
        dayBeforeContent.title = "Birthday Tomorrow!"
        dayBeforeContent.subtitle = "Press and hold for more details"
        dayBeforeContent.body = "\(name)'s birthday is tomorrow. Don't forget!"
        applyHidePreviewIfNeeded(dayBeforeContent, fallbackBody: "You have things to do today. Open the Unforgotten app to get started.")
        dayBeforeContent.sound = .default
        dayBeforeContent.categoryIdentifier = NotificationCategory.birthdayReminder.rawValue
        dayBeforeContent.userInfo = ["profileId": profileId.uuidString]

        // Schedule for 9am the day before the birthday
        var dayBeforeComponents = calendar.dateComponents([.month, .day], from: birthday)
        dayBeforeComponents.hour = 9
        dayBeforeComponents.minute = 0

        // Adjust to day before
        if let day = dayBeforeComponents.day {
            dayBeforeComponents.day = day - 1
            if dayBeforeComponents.day == 0 {
                // Handle month boundary
                if let month = dayBeforeComponents.month {
                    dayBeforeComponents.month = month - 1
                    if dayBeforeComponents.month == 0 {
                        dayBeforeComponents.month = 12
                    }
                    // Set to last day of previous month
                    dayBeforeComponents.day = calendar.range(of: .day, in: .month, for: birthday)?.count ?? 28
                }
            }
        }

        let dayBeforeTrigger = UNCalendarNotificationTrigger(dateMatching: dayBeforeComponents, repeats: true)
        let dayBeforeIdentifier = "birthday-daybefore-\(profileId.uuidString)"
        let dayBeforeRequest = UNNotificationRequest(identifier: dayBeforeIdentifier, content: dayBeforeContent, trigger: dayBeforeTrigger)

        do {
            try await notificationCenter.add(dayBeforeRequest)
            #if DEBUG
            print("📱 Scheduled birthday reminder for \(name) (day before birthday)")
            #endif
        } catch {
            #if DEBUG
            print("Failed to schedule day-before birthday reminder: \(error)")
            #endif
        }

        // MARK: Day Of Notification
        let dayOfContent = UNMutableNotificationContent()
        dayOfContent.title = "Happy Birthday!"
        dayOfContent.subtitle = "Press and hold for more details"
        dayOfContent.body = "Today is \(name)'s birthday! 🎂"
        dayOfContent.sound = .default
        dayOfContent.categoryIdentifier = NotificationCategory.birthdayReminder.rawValue
        dayOfContent.userInfo = ["profileId": profileId.uuidString]
        applyHidePreviewIfNeeded(dayOfContent, fallbackBody: "You have things to do today. Open the Unforgotten app to get started.")

        // Schedule for 9am on the birthday
        var dayOfComponents = calendar.dateComponents([.month, .day], from: birthday)
        dayOfComponents.hour = 9
        dayOfComponents.minute = 0

        let dayOfTrigger = UNCalendarNotificationTrigger(dateMatching: dayOfComponents, repeats: true)
        let dayOfIdentifier = "birthday-dayof-\(profileId.uuidString)"
        let dayOfRequest = UNNotificationRequest(identifier: dayOfIdentifier, content: dayOfContent, trigger: dayOfTrigger)

        do {
            try await notificationCenter.add(dayOfRequest)
            #if DEBUG
            print("📱 Scheduled birthday reminder for \(name) (day of birthday)")
            #endif
        } catch {
            #if DEBUG
            print("Failed to schedule day-of birthday reminder: \(error)")
            #endif
        }
    }

    /// Cancel birthday reminders
    func cancelBirthdayReminder(profileId: UUID) {
        let identifiers = [
            "birthday-daybefore-\(profileId.uuidString)",
            "birthday-dayof-\(profileId.uuidString)"
        ]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Countdown Reminders

    /// Schedule countdown reminders (advance reminder if set, plus day-of notification)
    func scheduleCountdownReminder(
        countdownId: UUID,
        title: String,
        countdownDate: Date,
        reminderMinutesBefore: Int,
        isRecurring: Bool
    ) async {
        guard await isNotificationAllowed() else {
            #if DEBUG
            print("📱 Notifications not allowed, skipping countdown reminder")
            #endif
            return
        }

        let calendar = Calendar.current

        // MARK: Advance Reminder (if not "On the day")
        if reminderMinutesBefore > 0 {
            let advanceContent = UNMutableNotificationContent()
            advanceContent.title = "Upcoming Event"
            advanceContent.subtitle = "Press and hold for more details"

            // Create descriptive body based on reminder offset
            let daysUntil = reminderMinutesBefore / 1440
            if daysUntil == 1 {
                advanceContent.body = "\(title) is tomorrow!"
            } else if daysUntil > 1 {
                advanceContent.body = "\(title) is in \(daysUntil) days"
            } else {
                advanceContent.body = title
            }

            advanceContent.sound = .default
            advanceContent.categoryIdentifier = NotificationCategory.birthdayReminder.rawValue
            advanceContent.userInfo = ["countdownId": countdownId.uuidString]
            applyHidePreviewIfNeeded(advanceContent, fallbackBody: "You have things to do today. Open the Unforgotten app to get started.")

            if isRecurring {
                // For recurring events, use calendar trigger with month/day
                var components = calendar.dateComponents([.month, .day], from: countdownDate)

                let daysBefore = reminderMinutesBefore / 1440
                if let day = components.day {
                    components.day = day - daysBefore
                    // Handle month boundary
                    if let newDay = components.day, newDay <= 0 {
                        // Need to go to previous month
                        if let month = components.month {
                            components.month = month - 1
                            if components.month == 0 {
                                components.month = 12
                            }
                            // Get days in previous month
                            if let prevMonthDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: countdownDate), month: components.month)),
                               let daysInPrevMonth = calendar.range(of: .day, in: .month, for: prevMonthDate)?.count {
                                components.day = daysInPrevMonth + newDay
                            } else {
                                components.day = 28 + newDay // Fallback
                            }
                        }
                    }
                }
                components.hour = 9
                components.minute = 0

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = "countdown-advance-\(countdownId.uuidString)"
                let request = UNNotificationRequest(identifier: identifier, content: advanceContent, trigger: trigger)

                do {
                    try await notificationCenter.add(request)
                    #if DEBUG
                    print("📱 Scheduled recurring advance countdown reminder for '\(title)'")
                    #endif
                } catch {
                    #if DEBUG
                    print("Failed to schedule advance countdown reminder: \(error)")
                    #endif
                }
            } else {
                // One-time countdown advance reminder
                let startOfEventDay = calendar.startOfDay(for: countdownDate)
                let reminderDate = startOfEventDay.addingTimeInterval(-Double(reminderMinutesBefore * 60))

                if reminderDate > Date() {
                    let trigger = UNTimeIntervalNotificationTrigger(
                        timeInterval: reminderDate.timeIntervalSinceNow,
                        repeats: false
                    )

                    let identifier = "countdown-advance-\(countdownId.uuidString)"
                    let request = UNNotificationRequest(identifier: identifier, content: advanceContent, trigger: trigger)

                    do {
                        try await notificationCenter.add(request)
                        #if DEBUG
                        print("📱 Scheduled one-time advance countdown reminder for '\(title)' at \(reminderDate)")
                        #endif
                    } catch {
                        #if DEBUG
                        print("Failed to schedule advance countdown reminder: \(error)")
                        #endif
                    }
                }
            }
        }

        // MARK: Day-Of Notification (always scheduled)
        let dayOfContent = UNMutableNotificationContent()
        dayOfContent.title = "Today's Event"
        dayOfContent.subtitle = "Press and hold for more details"
        dayOfContent.body = "\(title) is today!"
        dayOfContent.sound = .default
        dayOfContent.categoryIdentifier = NotificationCategory.birthdayReminder.rawValue
        dayOfContent.userInfo = ["countdownId": countdownId.uuidString]
        applyHidePreviewIfNeeded(dayOfContent, fallbackBody: "You have things to do today. Open the Unforgotten app to get started.")

        if isRecurring {
            // Schedule for 9am on the event day, repeating yearly
            var dayOfComponents = calendar.dateComponents([.month, .day], from: countdownDate)
            dayOfComponents.hour = 9
            dayOfComponents.minute = 0

            let dayOfTrigger = UNCalendarNotificationTrigger(dateMatching: dayOfComponents, repeats: true)
            let dayOfIdentifier = "countdown-dayof-\(countdownId.uuidString)"
            let dayOfRequest = UNNotificationRequest(identifier: dayOfIdentifier, content: dayOfContent, trigger: dayOfTrigger)

            do {
                try await notificationCenter.add(dayOfRequest)
                #if DEBUG
                print("📱 Scheduled recurring day-of countdown reminder for '\(title)'")
                #endif
            } catch {
                #if DEBUG
                print("Failed to schedule day-of countdown reminder: \(error)")
                #endif
            }
        } else {
            // One-time day-of notification at 9am
            var dayOfComponents = calendar.dateComponents([.year, .month, .day], from: countdownDate)
            dayOfComponents.hour = 9
            dayOfComponents.minute = 0

            if let dayOfDate = calendar.date(from: dayOfComponents), dayOfDate > Date() {
                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: dayOfDate.timeIntervalSinceNow,
                    repeats: false
                )

                let dayOfIdentifier = "countdown-dayof-\(countdownId.uuidString)"
                let dayOfRequest = UNNotificationRequest(identifier: dayOfIdentifier, content: dayOfContent, trigger: trigger)

                do {
                    try await notificationCenter.add(dayOfRequest)
                    #if DEBUG
                    print("📱 Scheduled one-time day-of countdown reminder for '\(title)' at \(dayOfDate)")
                    #endif
                } catch {
                    #if DEBUG
                    print("Failed to schedule day-of countdown reminder: \(error)")
                    #endif
                }
            }
        }
    }

    /// Cancel countdown reminders (both advance and day-of)
    func cancelCountdownReminder(countdownId: UUID) async {
        let identifiers = [
            "countdown-advance-\(countdownId.uuidString)",
            "countdown-dayof-\(countdownId.uuidString)"
        ]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        #if DEBUG
        print("📱 Cancelled countdown reminders for \(countdownId)")
        #endif
    }

    // MARK: - Sticky Reminders

    /// Schedule a sticky reminder notification
    func scheduleStickyReminder(reminder: StickyReminder) async {
        guard await isNotificationAllowed() else {
            #if DEBUG
            print("📱 Notifications not allowed, skipping sticky reminder")
            #endif
            return
        }

        // Don't schedule if dismissed or inactive
        guard reminder.isActive && !reminder.isDismissed else {
            #if DEBUG
            print("📱 Sticky reminder is dismissed or inactive, skipping")
            #endif
            return
        }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.subtitle = "Press and hold for more details"
        content.body = reminder.message ?? "Press and hold for more details"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.stickyReminder.rawValue
        content.userInfo = [
            "reminderId": reminder.id.uuidString,
            "title": reminder.title,
            "repeatInterval": "\(reminder.repeatInterval.value)_\(reminder.repeatInterval.unit.rawValue)"
        ]
        applyHidePreviewIfNeeded(content, fallbackBody: "You have things to do today. Open the Unforgotten app to get started.")

        // Calculate trigger time
        let triggerDate: Date
        if reminder.triggerTime > Date() {
            // Future trigger - schedule for that time
            triggerDate = reminder.triggerTime
        } else {
            // Already triggered - schedule next occurrence based on repeat interval
            triggerDate = Date().addingTimeInterval(reminder.repeatInterval.intervalInSeconds)
        }

        // Only schedule if in the future
        guard triggerDate > Date() else {
            // Schedule immediately for next interval
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: reminder.repeatInterval.intervalInSeconds,
                repeats: true
            )

            let identifier = "sticky-\(reminder.id.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await notificationCenter.add(request)
                #if DEBUG
                print("📱 Scheduled repeating sticky reminder '\(reminder.title)' every \(reminder.repeatInterval.displayName)")
                #endif
            } catch {
                #if DEBUG
                print("Failed to schedule sticky reminder: \(error)")
                #endif
            }
            return
        }

        // Schedule for specific future time, then repeat
        let timeInterval = triggerDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(timeInterval, 1), // At least 1 second in future
            repeats: false
        )

        let identifier = "sticky-\(reminder.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            #if DEBUG
            print("📱 Scheduled sticky reminder '\(reminder.title)' for \(triggerDate)")
            #endif

            // Schedule the repeating notification to start after the initial trigger
            await scheduleRepeatingStickReminder(reminder: reminder, startAfter: triggerDate)
        } catch {
            #if DEBUG
            print("Failed to schedule sticky reminder: \(error)")
            #endif
        }
    }

    /// Schedule the repeating part of a sticky reminder
    private func scheduleRepeatingStickReminder(reminder: StickyReminder, startAfter: Date) async {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.subtitle = "Press and hold for more details"
        content.body = reminder.message ?? "Tap to open the app and dismiss this reminder"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.stickyReminder.rawValue
        content.userInfo = [
            "reminderId": reminder.id.uuidString,
            "title": reminder.title,
            "repeatInterval": "\(reminder.repeatInterval.value)_\(reminder.repeatInterval.unit.rawValue)"
        ]
        applyHidePreviewIfNeeded(content, fallbackBody: "You have things to do today. Open the Unforgotten app to get started.")

        // Calculate time until first repeat after initial trigger
        let delay = startAfter.timeIntervalSinceNow + reminder.repeatInterval.intervalInSeconds

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(delay, 60), // At least 1 minute
            repeats: true
        )

        let identifier = "sticky-repeat-\(reminder.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            #if DEBUG
            print("📱 Scheduled repeating sticky reminder after initial trigger")
            #endif
        } catch {
            #if DEBUG
            print("Failed to schedule repeating sticky reminder: \(error)")
            #endif
        }
    }

    /// Cancel sticky reminder notifications
    func cancelStickyReminder(reminderId: UUID) async {
        let identifiers = [
            "sticky-\(reminderId.uuidString)",
            "sticky-repeat-\(reminderId.uuidString)"
        ]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
        #if DEBUG
        print("📱 Cancelled sticky reminder notifications for \(reminderId)")
        #endif
    }

    /// Reschedule all sticky reminders
    /// - Parameters:
    ///   - activeReminders: Active reminders to schedule
    ///   - allReminders: All reminders (including dismissed) to ensure cancelled ones stay cancelled
    func rescheduleAllStickyReminders(activeReminders: [StickyReminder], allReminders: [StickyReminder]) async {
        // First, cancel notifications for all dismissed/inactive reminders
        for reminder in allReminders {
            if !reminder.isActive || reminder.isDismissed {
                await cancelStickyReminder(reminderId: reminder.id)
            }
        }

        // Then schedule active reminders
        for reminder in activeReminders {
            await scheduleStickyReminder(reminder: reminder)
        }
    }

    /// Reschedule all sticky reminders (legacy - schedules only what's passed)
    func rescheduleAllStickyReminders(reminders: [StickyReminder]) async {
        for reminder in reminders {
            if reminder.isActive && !reminder.isDismissed {
                await scheduleStickyReminder(reminder: reminder)
            } else {
                await cancelStickyReminder(reminderId: reminder.id)
            }
        }
    }

    // MARK: - Utility

    /// Remove all pending notifications
    func removeAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// Get count of pending notifications
    func getPendingNotificationCount() async -> Int {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.count
    }

    /// Setup notification categories for actions
    func setupNotificationCategories() {
        // Medication reminder actions
        let takeMedicationAction = UNNotificationAction(
            identifier: "TAKE_MEDICATION",
            title: "Mark as Taken",
            options: []
        )
        let snoozeMedicationAction = UNNotificationAction(
            identifier: "SNOOZE_MEDICATION",
            title: "Remind in 10 min",
            options: []
        )
        let medicationCategory = UNNotificationCategory(
            identifier: "MEDICATION_REMINDER",
            actions: [takeMedicationAction, snoozeMedicationAction],
            intentIdentifiers: [],
            options: []
        )

        // Appointment reminder actions
        let viewAppointmentAction = UNNotificationAction(
            identifier: "VIEW_APPOINTMENT",
            title: "View Details",
            options: [.foreground]
        )
        let appointmentCategory = UNNotificationCategory(
            identifier: "APPOINTMENT_REMINDER",
            actions: [viewAppointmentAction],
            intentIdentifiers: [],
            options: []
        )

        // Birthday reminder category
        let birthdayCategory = UNNotificationCategory(
            identifier: "BIRTHDAY_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        // Sticky reminder actions
        let dismissStickyAction = UNNotificationAction(
            identifier: "DISMISS_STICKY_REMINDER",
            title: "Dismiss",
            options: []
        )
        let stickyCategory = UNNotificationCategory(
            identifier: "STICKY_REMINDER",
            actions: [dismissStickyAction],
            intentIdentifiers: [],
            options: []
        )

        // Morning briefing category (opens app to start Live Activity)
        let morningBriefingCategory = UNNotificationCategory(
            identifier: "MORNING_BRIEFING",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([
            medicationCategory,
            appointmentCategory,
            birthdayCategory,
            stickyCategory,
            morningBriefingCategory
        ])
    }

    // MARK: - Snooze Notification

    /// Schedule a snooze reminder for a medication (10 minutes from now)
    func scheduleMedicationSnooze(
        medicationId: UUID,
        medicationName: String,
        doseDescription: String?
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Medication Reminder"
        content.subtitle = "Press and hold for more details"
        if let doseDescription {
            content.body = "\(medicationName) - \(doseDescription)"
        } else {
            content.body = medicationName
        }
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.medicationReminder.rawValue
        content.userInfo = [
            "medicationId": medicationId.uuidString,
            "medicationName": medicationName,
            "doseDescription": doseDescription ?? "",
            "scheduledTime": Date().ISO8601Format()
        ]
        applyHidePreviewIfNeeded(content, fallbackBody: "You have things to do today. Open the Unforgotten app to get started.")

        // Trigger in 10 minutes
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)

        let identifier = "medication-snooze-\(medicationId.uuidString)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            #if DEBUG
            print("📱 Scheduled snooze reminder for \(medicationName) in 10 minutes")
            #endif
        } catch {
            #if DEBUG
            print("Failed to schedule snooze reminder: \(error)")
            #endif
        }
    }

    // MARK: - Re-schedule All Notifications

    /// Re-schedule all notifications on app launch (for appointments and birthdays)
    // MARK: - Morning Briefing Trigger

    /// Schedule a daily notification at midnight (12:00 AM) for the morning briefing
    func scheduleMorningBriefingTrigger() async {
        // Remove any existing morning briefing trigger
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["morning-briefing-trigger"])

        guard await isNotificationAllowed() else {
            #if DEBUG
            print("📱 Notifications not allowed, skipping morning briefing trigger")
            #endif
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Good Morning"
        content.body = "Your daily briefing is ready. Tap to view today's schedule."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.morningBriefing.rawValue
        content.userInfo = ["type": "morning_briefing"]
        applyHidePreviewIfNeeded(content, fallbackBody: "You have things to do today. Open the Unforgotten app to get started.")

        // Trigger at 12:00 AM (midnight) every day
        var dateComponents = DateComponents()
        dateComponents.hour = 0
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "morning-briefing-trigger",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            #if DEBUG
            print("📱 Scheduled morning briefing trigger for 12:00 AM daily")
            #endif
        } catch {
            #if DEBUG
            print("📱 Failed to schedule morning briefing trigger: \(error)")
            #endif
        }
    }

    // MARK: - Daily Summary Notification

    /// Schedule or update the daily summary notification at 2:00 AM
    func scheduleDailySummary(
        medications: [Medication],
        todayLogs: [MedicationLog],
        todayAppointments: [Appointment],
        todayBirthdays: [Profile],
        pendingToDoCount: Int
    ) async {
        // Remove any existing daily summary
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["daily-summary"])

        guard await isNotificationAllowed(), dailySummaryEnabled else {
            #if DEBUG
            print("📱 Daily summary not allowed or disabled, skipping")
            #endif
            return
        }

        let (title, subtitle, body) = buildDailySummaryContent(
            medications: medications,
            todayLogs: todayLogs,
            todayAppointments: todayAppointments,
            todayBirthdays: todayBirthdays,
            pendingToDoCount: pendingToDoCount
        )

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.morningBriefing.rawValue
        content.userInfo = ["type": "daily_summary"]
        content.interruptionLevel = .timeSensitive

        if let attachment = createLogoAttachment() {
            content.attachments = [attachment]
        }

        applyHidePreviewIfNeeded(content, fallbackBody: "You have things to do today. Open the Unforgotten app to get started.")

        // Schedule for 2:00 AM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 2
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily-summary",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            #if DEBUG
            print("📱 Scheduled daily summary notification for 2:00 AM")
            #endif
        } catch {
            #if DEBUG
            print("📱 Failed to schedule daily summary: \(error)")
            #endif
        }
    }

    /// Build concise summary text for the daily notification
    private func buildDailySummaryContent(
        medications: [Medication],
        todayLogs: [MedicationLog],
        todayAppointments: [Appointment],
        todayBirthdays: [Profile],
        pendingToDoCount: Int
    ) -> (title: String, subtitle: String, body: String) {
        // Subtitle: formatted date e.g. "Monday, February 23"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"
        let subtitleText = dateFormatter.string(from: Date())

        var summaryItems: [String] = []
        var totalItemCount = 0

        // 1. Medications (highest priority)
        let scheduledLogs = todayLogs.filter { $0.status == .scheduled }
        if !scheduledLogs.isEmpty {
            totalItemCount += scheduledLogs.count
            let medText = scheduledLogs.count == 1
                ? "1 medication to take"
                : "\(scheduledLogs.count) medications to take"
            summaryItems.append("💊 \(medText)")
        }

        // 2. Appointments
        if !todayAppointments.isEmpty {
            totalItemCount += todayAppointments.count
            if summaryItems.count < 4 {
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short
                if let firstAppt = todayAppointments.first {
                    var apptText = firstAppt.title
                    if let time = firstAppt.time {
                        apptText += " at \(timeFormatter.string(from: time))"
                    }
                    summaryItems.append("📅 \(apptText)")
                }
                if todayAppointments.count > 1 && summaryItems.count < 4 {
                    summaryItems.append("📅 +\(todayAppointments.count - 1) more appointment\(todayAppointments.count - 1 == 1 ? "" : "s")")
                }
            }
        }

        // 3. Birthdays
        if !todayBirthdays.isEmpty {
            totalItemCount += todayBirthdays.count
            if summaryItems.count < 4 {
                if let firstBirthday = todayBirthdays.first {
                    summaryItems.append("🎂 \(firstBirthday.displayName)'s birthday")
                }
            }
        }

        // 4. To-do items (lowest priority)
        if pendingToDoCount > 0 {
            totalItemCount += pendingToDoCount
            if summaryItems.count < 4 {
                let taskText = pendingToDoCount == 1
                    ? "1 task pending"
                    : "\(pendingToDoCount) tasks pending"
                summaryItems.append("✓ \(taskText)")
            }
        }

        // Build body
        var bodyText = summaryItems.joined(separator: "\n")
        let displayedCount = summaryItems.count
        if totalItemCount > displayedCount {
            let remaining = totalItemCount - displayedCount
            bodyText += "\n...and \(remaining) more"
        }

        if summaryItems.isEmpty {
            bodyText = "No activities scheduled for today. Enjoy your day!"
        }

        return (title: "Today's Overview", subtitle: subtitleText, body: bodyText)
    }

    /// Create a notification attachment from the app logo in Assets catalog
    /// Resizes to a small square so iOS renders it as a thumbnail in the top-right corner
    private func createLogoAttachment() -> UNNotificationAttachment? {
        guard let original = UIImage(named: "unforgotten-icon") else {
            #if DEBUG
            print("📱 Could not load AppLogo from assets")
            #endif
            return nil
        }

        // Resize to 100x100 so iOS treats it as a small thumbnail, not a full-width image
        let thumbnailSize = CGSize(width: 200, height: 100)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        let resized = renderer.image { _ in
            original.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }

        guard let data = resized.pngData() else { return nil }

        // Use a unique filename each time since iOS moves the file after attachment creation
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("applogo_\(UUID().uuidString).png")

        do {
            try data.write(to: fileURL)
            let attachment = try UNNotificationAttachment(
                identifier: "appLogo",
                url: fileURL,
                options: [
                    UNNotificationAttachmentOptionsThumbnailClippingRectKey:
                        CGRect(x: 0, y: 0, width: 1, height: 1).dictionaryRepresentation
                ]
            )
            return attachment
        } catch {
            #if DEBUG
            print("📱 Failed to create logo attachment: \(error)")
            #endif
            return nil
        }
    }

    /// Cancel the daily summary notification
    func cancelDailySummary() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["daily-summary"])
        #if DEBUG
        print("📱 Cancelled daily summary notification")
        #endif
    }

    /// Schedule a test daily summary notification that fires in 10 seconds
    func testDailySummary(
        medications: [Medication],
        todayLogs: [MedicationLog],
        todayAppointments: [Appointment],
        todayBirthdays: [Profile],
        pendingToDoCount: Int
    ) async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["daily-summary-test"])

        let (title, subtitle, body) = buildDailySummaryContent(
            medications: medications,
            todayLogs: todayLogs,
            todayAppointments: todayAppointments,
            todayBirthdays: todayBirthdays,
            pendingToDoCount: pendingToDoCount
        )

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.morningBriefing.rawValue
        content.userInfo = ["type": "daily_summary_test"]
        content.interruptionLevel = .timeSensitive

        if let attachment = createLogoAttachment() {
            content.attachments = [attachment]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)

        let request = UNNotificationRequest(
            identifier: "daily-summary-test",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            #if DEBUG
            print("📱 Test daily summary will fire in 10 seconds")
            #endif
        } catch {
            #if DEBUG
            print("📱 Test daily summary error: \(error)")
            #endif
        }
    }

    // MARK: - Reschedule All Notifications

    func rescheduleAllNotifications(
        appointments: [Appointment],
        profiles: [Profile],
        medications: [Medication],
        schedules: [UUID: [MedicationSchedule]]
    ) async {
        #if DEBUG
        print("📱 Re-scheduling all notifications...")
        #endif

        guard await isNotificationAllowed() else {
            #if DEBUG
            print("📱 Notifications not allowed, skipping re-schedule")
            #endif
            return
        }

        // Schedule appointment reminders
        for appointment in appointments {
            // Skip completed appointments
            guard !appointment.isCompleted else {
                // Cancel any existing notification for completed appointment
                cancelAppointmentReminder(appointmentId: appointment.id)
                continue
            }

            // Only schedule future appointments
            let appointmentDateTime = appointment.dateTime
            guard appointmentDateTime > Date() else { continue }

            await scheduleAppointmentReminder(
                appointmentId: appointment.id,
                title: appointment.title,
                appointmentDate: appointment.date,
                appointmentTime: appointment.time,
                location: appointment.location,
                reminderMinutesBefore: appointment.reminderOffsetMinutes ?? 60
            )
        }

        // Schedule birthday reminders for profiles with birthdays
        for profile in profiles {
            guard let birthday = profile.birthday else { continue }
            await scheduleBirthdayReminder(
                profileId: profile.id,
                name: profile.displayName,
                birthday: birthday
            )
        }

        // Schedule medication reminders
        for medication in medications {
            guard let medicationSchedules = schedules[medication.id] else { continue }

            for schedule in medicationSchedules {
                // Skip if schedule has ended
                if let endDate = schedule.endDate, endDate < Date() { continue }

                // Schedule for each time
                guard let times = schedule.times else { continue }

                for timeString in times {
                    // Parse time string (HH:mm format)
                    let components = timeString.split(separator: ":")
                    guard components.count >= 2,
                          let hour = Int(components[0]),
                          let minute = Int(components[1]) else { continue }

                    var dateComponents = DateComponents()
                    dateComponents.hour = hour
                    dateComponents.minute = minute

                    guard let scheduledTime = Calendar.current.date(from: dateComponents) else { continue }

                    await scheduleMedicationReminder(
                        medicationId: medication.id,
                        medicationName: medication.name,
                        scheduledTime: scheduledTime,
                        doseDescription: schedule.doseDescription
                    )
                }
            }
        }

        let count = await getPendingNotificationCount()
        #if DEBUG
        print("📱 Re-scheduled notifications complete. \(count) pending notifications.")
        #endif
    }

    // MARK: - Debug

    /// Print all pending notifications (for debugging)
    func debugPrintPendingNotifications() async {
        #if DEBUG
        let requests = await notificationCenter.pendingNotificationRequests()
        print("📱 Pending Notifications (\(requests.count)):")
        for request in requests {
            print("  - \(request.identifier): \(request.content.title)")
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                print("    Trigger: \(trigger.dateComponents)")
            } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                print("    Trigger: in \(trigger.timeInterval) seconds")
            }
        }
        #endif
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let categoryIdentifier = notification.request.content.categoryIdentifier

        // When the midnight morning briefing notification fires while the app is in the foreground,
        // regenerate medication logs for the new day
        if categoryIdentifier == NotificationCategory.morningBriefing.rawValue {
            NotificationCenter.default.post(name: .morningBriefingShouldRefresh, object: nil)
        }

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification response (user tapped notification or action button)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        let actionIdentifier = response.actionIdentifier

        #if DEBUG
        print("📱 Notification response: category=\(categoryIdentifier), action=\(actionIdentifier)")
        #endif

        // Handle navigation synchronously to ensure it works from locked screen
        handleNotificationResponseSync(
            categoryIdentifier: categoryIdentifier,
            actionIdentifier: actionIdentifier,
            userInfo: userInfo
        )

        // Call completion handler immediately
        completionHandler()
    }

    /// Process notification response synchronously (for navigation)
    private func handleNotificationResponseSync(
        categoryIdentifier: String,
        actionIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) {
        switch categoryIdentifier {
        case NotificationCategory.medicationReminder.rawValue:
            // Medication actions need async handling - fire and forget
            Task {
                await handleMedicationNotification(actionIdentifier: actionIdentifier, userInfo: userInfo)
            }

        case NotificationCategory.appointmentReminder.rawValue:
            handleAppointmentNotification(actionIdentifier: actionIdentifier, userInfo: userInfo)

        case NotificationCategory.birthdayReminder.rawValue:
            handleBirthdayNotification(userInfo: userInfo)

        case NotificationCategory.stickyReminder.rawValue:
            handleStickyReminderNotificationSync(actionIdentifier: actionIdentifier, userInfo: userInfo)

        case NotificationCategory.morningBriefing.rawValue:
            // Morning briefing tapped - open the app
            #if DEBUG
            print("📱 Morning briefing notification tapped")
            #endif

        default:
            #if DEBUG
            print("📱 Unknown notification category: \(categoryIdentifier)")
            #endif
        }
    }

    /// Handle sticky reminder notification actions (sync version for navigation)
    private func handleStickyReminderNotificationSync(actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        guard let reminderIdString = userInfo["reminderId"] as? String,
              let reminderId = UUID(uuidString: reminderIdString) else {
            #if DEBUG
            print("📱 Missing reminderId in notification")
            #endif
            return
        }

        switch actionIdentifier {
        case NotificationAction.dismissStickyReminder.rawValue:
            #if DEBUG
            print("📱 User dismissed sticky reminder: \(reminderId)")
            #endif
            // Dismiss action needs async - fire and forget
            Task {
                await delegate?.handleStickyReminderDismiss(reminderId: reminderId)
            }

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification - open the app to sticky reminders
            #if DEBUG
            print("📱 User tapped sticky reminder: \(reminderId)")
            #endif
            if let delegate = delegate {
                delegate.handleStickyReminderTapped(reminderId: reminderId)
            } else {
                // Store for later when delegate becomes available
                pendingStickyReminderId = reminderId
                #if DEBUG
                print("📱 Stored pending sticky reminder ID (delegate not ready)")
                #endif
            }

        default:
            break
        }
    }

    /// Handle medication notification actions
    private func handleMedicationNotification(actionIdentifier: String, userInfo: [AnyHashable: Any]) async {
        guard let medicationIdString = userInfo["medicationId"] as? String,
              let medicationId = UUID(uuidString: medicationIdString) else {
            #if DEBUG
            print("📱 Missing medicationId in notification")
            #endif
            return
        }

        let medicationName = userInfo["medicationName"] as? String ?? "Medication"
        let doseDescription = userInfo["doseDescription"] as? String
        let scheduledTimeString = userInfo["scheduledTime"] as? String

        // Parse scheduled time or use current time
        var scheduledTime = Date()
        if let timeString = scheduledTimeString {
            let formatter = ISO8601DateFormatter()
            scheduledTime = formatter.date(from: timeString) ?? Date()
        }

        switch actionIdentifier {
        case NotificationAction.takeMedication.rawValue:
            #if DEBUG
            print("📱 User marked medication as taken: \(medicationId)")
            #endif
            await delegate?.handleMedicationTaken(medicationId: medicationId, scheduledTime: scheduledTime)

        case NotificationAction.snoozeMedication.rawValue:
            #if DEBUG
            print("📱 User snoozed medication: \(medicationId)")
            #endif
            await delegate?.handleMedicationSnooze(
                medicationId: medicationId,
                medicationName: medicationName,
                doseDescription: doseDescription?.isEmpty == true ? nil : doseDescription
            )

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself - could open medication detail
            #if DEBUG
            print("📱 User tapped medication notification: \(medicationId)")
            #endif

        default:
            break
        }
    }

    /// Handle appointment notification actions
    private func handleAppointmentNotification(actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        guard let appointmentIdString = userInfo["appointmentId"] as? String,
              let appointmentId = UUID(uuidString: appointmentIdString) else {
            #if DEBUG
            print("📱 Missing appointmentId in notification")
            #endif
            return
        }

        switch actionIdentifier {
        case NotificationAction.viewAppointment.rawValue,
             UNNotificationDefaultActionIdentifier:
            #if DEBUG
            print("📱 User wants to view appointment: \(appointmentId)")
            #endif
            if let delegate = delegate {
                delegate.handleAppointmentView(appointmentId: appointmentId)
            } else {
                // Store for later when delegate becomes available
                pendingAppointmentId = appointmentId
                #if DEBUG
                print("📱 Stored pending appointment ID (delegate not ready)")
                #endif
            }

        default:
            break
        }
    }

    /// Handle birthday notification tap
    private func handleBirthdayNotification(userInfo: [AnyHashable: Any]) {
        guard let profileIdString = userInfo["profileId"] as? String,
              let profileId = UUID(uuidString: profileIdString) else {
            #if DEBUG
            print("📱 Missing profileId in notification")
            #endif
            return
        }

        #if DEBUG
        print("📱 User tapped birthday notification: \(profileId)")
        #endif
        if let delegate = delegate {
            delegate.handleBirthdayView(profileId: profileId)
        } else {
            // Store for later when delegate becomes available
            pendingProfileId = profileId
            #if DEBUG
            print("📱 Stored pending profile ID (delegate not ready)")
            #endif
        }
    }
}
