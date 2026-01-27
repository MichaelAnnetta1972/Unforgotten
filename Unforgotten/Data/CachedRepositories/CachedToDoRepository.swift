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
    func createList(accountId: UUID, title: String, listType: String? = nil) async throws -> ToDoList {
        let local = LocalToDoList(
            id: UUID(),
            accountId: accountId,
            title: title,
            listType: listType,
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

        if let local = try modelContext.fetch(descriptor).first {
            local.title = list.title
            local.listType = list.listType
            local.markAsModified()

            syncEngine.queueChange(
                entityType: "toDoList",
                entityId: list.id,
                accountId: list.accountId,
                changeType: .update
            )

            try modelContext.save()
            return local.toRemote(with: list.items)
        }

        throw SupabaseError.notFound
    }

    /// Delete a list
    func deleteList(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalToDoList>(
            predicate: #Predicate { $0.id == id }
        )

        if let local = try modelContext.fetch(descriptor).first {
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

            syncEngine.queueChange(
                entityType: "toDoList",
                entityId: id,
                accountId: local.accountId,
                changeType: .delete
            )

            try modelContext.save()
        }
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
        let local = LocalToDoItem(
            id: UUID(),
            listId: listId,
            text: text,
            sortOrder: sortOrder,
            isSynced: false
        )
        modelContext.insert(local)

        // Get accountId from list
        let listDescriptor = FetchDescriptor<LocalToDoList>(
            predicate: #Predicate { $0.id == listId }
        )
        let accountId = try modelContext.fetch(listDescriptor).first?.accountId ?? UUID()

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

        if let local = try modelContext.fetch(descriptor).first {
            local.text = item.text
            local.isCompleted = item.isCompleted
            local.sortOrder = item.sortOrder
            local.markAsModified()

            // Get accountId from list
            let itemListId = item.listId
            let listDescriptor = FetchDescriptor<LocalToDoList>(
                predicate: #Predicate { $0.id == itemListId }
            )
            let accountId = try modelContext.fetch(listDescriptor).first?.accountId ?? UUID()

            syncEngine.queueChange(
                entityType: "toDoItem",
                entityId: item.id,
                accountId: accountId,
                changeType: .update
            )

            try modelContext.save()
            return local.toRemote()
        }

        throw SupabaseError.notFound
    }

    /// Toggle item completion
    func toggleItemCompletion(id: UUID) async throws -> ToDoItem {
        let itemId = id
        let descriptor = FetchDescriptor<LocalToDoItem>(
            predicate: #Predicate { $0.id == itemId }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.isCompleted.toggle()
            local.markAsModified()

            // Get accountId from list using helper method
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

        throw SupabaseError.notFound
    }

    /// Delete an item
    func deleteItem(id: UUID) async throws {
        let itemId = id
        let descriptor = FetchDescriptor<LocalToDoItem>(
            predicate: #Predicate { $0.id == itemId }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.locallyDeleted = true
            local.markAsModified()

            // Get accountId from list using helper method
            let accountId = try getAccountIdForList(local.listId)

            syncEngine.queueChange(
                entityType: "toDoItem",
                entityId: id,
                accountId: accountId,
                changeType: .delete
            )

            try modelContext.save()
        }
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
