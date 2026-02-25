import Foundation
import Supabase

// MARK: - Medication Repository Protocol
protocol MedicationRepositoryProtocol {
    func getMedications(accountId: UUID) async throws -> [Medication]
    func getMedication(id: UUID) async throws -> Medication
    func createMedication(_ medication: MedicationInsert) async throws -> Medication
    func updateMedication(_ medication: Medication) async throws -> Medication
    func deleteMedication(id: UUID) async throws
    func updateMedicationSortOrders(_ updates: [SortOrderUpdate]) async throws

    // Schedules
    func getSchedules(medicationId: UUID) async throws -> [MedicationSchedule]
    func createSchedule(_ schedule: MedicationScheduleInsert) async throws -> MedicationSchedule
    func updateSchedule(_ schedule: MedicationSchedule) async throws -> MedicationSchedule
    func deleteSchedule(id: UUID) async throws

    // Logs
    func getTodaysLogs(accountId: UUID) async throws -> [MedicationLog]
    func getLogs(medicationId: UUID, from: Date, to: Date) async throws -> [MedicationLog]
    func getLogsForAccount(accountId: UUID, from: Date, to: Date) async throws -> [MedicationLog]
    func createLog(_ log: MedicationLogInsert) async throws -> MedicationLog
    func updateLogStatus(logId: UUID, status: MedicationLogStatus, takenAt: Date?) async throws -> MedicationLog
    func generateDailyLogs(accountId: UUID, date: Date) async throws
    func deleteFutureScheduledLogs(medicationId: UUID) async throws
    func regenerateTodaysLogs(medicationId: UUID, accountId: UUID) async throws
}

// MARK: - Medication Repository Implementation
final class MedicationRepository: MedicationRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Get All Medications
    func getMedications(accountId: UUID) async throws -> [Medication] {
        let medications: [Medication] = try await supabase
            .from(TableName.medications)
            .select()
            .eq("account_id", value: accountId)
            .order("sort_order")
            .order("name")
            .execute()
            .value

        return medications
    }
    
    // MARK: - Get Single Medication
    func getMedication(id: UUID) async throws -> Medication {
        let medication: Medication = try await supabase
            .from(TableName.medications)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        
        return medication
    }
    
    // MARK: - Create Medication
    func createMedication(_ medication: MedicationInsert) async throws -> Medication {
        let created: Medication = try await supabase
            .from(TableName.medications)
            .insert(medication)
            .select()
            .single()
            .execute()
            .value
        
        return created
    }
    
    // MARK: - Update Medication
    func updateMedication(_ medication: Medication) async throws -> Medication {
        let update = MedicationUpdate(
            name: medication.name,
            strength: medication.strength,
            form: medication.form,
            reason: medication.reason,
            prescribingDoctorId: medication.prescribingDoctorId,
            notes: medication.notes,
            imageUrl: medication.imageUrl,
            localImagePath: medication.localImagePath,
            intakeInstruction: medication.intakeInstruction,
            isPaused: medication.isPaused,
            pausedAt: medication.pausedAt
        )

        let updated: Medication = try await supabase
            .from(TableName.medications)
            .update(update)
            .eq("id", value: medication.id)
            .select()
            .single()
            .execute()
            .value

        return updated
    }
    
    // MARK: - Delete Medication
    func deleteMedication(id: UUID) async throws {
        try await supabase
            .from(TableName.medications)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Update Medication Sort Orders
    func updateMedicationSortOrders(_ updates: [SortOrderUpdate]) async throws {
        for update in updates {
            try await supabase
                .from(TableName.medications)
                .update(["sort_order": update.sortOrder])
                .eq("id", value: update.id)
                .execute()
        }
    }

    // MARK: - Get Schedules
    func getSchedules(medicationId: UUID) async throws -> [MedicationSchedule] {
        let schedules: [MedicationSchedule] = try await supabase
            .from(TableName.medicationSchedules)
            .select()
            .eq("medication_id", value: medicationId)
            .execute()
            .value
        
        return schedules
    }
    
    // MARK: - Create Schedule
    func createSchedule(_ schedule: MedicationScheduleInsert) async throws -> MedicationSchedule {
        let created: MedicationSchedule = try await supabase
            .from(TableName.medicationSchedules)
            .insert(schedule)
            .select()
            .single()
            .execute()
            .value
        
        return created
    }
    
    // MARK: - Update Schedule
    func updateSchedule(_ schedule: MedicationSchedule) async throws -> MedicationSchedule {
        let update = MedicationScheduleUpdate(
            scheduleType: schedule.scheduleType,
            startDate: schedule.startDate,
            endDate: schedule.endDate,
            daysOfWeek: schedule.daysOfWeek,
            scheduleEntries: schedule.scheduleEntries,
            doseDescription: schedule.doseDescription
        )

        let updated: MedicationSchedule = try await supabase
            .from(TableName.medicationSchedules)
            .update(update)
            .eq("id", value: schedule.id)
            .select()
            .single()
            .execute()
            .value

        return updated
    }
    
    // MARK: - Delete Schedule
    func deleteSchedule(id: UUID) async throws {
        try await supabase
            .from(TableName.medicationSchedules)
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Get Today's Logs
    func getTodaysLogs(accountId: UUID) async throws -> [MedicationLog] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let logs: [MedicationLog] = try await supabase
            .from(TableName.medicationLogs)
            .select()
            .eq("account_id", value: accountId)
            .gte("scheduled_at", value: today.ISO8601Format())
            .lt("scheduled_at", value: tomorrow.ISO8601Format())
            .order("scheduled_at")
            .execute()
            .value
        
        return logs
    }
    
    // MARK: - Get Logs for Date Range (by medication)
    func getLogs(medicationId: UUID, from: Date, to: Date) async throws -> [MedicationLog] {
        let logs: [MedicationLog] = try await supabase
            .from(TableName.medicationLogs)
            .select()
            .eq("medication_id", value: medicationId)
            .gte("scheduled_at", value: from.ISO8601Format())
            .lte("scheduled_at", value: to.ISO8601Format())
            .order("scheduled_at")
            .execute()
            .value

        return logs
    }

    // MARK: - Get Logs for Date Range (by account)
    func getLogsForAccount(accountId: UUID, from: Date, to: Date) async throws -> [MedicationLog] {
        let logs: [MedicationLog] = try await supabase
            .from(TableName.medicationLogs)
            .select()
            .eq("account_id", value: accountId)
            .gte("scheduled_at", value: from.ISO8601Format())
            .lt("scheduled_at", value: to.ISO8601Format())
            .order("scheduled_at")
            .execute()
            .value

        return logs
    }
    
    // MARK: - Create Log
    func createLog(_ log: MedicationLogInsert) async throws -> MedicationLog {
        let created: MedicationLog = try await supabase
            .from(TableName.medicationLogs)
            .insert(log)
            .select()
            .single()
            .execute()
            .value
        
        return created
    }
    
    // MARK: - Update Log Status
    func updateLogStatus(logId: UUID, status: MedicationLogStatus, takenAt: Date? = nil) async throws -> MedicationLog {
        let update = MedicationLogUpdate(
            status: status,
            takenAt: takenAt
        )
        
        let updated: MedicationLog = try await supabase
            .from(TableName.medicationLogs)
            .update(update)
            .eq("id", value: logId)
            .select()
            .single()
            .execute()
            .value
        
        return updated
    }
    
    // MARK: - Generate Daily Logs
    /// Generates medication logs for a specific date based on schedules
    func generateDailyLogs(accountId: UUID, date: Date) async throws {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: date) - 1 // 0-6 (Sun-Sat)

        #if DEBUG
        print("💊 generateDailyLogs: Starting for date \(date), dayOfWeek: \(dayOfWeek)")
        #endif

        // Get all medications for this account
        let medications = try await getMedications(accountId: accountId)
        #if DEBUG
        print("💊 generateDailyLogs: Found \(medications.count) medications")
        #endif

        for medication in medications {
            #if DEBUG
            print("💊 Processing medication: \(medication.name), isPaused: \(medication.isPaused)")
            #endif
            // Skip paused medications
            guard !medication.isPaused else {
                #if DEBUG
                print("💊 Skipping paused medication: \(medication.name)")
                #endif
                continue
            }

            let schedules = try await getSchedules(medicationId: medication.id)
            #if DEBUG
            print("💊 Found \(schedules.count) schedules for \(medication.name)")
            #endif

            for schedule in schedules {
                #if DEBUG
                print("💊 Schedule startDate: \(schedule.startDate), endDate: \(String(describing: schedule.endDate))")
                print("💊 Schedule entries: \(String(describing: schedule.scheduleEntries)), legacyTimes: \(String(describing: schedule.legacyTimes))")
                #endif

                // Check if schedule is active for this date
                let scheduleStartDay = calendar.startOfDay(for: schedule.startDate)
                let targetDay = calendar.startOfDay(for: date)
                guard scheduleStartDay <= targetDay else {
                    #if DEBUG
                    print("💊 Skipping schedule - startDate \(scheduleStartDay) is after target date \(targetDay)")
                    #endif
                    continue
                }
                if let endDate = schedule.endDate {
                    let endDay = calendar.startOfDay(for: endDate)
                    if endDay < targetDay {
                        #if DEBUG
                        print("💊 Skipping schedule - endDate \(endDay) is before target date \(targetDay)")
                        #endif
                        continue
                    }
                }

                // Get active entries for this date
                let activeEntries = getActiveEntriesForDate(
                    entries: schedule.scheduleEntries,
                    scheduleStartDate: schedule.startDate,
                    targetDate: date,
                    dayOfWeek: dayOfWeek,
                    legacyTimes: schedule.legacyTimes,
                    legacyDaysOfWeek: schedule.daysOfWeek,
                    doseDescription: schedule.doseDescription
                )

                #if DEBUG
                print("💊 Active entries for this schedule: \(activeEntries.count)")
                for entry in activeEntries {
                    print("💊   - time: \(entry.time), dosage: \(entry.dosage ?? "nil")")
                }
                #endif

                for (timeString, _) in activeEntries {
                    // Parse time string (HH:mm format)
                    let components = timeString.split(separator: ":")
                    guard components.count >= 2,
                          let hour = Int(components[0]),
                          let minute = Int(components[1]) else { continue }

                    var scheduledComponents = calendar.dateComponents([.year, .month, .day], from: date)
                    scheduledComponents.hour = hour
                    scheduledComponents.minute = minute

                    guard let scheduledAt = calendar.date(from: scheduledComponents) else { continue }

                    // Check if log already exists
                    let existingLogs = try await getLogs(
                        medicationId: medication.id,
                        from: scheduledAt,
                        to: scheduledAt
                    )

                    if existingLogs.isEmpty {
                        let log = MedicationLogInsert(
                            accountId: accountId,
                            medicationId: medication.id,
                            scheduledAt: scheduledAt,
                            status: .scheduled
                        )
                        _ = try await createLog(log)
                        #if DEBUG
                        print("💊 Created log for \(medication.name) at \(scheduledAt)")
                        #endif
                    } else {
                        #if DEBUG
                        print("💊 Log already exists for \(medication.name) at \(scheduledAt)")
                        #endif
                    }
                }
            }
        }
        #if DEBUG
        print("💊 generateDailyLogs: Complete")
        #endif
    }

    /// Gets active schedule entries for a specific date, handling sequential durations
    /// Returns array of (time, dosage) tuples for entries active on the target date
    private func getActiveEntriesForDate(
        entries: [ScheduleEntry]?,
        scheduleStartDate: Date,
        targetDate: Date,
        dayOfWeek: Int,
        legacyTimes: [String]?,
        legacyDaysOfWeek: [Int]?,
        doseDescription: String?
    ) -> [(time: String, dosage: String?)] {
        let calendar = Calendar.current

        // If we have schedule entries, process them with sequential duration logic
        if let entries = entries, !entries.isEmpty {
            // Sort entries by sortOrder to ensure correct sequence
            let sortedEntries = entries.sorted { $0.sortOrder < $1.sortOrder }

            // Calculate the day offset from schedule start
            let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: scheduleStartDate), to: calendar.startOfDay(for: targetDate)).day ?? 0

            // Track cumulative days to determine which entry is active
            var cumulativeDays = 0
            var activeEntries: [(time: String, dosage: String?)] = []

            for entry in sortedEntries {
                let entryDuration = entry.durationDays ?? Int.max // No limit = infinite duration

                // Check if this entry is active for the target date
                let entryStartDay = cumulativeDays
                let entryEndDay = entryDuration == Int.max ? Int.max : cumulativeDays + entryDuration - 1

                if daysSinceStart >= entryStartDay && daysSinceStart <= entryEndDay {
                    // This entry is active - check if target day of week is included
                    if entry.daysOfWeek.contains(dayOfWeek) {
                        activeEntries.append((time: entry.time, dosage: entry.dosage))
                    }
                }

                // Move to next entry's start (only if this entry has a duration limit)
                if entryDuration != Int.max {
                    cumulativeDays += entryDuration
                } else {
                    // Entry with no duration limit - it's active indefinitely from this point
                    // No further entries should be considered after an unlimited one
                    break
                }
            }

            return activeEntries
        }

        // Legacy: Use times array with global days of week
        if let times = legacyTimes {
            if let daysOfWeek = legacyDaysOfWeek, !daysOfWeek.contains(dayOfWeek) {
                return []
            }
            return times.map { (time: $0, dosage: doseDescription) }
        }

        return []
    }

    // MARK: - Delete Future Scheduled Logs
    /// Deletes all future logs with 'scheduled' status for a medication
    func deleteFutureScheduledLogs(medicationId: UUID) async throws {
        let now = Date()

        try await supabase
            .from(TableName.medicationLogs)
            .delete()
            .eq("medication_id", value: medicationId)
            .eq("status", value: MedicationLogStatus.scheduled.rawValue)
            .gte("scheduled_at", value: now.ISO8601Format())
            .execute()
    }

    // MARK: - Regenerate Today's Logs
    /// Deletes today's scheduled (not taken) logs and regenerates them for a single medication
    func regenerateTodaysLogs(medicationId: UUID, accountId: UUID) async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // Delete today's scheduled logs for this medication only
        try await supabase
            .from(TableName.medicationLogs)
            .delete()
            .eq("medication_id", value: medicationId)
            .eq("status", value: MedicationLogStatus.scheduled.rawValue)
            .gte("scheduled_at", value: today.ISO8601Format())
            .lt("scheduled_at", value: tomorrow.ISO8601Format())
            .execute()

        // Regenerate logs for today for this medication
        let medication = try await getMedication(id: medicationId)

        // Skip if medication is paused
        guard !medication.isPaused else { return }

        let schedules = try await getSchedules(medicationId: medicationId)
        let dayOfWeek = calendar.component(.weekday, from: today) - 1

        for schedule in schedules {
            let scheduleStartDay = calendar.startOfDay(for: schedule.startDate)
            guard scheduleStartDay <= today else { continue }
            if let endDate = schedule.endDate {
                let endDay = calendar.startOfDay(for: endDate)
                if endDay < today { continue }
            }

            // Get active entries for today using sequential duration logic
            let activeEntries = getActiveEntriesForDate(
                entries: schedule.scheduleEntries,
                scheduleStartDate: schedule.startDate,
                targetDate: today,
                dayOfWeek: dayOfWeek,
                legacyTimes: schedule.legacyTimes,
                legacyDaysOfWeek: schedule.daysOfWeek,
                doseDescription: schedule.doseDescription
            )

            for (timeString, _) in activeEntries {
                let components = timeString.split(separator: ":")
                guard components.count >= 2,
                      let hour = Int(components[0]),
                      let minute = Int(components[1]) else { continue }

                var scheduledComponents = calendar.dateComponents([.year, .month, .day], from: today)
                scheduledComponents.hour = hour
                scheduledComponents.minute = minute

                guard let scheduledAt = calendar.date(from: scheduledComponents) else { continue }

                let log = MedicationLogInsert(
                    accountId: accountId,
                    medicationId: medicationId,
                    scheduledAt: scheduledAt,
                    status: .scheduled
                )
                _ = try await createLog(log)
            }
        }
    }
}

// MARK: - Insert/Update Types
struct MedicationInsert: Encodable {
    let id: UUID?
    let accountId: UUID
    let profileId: UUID
    let name: String
    let strength: String?
    let form: String?
    let reason: String?
    let prescribingDoctorId: UUID?
    let notes: String?
    let imageUrl: String?
    let localImagePath: String?
    let intakeInstruction: IntakeInstruction?
    let isPaused: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case profileId = "profile_id"
        case name
        case strength
        case form
        case reason
        case prescribingDoctorId = "prescribing_doctor_id"
        case notes
        case imageUrl = "image_url"
        case localImagePath = "local_image_path"
        case intakeInstruction = "intake_instruction"
        case isPaused = "is_paused"
    }

    init(
        id: UUID? = nil,
        accountId: UUID,
        profileId: UUID,
        name: String,
        strength: String? = nil,
        form: String? = nil,
        reason: String? = nil,
        prescribingDoctorId: UUID? = nil,
        notes: String? = nil,
        imageUrl: String? = nil,
        localImagePath: String? = nil,
        intakeInstruction: IntakeInstruction? = nil,
        isPaused: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.profileId = profileId
        self.name = name
        self.strength = strength
        self.form = form
        self.reason = reason
        self.prescribingDoctorId = prescribingDoctorId
        self.notes = notes
        self.imageUrl = imageUrl
        self.localImagePath = localImagePath
        self.intakeInstruction = intakeInstruction
        self.isPaused = isPaused
    }
}

private struct MedicationUpdate: Encodable {
    let name: String
    let strength: String?
    let form: String?
    let reason: String?
    let prescribingDoctorId: UUID?
    let notes: String?
    let imageUrl: String?
    let localImagePath: String?
    let intakeInstruction: IntakeInstruction?
    let isPaused: Bool
    let pausedAt: Date?

    enum CodingKeys: String, CodingKey {
        case name
        case strength
        case form
        case reason
        case prescribingDoctorId = "prescribing_doctor_id"
        case notes
        case imageUrl = "image_url"
        case localImagePath = "local_image_path"
        case intakeInstruction = "intake_instruction"
        case isPaused = "is_paused"
        case pausedAt = "paused_at"
    }
}

struct MedicationScheduleInsert: Encodable {
    let id: UUID?
    let accountId: UUID
    let medicationId: UUID
    let scheduleType: ScheduleType
    let startDate: Date
    let endDate: Date?
    let daysOfWeek: [Int]?
    let scheduleEntries: [ScheduleEntry]?
    let doseDescription: String?

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case medicationId = "medication_id"
        case scheduleType = "schedule_type"
        case startDate = "start_date"
        case endDate = "end_date"
        case daysOfWeek = "days_of_week"
        case scheduleEntries = "schedule_entries"
        case doseDescription = "dose_description"
    }

    init(
        id: UUID? = nil,
        accountId: UUID,
        medicationId: UUID,
        scheduleType: ScheduleType = .scheduled,
        startDate: Date = Date(),
        endDate: Date? = nil,
        daysOfWeek: [Int]? = [0, 1, 2, 3, 4, 5, 6],
        scheduleEntries: [ScheduleEntry]? = nil,
        doseDescription: String? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.medicationId = medicationId
        self.scheduleType = scheduleType
        self.startDate = startDate
        self.endDate = endDate
        self.daysOfWeek = daysOfWeek
        self.scheduleEntries = scheduleEntries
        self.doseDescription = doseDescription
    }
}

private struct MedicationScheduleUpdate: Encodable {
    let scheduleType: ScheduleType
    let startDate: Date
    let endDate: Date?
    let daysOfWeek: [Int]?
    let scheduleEntries: [ScheduleEntry]?
    let doseDescription: String?

    enum CodingKeys: String, CodingKey {
        case scheduleType = "schedule_type"
        case startDate = "start_date"
        case endDate = "end_date"
        case daysOfWeek = "days_of_week"
        case scheduleEntries = "schedule_entries"
        case doseDescription = "dose_description"
    }
}

struct MedicationLogInsert: Encodable {
    let accountId: UUID
    let medicationId: UUID
    let scheduledAt: Date
    let status: MedicationLogStatus
    let takenAt: Date?
    let note: String?
    
    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case medicationId = "medication_id"
        case scheduledAt = "scheduled_at"
        case status
        case takenAt = "taken_at"
        case note
    }
    
    init(
        accountId: UUID,
        medicationId: UUID,
        scheduledAt: Date,
        status: MedicationLogStatus = .scheduled,
        takenAt: Date? = nil,
        note: String? = nil
    ) {
        self.accountId = accountId
        self.medicationId = medicationId
        self.scheduledAt = scheduledAt
        self.status = status
        self.takenAt = takenAt
        self.note = note
    }
}

private struct MedicationLogUpdate: Encodable {
    let status: MedicationLogStatus
    let takenAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case status
        case takenAt = "taken_at"
    }
}
