import ActivityKit
import Foundation
import Supabase

// MARK: - Suppression Logic

/// Tracks whether the user has dismissed the Live Activity for today.
/// If they clear it from the Lock Screen, we don't re-create it until tomorrow.
enum DailySummaryLiveActivitySuppression {
    private static let suppressedUntilKey = "dailySummaryLA_suppressedUntil"
    private static let lastStartedDayKey = "dailySummaryLA_lastStartedDay"

    /// Mark as suppressed until the start of tomorrow.
    static func suppressUntilTomorrow() {
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 60 * 60)
        UserDefaults.standard.set(tomorrow.timeIntervalSince1970, forKey: suppressedUntilKey)
        #if DEBUG
        print("🚫 Daily Summary Live Activity suppressed until \(tomorrow)")
        #endif
    }

    /// Whether the Live Activity is currently suppressed.
    static func isSuppressedNow() -> Bool {
        let ts = UserDefaults.standard.double(forKey: suppressedUntilKey)
        guard ts > 0 else { return false }
        return Date() < Date(timeIntervalSince1970: ts)
    }

    /// Clear suppression (e.g. user re-enables, or new day).
    static func clearSuppression() {
        UserDefaults.standard.removeObject(forKey: suppressedUntilKey)
    }

    /// Record that we started a Live Activity today.
    static func markStartedToday() {
        let todayString = Self.dayString(for: Date())
        UserDefaults.standard.set(todayString, forKey: lastStartedDayKey)
    }

    /// Whether we already started a Live Activity earlier today.
    /// Used to distinguish "first open of the day" from "user dismissed it".
    static func hasStartedToday() -> Bool {
        guard let stored = UserDefaults.standard.string(forKey: lastStartedDayKey) else {
            return false
        }
        return stored == Self.dayString(for: Date())
    }

    private static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Service

/// Manages the Daily Summary Live Activity lifecycle.
/// Starts the Lock Screen Live Activity with today's overview data,
/// can update it throughout the day, and ends it at the end of the day.
@MainActor
final class DailySummaryLiveActivityService {
    static let shared = DailySummaryLiveActivityService()
    private var pushTokenTask: Task<Void, Never>?
    private init() {}

    // MARK: - Start

    /// Start the daily summary Live Activity with current data.
    /// Respects suppression — won't start if user dismissed it today.
    /// Uses pushType: .token so the server can update/start it via APNs.
    func startDailySummary(appState: AppState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            #if DEBUG
            print("🔒 Live Activities are not enabled")
            #endif
            return
        }

        guard !DailySummaryLiveActivitySuppression.isSuppressedNow() else {
            #if DEBUG
            print("🚫 Daily Summary Live Activity is suppressed until tomorrow")
            #endif
            return
        }

        // End any existing daily summary activities
        await endAllDailySummaryActivities()

        let contentState = await buildContentState(appState: appState)

        let attributes = DailySummaryAttributes(date: Date())
        let content = ActivityContent(state: contentState, staleDate: nil)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: .token
            )
            DailySummaryLiveActivitySuppression.markStartedToday()
            #if DEBUG
            print("✅ Daily Summary Live Activity started: \(activity.id)")
            #endif

            // Observe push token updates and upload to Supabase
            observePushTokenUpdates(for: activity)
        } catch {
            #if DEBUG
            print("❌ Failed to start Daily Summary Live Activity: \(error)")
            #endif
        }
    }

    // MARK: - Push Token Observation

    /// Observe the Live Activity's push token and upload it to Supabase
    /// so the server can send updates via APNs.
    private func observePushTokenUpdates(for activity: Activity<DailySummaryAttributes>) {
        // Cancel any previous observation
        pushTokenTask?.cancel()

        pushTokenTask = Task.detached {
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                #if DEBUG
                await MainActor.run {
                    print("🔑 Live Activity push token: \(token)")
                }
                #endif
                await LiveActivityTokenRepository.shared.registerToken(token)
            }
        }
    }

    // MARK: - Update

    /// Update the content of any running daily summary Live Activity.
    func updateDailySummary(appState: AppState) async {
        let activities = Activity<DailySummaryAttributes>.activities
        guard !activities.isEmpty else { return }

        let contentState = await buildContentState(appState: appState)
        let content = ActivityContent(state: contentState, staleDate: nil)

        for activity in activities {
            await activity.update(content)
            // Ensure we're observing push token updates for existing activities
            // (e.g. activity was started in a previous session)
            observePushTokenUpdates(for: activity)
        }

        #if DEBUG
        print("🔄 Updated Daily Summary Live Activity")
        #endif
    }

    // MARK: - End

    /// End all daily summary Live Activities immediately.
    func endAllDailySummaryActivities() async {
        for activity in Activity<DailySummaryAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Start or Update (with dismissal detection)

    /// Smart entry point called on app launch and foreground resume.
    ///
    /// - If a Live Activity is already running, update it.
    /// - If none is running and we started one earlier today, the user must have
    ///   dismissed it — suppress until tomorrow.
    /// - If none is running and it's the first open of the day, start a new one.
    func startOrUpdateDailySummary(appState: AppState) async {
        let activities = Activity<DailySummaryAttributes>.activities

        if !activities.isEmpty {
            // Activity is still running — just update it
            await updateDailySummary(appState: appState)
        } else if DailySummaryLiveActivitySuppression.hasStartedToday() {
            // We started one today but it's gone — user dismissed it
            DailySummaryLiveActivitySuppression.suppressUntilTomorrow()
            #if DEBUG
            print("🚫 User dismissed Live Activity — suppressing until tomorrow")
            #endif
        } else {
            // First open of the day (or never started) — create a new one
            await startDailySummary(appState: appState)
        }
    }

    // MARK: - Build Content State

    private func buildContentState(appState: AppState) async -> DailySummaryAttributes.ContentState {
        guard let accountId = appState.currentAccount?.id else {
            return DailySummaryAttributes.ContentState(
                medicationCount: 0,
                appointments: [],
                birthdays: [],
                countdowns: [],
                taskCount: 0,
                lastUpdated: Date()
            )
        }

        var medicationCount = 0
        var appointmentItems: [DailySummaryAttributes.AppointmentItem] = []
        var birthdayNames: [String] = []
        var countdownItems: [DailySummaryAttributes.CountdownItem] = []
        var taskCount = 0

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        do {
            // Medications due today
            let allLogs = try await appState.medicationRepository.getTodaysLogs(accountId: accountId)
            let scheduledLogs = allLogs.filter { $0.status == .scheduled }
            medicationCount = scheduledLogs.count

            // Today's appointments
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                return DailySummaryAttributes.ContentState(
                    medicationCount: 0, appointments: [], birthdays: [], countdowns: [], taskCount: 0, lastUpdated: Date()
                )
            }

            let todayAppointments = try await appState.appointmentRepository.getAppointments(accountId: accountId)
                .filter { $0.date >= startOfDay && $0.date < endOfDay }

            for appointment in todayAppointments {
                let time: String
                if let appointmentTime = appointment.time {
                    time = timeFormatter.string(from: appointmentTime)
                } else {
                    time = "All day"
                }
                appointmentItems.append(DailySummaryAttributes.AppointmentItem(
                    title: appointment.title,
                    time: time
                ))
            }

            // Today's birthdays
            let allProfiles = try await appState.profileRepository.getProfiles(accountId: accountId)
            let todayBirthdays = allProfiles.filter { profile in
                guard let birthday = profile.birthday else { return false }
                return birthday.daysUntilNextOccurrence() == 0
            }
            birthdayNames = todayBirthdays.map { $0.displayName }

            // Today's countdowns
            let allCountdowns = try await appState.countdownRepository.getUpcomingCountdowns(accountId: accountId, days: 365)
            let todayCountdowns = allCountdowns.filter { $0.daysUntilNextOccurrence == 0 }
            countdownItems = todayCountdowns.map {
                DailySummaryAttributes.CountdownItem(title: $0.title, typeName: $0.displayTypeName)
            }

            // Pending to-do items (only from lists due today)
            let todoCalendar = Calendar.current
            let todoTodayStart = todoCalendar.startOfDay(for: Date())
            guard let todoTodayEnd = todoCalendar.date(byAdding: .day, value: 1, to: todoTodayStart) else {
                return DailySummaryAttributes.ContentState(
                    medicationCount: medicationCount, appointments: appointmentItems, birthdays: birthdayNames, countdowns: countdownItems, taskCount: taskCount, lastUpdated: Date()
                )
            }
            let allLists = try await appState.toDoRepository.getLists(accountId: accountId)
            for list in allLists {
                guard let dueDate = list.dueDate,
                      dueDate >= todoTodayStart && dueDate < todoTodayEnd else { continue }
                let items = try await appState.toDoRepository.getItems(listId: list.id)
                taskCount += items.filter { !$0.isCompleted }.count
            }
        } catch {
            #if DEBUG
            print("❌ Failed to build Live Activity content: \(error)")
            #endif
        }

        return DailySummaryAttributes.ContentState(
            medicationCount: medicationCount,
            appointments: appointmentItems,
            birthdays: birthdayNames,
            countdowns: countdownItems,
            taskCount: taskCount,
            lastUpdated: Date()
        )
    }

    // MARK: - Upload Briefing Cache

    /// Upload tomorrow's content state to Supabase so the server-side
    /// cron job can send it as a Live Activity push notification in the morning.
    /// Builds data directly from repositories to avoid stale widget cache.
    func uploadBriefingCache(appState: AppState) async {
        guard let userId = await SupabaseManager.shared.currentUserId else { return }
        guard let accountId = appState.currentAccount?.id else { return }

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: tomorrow)!
        let tomorrowWeekday = calendar.component(.weekday, from: tomorrow) - 1

        var medicationCount = 0
        var appointmentItems: [DailySummaryAttributes.AppointmentItem] = []
        var birthdayNames: [String] = []
        var countdownItems: [DailySummaryAttributes.CountdownItem] = []
        var taskCount = 0

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        do {
            // Medications: predict from schedules for tomorrow's day of week
            let medications = try await appState.medicationRepository.getMedications(accountId: accountId)
            let activeMedications = medications.filter { !$0.isPaused }

            for medication in activeMedications {
                let schedules = try await appState.medicationRepository.getSchedules(medicationId: medication.id)
                for schedule in schedules {
                    guard schedule.scheduleType == .scheduled else { continue }
                    if schedule.startDate > tomorrowEnd { continue }
                    if let endDate = schedule.endDate, endDate < tomorrow { continue }

                    guard let entries = schedule.scheduleEntries else { continue }
                    for entry in entries where entry.daysOfWeek.contains(tomorrowWeekday) {
                        medicationCount += 1
                    }
                }
            }

            // Tomorrow's appointments
            let allAppointments = try await appState.appointmentRepository.getAppointments(accountId: accountId)
            let tomorrowAppointments = allAppointments.filter { $0.date >= tomorrow && $0.date < tomorrowEnd }

            for appointment in tomorrowAppointments {
                let time: String
                if let appointmentTime = appointment.time {
                    time = timeFormatter.string(from: appointmentTime)
                } else {
                    time = "All day"
                }
                appointmentItems.append(DailySummaryAttributes.AppointmentItem(
                    title: appointment.title,
                    time: time
                ))
            }

            // Tomorrow's birthdays
            let allProfiles = try await appState.profileRepository.getProfiles(accountId: accountId)
            let tomorrowBirthdays = allProfiles.filter { profile in
                guard let birthday = profile.birthday else { return false }
                return birthday.daysUntilNextOccurrence() == 1
            }
            birthdayNames = tomorrowBirthdays.map { $0.displayName }

            // Tomorrow's countdowns
            let allCountdowns = try await appState.countdownRepository.getUpcomingCountdowns(accountId: accountId, days: 365)
            let tomorrowCountdowns = allCountdowns.filter { $0.daysUntilNextOccurrence == 1 }
            countdownItems = tomorrowCountdowns.map {
                DailySummaryAttributes.CountdownItem(title: $0.title, typeName: $0.displayTypeName)
            }

            // To-do lists due tomorrow
            let allLists = try await appState.toDoRepository.getLists(accountId: accountId)
            for list in allLists {
                guard let dueDate = list.dueDate,
                      dueDate >= tomorrow && dueDate < tomorrowEnd else { continue }
                let items = try await appState.toDoRepository.getItems(listId: list.id)
                taskCount += items.filter { !$0.isCompleted }.count
            }
        } catch {
            #if DEBUG
            print("❌ Failed to build briefing cache content: \(error)")
            #endif
        }

        let contentState = DailySummaryAttributes.ContentState(
            medicationCount: medicationCount,
            appointments: appointmentItems,
            birthdays: birthdayNames,
            countdowns: countdownItems,
            taskCount: taskCount,
            lastUpdated: Date()
        )

        // Calculate tomorrow's date string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let targetDate = dateFormatter.string(from: tomorrow)

        do {
            try await SupabaseManager.shared.client
                .from(TableName.morningBriefingCache)
                .upsert(
                    BriefingCacheInsert(
                        userId: userId,
                        contentState: contentState,
                        targetDate: targetDate
                    ),
                    onConflict: "user_id"
                )
                .execute()

            #if DEBUG
            print("📋 Uploaded briefing cache for \(targetDate) — meds: \(medicationCount), appts: \(appointmentItems.count), bdays: \(birthdayNames.count), countdowns: \(countdownItems.count), tasks: \(taskCount)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to upload briefing cache: \(error)")
            #endif
        }
    }
}

// MARK: - Briefing Cache Insert Model

private struct BriefingCacheInsert: Encodable {
    let userId: UUID
    let contentState: DailySummaryAttributes.ContentState
    let targetDate: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case contentState = "content_state"
        case targetDate = "target_date"
    }
}
