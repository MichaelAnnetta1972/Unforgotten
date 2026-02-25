import SwiftUI
import SwiftData

// MARK: - Cached Sticky Reminder Repository
/// Provides offline-first access to StickyReminder data with background sync
@MainActor
final class CachedStickyReminderRepository {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let remoteRepository: StickyReminderRepository
    private let syncEngine: SyncEngine
    private let networkMonitor: NetworkMonitor

    // MARK: - Initialization
    init(modelContext: ModelContext, remoteRepository: StickyReminderRepository, syncEngine: SyncEngine, networkMonitor: NetworkMonitor = .shared) {
        self.modelContext = modelContext
        self.remoteRepository = remoteRepository
        self.syncEngine = syncEngine
        self.networkMonitor = networkMonitor
    }

    // MARK: - Read Operations

    /// Force refresh reminders from remote server and update local cache
    /// Call this when receiving realtime change notifications or app becomes active
    func refreshFromRemote(accountId: UUID) async throws -> [StickyReminder] {
        guard networkMonitor.isConnected else {
            // If offline, return cached data
            return try await getReminders(accountId: accountId)
        }

        // Fetch fresh data from server
        let remoteReminders = try await remoteRepository.getReminders(accountId: accountId)

        // Update local cache
        for remote in remoteReminders {
            let remoteId = remote.id
            let existingDescriptor = FetchDescriptor<LocalStickyReminder>(
                predicate: #Predicate { $0.id == remoteId }
            )

            if let existing = try modelContext.fetch(existingDescriptor).first {
                // Update existing
                existing.update(from: remote)
            } else {
                // Insert new
                let local = LocalStickyReminder(from: remote)
                modelContext.insert(local)
            }
        }

        // Remove locally cached items that no longer exist on server
        let remoteIds = Set(remoteReminders.map { $0.id })
        let localDescriptor = FetchDescriptor<LocalStickyReminder>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted }
        )
        let localReminders = try modelContext.fetch(localDescriptor)

        for local in localReminders {
            if !remoteIds.contains(local.id) && local.isSynced {
                // This item was deleted on server, remove from local cache
                modelContext.delete(local)
            }
        }

        try? modelContext.save()
        return remoteReminders
    }

    /// Get all reminders for an account, falling back to network if cache is empty
    func getReminders(accountId: UUID) async throws -> [StickyReminder] {
        let descriptor = FetchDescriptor<LocalStickyReminder>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalStickyReminder>(\.sortOrder), SortDescriptor<LocalStickyReminder>(\.triggerTime)]
        )

        let localReminders = try modelContext.fetch(descriptor)

        // If cache is empty and we're online, fetch from network and cache
        if localReminders.isEmpty && networkMonitor.isConnected {
            let remoteReminders = try await remoteRepository.getReminders(accountId: accountId)
            for remote in remoteReminders {
                // Check if already exists to avoid duplicates
                let remoteId = remote.id
                let existingDescriptor = FetchDescriptor<LocalStickyReminder>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                if try modelContext.fetch(existingDescriptor).isEmpty {
                    let local = LocalStickyReminder(from: remote)
                    modelContext.insert(local)
                }
            }
            try? modelContext.save()
            return remoteReminders
        }

        return localReminders.map { (local: LocalStickyReminder) in local.toRemote() }
    }

    /// Get active (not dismissed) reminders
    func getActiveReminders(accountId: UUID) async throws -> [StickyReminder] {
        let descriptor = FetchDescriptor<LocalStickyReminder>(
            predicate: #Predicate {
                $0.accountId == accountId &&
                $0.isActive &&
                !$0.isDismissed &&
                !$0.locallyDeleted
            },
            sortBy: [SortDescriptor<LocalStickyReminder>(\.sortOrder), SortDescriptor<LocalStickyReminder>(\.triggerTime)]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalStickyReminder) in local.toRemote() }
    }

    // MARK: - Write Operations

    /// Create a new reminder from a StickyReminderInsert struct
    func createReminder(_ insert: StickyReminderInsert) async throws -> StickyReminder {
        return try await createReminder(
            accountId: insert.accountId,
            title: insert.title,
            message: insert.message,
            triggerTime: insert.triggerTime,
            repeatInterval: insert.repeatInterval
        )
    }

    /// Create a new reminder with individual parameters
    func createReminder(
        accountId: UUID,
        title: String,
        message: String? = nil,
        triggerTime: Date,
        repeatInterval: StickyReminderInterval = .everyHour
    ) async throws -> StickyReminder {
        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let insert = StickyReminderInsert(
                    accountId: accountId,
                    title: title,
                    message: message,
                    triggerTime: triggerTime,
                    repeatInterval: repeatInterval
                )
                let remote = try await remoteRepository.createReminder(insert)
                let local = LocalStickyReminder(from: remote)
                modelContext.insert(local)
                try? modelContext.save()
                return remote
            } catch {
                print("[CachedStickyReminderRepo] Remote createReminder failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: create locally and queue for sync
        let local = LocalStickyReminder(
            id: UUID(),
            accountId: accountId,
            title: title,
            message: message,
            triggerTime: triggerTime,
            repeatInterval: "\(repeatInterval.value)_\(repeatInterval.unit.rawValue)",
            isSynced: false
        )
        modelContext.insert(local)

        syncEngine.queueChange(
            entityType: "stickyReminder",
            entityId: local.id,
            accountId: accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update a reminder
    func updateReminder(_ reminder: StickyReminder) async throws -> StickyReminder {
        let reminderId = reminder.id
        let descriptor = FetchDescriptor<LocalStickyReminder>(
            predicate: #Predicate { $0.id == reminderId }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        local.title = reminder.title
        local.message = reminder.message
        local.triggerTime = reminder.triggerTime
        local.repeatInterval = "\(reminder.repeatInterval.value)_\(reminder.repeatInterval.unit.rawValue)"
        local.isActive = reminder.isActive
        local.isDismissed = reminder.isDismissed
        local.lastNotifiedAt = reminder.lastNotifiedAt
        local.sortOrder = reminder.sortOrder
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let updated = try await remoteRepository.updateReminder(reminder)
                local.isSynced = true
                try modelContext.save()
                return updated
            } catch {
                print("[CachedStickyReminderRepo] Remote updateReminder failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "stickyReminder",
            entityId: reminder.id,
            accountId: reminder.accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Dismiss a reminder
    func dismissReminder(id: UUID) async throws -> StickyReminder {
        let descriptor = FetchDescriptor<LocalStickyReminder>(
            predicate: #Predicate { $0.id == id }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        local.isDismissed = true
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let updated = try await remoteRepository.updateReminder(local.toRemote())
                local.isSynced = true
                try modelContext.save()
                return updated
            } catch {
                print("[CachedStickyReminderRepo] Remote dismissReminder failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "stickyReminder",
            entityId: id,
            accountId: local.accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Reactivate a dismissed reminder
    func reactivateReminder(id: UUID) async throws -> StickyReminder {
        let descriptor = FetchDescriptor<LocalStickyReminder>(
            predicate: #Predicate { $0.id == id }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        local.isDismissed = false
        local.isActive = true
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let updated = try await remoteRepository.updateReminder(local.toRemote())
                local.isSynced = true
                try modelContext.save()
                return updated
            } catch {
                print("[CachedStickyReminderRepo] Remote reactivateReminder failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "stickyReminder",
            entityId: id,
            accountId: local.accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Delete a reminder
    func deleteReminder(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalStickyReminder>(
            predicate: #Predicate { $0.id == id }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        local.locallyDeleted = true
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.deleteReminder(id: id)
                local.isSynced = true
                try modelContext.save()
                return
            } catch {
                print("[CachedStickyReminderRepo] Remote deleteReminder failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "stickyReminder",
            entityId: id,
            accountId: local.accountId,
            changeType: .delete
        )

        try modelContext.save()
    }
}
