import ActivityKit
import Foundation

// MARK: - Dismissal Tracking

/// Tracks which set of due doses the user has dismissed from the Lock Screen.
/// A "signature" is the sorted list of due medication-log IDs, so the card
/// reappears automatically as soon as a new dose becomes due (the set changes),
/// but stays away if the user swiped away the current set.
enum MedicationDoseLiveActivityState {
    private static let lastStartedSignatureKey = "medicationDoseLA_lastStartedSignature"
    private static let dismissedSignatureKey = "medicationDoseLA_dismissedSignature"

    static var lastStartedSignature: String? {
        UserDefaults.standard.string(forKey: lastStartedSignatureKey)
    }

    static var dismissedSignature: String? {
        UserDefaults.standard.string(forKey: dismissedSignatureKey)
    }

    static func markStarted(signature: String) {
        UserDefaults.standard.set(signature, forKey: lastStartedSignatureKey)
    }

    static func markDismissed(signature: String) {
        UserDefaults.standard.set(signature, forKey: dismissedSignatureKey)
        #if DEBUG
        print("🚫 Medication Dose Live Activity dismissed for current dose set")
        #endif
    }

    static func clearDismissed() {
        UserDefaults.standard.removeObject(forKey: dismissedSignatureKey)
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: lastStartedSignatureKey)
        UserDefaults.standard.removeObject(forKey: dismissedSignatureKey)
    }
}

// MARK: - Service

/// Manages the Medication Dose Live Activity lifecycle.
/// While one or more doses are due and untaken, a persistent card sits on the
/// Lock Screen until the doses are marked taken/skipped or the user swipes it away.
@MainActor
final class MedicationDoseLiveActivityService {
    static let shared = MedicationDoseLiveActivityService()
    private init() {}

    /// A dose counts as overdue once it is more than an hour past its scheduled time.
    private static let overdueThreshold: TimeInterval = 60 * 60

    // MARK: - Start or Update

    /// Smart entry point called on app launch, foreground resume, and whenever
    /// a medication log changes.
    ///
    /// - No due doses → end any running activity.
    /// - Activity already running → update it with the latest due doses.
    /// - No activity but we started one for this exact dose set → the user
    ///   dismissed it; stay quiet until the due set changes.
    /// - Otherwise → start a new activity.
    func startOrUpdateDoseActivity(appState: AppState) async {
        // Respect the in-app master notifications toggle.
        guard NotificationService.shared.allowNotifications else {
            await endAllDoseActivities()
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            #if DEBUG
            print("🔒 Live Activities are not enabled")
            #endif
            return
        }

        guard let (contentState, signature) = await buildContentState(appState: appState),
              !contentState.doses.isEmpty else {
            // Nothing due — remove the card and reset tracking for the next dose.
            await endAllDoseActivities()
            MedicationDoseLiveActivityState.clearAll()
            return
        }
        let content = ActivityContent(state: contentState, staleDate: nil)
        let activities = Activity<MedicationDoseAttributes>.activities

        if !activities.isEmpty {
            for activity in activities {
                await activity.update(content)
            }
            MedicationDoseLiveActivityState.markStarted(signature: signature)
            #if DEBUG
            print("🔄 Updated Medication Dose Live Activity (\(contentState.doses.count) due)")
            #endif
        } else if MedicationDoseLiveActivityState.dismissedSignature == signature {
            // User already dismissed this exact set of due doses — respect it.
            #if DEBUG
            print("🚫 Medication Dose Live Activity suppressed (user dismissed this dose set)")
            #endif
        } else if MedicationDoseLiveActivityState.lastStartedSignature == signature {
            // We showed this exact set before and it's gone — user dismissed it.
            MedicationDoseLiveActivityState.markDismissed(signature: signature)
        } else {
            let attributes = MedicationDoseAttributes(date: ISO8601DateFormatter().string(from: Date()))
            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                MedicationDoseLiveActivityState.markStarted(signature: signature)
                MedicationDoseLiveActivityState.clearDismissed()
                #if DEBUG
                print("✅ Medication Dose Live Activity started: \(activity.id)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to start Medication Dose Live Activity: \(error)")
                #endif
            }
        }
    }

    // MARK: - End

    /// End all medication dose Live Activities immediately.
    func endAllDoseActivities() async {
        for activity in Activity<MedicationDoseAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Build Content State

    /// Fetch today's logs and return the due-and-untaken doses, along with a
    /// stable signature for that dose set (used for dismissal tracking).
    /// Returns nil when there is no account or the fetch fails.
    private func buildContentState(
        appState: AppState
    ) async -> (state: MedicationDoseAttributes.ContentState, signature: String)? {
        guard let accountId = appState.currentAccount?.id else { return nil }

        do {
            let logs = try await appState.medicationRepository.getTodaysLogs(accountId: accountId)
            let medications = try await appState.medicationRepository.getMedications(accountId: accountId)
            let medicationsById = Dictionary(uniqueKeysWithValues: medications.map { ($0.id, $0) })

            let now = Date()
            let dueLogs = logs
                .filter { $0.status == .scheduled && $0.scheduledAt <= now }
                .sorted { $0.scheduledAt < $1.scheduledAt }

            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short

            let doses = dueLogs.compactMap { log -> MedicationDoseAttributes.DoseItem? in
                guard let medication = medicationsById[log.medicationId] else { return nil }
                return MedicationDoseAttributes.DoseItem(
                    medicationName: medication.name,
                    doseDescription: medication.strength,
                    time: timeFormatter.string(from: log.scheduledAt),
                    isOverdue: now.timeIntervalSince(log.scheduledAt) > Self.overdueThreshold
                )
            }

            let state = MedicationDoseAttributes.ContentState(
                doses: doses,
                takenTodayCount: logs.filter { $0.status == .taken }.count,
                totalTodayCount: logs.count,
                lastUpdated: now
            )

            let signature = dueLogs
                .map { $0.id.uuidString }
                .sorted()
                .joined(separator: ",")

            return (state, signature)
        } catch {
            #if DEBUG
            print("❌ Failed to build Medication Dose Live Activity content: \(error)")
            #endif
            return nil
        }
    }
}
