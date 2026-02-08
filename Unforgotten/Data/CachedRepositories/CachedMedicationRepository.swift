import SwiftUI
import SwiftData

// MARK: - Cached Medication Repository
/// Provides offline-first access to Medication data with background sync
@MainActor
final class CachedMedicationRepository {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let remoteRepository: MedicationRepository
    private let syncEngine: SyncEngine
    private let networkMonitor: NetworkMonitor

    // MARK: - Initialization
    init(modelContext: ModelContext, remoteRepository: MedicationRepository, syncEngine: SyncEngine, networkMonitor: NetworkMonitor = .shared) {
        self.modelContext = modelContext
        self.remoteRepository = remoteRepository
        self.syncEngine = syncEngine
        self.networkMonitor = networkMonitor
    }

    // MARK: - Medication Read Operations

    /// Get all medications for an account from local cache, falling back to network if cache is empty
    func getMedications(accountId: UUID) async throws -> [Medication] {
        let descriptor = FetchDescriptor<LocalMedication>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalMedication>(\.sortOrder), SortDescriptor<LocalMedication>(\.name)]
        )

        let localMedications = try modelContext.fetch(descriptor)

        // If cache is empty and we're online, fetch from network and cache
        if localMedications.isEmpty && networkMonitor.isConnected {
            let remoteMedications = try await remoteRepository.getMedications(accountId: accountId)
            for remote in remoteMedications {
                let remoteId = remote.id
                let existingDescriptor = FetchDescriptor<LocalMedication>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                if try modelContext.fetch(existingDescriptor).isEmpty {
                    let local = LocalMedication(from: remote)
                    modelContext.insert(local)
                }
            }
            try? modelContext.save()
            return remoteMedications
        }

        return localMedications.map { (local: LocalMedication) in local.toRemote() }
    }

    /// Force refresh medications from network and update local cache
    func refreshMedications(accountId: UUID) async throws -> [Medication] {
        guard networkMonitor.isConnected else {
            return try await getMedications(accountId: accountId)
        }

        let remoteMedications = try await remoteRepository.getMedications(accountId: accountId)
        let remoteIds = Set(remoteMedications.map { $0.id })

        // Update local cache with remote data
        for remote in remoteMedications {
            let remoteId = remote.id
            let existingDescriptor = FetchDescriptor<LocalMedication>(
                predicate: #Predicate { $0.id == remoteId }
            )

            if let existing = try modelContext.fetch(existingDescriptor).first {
                existing.update(from: remote)
            } else {
                let local = LocalMedication(from: remote)
                modelContext.insert(local)
            }
        }

        // Remove local medications that no longer exist on server (orphans/duplicates)
        let localDescriptor = FetchDescriptor<LocalMedication>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted }
        )
        let localMedications = try modelContext.fetch(localDescriptor)

        for local in localMedications {
            if !remoteIds.contains(local.id) && local.isSynced {
                modelContext.delete(local)
            }
        }

        try? modelContext.save()
        return remoteMedications
    }

    /// Get medications for a specific profile
    func getMedications(profileId: UUID) async throws -> [Medication] {
        let descriptor = FetchDescriptor<LocalMedication>(
            predicate: #Predicate { $0.profileId == profileId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalMedication>(\.sortOrder), SortDescriptor<LocalMedication>(\.name)]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalMedication) in local.toRemote() }
    }

    /// Get a specific medication
    func getMedication(id: UUID) async throws -> Medication? {
        let descriptor = FetchDescriptor<LocalMedication>(
            predicate: #Predicate { $0.id == id && !$0.locallyDeleted }
        )

        return try modelContext.fetch(descriptor).first?.toRemote()
    }

    // MARK: - Medication Write Operations

    /// Create a new medication
    func createMedication(_ insert: MedicationInsert) async throws -> Medication {
        let local = LocalMedication(
            id: UUID(),
            accountId: insert.accountId,
            profileId: insert.profileId,
            name: insert.name,
            strength: insert.strength,
            form: insert.form,
            reason: insert.reason,
            prescribingDoctorId: insert.prescribingDoctorId,
            notes: insert.notes,
            imageUrl: insert.imageUrl,
            localImagePath: insert.localImagePath,
            intakeInstruction: insert.intakeInstruction?.rawValue,
            isPaused: insert.isPaused,
            isSynced: false
        )
        modelContext.insert(local)

        syncEngine.queueChange(
            entityType: "medication",
            entityId: local.id,
            accountId: insert.accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update a medication
    func updateMedication(_ medication: Medication) async throws -> Medication {
        let medicationId = medication.id
        let descriptor = FetchDescriptor<LocalMedication>(
            predicate: #Predicate { $0.id == medicationId }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.name = medication.name
            local.strength = medication.strength
            local.form = medication.form
            local.reason = medication.reason
            local.prescribingDoctorId = medication.prescribingDoctorId
            local.notes = medication.notes
            local.imageUrl = medication.imageUrl
            local.localImagePath = medication.localImagePath
            local.intakeInstruction = medication.intakeInstruction?.rawValue
            local.isPaused = medication.isPaused
            local.pausedAt = medication.pausedAt
            local.sortOrder = medication.sortOrder
            local.markAsModified()

            syncEngine.queueChange(
                entityType: "medication",
                entityId: medication.id,
                accountId: medication.accountId,
                changeType: .update
            )

            try modelContext.save()
            return local.toRemote()
        }

        throw SupabaseError.notFound
    }

    /// Toggle medication paused status
    func toggleMedicationPaused(id: UUID, isPaused: Bool) async throws -> Medication {
        let descriptor = FetchDescriptor<LocalMedication>(
            predicate: #Predicate { $0.id == id }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.isPaused = isPaused
            local.pausedAt = isPaused ? Date() : nil
            local.markAsModified()

            syncEngine.queueChange(
                entityType: "medication",
                entityId: id,
                accountId: local.accountId,
                changeType: .update
            )

            try modelContext.save()
            return local.toRemote()
        }

        throw SupabaseError.notFound
    }

    /// Update sort orders for multiple medications
    func updateMedicationSortOrders(_ updates: [SortOrderUpdate]) async throws {
        for update in updates {
            let updateId = update.id
            let descriptor = FetchDescriptor<LocalMedication>(
                predicate: #Predicate { $0.id == updateId }
            )

            if let local = try modelContext.fetch(descriptor).first {
                local.sortOrder = update.sortOrder
                local.markAsModified()

                syncEngine.queueChange(
                    entityType: "medication",
                    entityId: update.id,
                    accountId: local.accountId,
                    changeType: .update
                )
            }
        }

        try modelContext.save()
    }

    /// Delete a medication
    func deleteMedication(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalMedication>(
            predicate: #Predicate { $0.id == id }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.locallyDeleted = true
            local.markAsModified()

            syncEngine.queueChange(
                entityType: "medication",
                entityId: id,
                accountId: local.accountId,
                changeType: .delete
            )

            try modelContext.save()
        }
    }

    // MARK: - Schedule Operations

    /// Get schedules for a medication
    func getSchedules(medicationId: UUID) async throws -> [MedicationSchedule] {
        let descriptor = FetchDescriptor<LocalMedicationSchedule>(
            predicate: #Predicate { $0.medicationId == medicationId && !$0.locallyDeleted }
        )

        return try modelContext.fetch(descriptor).map { (local: LocalMedicationSchedule) in local.toRemote() }
    }

    /// Create a new schedule
    func createSchedule(_ insert: MedicationScheduleInsert) async throws -> MedicationSchedule {
        let encoder = JSONEncoder()

        // Encode daysOfWeek to Data
        var daysOfWeekData: Data? = nil
        if let daysOfWeek = insert.daysOfWeek {
            daysOfWeekData = try? encoder.encode(daysOfWeek)
        }

        // Encode schedule entries to Data
        var entriesData: Data? = nil
        if let entries = insert.scheduleEntries {
            entriesData = try? encoder.encode(entries)
        }

        let local = LocalMedicationSchedule(
            id: UUID(),
            accountId: insert.accountId,
            medicationId: insert.medicationId,
            scheduleType: insert.scheduleType.rawValue,
            startDate: insert.startDate,
            endDate: insert.endDate,
            daysOfWeek: daysOfWeekData,
            scheduleEntries: entriesData,
            doseDescription: insert.doseDescription,
            isSynced: false
        )
        modelContext.insert(local)

        syncEngine.queueChange(
            entityType: "medicationSchedule",
            entityId: local.id,
            accountId: insert.accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update a schedule
    func updateSchedule(_ schedule: MedicationSchedule) async throws -> MedicationSchedule {
        let scheduleId = schedule.id
        let descriptor = FetchDescriptor<LocalMedicationSchedule>(
            predicate: #Predicate { $0.id == scheduleId }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.update(from: schedule)
            local.markAsModified()

            syncEngine.queueChange(
                entityType: "medicationSchedule",
                entityId: schedule.id,
                accountId: schedule.accountId,
                changeType: .update
            )

            try modelContext.save()
            return local.toRemote()
        }

        throw SupabaseError.notFound
    }

    // MARK: - Log Operations

    /// Get logs for a medication in a date range
    func getLogs(medicationId: UUID, from startDate: Date, to endDate: Date) async throws -> [MedicationLog] {
        let descriptor = FetchDescriptor<LocalMedicationLog>(
            predicate: #Predicate {
                $0.medicationId == medicationId &&
                $0.scheduledAt >= startDate &&
                $0.scheduledAt < endDate &&
                !$0.locallyDeleted
            },
            sortBy: [SortDescriptor<LocalMedicationLog>(\.scheduledAt)]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalMedicationLog) in local.toRemote() }
    }

    /// Get today's logs for an account
    func getTodaysLogs(accountId: UUID) async throws -> [MedicationLog] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<LocalMedicationLog>(
            predicate: #Predicate {
                $0.accountId == accountId &&
                $0.scheduledAt >= startOfDay &&
                $0.scheduledAt < endOfDay &&
                !$0.locallyDeleted
            },
            sortBy: [SortDescriptor<LocalMedicationLog>(\.scheduledAt)]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalMedicationLog) in local.toRemote() }
    }

    /// Update log status (taken, missed, skipped)
    func updateLogStatus(logId: UUID, status: MedicationLogStatus, takenAt: Date? = nil) async throws -> MedicationLog {
        let descriptor = FetchDescriptor<LocalMedicationLog>(
            predicate: #Predicate { $0.id == logId }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.status = status.rawValue
            local.takenAt = takenAt
            local.markAsModified()

            syncEngine.queueChange(
                entityType: "medicationLog",
                entityId: logId,
                accountId: local.accountId,
                changeType: .update
            )

            try modelContext.save()
            return local.toRemote()
        }

        throw SupabaseError.notFound
    }

    /// Generate daily logs for today (local-only for offline support)
    func generateDailyLogs(accountId: UUID, date: Date) async throws {
        try await syncEngine.generateLocalMedicationLogs(accountId: accountId)
    }

    /// Get logs for an account in a date range
    func getLogsForAccount(accountId: UUID, from startDate: Date, to endDate: Date) async throws -> [MedicationLog] {
        let descriptor = FetchDescriptor<LocalMedicationLog>(
            predicate: #Predicate {
                $0.accountId == accountId &&
                $0.scheduledAt >= startDate &&
                $0.scheduledAt < endDate &&
                !$0.locallyDeleted
            },
            sortBy: [SortDescriptor<LocalMedicationLog>(\.scheduledAt)]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalMedicationLog) in local.toRemote() }
    }

    /// Delete future scheduled logs for a medication
    func deleteFutureScheduledLogs(medicationId: UUID) async throws {
        let now = Date()
        let scheduledStatus = MedicationLogStatus.scheduled.rawValue

        let descriptor = FetchDescriptor<LocalMedicationLog>(
            predicate: #Predicate {
                $0.medicationId == medicationId &&
                $0.status == scheduledStatus &&
                $0.scheduledAt >= now &&
                !$0.locallyDeleted
            }
        )

        let logs = try modelContext.fetch(descriptor)
        for log in logs {
            log.locallyDeleted = true
            log.markAsModified()

            syncEngine.queueChange(
                entityType: "medicationLog",
                entityId: log.id,
                accountId: log.accountId,
                changeType: .delete
            )
        }

        try modelContext.save()
    }

    /// Regenerate today's logs for a specific medication
    func regenerateTodaysLogs(medicationId: UUID, accountId: UUID) async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let scheduledStatus = MedicationLogStatus.scheduled.rawValue

        // Delete today's scheduled logs for this medication only
        let deleteDescriptor = FetchDescriptor<LocalMedicationLog>(
            predicate: #Predicate {
                $0.medicationId == medicationId &&
                $0.status == scheduledStatus &&
                $0.scheduledAt >= today &&
                $0.scheduledAt < tomorrow &&
                !$0.locallyDeleted
            }
        )

        let logsToDelete = try modelContext.fetch(deleteDescriptor)
        for log in logsToDelete {
            log.locallyDeleted = true
            log.markAsModified()

            syncEngine.queueChange(
                entityType: "medicationLog",
                entityId: log.id,
                accountId: log.accountId,
                changeType: .delete
            )
        }

        try modelContext.save()

        // Regenerate logs for this medication
        try await syncEngine.generateLocalMedicationLogs(accountId: accountId)
    }

    // MARK: - Combined Queries

    /// Get medications with their logs for today
    func getMedicationsWithTodaysLogs(accountId: UUID) async throws -> [MedicationWithLog] {
        let medications = try await getMedications(accountId: accountId)
        let todaysLogs = try await getTodaysLogs(accountId: accountId)

        var results: [MedicationWithLog] = []

        for log in todaysLogs {
            if let medication = medications.first(where: { $0.id == log.medicationId }) {
                // Get schedule for this medication
                let schedules = try await getSchedules(medicationId: medication.id)
                let schedule = schedules.first

                results.append(MedicationWithLog(
                    medication: medication,
                    log: log,
                    schedule: schedule
                ))
            }
        }

        return results.sorted { $0.log.scheduledAt < $1.log.scheduledAt }
    }
}
