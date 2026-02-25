import SwiftUI
import SwiftData

// MARK: - Cached ToDo Repository
/// Provides offline-first access to ToDoList and ToDoItem data with background sync
@MainActor
final class CachedToDoRepository {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let remoteRepository: ToDoRepository
    private let syncEngine: SyncEngine
    private let networkMonitor: NetworkMonitor

    // MARK: - Initialization
    init(modelContext: ModelContext, remoteRepository: ToDoRepository, syncEngine: SyncEngine, networkMonitor: NetworkMonitor = .shared) {
        self.modelContext = modelContext
        self.remoteRepository = remoteRepository
        self.syncEngine = syncEngine
        self.networkMonitor = networkMonitor
    }

    // MARK: - List Read Operations

    /// Get all lists for an account, falling back to network if cache is empty
    func getLists(accountId: UUID) async throws -> [ToDoList] {
        let listDescriptor = FetchDescriptor<LocalToDoList>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalToDoList>(\.createdAt, order: .reverse)]
        )

        let localLists = try modelContext.fetch(listDescriptor)

        // If cache is empty and we're online, fetch from network and cache
        if localLists.isEmpty && networkMonitor.isConnected {
            let remoteLists = try await remoteRepository.getLists(accountId: accountId)
            for remote in remoteLists {
                // Check if list already exists to avoid duplicates
                let remoteListId = remote.id
                let existingListDescriptor = FetchDescriptor<LocalToDoList>(
                    predicate: #Predicate { $0.id == remoteListId }
                )
                if try modelContext.fetch(existingListDescriptor).isEmpty {
                    let localList = LocalToDoList(from: remote)
                    modelContext.insert(localList)
                }
                // Also cache items (checking for duplicates)
                for item in remote.items {
                    let remoteItemId = item.id
                    let existingItemDescriptor = FetchDescriptor<LocalToDoItem>(
                        predicate: #Predicate { $0.id == remoteItemId }
                    )
                    if try modelContext.fetch(existingItemDescriptor).isEmpty {
                        let localItem = LocalToDoItem(from: item)
                        modelContext.insert(localItem)
                    }
                }
            }
            try? modelContext.save()
            return remoteLists
        }

        // Fetch items for each list
        var results: [ToDoList] = []
        for localList in localLists {
            let items = try await getItems(listId: localList.id)
            results.append(localList.toRemote(with: items))
        }

        return results
    }

    /// Force refresh lists from network and update local cache
    func refreshFromRemote(accountId: UUID) async throws -> [ToDoList] {
        guard networkMonitor.isConnected else {
            return try await getLists(accountId: accountId)
        }

        let remoteLists = try await remoteRepository.getLists(accountId: accountId)

        // Update local cache with remote data
        for remote in remoteLists {
            let remoteListId = remote.id
            let existingDescriptor = FetchDescriptor<LocalToDoList>(
                predicate: #Predicate { $0.id == remoteListId }
            )

            if let existingLocal = try modelContext.fetch(existingDescriptor).first {
                existingLocal.update(from: remote)
            } else {
                let local = LocalToDoList(from: remote)
                modelContext.insert(local)
            }

            // Also refresh items for this list
            for remoteItem in remote.items {
                let remoteItemId = remoteItem.id
                let existingItemDescriptor = FetchDescriptor<LocalToDoItem>(
                    predicate: #Predicate { $0.id == remoteItemId }
                )

                if let existingItem = try modelContext.fetch(existingItemDescriptor).first {
                    existingItem.update(from: remoteItem)
                } else {
                    let localItem = LocalToDoItem(from: remoteItem)
                    modelContext.insert(localItem)
                }
            }
        }

        // Remove synced local lists that no longer exist on server
        let remoteIds = Set(remoteLists.map { $0.id })
        let allLocalDescriptor = FetchDescriptor<LocalToDoList>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted }
        )
        let allLocalLists = try modelContext.fetch(allLocalDescriptor)
        for local in allLocalLists where !remoteIds.contains(local.id) && local.isSynced {
            modelContext.delete(local)
        }

        try? modelContext.save()
        return remoteLists
    }

    /// Get a specific list
    func getList(id: UUID) async throws -> ToDoList? {
        let descriptor = FetchDescriptor<LocalToDoList>(
            predicate: #Predicate { $0.id == id && !$0.locallyDeleted }
        )

        if let local = try modelContext.fetch(descriptor).first {
            let items = try await getItems(listId: id)
            return local.toRemote(with: items)
        }
        return nil
    }

    // MARK: - List Write Operations

    /// Create a new list
    func createList(accountId: UUID, title: String, listType: String? = nil, dueDate: Date? = nil) async throws -> ToDoList {
        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let remote = try await remoteRepository.createList(accountId: accountId, title: title, listType: listType, dueDate: dueDate)
                let local = LocalToDoList(from: remote)
                modelContext.insert(local)
                try? modelContext.save()
                return remote
            } catch {
                print("[CachedToDoRepo] Remote createList failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: create locally and queue for sync
        let local = LocalToDoList(
            id: UUID(),
            accountId: accountId,
            title: title,
            listType: listType,
            dueDate: dueDate,
            isSynced: false
        )
        modelContext.insert(local)

        syncEngine.queueChange(
            entityType: "toDoList",
            entityId: local.id,
            accountId: accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update a list
    func updateList(_ list: ToDoList) async throws -> ToDoList {
        let listId = list.id
        let descriptor = FetchDescriptor<LocalToDoList>(
            predicate: #Predicate { $0.id == listId }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        local.title = list.title
        local.listType = list.listType
        local.dueDate = list.dueDate
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.updateList(list)
                local.isSynced = true
                try modelContext.save()
                return local.toRemote(with: list.items)
            } catch {
                print("[CachedToDoRepo] Remote updateList failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "toDoList",
            entityId: list.id,
            accountId: list.accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote(with: list.items)
    }

    /// Delete a list
    func deleteList(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalToDoList>(
            predicate: #Predicate { $0.id == id }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        local.locallyDeleted = true
        local.markAsModified()

        // Also mark all items as deleted
        let itemDescriptor = FetchDescriptor<LocalToDoItem>(
            predicate: #Predicate { $0.listId == id }
        )
        let items = try modelContext.fetch(itemDescriptor)
        for item in items {
            item.locallyDeleted = true
        }

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.deleteList(id: id)
                local.isSynced = true
                try modelContext.save()
                return
            } catch {
                print("[CachedToDoRepo] Remote deleteList failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "toDoList",
            entityId: id,
            accountId: local.accountId,
            changeType: .delete
        )

        try modelContext.save()
    }

    // MARK: - Item Read Operations

    /// Get items for a list
    func getItems(listId: UUID) async throws -> [ToDoItem] {
        let descriptor = FetchDescriptor<LocalToDoItem>(
            predicate: #Predicate { $0.listId == listId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalToDoItem>(\.sortOrder), SortDescriptor<LocalToDoItem>(\.createdAt)]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalToDoItem) in local.toRemote() }
    }

    // MARK: - Item Write Operations

    /// Create a new item
    func createItem(listId: UUID, text: String, sortOrder: Int = 0) async throws -> ToDoItem {
        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let remote = try await remoteRepository.createItem(listId: listId, text: text, sortOrder: sortOrder)
                let local = LocalToDoItem(from: remote)
                modelContext.insert(local)
                try? modelContext.save()
                return remote
            } catch {
                print("[CachedToDoRepo] Remote createItem failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: create locally and queue for sync
        let local = LocalToDoItem(
            id: UUID(),
            listId: listId,
            text: text,
            sortOrder: sortOrder,
            isSynced: false
        )
        modelContext.insert(local)

        let accountId = try getAccountIdForList(listId)

        syncEngine.queueChange(
            entityType: "toDoItem",
            entityId: local.id,
            accountId: accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update an item
    func updateItem(_ item: ToDoItem) async throws -> ToDoItem {
        let itemId = item.id
        let descriptor = FetchDescriptor<LocalToDoItem>(
            predicate: #Predicate { $0.id == itemId }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        local.text = item.text
        local.isCompleted = item.isCompleted
        local.sortOrder = item.sortOrder
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.updateItem(item)
                local.isSynced = true
                try modelContext.save()
                return local.toRemote()
            } catch {
                print("[CachedToDoRepo] Remote updateItem failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        let accountId = try getAccountIdForList(item.listId)

        syncEngine.queueChange(
            entityType: "toDoItem",
            entityId: item.id,
            accountId: accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Toggle item completion
    func toggleItemCompletion(id: UUID) async throws -> ToDoItem {
        let itemId = id
        let descriptor = FetchDescriptor<LocalToDoItem>(
            predicate: #Predicate { $0.id == itemId }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        local.isCompleted.toggle()
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.updateItem(local.toRemote())
                local.isSynced = true
                try modelContext.save()
                return local.toRemote()
            } catch {
                print("[CachedToDoRepo] Remote toggleItemCompletion failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        let accountId = try getAccountIdForList(local.listId)

        syncEngine.queueChange(
            entityType: "toDoItem",
            entityId: id,
            accountId: accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Delete an item
    func deleteItem(id: UUID) async throws {
        let itemId = id
        let descriptor = FetchDescriptor<LocalToDoItem>(
            predicate: #Predicate { $0.id == itemId }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        local.locallyDeleted = true
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.deleteItem(id: id)
                local.isSynced = true
                try modelContext.save()
                return
            } catch {
                print("[CachedToDoRepo] Remote deleteItem failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        let accountId = try getAccountIdForList(local.listId)

        syncEngine.queueChange(
            entityType: "toDoItem",
            entityId: id,
            accountId: accountId,
            changeType: .delete
        )

        try modelContext.save()
    }

    // MARK: - Calendar Queries

    /// Get lists that have a due date set (for calendar display)
    /// Prefers remote data when online to ensure freshness, falls back to local cache offline
    func getListsWithDueDates(accountId: UUID) async throws -> [ToDoList] {
        // Prefer remote data when online (ensures due date changes are reflected immediately)
        if networkMonitor.isConnected {
            let remoteLists = try await remoteRepository.getListsWithDueDates(accountId: accountId)
            // Update local cache with remote data
            for remote in remoteLists {
                let remoteId = remote.id
                let existingDescriptor = FetchDescriptor<LocalToDoList>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                if let existing = try modelContext.fetch(existingDescriptor).first {
                    existing.update(from: remote)
                } else {
                    modelContext.insert(LocalToDoList(from: remote))
                }
            }
            try? modelContext.save()
            return remoteLists
        }

        // Fall back to local cache when offline
        let descriptor = FetchDescriptor<LocalToDoList>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted && $0.dueDate != nil }
        )
        let localLists = try modelContext.fetch(descriptor)
        return localLists.map { $0.toRemote() }
    }

    // MARK: - Private Helpers

    /// Helper to get accountId from a list - avoids SwiftData predicate issues with captured @Model properties
    private func getAccountIdForList(_ listId: UUID) throws -> UUID {
        let listIdToFind = listId
        let listDescriptor = FetchDescriptor<LocalToDoList>(
            predicate: #Predicate { $0.id == listIdToFind }
        )
        return try modelContext.fetch(listDescriptor).first?.accountId ?? UUID()
    }
}
