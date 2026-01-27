import SwiftUI
import SwiftData

// MARK: - Cached Countdown Repository
/// Provides offline-first access to Countdown data with background sync
@MainActor
final class CachedCountdownRepository {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let remoteRepository: CountdownRepository
    private let syncEngine: SyncEngine
    private let networkMonitor: NetworkMonitor

    // MARK: - Initialization
    init(modelContext: ModelContext, remoteRepository: CountdownRepository, syncEngine: SyncEngine, networkMonitor: NetworkMonitor = .shared) {
        self.modelContext = modelContext
        self.remoteRepository = remoteRepository
        self.syncEngine = syncEngine
        self.networkMonitor = networkMonitor
    }

    // MARK: - Read Operations

    /// Force refresh countdowns from remote server and update local cache
    /// Call this when receiving realtime change notifications
    func refreshFromRemote(accountId: UUID) async throws -> [Countdown] {
        guard networkMonitor.isConnected else {
            // If offline, return cached data
            return try await getCountdowns(accountId: accountId)
        }

        // Fetch fresh data from server
        let remoteCountdowns = try await remoteRepository.getCountdowns(accountId: accountId)

        // Update local cache
        for remote in remoteCountdowns {
            let remoteId = remote.id
            let existingDescriptor = FetchDescriptor<LocalCountdown>(
                predicate: #Predicate { $0.id == remoteId }
            )

            if let existing = try modelContext.fetch(existingDescriptor).first {
                // Update existing
                existing.update(from: remote)
            } else {
                // Insert new
                let local = LocalCountdown(from: remote)
                modelContext.insert(local)
            }
        }

        // Remove locally cached items that no longer exist on server
        let remoteIds = Set(remoteCountdowns.map { $0.id })
        let localDescriptor = FetchDescriptor<LocalCountdown>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted }
        )
        let localCountdowns = try modelContext.fetch(localDescriptor)

        for local in localCountdowns {
            if !remoteIds.contains(local.id) && local.isSynced {
                // This item was deleted on server, remove from local cache
                modelContext.delete(local)
            }
        }

        try? modelContext.save()
        return remoteCountdowns
    }

    /// Get all countdowns for an account, falling back to network if cache is empty
    func getCountdowns(accountId: UUID) async throws -> [Countdown] {
        let descriptor = FetchDescriptor<LocalCountdown>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalCountdown>(\.date)]
        )

        let localCountdowns = try modelContext.fetch(descriptor)

        // If cache is empty and we're online, fetch from network and cache
        if localCountdowns.isEmpty && networkMonitor.isConnected {
            let remoteCountdowns = try await remoteRepository.getCountdowns(accountId: accountId)
            for remote in remoteCountdowns {
                // Check if already exists to avoid duplicates
                let remoteId = remote.id
                let existingDescriptor = FetchDescriptor<LocalCountdown>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                if try modelContext.fetch(existingDescriptor).isEmpty {
                    let local = LocalCountdown(from: remote)
                    modelContext.insert(local)
                }
            }
            try? modelContext.save()
            return remoteCountdowns
        }

        return localCountdowns.map { (local: LocalCountdown) in local.toRemote() }
    }

    /// Get upcoming countdowns
    func getUpcomingCountdowns(accountId: UUID, days: Int = 30) async throws -> [Countdown] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let futureDate = calendar.date(byAdding: .day, value: days, to: today)!

        let descriptor = FetchDescriptor<LocalCountdown>(
            predicate: #Predicate {
                $0.accountId == accountId &&
                ($0.date >= today || $0.isRecurring) &&
                !$0.locallyDeleted
            },
            sortBy: [SortDescriptor<LocalCountdown>(\.date)]
        )

        let countdowns = try modelContext.fetch(descriptor)

        // Filter by days until next occurrence
        return countdowns
            .filter { $0.daysUntilNextOccurrence <= days }
            .map { (local: LocalCountdown) in local.toRemote() }
    }

    // MARK: - Write Operations

    /// Create a new countdown from a CountdownInsert struct
    func createCountdown(_ insert: CountdownInsert) async throws -> Countdown {
        return try await createCountdown(
            accountId: insert.accountId,
            title: insert.title,
            date: insert.date,
            type: insert.type,
            customType: insert.customType,
            notes: insert.notes,
            reminderOffsetMinutes: insert.reminderOffsetMinutes,
            isRecurring: insert.isRecurring
        )
    }

    /// Create a new countdown with individual parameters
    func createCountdown(
        accountId: UUID,
        title: String,
        date: Date,
        type: CountdownType = .countdown,
        customType: String? = nil,
        notes: String? = nil,
        reminderOffsetMinutes: Int? = nil,
        isRecurring: Bool = false
    ) async throws -> Countdown {
        let local = LocalCountdown(
            id: UUID(),
            accountId: accountId,
            title: title,
            date: date,
            type: type.rawValue,
            customType: customType,
            notes: notes,
            reminderOffsetMinutes: reminderOffsetMinutes,
            isRecurring: isRecurring,
            isSynced: false
        )
        modelContext.insert(local)

        syncEngine.queueChange(
            entityType: "countdown",
            entityId: local.id,
            accountId: accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update a countdown
    func updateCountdown(_ countdown: Countdown) async throws -> Countdown {
        let countdownId = countdown.id
        let descriptor = FetchDescriptor<LocalCountdown>(
            predicate: #Predicate { $0.id == countdownId }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.title = countdown.title
            local.date = countdown.date
            local.type = countdown.type.rawValue
            local.customType = countdown.customType
            local.notes = countdown.notes
            local.reminderOffsetMinutes = countdown.reminderOffsetMinutes
            local.isRecurring = countdown.isRecurring
            local.markAsModified()

            syncEngine.queueChange(
                entityType: "countdown",
                entityId: countdown.id,
                accountId: countdown.accountId,
                changeType: .update
            )

            try modelContext.save()
            return local.toRemote()
        }

        throw SupabaseError.notFound
    }

    /// Delete a countdown
    func deleteCountdown(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalCountdown>(
            predicate: #Predicate { $0.id == id }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.locallyDeleted = true
            local.markAsModified()

            syncEngine.queueChange(
                entityType: "countdown",
                entityId: id,
                accountId: local.accountId,
                changeType: .delete
            )

            try modelContext.save()
        }
    }
}
