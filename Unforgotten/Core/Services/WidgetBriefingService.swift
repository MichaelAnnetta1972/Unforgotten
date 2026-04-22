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
                    ageText = "Turned \(age)"
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

    /// Pre-cache tomorrow's briefing data so the background task (at ~2 AM) has
    /// valid data to display on the Live Activity without needing the app to be open.
    func cacheTomorrowsData(appState: AppState) async {
        guard let accountId = appState.currentAccount?.id else { return }

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: tomorrow)!
        let tomorrowWeekday = calendar.component(.weekday, from: tomorrow) - 1 // 0=Sunday to match ScheduleEntry

        do {
            var items: [WidgetBriefingItemData] = []
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short

            // Medications: check schedules to predict tomorrow's entries
            let medications = try await appState.medicationRepository.getMedications(accountId: accountId)
            let activeMedications = medications.filter { !$0.isPaused }

            for medication in activeMedications {
                let schedules = try await appState.medicationRepository.getSchedules(medicationId: medication.id)
                for schedule in schedules {
                    guard schedule.scheduleType == .scheduled else { continue }
                    // Skip if schedule hasn't started yet or has ended
                    if schedule.startDate > tomorrowEnd { continue }
                    if let endDate = schedule.endDate, endDate < tomorrow { continue }

                    // Check each schedule entry for tomorrow's day of week
                    guard let entries = schedule.scheduleEntries else { continue }
                    for entry in entries where entry.daysOfWeek.contains(tomorrowWeekday) {
                        // Parse time string for display
                        let displayTime: String
                        let parts = entry.time.split(separator: ":")
                        if parts.count == 2,
                           let hour = Int(parts[0]),
                           let minute = Int(parts[1]) {
                            var comps = DateComponents()
                            comps.hour = hour
                            comps.minute = minute
                            if let date = calendar.date(from: comps) {
                                displayTime = timeFormatter.string(from: date)
                            } else {
                                displayTime = entry.time
                            }
                        } else {
                            displayTime = entry.time
                        }

                        items.append(WidgetBriefingItemData(
                            id: "med-\(medication.id.uuidString)-\(entry.id.uuidString)",
                            icon: "pill.fill",
                            title: medication.name,
                            subtitle: displayTime,
                            colorHex: "F36A6A"
                        ))
                    }
                }
            }

            // Tomorrow's appointments
            let allAppointments = try await appState.appointmentRepository.getAppointments(accountId: accountId)
            let tomorrowAppointments = allAppointments.filter { $0.date >= tomorrow && $0.date < tomorrowEnd }

            for appointment in tomorrowAppointments {
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

            // Tomorrow's birthdays
            let allProfiles = try await appState.profileRepository.getProfiles(accountId: accountId)
            let tomorrowBirthdays = allProfiles.filter { profile in
                guard let birthday = profile.birthday else { return false }
                return birthday.daysUntilNextOccurrence() == 1
            }

            for profile in tomorrowBirthdays {
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

            // Tomorrow's countdowns
            let allCountdowns = try await appState.countdownRepository.getUpcomingCountdowns(accountId: accountId, days: 365)
            let tomorrowCountdowns = allCountdowns.filter { $0.daysUntilNextOccurrence == 1 }

            for countdown in tomorrowCountdowns {
                items.append(WidgetBriefingItemData(
                    id: "countdown-\(countdown.id.uuidString)",
                    icon: "clock.fill",
                    title: countdown.title,
                    subtitle: nil,
                    colorHex: "9B59B6"
                ))
            }

            // To-do lists due tomorrow
            let allLists = try await appState.toDoRepository.getLists(accountId: accountId)
            var taskCount = 0
            for list in allLists {
                guard let dueDate = list.dueDate,
                      dueDate >= tomorrow && dueDate < tomorrowEnd else { continue }
                let listItems = try await appState.toDoRepository.getItems(listId: list.id)
                taskCount += listItems.filter { !$0.isCompleted }.count
            }

            // Add task items for display
            if taskCount > 0 {
                items.append(WidgetBriefingItemData(
                    id: "tasks-tomorrow",
                    icon: "checklist",
                    title: taskCount == 1 ? "1 task due" : "\(taskCount) tasks due",
                    subtitle: nil,
                    colorHex: "2ECC71"
                ))
            }

            let totalCount = items.count
            let briefingData = WidgetBriefingData(
                date: tomorrow,
                items: Array(items.prefix(8)),
                totalCount: totalCount
            )

            WidgetDataStore.saveTomorrowBriefingData(briefingData)

            #if DEBUG
            print("📊 WidgetBriefingService: Pre-cached tomorrow's data with \(totalCount) items")
            #endif
        } catch {
            #if DEBUG
            print("📊 WidgetBriefingService: Failed to cache tomorrow's data: \(error)")
            #endif
        }
    }
}
