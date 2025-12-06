import Foundation
import UserNotifications

// MARK: - Notification Action Identifiers
enum NotificationAction: String {
    case takeMedication = "TAKE_MEDICATION"
    case snoozeMedication = "SNOOZE_MEDICATION"
    case viewAppointment = "VIEW_APPOINTMENT"
}

// MARK: - Notification Category Identifiers
enum NotificationCategory: String {
    case medicationReminder = "MEDICATION_REMINDER"
    case appointmentReminder = "APPOINTMENT_REMINDER"
    case birthdayReminder = "BIRTHDAY_REMINDER"
}

// MARK: - Notification Handler Protocol
protocol NotificationHandlerDelegate: AnyObject {
    func handleMedicationTaken(medicationId: UUID, scheduledTime: Date) async
    func handleMedicationSnooze(medicationId: UUID, medicationName: String, doseDescription: String?) async
    func handleAppointmentView(appointmentId: UUID)
    func handleBirthdayView(profileId: UUID)
}

// MARK: - Notification Service
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    weak var delegate: NotificationHandlerDelegate?

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    // MARK: - Permission

    /// Request notification permission from the user
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification permission error: \(error)")
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
        // Check permission first
        let status = await checkPermissionStatus()
        guard status == .authorized else {
            print("📱 Notifications not authorized, skipping medication reminder")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Time to take your medication"
        content.body = doseDescription != nil
            ? "\(medicationName) - \(doseDescription!)"
            : medicationName
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
            print("📱 Scheduled medication reminder for \(medicationName) at \(components.hour ?? 0):\(components.minute ?? 0)")
        } catch {
            print("Failed to schedule medication reminder: \(error)")
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
        // Check permission first
        let status = await checkPermissionStatus()
        guard status == .authorized else {
            print("📱 Notifications not authorized, skipping appointment reminder")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Appointment"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.appointmentReminder.rawValue
        content.userInfo = ["appointmentId": appointmentId.uuidString]

        // Build body text
        var bodyParts: [String] = [title]
        if let location = location {
            bodyParts.append("at \(location)")
        }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        if let time = appointmentTime {
            bodyParts.append("at \(timeFormatter.string(from: time))")
        }

        content.body = bodyParts.joined(separator: " ")

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
            print("📱 Scheduled appointment reminder for '\(title)' at \(reminderDate)")
        } catch {
            print("Failed to schedule appointment reminder: \(error)")
        }
    }

    /// Cancel reminder for an appointment
    func cancelAppointmentReminder(appointmentId: UUID) {
        let identifier = "appointment-\(appointmentId.uuidString)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Birthday Reminders

    /// Schedule a birthday reminder for the day before
    func scheduleBirthdayReminder(
        profileId: UUID,
        name: String,
        birthday: Date
    ) async {
        // Check permission first
        let status = await checkPermissionStatus()
        guard status == .authorized else {
            print("📱 Notifications not authorized, skipping birthday reminder")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Birthday Tomorrow!"
        content.body = "\(name)'s birthday is tomorrow. Don't forget!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.birthdayReminder.rawValue
        content.userInfo = ["profileId": profileId.uuidString]

        // Schedule for 9am the day before the birthday
        let calendar = Calendar.current
        var components = calendar.dateComponents([.month, .day], from: birthday)
        components.hour = 9
        components.minute = 0

        // Adjust to day before
        if let day = components.day {
            components.day = day - 1
            if components.day == 0 {
                // Handle month boundary
                if let month = components.month {
                    components.month = month - 1
                    if components.month == 0 {
                        components.month = 12
                    }
                    // Set to last day of previous month
                    components.day = calendar.range(of: .day, in: .month, for: birthday)?.count ?? 28
                }
            }
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let identifier = "birthday-\(profileId.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            print("📱 Scheduled birthday reminder for \(name) (day before birthday)")
        } catch {
            print("Failed to schedule birthday reminder: \(error)")
        }
    }

    /// Cancel birthday reminder
    func cancelBirthdayReminder(profileId: UUID) {
        let identifier = "birthday-\(profileId.uuidString)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
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

        notificationCenter.setNotificationCategories([
            medicationCategory,
            appointmentCategory,
            birthdayCategory
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
        content.body = doseDescription != nil
            ? "\(medicationName) - \(doseDescription!)"
            : medicationName
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.medicationReminder.rawValue
        content.userInfo = [
            "medicationId": medicationId.uuidString,
            "medicationName": medicationName,
            "doseDescription": doseDescription ?? "",
            "scheduledTime": Date().ISO8601Format()
        ]

        // Trigger in 10 minutes
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)

        let identifier = "medication-snooze-\(medicationId.uuidString)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            print("📱 Scheduled snooze reminder for \(medicationName) in 10 minutes")
        } catch {
            print("Failed to schedule snooze reminder: \(error)")
        }
    }

    // MARK: - Re-schedule All Notifications

    /// Re-schedule all notifications on app launch (for appointments and birthdays)
    func rescheduleAllNotifications(
        appointments: [Appointment],
        profiles: [Profile],
        medications: [Medication],
        schedules: [UUID: [MedicationSchedule]]
    ) async {
        print("📱 Re-scheduling all notifications...")

        // Check permission first
        let status = await checkPermissionStatus()
        guard status == .authorized else {
            print("📱 Notifications not authorized, skipping re-schedule")
            return
        }

        // Schedule appointment reminders
        for appointment in appointments {
            // Only schedule future appointments
            let appointmentDateTime = appointment.dateTime ?? appointment.date
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
        print("📱 Re-scheduled notifications complete. \(count) pending notifications.")
    }

    // MARK: - Debug

    /// Print all pending notifications (for debugging)
    func debugPrintPendingNotifications() async {
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

        print("📱 Notification response: category=\(categoryIdentifier), action=\(actionIdentifier)")

        Task {
            await handleNotificationResponse(
                categoryIdentifier: categoryIdentifier,
                actionIdentifier: actionIdentifier,
                userInfo: userInfo
            )
            completionHandler()
        }
    }

    /// Process notification response
    private func handleNotificationResponse(
        categoryIdentifier: String,
        actionIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) async {
        switch categoryIdentifier {
        case NotificationCategory.medicationReminder.rawValue:
            await handleMedicationNotification(actionIdentifier: actionIdentifier, userInfo: userInfo)

        case NotificationCategory.appointmentReminder.rawValue:
            handleAppointmentNotification(actionIdentifier: actionIdentifier, userInfo: userInfo)

        case NotificationCategory.birthdayReminder.rawValue:
            handleBirthdayNotification(userInfo: userInfo)

        default:
            print("📱 Unknown notification category: \(categoryIdentifier)")
        }
    }

    /// Handle medication notification actions
    private func handleMedicationNotification(actionIdentifier: String, userInfo: [AnyHashable: Any]) async {
        guard let medicationIdString = userInfo["medicationId"] as? String,
              let medicationId = UUID(uuidString: medicationIdString) else {
            print("📱 Missing medicationId in notification")
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
            print("📱 User marked medication as taken: \(medicationId)")
            await delegate?.handleMedicationTaken(medicationId: medicationId, scheduledTime: scheduledTime)

        case NotificationAction.snoozeMedication.rawValue:
            print("📱 User snoozed medication: \(medicationId)")
            await delegate?.handleMedicationSnooze(
                medicationId: medicationId,
                medicationName: medicationName,
                doseDescription: doseDescription?.isEmpty == true ? nil : doseDescription
            )

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself - could open medication detail
            print("📱 User tapped medication notification: \(medicationId)")

        default:
            break
        }
    }

    /// Handle appointment notification actions
    private func handleAppointmentNotification(actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        guard let appointmentIdString = userInfo["appointmentId"] as? String,
              let appointmentId = UUID(uuidString: appointmentIdString) else {
            print("📱 Missing appointmentId in notification")
            return
        }

        switch actionIdentifier {
        case NotificationAction.viewAppointment.rawValue,
             UNNotificationDefaultActionIdentifier:
            print("📱 User wants to view appointment: \(appointmentId)")
            delegate?.handleAppointmentView(appointmentId: appointmentId)

        default:
            break
        }
    }

    /// Handle birthday notification tap
    private func handleBirthdayNotification(userInfo: [AnyHashable: Any]) {
        guard let profileIdString = userInfo["profileId"] as? String,
              let profileId = UUID(uuidString: profileIdString) else {
            print("📱 Missing profileId in notification")
            return
        }

        print("📱 User tapped birthday notification: \(profileId)")
        delegate?.handleBirthdayView(profileId: profileId)
    }
}
