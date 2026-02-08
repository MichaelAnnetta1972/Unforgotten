import SwiftUI
import SwiftData
import Combine

// MARK: - Sync Engine
/// Central orchestrator for syncing local data with Supabase
@MainActor
final class SyncEngine: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var status: GlobalSyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pendingChangesCount: Int = 0

    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let networkMonitor: NetworkMonitor

    // MARK: - Remote Repositories
    private let accountRepository = AccountRepository()
    private let profileRepository = ProfileRepository()
    private let medicationRepository = MedicationRepository()
    private let appointmentRepository = AppointmentRepository()
    private let usefulContactRepository = UsefulContactRepository()
    private let toDoRepository = ToDoRepository()
    private let countdownRepository = CountdownRepository()
    private let stickyReminderRepository = StickyReminderRepository()
    private let moodRepository = MoodRepository()
    private let importantAccountRepository = ImportantAccountRepository()

    // MARK: - Sync State
    private var syncTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(modelContext: ModelContext, networkMonitor: NetworkMonitor = .shared) {
        self.modelContext = modelContext
        self.networkMonitor = networkMonitor

        // Subscribe to network changes
        setupNetworkObserver()

        // Update pending changes count
        updatePendingChangesCount()
    }

    // MARK: - Network Observer
    private func setupNetworkObserver() {
        networkMonitor.$isConnected
            .dropFirst()
            .sink { [weak self] isConnected in
                Task { @MainActor in
                    if isConnected {
                        // Network restored - attempt to sync pending changes
                        await self?.processPendingChanges()
                    } else {
                        self?.status = .offline
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Full Sync
    /// Performs a full sync for the given account
    func performFullSync(accountId: UUID) async {
        guard networkMonitor.isConnected else {
            status = .offline
            return
        }

        // Cancel any existing sync
        syncTask?.cancel()

        syncTask = Task {
            await executeFullSync(accountId: accountId)
        }

        await syncTask?.value
    }

    private func executeFullSync(accountId: UUID) async {
        status = .syncing(entity: "starting", progress: 0)

        do {
            // 1. Push pending local changes first
            status = .syncing(entity: "uploading changes", progress: 0.05)
            await processPendingChanges()

            // 2. Pull and merge remote changes for each entity type
            let entities: [(String, Double)] = [
                ("profiles", 0.15),
                ("medications", 0.30),
                ("schedules", 0.40),
                ("logs", 0.50),
                ("appointments", 0.60),
                ("contacts", 0.70),
                ("todos", 0.80),
                ("countdowns", 0.85),
                ("reminders", 0.90),
                ("mood", 0.95)
            ]

            var totalChanges = 0

            for (entity, progress) in entities {
                guard !Task.isCancelled else { return }

                status = .syncing(entity: entity, progress: progress)
                let changes = try await syncEntity(entity, accountId: accountId)
                totalChanges += changes
            }

            // 3. Generate medication logs locally for today
            status = .syncing(entity: "medication logs", progress: 0.98)
            try await generateLocalMedicationLogs(accountId: accountId)

            // 4. Update sync metadata
            updateSyncMetadata(accountId: accountId)

            status = .completed(changesCount: totalChanges)
            lastSyncDate = Date()

            // Reset to idle after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if case .completed = status {
                status = .idle
            }

        } catch {
            #if DEBUG
            print("🔄 Sync error: \(error)")
            #endif
            status = .failed(error: error.localizedDescription)
        }
    }

    // MARK: - Entity Sync
    private func syncEntity(_ entityType: String, accountId: UUID) async throws -> Int {
        switch entityType {
        case "profiles":
            return try await syncProfiles(accountId: accountId)
        case "medications":
            return try await syncMedications(accountId: accountId)
        case "schedules":
            return try await syncMedicationSchedules(accountId: accountId)
        case "logs":
            return try await syncMedicationLogs(accountId: accountId)
        case "appointments":
            return try await syncAppointments(accountId: accountId)
        case "contacts":
            return try await syncContacts(accountId: accountId)
        case "todos":
            return try await syncToDos(accountId: accountId)
        case "countdowns":
            return try await syncCountdowns(accountId: accountId)
        case "reminders":
            return try await syncStickyReminders(accountId: accountId)
        case "mood":
            return try await syncMoodEntries(accountId: accountId)
        default:
            return 0
        }
    }

    // MARK: - Profile Sync
    private func syncProfiles(accountId: UUID) async throws -> Int {
        let remoteProfiles = try await profileRepository.getProfiles(accountId: accountId)
        var changesCount = 0

        for remote in remoteProfiles {
            let descriptor = FetchDescriptor<LocalProfile>(
                predicate: #Predicate { $0.id == remote.id }
            )

            let localProfiles = try modelContext.fetch(descriptor)

            if let local = localProfiles.first {
                // Merge: last-write-wins
                if remote.updatedAt > local.updatedAt {
                    local.update(from: remote)
                    changesCount += 1
                }
            } else {
                // Insert new
                let newLocal = LocalProfile(from: remote)
                modelContext.insert(newLocal)
                changesCount += 1
            }
        }

        try modelContext.save()
        return changesCount
    }

    // MARK: - Medication Sync
    private func syncMedications(accountId: UUID) async throws -> Int {
        let remoteMedications = try await medicationRepository.getMedications(accountId: accountId)
        var changesCount = 0

        for remote in remoteMedications {
            let descriptor = FetchDescriptor<LocalMedication>(
                predicate: #Predicate { $0.id == remote.id }
            )

            let localMedications = try modelContext.fetch(descriptor)

            if let local = localMedications.first {
                if remote.updatedAt > local.updatedAt {
                    local.update(from: remote)
                    changesCount += 1
                }
            } else {
                let newLocal = LocalMedication(from: remote)
                modelContext.insert(newLocal)
                changesCount += 1
            }
        }

        try modelContext.save()
        return changesCount
    }

    // MARK: - Medication Schedule Sync
    private func syncMedicationSchedules(accountId: UUID) async throws -> Int {
        // Get all medications for this account first
        let medDescriptor = FetchDescriptor<LocalMedication>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted }
        )
        let localMedications = try modelContext.fetch(medDescriptor)
        var changesCount = 0

        for medication in localMedications {
            let remoteSchedules = try await medicationRepository.getSchedules(medicationId: medication.id)

            for remote in remoteSchedules {
                let descriptor = FetchDescriptor<LocalMedicationSchedule>(
                    predicate: #Predicate { $0.id == remote.id }
                )

                let localSchedules = try modelContext.fetch(descriptor)

                if let local = localSchedules.first {
                    if remote.updatedAt > local.updatedAt {
                        local.update(from: remote)
                        changesCount += 1
                    }
                } else {
                    let newLocal = LocalMedicationSchedule(from: remote)
                    modelContext.insert(newLocal)
                    changesCount += 1
                }
            }
        }

        try modelContext.save()
        return changesCount
    }

    // MARK: - Medication Log Sync
    private func syncMedicationLogs(accountId: UUID) async throws -> Int {
        // Sync logs for recent days (last 7 days + today)
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        let endDate = calendar.date(byAdding: .day, value: 1, to: Date())!

        let medDescriptor = FetchDescriptor<LocalMedication>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted }
        )
        let localMedications = try modelContext.fetch(medDescriptor)
        var changesCount = 0

        for medication in localMedications {
            let remoteLogs = try await medicationRepository.getLogs(
                medicationId: medication.id,
                from: startDate,
                to: endDate
            )

            for remote in remoteLogs {
                let descriptor = FetchDescriptor<LocalMedicationLog>(
                    predicate: #Predicate { $0.id == remote.id }
                )

                let localLogs = try modelContext.fetch(descriptor)

                if let local = localLogs.first {
                    // For logs, remote always wins (server generates them)
                    local.update(from: remote)
                    changesCount += 1
                } else {
                    let newLocal = LocalMedicationLog(from: remote)
                    modelContext.insert(newLocal)
                    changesCount += 1
                }
            }
        }

        try modelContext.save()
        return changesCount
    }

    // MARK: - Appointment Sync
    private func syncAppointments(accountId: UUID) async throws -> Int {
        let remoteAppointments = try await appointmentRepository.getAppointments(accountId: accountId)
        var changesCount = 0

        for remote in remoteAppointments {
            let descriptor = FetchDescriptor<LocalAppointment>(
                predicate: #Predicate { $0.id == remote.id }
            )

            let localAppointments = try modelContext.fetch(descriptor)

            if let local = localAppointments.first {
                if remote.updatedAt > local.updatedAt {
                    local.update(from: remote)
                    changesCount += 1
                }
            } else {
                let newLocal = LocalAppointment(from: remote)
                modelContext.insert(newLocal)
                changesCount += 1
            }
        }

        try modelContext.save()
        return changesCount
    }

    // MARK: - Contact Sync
    private func syncContacts(accountId: UUID) async throws -> Int {
        let remoteContacts = try await usefulContactRepository.getContacts(accountId: accountId)
        var changesCount = 0

        for remote in remoteContacts {
            let descriptor = FetchDescriptor<LocalUsefulContact>(
                predicate: #Predicate { $0.id == remote.id }
            )

            let localContacts = try modelContext.fetch(descriptor)

            if let local = localContacts.first {
                if remote.updatedAt > local.updatedAt {
                    local.update(from: remote)
                    changesCount += 1
                }
            } else {
                let newLocal = LocalUsefulContact(from: remote)
                modelContext.insert(newLocal)
                changesCount += 1
            }
        }

        try modelContext.save()
        return changesCount
    }

    // MARK: - ToDo Sync
    private func syncToDos(accountId: UUID) async throws -> Int {
        let remoteLists = try await toDoRepository.getLists(accountId: accountId)
        var changesCount = 0

        for remote in remoteLists {
            // Sync list
            let listDescriptor = FetchDescriptor<LocalToDoList>(
                predicate: #Predicate { $0.id == remote.id }
            )

            let localLists = try modelContext.fetch(listDescriptor)

            if let local = localLists.first {
                if remote.updatedAt > local.updatedAt {
                    local.update(from: remote)
                    changesCount += 1
                }
            } else {
                let newLocal = LocalToDoList(from: remote)
                modelContext.insert(newLocal)
                changesCount += 1
            }

            // Sync items
            for remoteItem in remote.items {
                let itemDescriptor = FetchDescriptor<LocalToDoItem>(
                    predicate: #Predicate { $0.id == remoteItem.id }
                )

                let localItems = try modelContext.fetch(itemDescriptor)

                if let localItem = localItems.first {
                    if remoteItem.updatedAt > localItem.updatedAt {
                        localItem.update(from: remoteItem)
                        changesCount += 1
                    }
                } else {
                    let newItem = LocalToDoItem(from: remoteItem)
                    modelContext.insert(newItem)
                    changesCount += 1
                }
            }
        }

        try modelContext.save()
        return changesCount
    }

    // MARK: - Countdown Sync
    private func syncCountdowns(accountId: UUID) async throws -> Int {
        let remoteCountdowns = try await countdownRepository.getCountdowns(accountId: accountId)
        var changesCount = 0

        for remote in remoteCountdowns {
            let descriptor = FetchDescriptor<LocalCountdown>(
                predicate: #Predicate { $0.id == remote.id }
            )

            let localCountdowns = try modelContext.fetch(descriptor)

            if let local = localCountdowns.first {
                if remote.updatedAt > local.updatedAt {
                    local.update(from: remote)
                    changesCount += 1
                }
            } else {
                let newLocal = LocalCountdown(from: remote)
                modelContext.insert(newLocal)
                changesCount += 1
            }
        }

        try modelContext.save()
        return changesCount
    }

    // MARK: - Sticky Reminder Sync
    private func syncStickyReminders(accountId: UUID) async throws -> Int {
        let remoteReminders = try await stickyReminderRepository.getReminders(accountId: accountId)
        var changesCount = 0

        for remote in remoteReminders {
            let descriptor = FetchDescriptor<LocalStickyReminder>(
                predicate: #Predicate { $0.id == remote.id }
            )

            let localReminders = try modelContext.fetch(descriptor)

            if let local = localReminders.first {
                if remote.updatedAt > local.updatedAt {
                    local.update(from: remote)
                    changesCount += 1
                }
            } else {
                let newLocal = LocalStickyReminder(from: remote)
                modelContext.insert(newLocal)
                changesCount += 1
            }
        }

        try modelContext.save()
        return changesCount
    }

    // MARK: - Mood Entry Sync
    private func syncMoodEntries(accountId: UUID) async throws -> Int {
        guard let userId = await SupabaseManager.shared.currentUserId else { return 0 }

        // Sync recent mood entries (last 30 days)
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -30, to: Date())!

        let remoteMoods = try await moodRepository.getEntries(
            accountId: accountId,
            from: startDate,
            to: Date()
        )
        var changesCount = 0

        for remote in remoteMoods {
            let descriptor = FetchDescriptor<LocalMoodEntry>(
                predicate: #Predicate { $0.id == remote.id }
            )

            let localMoods = try modelContext.fetch(descriptor)

            if let local = localMoods.first {
                // For mood entries, remote wins
                local.update(from: remote)
            } else {
                let newLocal = LocalMoodEntry(from: remote)
                modelContext.insert(newLocal)
                changesCount += 1
            }
        }

        try modelContext.save()
        return changesCount
    }

    // MARK: - Process Pending Changes
    /// Process all pending offline changes
    func processPendingChanges() async {
        guard networkMonitor.isConnected else { return }

        let descriptor = FetchDescriptor<PendingChange>(
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let changes = try? modelContext.fetch(descriptor), !changes.isEmpty else {
            updatePendingChangesCount()
            return
        }

        #if DEBUG
        print("🔄 Processing \(changes.count) pending changes")
        #endif

        for change in changes {
            guard change.shouldRetry else {
                // Max retries exceeded - remove the change
                modelContext.delete(change)
                continue
            }

            do {
                try await pushChange(change)
                modelContext.delete(change)
            } catch {
                change.recordFailure(error: error.localizedDescription)
                #if DEBUG
                print("🔄 Failed to push change: \(error)")
                #endif
            }
        }

        try? modelContext.save()
        updatePendingChangesCount()
    }

    // MARK: - Push Change
    private func pushChange(_ change: PendingChange) async throws {
        let changeType = PendingChange.ChangeType(rawValue: change.changeType)

        switch change.entityType {
        case "profile":
            try await pushProfileChange(change, type: changeType)
        case "medication":
            try await pushMedicationChange(change, type: changeType)
        case "medicationLog":
            try await pushMedicationLogChange(change, type: changeType)
        case "appointment":
            try await pushAppointmentChange(change, type: changeType)
        case "usefulContact":
            try await pushContactChange(change, type: changeType)
        case "toDoList":
            try await pushToDoListChange(change, type: changeType)
        case "toDoItem":
            try await pushToDoItemChange(change, type: changeType)
        case "countdown":
            try await pushCountdownChange(change, type: changeType)
        case "stickyReminder":
            try await pushStickyReminderChange(change, type: changeType)
        case "profileDetail":
            try await pushProfileDetailChange(change, type: changeType)
        default:
            #if DEBUG
            print("🔄 Unknown entity type: \(change.entityType)")
            #endif
        }
    }

    // MARK: - Push Entity Changes

    private func pushProfileChange(_ change: PendingChange, type: PendingChange.ChangeType?) async throws {
        let entityId = change.entityId
        let descriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate { $0.id == entityId }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        switch type {
        case .create:
            let insert = ProfileInsert(
                id: local.id,
                accountId: local.accountId,
                type: local.profileType,
                fullName: local.fullName,
                birthday: local.birthday
            )
            _ = try await profileRepository.createProfile(insert)
        case .update:
            _ = try await profileRepository.updateProfile(local.toRemote())
        case .delete:
            try await profileRepository.deleteProfile(id: change.entityId)
        default:
            break
        }

        local.isSynced = true
    }

    private func pushMedicationChange(_ change: PendingChange, type: PendingChange.ChangeType?) async throws {
        let entityId = change.entityId
        let descriptor = FetchDescriptor<LocalMedication>(
            predicate: #Predicate { $0.id == entityId }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        switch type {
        case .create:
            let insert = MedicationInsert(
                id: local.id,
                accountId: local.accountId,
                profileId: local.profileId,
                name: local.name,
                strength: local.strength,
                form: local.form,
                reason: local.reason,
                prescribingDoctorId: local.prescribingDoctorId,
                notes: local.notes,
                imageUrl: local.imageUrl,
                localImagePath: local.localImagePath,
                intakeInstruction: local.intakeInstruction.flatMap { IntakeInstruction(rawValue: $0) },
                isPaused: local.isPaused
            )
            _ = try await medicationRepository.createMedication(insert)
        case .update:
            _ = try await medicationRepository.updateMedication(local.toRemote())
        case .delete:
            try await medicationRepository.deleteMedication(id: change.entityId)
        default:
            break
        }

        local.isSynced = true
    }

    private func pushMedicationLogChange(_ change: PendingChange, type: PendingChange.ChangeType?) async throws {
        let entityId = change.entityId
        let descriptor = FetchDescriptor<LocalMedicationLog>(
            predicate: #Predicate { $0.id == entityId }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        if type == .update {
            _ = try await medicationRepository.updateLogStatus(
                logId: local.id,
                status: local.logStatus,
                takenAt: local.takenAt
            )
        }

        local.isSynced = true
    }

    private func pushAppointmentChange(_ change: PendingChange, type: PendingChange.ChangeType?) async throws {
        let entityId = change.entityId
        let descriptor = FetchDescriptor<LocalAppointment>(
            predicate: #Predicate { $0.id == entityId }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        switch type {
        case .create:
            let insert = AppointmentInsert(
                id: local.id,
                accountId: local.accountId,
                profileId: local.profileId,
                title: local.title,
                date: local.date,
                withProfileId: local.withProfileId,
                type: local.appointmentType,
                time: local.time,
                location: local.location,
                notes: local.notes,
                reminderOffsetMinutes: local.reminderOffsetMinutes
            )
            _ = try await appointmentRepository.createAppointment(insert)
        case .update:
            _ = try await appointmentRepository.updateAppointment(local.toRemote())
        case .delete:
            try await appointmentRepository.deleteAppointment(id: change.entityId)
        default:
            break
        }

        local.isSynced = true
    }

    private func pushContactChange(_ change: PendingChange, type: PendingChange.ChangeType?) async throws {
        let entityId = change.entityId
        let descriptor = FetchDescriptor<LocalUsefulContact>(
            predicate: #Predicate { $0.id == entityId }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        switch type {
        case .create:
            let insert = UsefulContactInsert(
                id: local.id,
                accountId: local.accountId,
                name: local.name,
                category: local.contactCategory,
                companyName: local.companyName,
                phone: local.phone,
                email: local.email,
                website: local.website,
                address: local.address,
                notes: local.notes,
                isFavourite: local.isFavourite
            )
            _ = try await usefulContactRepository.createContact(insert)
        case .update:
            _ = try await usefulContactRepository.updateContact(local.toRemote())
        case .delete:
            try await usefulContactRepository.deleteContact(id: change.entityId)
        default:
            break
        }

        local.isSynced = true
    }

    private func pushToDoListChange(_ change: PendingChange, type: PendingChange.ChangeType?) async throws {
        let entityId = change.entityId
        let descriptor = FetchDescriptor<LocalToDoList>(
            predicate: #Predicate { $0.id == entityId }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        switch type {
        case .create:
            _ = try await toDoRepository.createList(
                accountId: local.accountId,
                title: local.title,
                listType: local.listType
            )
        case .update:
            _ = try await toDoRepository.updateList(local.toRemote())
        case .delete:
            try await toDoRepository.deleteList(id: change.entityId)
        default:
            break
        }

        local.isSynced = true
    }

    private func pushToDoItemChange(_ change: PendingChange, type: PendingChange.ChangeType?) async throws {
        let entityId = change.entityId
        let descriptor = FetchDescriptor<LocalToDoItem>(
            predicate: #Predicate { $0.id == entityId }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        switch type {
        case .create:
            _ = try await toDoRepository.createItem(
                listId: local.listId,
                text: local.text,
                sortOrder: local.sortOrder
            )
        case .update:
            _ = try await toDoRepository.updateItem(local.toRemote())
        case .delete:
            try await toDoRepository.deleteItem(id: change.entityId)
        default:
            break
        }

        local.isSynced = true
    }

    private func pushCountdownChange(_ change: PendingChange, type: PendingChange.ChangeType?) async throws {
        let entityId = change.entityId
        let descriptor = FetchDescriptor<LocalCountdown>(
            predicate: #Predicate { $0.id == entityId }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        switch type {
        case .create:
            let insert = CountdownInsert(
                accountId: local.accountId,
                title: local.title,
                date: local.date,
                type: local.countdownType,
                customType: local.customType,
                notes: local.notes,
                reminderOffsetMinutes: local.reminderOffsetMinutes,
                isRecurring: local.isRecurring
            )
            _ = try await countdownRepository.createCountdown(insert)
        case .update:
            _ = try await countdownRepository.updateCountdown(local.toRemote())
        case .delete:
            try await countdownRepository.deleteCountdown(id: change.entityId)
        default:
            break
        }

        local.isSynced = true
    }

    private func pushStickyReminderChange(_ change: PendingChange, type: PendingChange.ChangeType?) async throws {
        let entityId = change.entityId
        let descriptor = FetchDescriptor<LocalStickyReminder>(
            predicate: #Predicate { $0.id == entityId }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        switch type {
        case .create:
            let insert = StickyReminderInsert(
                id: local.id,
                accountId: local.accountId,
                title: local.title,
                message: local.message,
                triggerTime: local.triggerTime,
                repeatInterval: local.decodedRepeatInterval,
                isActive: local.isActive
            )
            _ = try await stickyReminderRepository.createReminder(insert)
        case .update:
            _ = try await stickyReminderRepository.updateReminder(local.toRemote())
        case .delete:
            try await stickyReminderRepository.deleteReminder(id: change.entityId)
        default:
            break
        }

        local.isSynced = true
    }

    private func pushProfileDetailChange(_ change: PendingChange, type: PendingChange.ChangeType?) async throws {
        let entityId = change.entityId
        let descriptor = FetchDescriptor<LocalProfileDetail>(
            predicate: #Predicate { $0.id == entityId }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        // Decode metadata from local storage
        var metadataDict: [String: String]?
        if let metadataData = local.metadata {
            metadataDict = try? JSONDecoder().decode([String: String].self, from: metadataData)
        }

        switch type {
        case .create:
            let insert = ProfileDetailInsert(
                id: local.id,
                accountId: local.accountId,
                profileId: local.profileId,
                category: local.detailCategory,
                label: local.label,
                value: local.value,
                status: local.status,
                occasion: local.occasion,
                metadata: metadataDict
            )
            _ = try await profileRepository.createProfileDetail(insert)
        case .update:
            _ = try await profileRepository.updateProfileDetail(local.toRemote())
        case .delete:
            try await profileRepository.deleteProfileDetail(id: change.entityId)
        default:
            break
        }

        local.isSynced = true
    }

    // MARK: - Local Medication Log Generation
    /// Generate medication logs locally for today
    func generateLocalMedicationLogs(accountId: UUID) async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayOfWeek = calendar.component(.weekday, from: today) - 1  // 0-6

        // Fetch all active medications
        let medDescriptor = FetchDescriptor<LocalMedication>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted && !$0.isPaused }
        )
        let medications = try modelContext.fetch(medDescriptor)

        for medication in medications {
            // Get schedules for this medication
            let medicationId = medication.id
            let scheduleDescriptor = FetchDescriptor<LocalMedicationSchedule>(
                predicate: #Predicate { $0.medicationId == medicationId && !$0.locallyDeleted }
            )
            let schedules = try modelContext.fetch(scheduleDescriptor)

            for schedule in schedules {
                guard schedule.schedule == .scheduled else { continue }
                guard let entries = schedule.decodedScheduleEntries else { continue }

                for entry in entries {
                    // Check if this entry is active for today
                    guard entry.daysOfWeek.contains(dayOfWeek) else { continue }

                    // Parse time and create scheduled datetime
                    let timeComponents = entry.time.split(separator: ":")
                    guard timeComponents.count >= 2,
                          let hour = Int(timeComponents[0]),
                          let minute = Int(timeComponents[1]) else { continue }

                    var components = calendar.dateComponents([.year, .month, .day], from: today)
                    components.hour = hour
                    components.minute = minute

                    guard let scheduledAt = calendar.date(from: components) else { continue }

                    // Check if log already exists
                    let medIdForLog = medication.id
                    let scheduledAtForLog = scheduledAt
                    let logDescriptor = FetchDescriptor<LocalMedicationLog>(
                        predicate: #Predicate {
                            $0.medicationId == medIdForLog && $0.scheduledAt == scheduledAtForLog
                        }
                    )

                    let existingLogs = try modelContext.fetch(logDescriptor)

                    if existingLogs.isEmpty {
                        // Create new log
                        let newLog = LocalMedicationLog(
                            accountId: accountId,
                            medicationId: medication.id,
                            scheduledAt: scheduledAt,
                            status: "scheduled"
                        )
                        newLog.isSynced = false
                        modelContext.insert(newLog)
                    }
                }
            }
        }

        try modelContext.save()
    }

    // MARK: - Sync Metadata
    private func updateSyncMetadata(accountId: UUID) {
        // Update last sync timestamp for this account
        let descriptor = FetchDescriptor<SyncMetadata>(
            predicate: #Predicate { $0.accountId == accountId }
        )

        if let metadata = try? modelContext.fetch(descriptor) {
            for item in metadata {
                item.updateSyncTimestamp()
            }
        }

        try? modelContext.save()
    }

    // MARK: - Pending Changes Count
    private func updatePendingChangesCount() {
        let descriptor = FetchDescriptor<PendingChange>()
        pendingChangesCount = (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Queue Change
    /// Queue a pending change for later sync
    func queueChange(entityType: String, entityId: UUID, accountId: UUID, changeType: PendingChange.ChangeType) {
        let change = PendingChange(
            entityType: entityType,
            entityId: entityId,
            accountId: accountId,
            changeType: changeType.rawValue
        )
        modelContext.insert(change)
        try? modelContext.save()
        updatePendingChangesCount()

        // Attempt immediate sync if online
        if networkMonitor.isConnected {
            Task {
                await processPendingChanges()
            }
        }
    }
}
