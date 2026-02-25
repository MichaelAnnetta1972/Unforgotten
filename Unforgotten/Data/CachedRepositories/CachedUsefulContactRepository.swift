import SwiftUI
import SwiftData

// MARK: - Cached Useful Contact Repository
/// Provides offline-first access to UsefulContact data with background sync
@MainActor
final class CachedUsefulContactRepository {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let remoteRepository: UsefulContactRepository
    private let syncEngine: SyncEngine
    private let networkMonitor: NetworkMonitor

    // MARK: - Initialization
    init(modelContext: ModelContext, remoteRepository: UsefulContactRepository, syncEngine: SyncEngine, networkMonitor: NetworkMonitor = .shared) {
        self.modelContext = modelContext
        self.remoteRepository = remoteRepository
        self.syncEngine = syncEngine
        self.networkMonitor = networkMonitor
    }

    // MARK: - Read Operations

    /// Get all contacts for an account, falling back to network if cache is empty
    func getContacts(accountId: UUID) async throws -> [UsefulContact] {
        let descriptor = FetchDescriptor<LocalUsefulContact>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted },
            sortBy: [
                SortDescriptor<LocalUsefulContact>(\.sortOrder),
                SortDescriptor<LocalUsefulContact>(\.name)
            ]
        )

        let localContacts = try modelContext.fetch(descriptor)

        // If cache is empty and we're online, fetch from network and cache
        if localContacts.isEmpty && networkMonitor.isConnected {
            let remoteContacts = try await remoteRepository.getContacts(accountId: accountId)
            for remote in remoteContacts {
                // Check if already exists to avoid duplicates
                let remoteId = remote.id
                let existingDescriptor = FetchDescriptor<LocalUsefulContact>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                if try modelContext.fetch(existingDescriptor).isEmpty {
                    let local = LocalUsefulContact(from: remote)
                    modelContext.insert(local)
                }
            }
            try? modelContext.save()
            return remoteContacts
        }

        // Sort favourites first manually since Bool sorting with order parameter requires NSObject
        return localContacts
            .sorted { ($0.isFavourite ? 0 : 1) < ($1.isFavourite ? 0 : 1) }
            .map { (local: LocalUsefulContact) in local.toRemote() }
    }

    /// Get contacts by category
    func getContacts(accountId: UUID, category: ContactCategory) async throws -> [UsefulContact] {
        let categoryValue = category.rawValue
        let descriptor = FetchDescriptor<LocalUsefulContact>(
            predicate: #Predicate {
                $0.accountId == accountId && $0.category == categoryValue && !$0.locallyDeleted
            },
            sortBy: [
                SortDescriptor<LocalUsefulContact>(\.sortOrder),
                SortDescriptor<LocalUsefulContact>(\.name)
            ]
        )

        // Sort favourites first manually since Bool sorting with order parameter requires NSObject
        return try modelContext.fetch(descriptor)
            .sorted { ($0.isFavourite ? 0 : 1) < ($1.isFavourite ? 0 : 1) }
            .map { (local: LocalUsefulContact) in local.toRemote() }
    }

    /// Get favourite contacts
    func getFavouriteContacts(accountId: UUID) async throws -> [UsefulContact] {
        let descriptor = FetchDescriptor<LocalUsefulContact>(
            predicate: #Predicate {
                $0.accountId == accountId && $0.isFavourite && !$0.locallyDeleted
            },
            sortBy: [
                SortDescriptor<LocalUsefulContact>(\.sortOrder),
                SortDescriptor<LocalUsefulContact>(\.name)
            ]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalUsefulContact) in local.toRemote() }
    }

    /// Force refresh contacts from network and update local cache
    func refreshFromRemote(accountId: UUID) async throws -> [UsefulContact] {
        guard networkMonitor.isConnected else {
            return try await getContacts(accountId: accountId)
        }

        let remoteContacts = try await remoteRepository.getContacts(accountId: accountId)
        let remoteIds = Set(remoteContacts.map { $0.id })

        // Update local cache with remote data
        for remote in remoteContacts {
            let remoteId = remote.id
            let existingDescriptor = FetchDescriptor<LocalUsefulContact>(
                predicate: #Predicate { $0.id == remoteId }
            )

            if let existing = try modelContext.fetch(existingDescriptor).first {
                existing.update(from: remote)
            } else {
                let local = LocalUsefulContact(from: remote)
                modelContext.insert(local)
            }
        }

        // Remove local contacts that no longer exist on server (orphans/duplicates)
        let localDescriptor = FetchDescriptor<LocalUsefulContact>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted }
        )
        let localContacts = try modelContext.fetch(localDescriptor)

        for local in localContacts {
            if !remoteIds.contains(local.id) && local.isSynced {
                modelContext.delete(local)
            }
        }

        try? modelContext.save()
        return remoteContacts
    }

    // MARK: - Write Operations

    /// Create a new contact from a UsefulContactInsert struct
    func createContact(_ insert: UsefulContactInsert) async throws -> UsefulContact {
        return try await createContact(
            accountId: insert.accountId,
            name: insert.name,
            category: insert.category,
            companyName: insert.companyName,
            phone: insert.phone,
            email: insert.email,
            website: insert.website,
            address: insert.address,
            notes: insert.notes,
            isFavourite: insert.isFavourite
        )
    }

    /// Create a new contact with individual parameters
    func createContact(
        accountId: UUID,
        name: String,
        category: ContactCategory,
        companyName: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        isFavourite: Bool = false
    ) async throws -> UsefulContact {
        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let insert = UsefulContactInsert(
                    accountId: accountId,
                    name: name,
                    category: category,
                    companyName: companyName,
                    phone: phone,
                    email: email,
                    website: website,
                    address: address,
                    notes: notes,
                    isFavourite: isFavourite
                )
                let remote = try await remoteRepository.createContact(insert)
                let local = LocalUsefulContact(from: remote)
                modelContext.insert(local)
                try? modelContext.save()
                return remote
            } catch {
                print("[CachedContactRepo] Remote createContact failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: create locally and queue for sync
        let local = LocalUsefulContact(
            id: UUID(),
            accountId: accountId,
            name: name,
            category: category.rawValue,
            companyName: companyName,
            phone: phone,
            email: email,
            website: website,
            address: address,
            notes: notes,
            isFavourite: isFavourite,
            isSynced: false
        )
        modelContext.insert(local)

        syncEngine.queueChange(
            entityType: "usefulContact",
            entityId: local.id,
            accountId: accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update a contact
    func updateContact(_ contact: UsefulContact) async throws -> UsefulContact {
        let contactId = contact.id
        let descriptor = FetchDescriptor<LocalUsefulContact>(
            predicate: #Predicate { $0.id == contactId }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        local.name = contact.name
        local.category = contact.category.rawValue
        local.companyName = contact.companyName
        local.phone = contact.phone
        local.email = contact.email
        local.website = contact.website
        local.address = contact.address
        local.notes = contact.notes
        local.isFavourite = contact.isFavourite
        local.sortOrder = contact.sortOrder
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let updated = try await remoteRepository.updateContact(contact)
                local.isSynced = true
                try modelContext.save()
                return updated
            } catch {
                print("[CachedContactRepo] Remote updateContact failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "usefulContact",
            entityId: contact.id,
            accountId: contact.accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Delete a contact
    func deleteContact(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalUsefulContact>(
            predicate: #Predicate { $0.id == id }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        local.locallyDeleted = true
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.deleteContact(id: id)
                local.isSynced = true
                try modelContext.save()
                return
            } catch {
                print("[CachedContactRepo] Remote deleteContact failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "usefulContact",
            entityId: id,
            accountId: local.accountId,
            changeType: .delete
        )

        try modelContext.save()
    }

    /// Update sort orders for multiple contacts
    func updateContactSortOrders(_ updates: [SortOrderUpdate]) async throws {
        for update in updates {
            let contactId = update.id
            let descriptor = FetchDescriptor<LocalUsefulContact>(
                predicate: #Predicate { $0.id == contactId }
            )

            if let local = try modelContext.fetch(descriptor).first {
                local.sortOrder = update.sortOrder
                local.markAsModified()

                // When online, try remote first
                if networkMonitor.isConnected {
                    do {
                        _ = try await remoteRepository.updateContact(local.toRemote())
                        local.isSynced = true
                    } catch {
                        print("[CachedContactRepo] Remote updateContactSortOrder failed: \(error). Queuing for sync.")
                        syncEngine.queueChange(
                            entityType: "usefulContact",
                            entityId: update.id,
                            accountId: local.accountId,
                            changeType: .update
                        )
                    }
                } else {
                    syncEngine.queueChange(
                        entityType: "usefulContact",
                        entityId: update.id,
                        accountId: local.accountId,
                        changeType: .update
                    )
                }
            }
        }

        try modelContext.save()
    }
}
