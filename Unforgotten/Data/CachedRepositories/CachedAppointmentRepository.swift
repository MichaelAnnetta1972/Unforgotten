import SwiftUI
import SwiftData

// MARK: - Cached Appointment Repository
/// Provides offline-first access to Appointment data with background sync
@MainActor
final class CachedAppointmentRepository {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let remoteRepository: AppointmentRepository
    private let syncEngine: SyncEngine
    private let networkMonitor: NetworkMonitor

    // MARK: - Initialization
    init(modelContext: ModelContext, remoteRepository: AppointmentRepository, syncEngine: SyncEngine, networkMonitor: NetworkMonitor = .shared) {
        self.modelContext = modelContext
        self.remoteRepository = remoteRepository
        self.syncEngine = syncEngine
        self.networkMonitor = networkMonitor
    }

    // MARK: - Read Operations

    /// Force refresh appointments from remote server and update local cache
    /// Call this when receiving realtime change notifications or app becomes active
    func refreshFromRemote(accountId: UUID) async throws -> [Appointment] {
        guard networkMonitor.isConnected else {
            // If offline, return cached data
            return try await getAppointments(accountId: accountId)
        }

        // Fetch fresh data from server
        let remoteAppointments = try await remoteRepository.getAppointments(accountId: accountId)

        // Update local cache
        for remote in remoteAppointments {
            let remoteId = remote.id
            let existingDescriptor = FetchDescriptor<LocalAppointment>(
                predicate: #Predicate { $0.id == remoteId }
            )

            if let existing = try modelContext.fetch(existingDescriptor).first {
                // Update existing
                existing.update(from: remote)
            } else {
                // Insert new
                let local = LocalAppointment(from: remote)
                modelContext.insert(local)
            }
        }

        // Remove locally cached items that no longer exist on server
        let remoteIds = Set(remoteAppointments.map { $0.id })
        let localDescriptor = FetchDescriptor<LocalAppointment>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted }
        )
        let localAppointments = try modelContext.fetch(localDescriptor)

        for local in localAppointments {
            if !remoteIds.contains(local.id) && local.isSynced {
                // This item was deleted on server, remove from local cache
                modelContext.delete(local)
            }
        }

        try? modelContext.save()
        return remoteAppointments
    }

    /// Get all appointments for an account, falling back to network if cache is empty
    func getAppointments(accountId: UUID) async throws -> [Appointment] {
        let descriptor = FetchDescriptor<LocalAppointment>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalAppointment>(\.date), SortDescriptor<LocalAppointment>(\.time)]
        )

        let localAppointments = try modelContext.fetch(descriptor)

        // If cache is empty and we're online, fetch from network and cache
        if localAppointments.isEmpty && networkMonitor.isConnected {
            let remoteAppointments = try await remoteRepository.getAppointments(accountId: accountId)
            for remote in remoteAppointments {
                // Check if already exists to avoid duplicates
                let remoteId = remote.id
                let existingDescriptor = FetchDescriptor<LocalAppointment>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                if try modelContext.fetch(existingDescriptor).isEmpty {
                    let local = LocalAppointment(from: remote)
                    modelContext.insert(local)
                }
            }
            try? modelContext.save()
            return remoteAppointments
        }

        return localAppointments.map { (local: LocalAppointment) in local.toRemote() }
    }

    /// Get appointments for a specific profile
    func getAppointments(profileId: UUID) async throws -> [Appointment] {
        let descriptor = FetchDescriptor<LocalAppointment>(
            predicate: #Predicate { $0.profileId == profileId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalAppointment>(\.date), SortDescriptor<LocalAppointment>(\.time)]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalAppointment) in local.toRemote() }
    }

    /// Get today's appointments
    func getTodaysAppointments(accountId: UUID) async throws -> [Appointment] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<LocalAppointment>(
            predicate: #Predicate {
                $0.accountId == accountId &&
                $0.date >= startOfDay &&
                $0.date < endOfDay &&
                !$0.locallyDeleted
            },
            sortBy: [SortDescriptor<LocalAppointment>(\.time)]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalAppointment) in local.toRemote() }
    }

    /// Get a specific appointment by ID
    func getAppointment(id: UUID) async throws -> Appointment? {
        let descriptor = FetchDescriptor<LocalAppointment>(
            predicate: #Predicate { $0.id == id && !$0.locallyDeleted }
        )

        return try modelContext.fetch(descriptor).first?.toRemote()
    }

    /// Get upcoming appointments
    func getUpcomingAppointments(accountId: UUID, days: Int = 30) async throws -> [Appointment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let futureDate = calendar.date(byAdding: .day, value: days, to: today)!

        let descriptor = FetchDescriptor<LocalAppointment>(
            predicate: #Predicate {
                $0.accountId == accountId &&
                $0.date >= today &&
                $0.date < futureDate &&
                !$0.isCompleted &&
                !$0.locallyDeleted
            },
            sortBy: [SortDescriptor<LocalAppointment>(\.date), SortDescriptor<LocalAppointment>(\.time)]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalAppointment) in local.toRemote() }
    }

    /// Get appointments in a date range
    func getAppointmentsInRange(accountId: UUID, startDate: Date, endDate: Date) async throws -> [Appointment] {
        let descriptor = FetchDescriptor<LocalAppointment>(
            predicate: #Predicate {
                $0.accountId == accountId &&
                $0.date >= startDate &&
                $0.date <= endDate &&
                !$0.locallyDeleted
            },
            sortBy: [SortDescriptor<LocalAppointment>(\.date), SortDescriptor<LocalAppointment>(\.time)]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalAppointment) in local.toRemote() }
    }

    // MARK: - Get Appointments By IDs (for shared events from other accounts)
    func getAppointmentsByIds(_ ids: [UUID]) async throws -> [Appointment] {
        guard !ids.isEmpty else { return [] }
        return try await remoteRepository.getAppointmentsByIds(ids)
    }

    // MARK: - Get Shared Appointments (via RPC, bypasses RLS)
    func getSharedAppointments() async throws -> [Appointment] {
        return try await remoteRepository.getSharedAppointments()
    }

    // MARK: - Write Operations

    /// Create a new appointment from an AppointmentInsert struct
    func createAppointment(_ insert: AppointmentInsert) async throws -> Appointment {
        return try await createAppointment(
            accountId: insert.accountId,
            profileId: insert.profileId,
            type: insert.type,
            title: insert.title,
            date: insert.date,
            time: insert.time,
            location: insert.location,
            notes: insert.notes,
            reminderOffsetMinutes: insert.reminderOffsetMinutes,
            repeatInterval: insert.repeatInterval,
            repeatUnit: insert.repeatUnit
        )
    }

    /// Create a new appointment with individual parameters
    func createAppointment(
        accountId: UUID,
        profileId: UUID,
        type: AppointmentType,
        title: String,
        date: Date,
        time: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        reminderOffsetMinutes: Int? = nil,
        repeatInterval: Int? = nil,
        repeatUnit: String? = nil
    ) async throws -> Appointment {
        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let insert = AppointmentInsert(
                    accountId: accountId,
                    profileId: profileId,
                    title: title,
                    date: date,
                    type: type,
                    time: time,
                    location: location,
                    notes: notes,
                    reminderOffsetMinutes: reminderOffsetMinutes,
                    repeatInterval: repeatInterval,
                    repeatUnit: repeatUnit
                )
                let remote = try await remoteRepository.createAppointment(insert)
                let local = LocalAppointment(from: remote)
                modelContext.insert(local)
                try? modelContext.save()
                return remote
            } catch {
                print("[CachedAppointmentRepo] Remote createAppointment failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: create locally and queue for sync
        let local = LocalAppointment(
            id: UUID(),
            accountId: accountId,
            profileId: profileId,
            type: type.rawValue,
            title: title,
            date: date,
            time: time,
            location: location,
            notes: notes,
            reminderOffsetMinutes: reminderOffsetMinutes,
            repeatInterval: repeatInterval,
            repeatUnit: repeatUnit,
            isSynced: false
        )
        modelContext.insert(local)

        syncEngine.queueChange(
            entityType: "appointment",
            entityId: local.id,
            accountId: accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Create an appointment on Supabase first, then cache locally.
    /// Use this when the appointment will be shared immediately after creation,
    /// since the share references the event_id which must exist in Supabase.
    func createAppointmentRemoteFirst(_ insert: AppointmentInsert) async throws -> Appointment {
        let remote = try await remoteRepository.createAppointment(insert)

        let local = LocalAppointment(from: remote)
        modelContext.insert(local)
        try? modelContext.save()

        return remote
    }

    /// Update an appointment
    func updateAppointment(_ appointment: Appointment) async throws -> Appointment {
        let appointmentId = appointment.id
        let descriptor = FetchDescriptor<LocalAppointment>(
            predicate: #Predicate { $0.id == appointmentId }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        local.type = appointment.type.rawValue
        local.title = appointment.title
        local.date = appointment.date
        local.time = appointment.time
        local.location = appointment.location
        local.notes = appointment.notes
        local.imageUrl = appointment.imageUrl
        local.reminderOffsetMinutes = appointment.reminderOffsetMinutes
        local.repeatInterval = appointment.repeatInterval
        local.repeatUnit = appointment.repeatUnit
        local.isCompleted = appointment.isCompleted
        local.withProfileId = appointment.withProfileId
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let updated = try await remoteRepository.updateAppointment(appointment)
                local.isSynced = true
                try modelContext.save()
                return updated
            } catch {
                print("[CachedAppointmentRepo] Remote updateAppointment failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "appointment",
            entityId: appointment.id,
            accountId: appointment.accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Toggle appointment completion
    func toggleAppointmentCompletion(id: UUID, isCompleted: Bool) async throws -> Appointment {
        let descriptor = FetchDescriptor<LocalAppointment>(
            predicate: #Predicate { $0.id == id }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        local.isCompleted = isCompleted
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                var updated = local.toRemote()
                updated = try await remoteRepository.updateAppointment(updated)
                local.isSynced = true
                try modelContext.save()
                return updated
            } catch {
                print("[CachedAppointmentRepo] Remote toggleCompletion failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "appointment",
            entityId: id,
            accountId: local.accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Delete an appointment
    func deleteAppointment(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalAppointment>(
            predicate: #Predicate { $0.id == id }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        local.locallyDeleted = true
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.deleteAppointment(id: id)
                local.isSynced = true
                try modelContext.save()
                return
            } catch {
                print("[CachedAppointmentRepo] Remote deleteAppointment failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "appointment",
            entityId: id,
            accountId: local.accountId,
            changeType: .delete
        )

        try modelContext.save()
    }
}
