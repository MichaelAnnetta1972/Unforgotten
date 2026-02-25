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

    // MARK: - Get Countdowns By IDs (for shared events from other accounts)
    func getCountdownsByIds(_ ids: [UUID]) async throws -> [Countdown] {
        guard !ids.isEmpty else { return [] }
        return try await remoteRepository.getCountdownsByIds(ids)
    }

    // MARK: - Get Shared Countdowns (via RPC, bypasses RLS)
    func getSharedCountdowns() async throws -> [Countdown] {
        return try await remoteRepository.getSharedCountdowns()
    }

    // MARK: - Get Countdowns By Group ID
    func getCountdownsByGroupId(_ groupId: UUID) async throws -> [Countdown] {
        // Try local first
        let descriptor = FetchDescriptor<LocalCountdown>(
            predicate: #Predicate { $0.groupId == groupId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalCountdown>(\.date)]
        )
        let localCountdowns = try modelContext.fetch(descriptor)

        if !localCountdowns.isEmpty {
            return localCountdowns.map { $0.toRemote() }
        }

        // Fallback to remote
        if networkMonitor.isConnected {
            return try await remoteRepository.getCountdownsByGroupId(groupId)
        }

        return []
    }

    // MARK: - Write Operations

    /// Create a new countdown from a CountdownInsert struct
    func createCountdown(_ insert: CountdownInsert) async throws -> Countdown {
        return try await createCountdown(
            accountId: insert.accountId,
            title: insert.title,
            subtitle: insert.subtitle,
            date: insert.date,
            endDate: insert.endDate,
            hasTime: insert.hasTime,
            type: insert.type,
            customType: insert.customType,
            notes: insert.notes,
            imageUrl: insert.imageUrl,
            groupId: insert.groupId,
            reminderOffsetMinutes: insert.reminderOffsetMinutes,
            isRecurring: insert.isRecurring
        )
    }

    /// Create a new countdown with individual parameters
    func createCountdown(
        accountId: UUID,
        title: String,
        subtitle: String? = nil,
        date: Date,
        endDate: Date? = nil,
        hasTime: Bool = false,
        type: CountdownType = .countdown,
        customType: String? = nil,
        notes: String? = nil,
        imageUrl: String? = nil,
        groupId: UUID? = nil,
        reminderOffsetMinutes: Int? = nil,
        isRecurring: Bool = false
    ) async throws -> Countdown {
        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let insert = CountdownInsert(
                    accountId: accountId,
                    title: title,
                    subtitle: subtitle,
                    date: date,
                    endDate: endDate,
                    hasTime: hasTime,
                    type: type,
                    customType: customType,
                    notes: notes,
                    imageUrl: imageUrl,
                    groupId: groupId,
                    reminderOffsetMinutes: reminderOffsetMinutes,
                    isRecurring: isRecurring
                )
                let remote = try await remoteRepository.createCountdown(insert)
                let local = LocalCountdown(from: remote)
                modelContext.insert(local)
                try? modelContext.save()
                return remote
            } catch {
                print("[CachedCountdownRepo] Remote createCountdown failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: create locally and queue for sync
        let local = LocalCountdown(
            id: UUID(),
            accountId: accountId,
            title: title,
            subtitle: subtitle,
            date: date,
            endDate: endDate,
            hasTime: hasTime,
            type: type.rawValue,
            customType: customType,
            notes: notes,
            imageUrl: imageUrl,
            groupId: groupId,
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

    /// Create a countdown on Supabase first, then cache locally.
    /// Use this when the countdown will be shared immediately after creation,
    /// since the share references the event_id which must exist in Supabase.
    func createCountdownRemoteFirst(_ insert: CountdownInsert) async throws -> Countdown {
        // Create on Supabase first to get the server-assigned ID
        let remote = try await remoteRepository.createCountdown(insert)

        // Cache locally with the same ID (already synced)
        let local = LocalCountdown(from: remote)
        modelContext.insert(local)
        try? modelContext.save()

        return remote
    }

    /// Create multiple countdowns for a multi-day event, one record per day
    func createMultiDayCountdowns(
        accountId: UUID,
        title: String,
        startDate: Date,
        endDate: Date,
        hasTime: Bool,
        type: CountdownType,
        customType: String?,
        notes: String?,
        imageUrl: String?,
        reminderOffsetMinutes: Int?,
        isRecurring: Bool,
        useRemoteFirst: Bool = false
    ) async throws -> [Countdown] {
        let groupId = UUID()
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        var createdCountdowns: [Countdown] = []
        var currentDay = startDay

        while currentDay <= endDay {
            // Preserve time from start date if hasTime is true
            var dayDate = currentDay
            if hasTime {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: startDate)
                dayDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: currentDay) ?? currentDay
            }

            let insert = CountdownInsert(
                accountId: accountId,
                title: title,
                date: dayDate,
                hasTime: hasTime,
                type: type,
                customType: customType,
                notes: notes,
                imageUrl: imageUrl,
                groupId: groupId,
                reminderOffsetMinutes: currentDay == startDay ? reminderOffsetMinutes : nil,
                isRecurring: isRecurring
            )

            let countdown: Countdown
            if useRemoteFirst {
                countdown = try await createCountdownRemoteFirst(insert)
            } else {
                countdown = try await createCountdown(insert)
            }
            createdCountdowns.append(countdown)

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }

        return createdCountdowns
    }

    /// Update a countdown
    func updateCountdown(_ countdown: Countdown) async throws -> Countdown {
        let countdownId = countdown.id
        let descriptor = FetchDescriptor<LocalCountdown>(
            predicate: #Predicate { $0.id == countdownId }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        local.title = countdown.title
        local.subtitle = countdown.subtitle
        local.date = countdown.date
        local.endDate = countdown.endDate
        local.hasTime = countdown.hasTime
        local.type = countdown.type.rawValue
        local.customType = countdown.customType
        local.notes = countdown.notes
        local.imageUrl = countdown.imageUrl
        local.groupId = countdown.groupId
        local.reminderOffsetMinutes = countdown.reminderOffsetMinutes
        local.isRecurring = countdown.isRecurring
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let updated = try await remoteRepository.updateCountdown(countdown)
                local.isSynced = true
                try modelContext.save()
                return updated
            } catch {
                print("[CachedCountdownRepo] Remote updateCountdown failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "countdown",
            entityId: countdown.id,
            accountId: countdown.accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Delete a countdown
    func deleteCountdown(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalCountdown>(
            predicate: #Predicate { $0.id == id }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        local.locallyDeleted = true
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.deleteCountdown(id: id)
                local.isSynced = true
                try modelContext.save()
                return
            } catch {
                print("[CachedCountdownRepo] Remote deleteCountdown failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "countdown",
            entityId: id,
            accountId: local.accountId,
            changeType: .delete
        )

        try modelContext.save()
    }

    /// Delete all countdowns in a group
    func deleteCountdownsByGroupId(_ groupId: UUID) async throws {
        let descriptor = FetchDescriptor<LocalCountdown>(
            predicate: #Predicate { $0.groupId == groupId && !$0.locallyDeleted }
        )
        let locals = try modelContext.fetch(descriptor)

        for local in locals {
            local.locallyDeleted = true
            local.markAsModified()
        }

        if networkMonitor.isConnected {
            do {
                try await remoteRepository.deleteCountdownsByGroupId(groupId)
                for local in locals {
                    local.isSynced = true
                }
                try modelContext.save()
                return
            } catch {
                print("[CachedCountdownRepo] Remote deleteCountdownsByGroupId failed: \(error). Saving locally.")
            }
        }

        for local in locals {
            syncEngine.queueChange(
                entityType: "countdown",
                entityId: local.id,
                accountId: local.accountId,
                changeType: .delete
            )
        }

        try modelContext.save()
    }

    /// Update shared fields across all countdowns in a group
    func updateCountdownGroupFields(_ groupId: UUID, update: CountdownGroupUpdate) async throws -> [Countdown] {
        // Update local records
        let descriptor = FetchDescriptor<LocalCountdown>(
            predicate: #Predicate { $0.groupId == groupId && !$0.locallyDeleted }
        )
        let locals = try modelContext.fetch(descriptor)

        for local in locals {
            local.title = update.title
            local.hasTime = update.hasTime
            local.type = update.type.rawValue
            local.customType = update.customType
            local.notes = update.notes
            local.imageUrl = update.imageUrl
            local.reminderOffsetMinutes = update.reminderOffsetMinutes
            local.isRecurring = update.isRecurring
            local.markAsModified()
        }

        if networkMonitor.isConnected {
            do {
                let updated = try await remoteRepository.updateCountdownGroupFields(groupId, update: update)
                for local in locals {
                    local.isSynced = true
                }
                try modelContext.save()
                return updated
            } catch {
                print("[CachedCountdownRepo] Remote updateCountdownGroupFields failed: \(error). Saving locally.")
            }
        }

        for local in locals {
            syncEngine.queueChange(
                entityType: "countdown",
                entityId: local.id,
                accountId: local.accountId,
                changeType: .update
            )
        }

        try modelContext.save()
        return locals.map { $0.toRemote() }
    }
}
