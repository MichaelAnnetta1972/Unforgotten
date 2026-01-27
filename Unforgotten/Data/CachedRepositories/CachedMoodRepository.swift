import SwiftUI
import SwiftData

// MARK: - Cached Mood Repository
/// Provides offline-first access to MoodEntry data with background sync
@MainActor
final class CachedMoodRepository {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let remoteRepository: MoodRepository
    private let syncEngine: SyncEngine
    private let networkMonitor: NetworkMonitor

    // MARK: - Initialization
    init(modelContext: ModelContext, remoteRepository: MoodRepository, syncEngine: SyncEngine, networkMonitor: NetworkMonitor = .shared) {
        self.modelContext = modelContext
        self.remoteRepository = remoteRepository
        self.syncEngine = syncEngine
        self.networkMonitor = networkMonitor
    }

    // MARK: - Read Operations

    /// Get today's mood entry
    func getTodaysEntry(accountId: UUID, userId: UUID) async throws -> MoodEntry? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<LocalMoodEntry>(
            predicate: #Predicate {
                $0.accountId == accountId &&
                $0.userId == userId &&
                $0.date >= startOfDay &&
                $0.date < endOfDay &&
                !$0.locallyDeleted
            }
        )

        let localEntry = try modelContext.fetch(descriptor).first

        // If no local entry and we're online, check remote
        if localEntry == nil && networkMonitor.isConnected {
            if let remoteEntry = try await remoteRepository.getTodaysEntry(accountId: accountId, userId: userId) {
                // Check if already exists to avoid duplicates
                let remoteId = remoteEntry.id
                let existingDescriptor = FetchDescriptor<LocalMoodEntry>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                if try modelContext.fetch(existingDescriptor).isEmpty {
                    let local = LocalMoodEntry(from: remoteEntry)
                    modelContext.insert(local)
                    try? modelContext.save()
                }
                return remoteEntry
            }
        }

        return localEntry?.toRemote()
    }

    /// Get mood entries in a date range (matches remote repository signature)
    func getEntries(accountId: UUID, from startDate: Date, to endDate: Date) async throws -> [MoodEntry] {
        let descriptor = FetchDescriptor<LocalMoodEntry>(
            predicate: #Predicate {
                $0.accountId == accountId &&
                $0.date >= startDate &&
                $0.date < endDate &&
                !$0.locallyDeleted
            },
            sortBy: [SortDescriptor<LocalMoodEntry>(\.date, order: .reverse)]
        )

        let localEntries = try modelContext.fetch(descriptor)

        // If cache is empty and we're online, fetch from network and cache
        if localEntries.isEmpty && networkMonitor.isConnected {
            let remoteEntries = try await remoteRepository.getEntries(accountId: accountId, from: startDate, to: endDate)
            for remote in remoteEntries {
                // Check if already exists to avoid duplicates
                let remoteId = remote.id
                let existingDescriptor = FetchDescriptor<LocalMoodEntry>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                if try modelContext.fetch(existingDescriptor).isEmpty {
                    let local = LocalMoodEntry(from: remote)
                    modelContext.insert(local)
                }
            }
            try? modelContext.save()
            return remoteEntries
        }

        return localEntries.map { (local: LocalMoodEntry) in local.toRemote() }
    }

    // MARK: - Write Operations

    /// Create a new mood entry
    func createEntry(_ insert: MoodEntryInsert) async throws -> MoodEntry {
        let local = LocalMoodEntry(
            id: UUID(),
            accountId: insert.accountId,
            userId: insert.userId,
            date: insert.date,
            rating: insert.rating,
            note: insert.note,
            isSynced: false
        )
        modelContext.insert(local)

        syncEngine.queueChange(
            entityType: "moodEntry",
            entityId: local.id,
            accountId: insert.accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update a mood entry
    func updateEntry(id: UUID, rating: Int, note: String?) async throws -> MoodEntry {
        let descriptor = FetchDescriptor<LocalMoodEntry>(
            predicate: #Predicate { $0.id == id }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.rating = rating
            local.note = note
            local.markAsModified()

            syncEngine.queueChange(
                entityType: "moodEntry",
                entityId: id,
                accountId: local.accountId,
                changeType: .update
            )

            try modelContext.save()
            return local.toRemote()
        }

        throw SupabaseError.notFound
    }
}
