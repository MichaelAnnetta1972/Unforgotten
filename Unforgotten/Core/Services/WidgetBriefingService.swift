import Foundation
import WidgetKit

/// Writes morning briefing data to the shared App Group container
/// so the widget extension can display live data.
@MainActor
class WidgetBriefingService {
    static let shared = WidgetBriefingService()
    private init() {}

    /// Build today's briefing data from AppState repositories and save to shared store
    func updateWidgetData(appState: AppState) async {
        guard let accountId = appState.currentAccount?.id else { return }

        do {
            var items: [WidgetBriefingItemData] = []
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short

            // Load medications
            let medications = try await appState.medicationRepository.getMedications(accountId: accountId)
            let allLogs = try await appState.medicationRepository.getTodaysLogs(accountId: accountId)
            let todayLogs = allLogs.filter { $0.status == .scheduled || $0.status == .taken || $0.status == .skipped }

            for log in todayLogs {
                let medName = medications.first(where: { $0.id == log.medicationId })?.name ?? "Medication"
                let timeString = timeFormatter.string(from: log.scheduledAt)
                items.append(WidgetBriefingItemData(
                    id: "med-\(log.id.uuidString)",
                    icon: "pill.fill",
                    title: medName,
                    subtitle: timeString,
                    colorHex: "F36A6A"
                ))
            }

            // Load appointments
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let todayAppointments = try await appState.appointmentRepository.getAppointments(accountId: accountId)
                .filter { $0.date >= startOfDay && $0.date < endOfDay }

            for appointment in todayAppointments {
                let subtitle: String
                if let time = appointment.time {
                    subtitle = timeFormatter.string(from: time)
                } else {
                    subtitle = "All day"
                }
                items.append(WidgetBriefingItemData(
                    id: "apt-\(appointment.id.uuidString)",
                    icon: "calendar",
                    title: appointment.title,
                    subtitle: subtitle,
                    colorHex: "4A90D9"
                ))
            }

            // Load birthdays
            let allProfiles = try await appState.profileRepository.getProfiles(accountId: accountId)
            let todayBirthdays = allProfiles.filter { profile in
                guard let birthday = profile.birthday else { return false }
                return birthday.daysUntilNextOccurrence() == 0
            }

            for profile in todayBirthdays {
                let ageText: String
                if let age = profile.age {
                    ageText = "Turning \(age + 1)"
                } else {
                    ageText = ""
                }
                items.append(WidgetBriefingItemData(
                    id: "bday-\(profile.id.uuidString)",
                    icon: "gift.fill",
                    title: "\(profile.displayName)'s Birthday",
                    subtitle: ageText.isEmpty ? nil : ageText,
                    colorHex: "F25BA5"
                ))
            }

            // Load countdowns
            let allCountdowns = try await appState.countdownRepository.getUpcomingCountdowns(accountId: accountId, days: 365)
            let todayCountdowns = allCountdowns.filter { $0.daysUntilNextOccurrence == 0 }

            for countdown in todayCountdowns {
                items.append(WidgetBriefingItemData(
                    id: "countdown-\(countdown.id.uuidString)",
                    icon: "clock.fill",
                    title: countdown.title,
                    subtitle: nil,
                    colorHex: "9B59B6"
                ))
            }

            let totalCount = items.count
            let briefingData = WidgetBriefingData(
                date: Date(),
                items: Array(items.prefix(8)),
                totalCount: totalCount
            )

            WidgetDataStore.saveBriefingData(briefingData)
            WidgetCenter.shared.reloadAllTimelines()

            #if DEBUG
            print("📊 WidgetBriefingService: Updated widget data with \(totalCount) items")
            #endif
        } catch {
            #if DEBUG
            print("📊 WidgetBriefingService: Failed to update widget data: \(error)")
            #endif
        }
    }
}
