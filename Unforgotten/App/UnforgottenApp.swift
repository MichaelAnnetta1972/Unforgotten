import SwiftUI
import UIKit

// MARK: - App Delegate for Orientation Lock
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait  // Lock to portrait only
    }
}

@main
struct UnforgottenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)  // Hide status bar globally
        }
    }
}

// MARK: - App State
@MainActor
final class AppState: ObservableObject {
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var currentAccount: Account?
    @Published var currentUserRole: MemberRole?
    @Published var showMoodPrompt = false
    @Published var hasCompletedOnboarding = false

    // MARK: - Navigation State (for deep linking from notifications)
    @Published var pendingAppointmentId: UUID?
    @Published var pendingProfileId: UUID?

    // MARK: - Repositories
    let authRepository = AuthRepository()
    let accountRepository = AccountRepository()
    let invitationRepository = InvitationRepository()
    let profileRepository = ProfileRepository()
    let medicationRepository = MedicationRepository()
    let appointmentRepository = AppointmentRepository()
    let usefulContactRepository = UsefulContactRepository()
    let moodRepository = MoodRepository()

    // MARK: - Initialization
    init() {
        // Setup notification categories and delegate
        NotificationService.shared.setupNotificationCategories()
        NotificationService.shared.delegate = self

        Task {
            await checkAuthState()
            // Request notification permissions
            _ = await NotificationService.shared.requestPermission()
            // Re-schedule notifications on app launch
            await rescheduleNotifications()
        }
    }
    
    // MARK: - Auth State
    func checkAuthState() async {
        isLoading = true

        if await authRepository.getCurrentUser() != nil {
            isAuthenticated = true
            await loadAccountData()
            await checkMoodPrompt()
        } else {
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    // MARK: - Load Account Data
    func loadAccountData() async {
        do {
            currentAccount = try await accountRepository.getCurrentUserAccount()
            
            if let account = currentAccount {
                currentUserRole = try await accountRepository.getCurrentUserRole(accountId: account.id)
                hasCompletedOnboarding = true
            } else {
                hasCompletedOnboarding = false
            }
        } catch {
            print("Error loading account: \(error)")
            currentAccount = nil
            hasCompletedOnboarding = false
        }
    }
    
    // MARK: - Check Mood Prompt
    func checkMoodPrompt() async {
        guard let account = currentAccount,
              let userId = await SupabaseManager.shared.currentUserId else {
            return
        }
        
        do {
            let todaysMood = try await moodRepository.getTodaysEntry(
                accountId: account.id,
                userId: userId
            )
            showMoodPrompt = (todaysMood == nil)
        } catch {
            print("Error checking mood: \(error)")
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        do {
            try await authRepository.signOut()
            isAuthenticated = false
            currentAccount = nil
            currentUserRole = nil
            hasCompletedOnboarding = false
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    // MARK: - Complete Onboarding
    func completeOnboarding(accountName: String, primaryProfileName: String, birthday: Date?) async throws {
        print("🔵 Starting onboarding...")
        print("🔵 Account name: \(accountName)")
        print("🔵 Profile name: \(primaryProfileName)")

        // Create account
        print("🔵 Creating account...")
        let account = try await accountRepository.createAccount(
            displayName: accountName,
            timezone: TimeZone.current.identifier
        )
        print("✅ Account created: \(account.id)")

        // Create primary profile
        print("🔵 Creating primary profile...")
        let profileInsert = ProfileInsert(
            accountId: account.id,
            type: .primary,
            fullName: primaryProfileName,
            birthday: birthday
        )
        let profile = try await profileRepository.createProfile(profileInsert)
        print("✅ Profile created: \(profile.id)")

        // Update state
        currentAccount = account
        currentUserRole = .owner
        hasCompletedOnboarding = true
        print("✅ Onboarding state updated")

        // Check mood prompt
        await checkMoodPrompt()
        print("✅ Onboarding complete!")
    }
    
    // MARK: - Record Mood
    func recordMood(rating: Int, note: String? = nil) async {
        print("📝 recordMood called with rating: \(rating)")

        guard let account = currentAccount else {
            print("❌ recordMood failed: no currentAccount")
            return
        }

        guard let userId = await SupabaseManager.shared.currentUserId else {
            print("❌ recordMood failed: no currentUserId")
            return
        }

        print("📝 Recording mood for account: \(account.id), user: \(userId)")

        do {
            // Check if there's already a mood entry for today
            if let existingEntry = try await moodRepository.getTodaysEntry(accountId: account.id, userId: userId) {
                // Update existing entry
                print("📝 Updating existing mood entry: \(existingEntry.id)")
                _ = try await moodRepository.updateEntry(id: existingEntry.id, rating: rating, note: note)
                print("✅ Mood entry updated")
            } else {
                // Create new entry
                let entry = MoodEntryInsert(
                    accountId: account.id,
                    userId: userId,
                    rating: rating,
                    note: note
                )
                let created = try await moodRepository.createEntry(entry)
                print("✅ Mood entry created: \(created.id)")
            }
            showMoodPrompt = false
        } catch {
            print("❌ Error recording mood: \(error)")
        }
    }
    
    // MARK: - Generate Today's Medication Logs
    func generateTodaysMedicationLogs() async {
        guard let account = currentAccount else { return }

        do {
            try await medicationRepository.generateDailyLogs(
                accountId: account.id,
                date: Date()
            )
        } catch {
            print("Error generating medication logs: \(error)")
        }
    }

    // MARK: - Re-schedule Notifications
    func rescheduleNotifications() async {
        guard let account = currentAccount else {
            print("📱 No account, skipping notification re-schedule")
            return
        }

        print("📱 Re-scheduling notifications for account: \(account.id)")

        do {
            // Fetch upcoming appointments (next 30 days)
            let appointments = try await appointmentRepository.getUpcomingAppointments(
                accountId: account.id,
                days: 30
            )

            // Fetch all profiles (for birthday reminders)
            let profiles = try await profileRepository.getProfiles(accountId: account.id)

            // Fetch medications and their schedules
            let medications = try await medicationRepository.getMedications(accountId: account.id)
            var schedules: [UUID: [MedicationSchedule]] = [:]
            for medication in medications {
                let medicationSchedules = try await medicationRepository.getSchedules(medicationId: medication.id)
                schedules[medication.id] = medicationSchedules
            }

            // Re-schedule all notifications
            await NotificationService.shared.rescheduleAllNotifications(
                appointments: appointments,
                profiles: profiles,
                medications: medications,
                schedules: schedules
            )
        } catch {
            print("Error re-scheduling notifications: \(error)")
        }
    }

    // MARK: - Schedule Birthday Reminder
    func scheduleBirthdayReminder(for profile: Profile) async {
        guard let birthday = profile.birthday else { return }
        await NotificationService.shared.scheduleBirthdayReminder(
            profileId: profile.id,
            name: profile.displayName,
            birthday: birthday
        )
    }

    // MARK: - Cancel Birthday Reminder
    func cancelBirthdayReminder(for profileId: UUID) {
        NotificationService.shared.cancelBirthdayReminder(profileId: profileId)
    }
}

// MARK: - NotificationHandlerDelegate
extension AppState: NotificationHandlerDelegate {

    /// Handle "Mark as Taken" action from medication notification
    func handleMedicationTaken(medicationId: UUID, scheduledTime: Date) async {
        guard let account = currentAccount else {
            print("📱 No account for medication taken action")
            return
        }

        do {
            // Find the medication log for this medication and scheduled time
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: scheduledTime)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let logs = try await medicationRepository.getLogs(
                medicationId: medicationId,
                from: startOfDay,
                to: endOfDay
            )

            // Find the log closest to the scheduled time
            if let log = logs.first(where: { log in
                let logHour = calendar.component(.hour, from: log.scheduledAt)
                let logMinute = calendar.component(.minute, from: log.scheduledAt)
                let scheduledHour = calendar.component(.hour, from: scheduledTime)
                let scheduledMinute = calendar.component(.minute, from: scheduledTime)
                return logHour == scheduledHour && logMinute == scheduledMinute
            }) {
                // Update the log status to taken
                _ = try await medicationRepository.updateLogStatus(
                    logId: log.id,
                    status: .taken,
                    takenAt: Date()
                )
                print("📱 Marked medication as taken: \(medicationId)")
            } else {
                print("📱 Could not find medication log to mark as taken")
            }
        } catch {
            print("📱 Error marking medication as taken: \(error)")
        }
    }

    /// Handle "Snooze" action from medication notification
    func handleMedicationSnooze(medicationId: UUID, medicationName: String, doseDescription: String?) async {
        // Schedule a new notification in 10 minutes
        await NotificationService.shared.scheduleMedicationSnooze(
            medicationId: medicationId,
            medicationName: medicationName,
            doseDescription: doseDescription
        )
    }

    /// Handle "View" action from appointment notification
    nonisolated func handleAppointmentView(appointmentId: UUID) {
        Task { @MainActor in
            pendingAppointmentId = appointmentId
        }
    }

    /// Handle tap on birthday notification
    nonisolated func handleBirthdayView(profileId: UUID) {
        Task { @MainActor in
            pendingProfileId = profileId
        }
    }
}
