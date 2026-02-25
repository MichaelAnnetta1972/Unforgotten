import SwiftUI
import SwiftData

// MARK: - Cached Important Account Repository
/// Provides offline-first access to ImportantAccount data with background sync
@MainActor
final class CachedImportantAccountRepository {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let remoteRepository: ImportantAccountRepository
    private let syncEngine: SyncEngine
    private let networkMonitor: NetworkMonitor

    // MARK: - Initialization
    init(modelContext: ModelContext, remoteRepository: ImportantAccountRepository, syncEngine: SyncEngine, networkMonitor: NetworkMonitor = .shared) {
        self.modelContext = modelContext
        self.remoteRepository = remoteRepository
        self.syncEngine = syncEngine
        self.networkMonitor = networkMonitor
    }

    // MARK: - Read Operations

    /// Get all important accounts for a profile, falling back to network if cache is empty
    func getAccounts(profileId: UUID) async throws -> [ImportantAccount] {
        let descriptor = FetchDescriptor<LocalImportantAccount>(
            predicate: #Predicate { $0.profileId == profileId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalImportantAccount>(\.accountName)]
        )

        let localAccounts = try modelContext.fetch(descriptor)

        // If cache is empty and we're online, fetch from network and cache
        if localAccounts.isEmpty && networkMonitor.isConnected {
            let remoteAccounts = try await remoteRepository.getAccounts(profileId: profileId)
            for remote in remoteAccounts {
                // Check if already exists to avoid duplicates
                let remoteId = remote.id
                let existingDescriptor = FetchDescriptor<LocalImportantAccount>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                if try modelContext.fetch(existingDescriptor).isEmpty {
                    let local = LocalImportantAccount(from: remote)
                    modelContext.insert(local)
                }
            }
            try? modelContext.save()
            return remoteAccounts
        }

        return localAccounts.map { (local: LocalImportantAccount) in local.toRemote() }
    }

    /// Get shared important accounts for a synced profile (fetches from source profile via RPC)
    func getSharedAccounts(syncedProfileId: UUID) async throws -> [ImportantAccount] {
        // For synced profiles, always fetch from remote since the data lives in the source account
        guard networkMonitor.isConnected else {
            return []
        }
        return try await remoteRepository.getSharedAccounts(syncedProfileId: syncedProfileId)
    }

    /// Get a single important account by ID
    func getAccount(id: UUID) async throws -> ImportantAccount? {
        let descriptor = FetchDescriptor<LocalImportantAccount>(
            predicate: #Predicate { $0.id == id && !$0.locallyDeleted }
        )

        return try modelContext.fetch(descriptor).first?.toRemote()
    }

    /// Get accounts by category
    func getAccountsByCategory(profileId: UUID, category: AccountCategory) async throws -> [ImportantAccount] {
        let categoryRaw = category.rawValue
        let descriptor = FetchDescriptor<LocalImportantAccount>(
            predicate: #Predicate {
                $0.profileId == profileId &&
                $0.category == categoryRaw &&
                !$0.locallyDeleted
            },
            sortBy: [SortDescriptor<LocalImportantAccount>(\.accountName)]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalImportantAccount) in local.toRemote() }
    }

    /// Force refresh important accounts from network and update local cache
    func refreshAccounts(profileId: UUID) async throws -> [ImportantAccount] {
        guard networkMonitor.isConnected else {
            return try await getAccounts(profileId: profileId)
        }

        let remoteAccounts = try await remoteRepository.getAccounts(profileId: profileId)

        // Update local cache with remote data
        for remote in remoteAccounts {
            let remoteId = remote.id
            let existingDescriptor = FetchDescriptor<LocalImportantAccount>(
                predicate: #Predicate { $0.id == remoteId }
            )

            if let existingLocal = try modelContext.fetch(existingDescriptor).first {
                existingLocal.update(from: remote)
            } else {
                let local = LocalImportantAccount(from: remote)
                modelContext.insert(local)
            }
        }

        // Remove synced local accounts that no longer exist on server
        let remoteIds = Set(remoteAccounts.map { $0.id })
        let localDescriptor = FetchDescriptor<LocalImportantAccount>(
            predicate: #Predicate { $0.profileId == profileId && !$0.locallyDeleted }
        )
        let localAccounts = try modelContext.fetch(localDescriptor)
        var unsyncedAccounts: [ImportantAccount] = []
        for local in localAccounts {
            if !remoteIds.contains(local.id) {
                if local.isSynced {
                    modelContext.delete(local)
                } else {
                    unsyncedAccounts.append(local.toRemote())
                }
            }
        }

        try? modelContext.save()
        return remoteAccounts + unsyncedAccounts
    }

    // MARK: - Write Operations

    /// Create a new important account
    /// Uses remote-first approach when online for immediate cross-device sync
    func createAccount(_ insert: ImportantAccountInsert) async throws -> ImportantAccount {
        // Look up the profile to get the accountId for sync purposes
        let profileId = insert.profileId
        let profileDescriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate { $0.id == profileId }
        )
        guard let profile = try modelContext.fetch(profileDescriptor).first else {
            throw SupabaseError.notFound
        }

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let remote = try await remoteRepository.createAccount(insert)
                let local = LocalImportantAccount(from: remote)
                modelContext.insert(local)
                try? modelContext.save()
                return remote
            } catch {
                print("[CachedImportantAccountRepo] Remote createAccount failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: create locally and queue for sync
        let local = LocalImportantAccount(
            id: UUID(),
            profileId: insert.profileId,
            accountName: insert.accountName,
            websiteURL: insert.websiteURL,
            username: insert.username,
            emailAddress: insert.emailAddress,
            phoneNumber: insert.phoneNumber,
            securityQuestionHint: insert.securityQuestionHint,
            recoveryHint: insert.recoveryHint,
            notes: insert.notes,
            category: insert.category?.rawValue,
            imageUrl: insert.imageUrl,
            isSynced: false
        )
        modelContext.insert(local)

        syncEngine.queueChange(
            entityType: "importantAccount",
            entityId: local.id,
            accountId: profile.accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update an important account
    /// Uses remote-first approach when online for immediate cross-device sync
    func updateAccount(_ account: ImportantAccount) async throws -> ImportantAccount {
        let importantAccountId = account.id
        let descriptor = FetchDescriptor<LocalImportantAccount>(
            predicate: #Predicate { $0.id == importantAccountId }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        // Look up the profile to get the accountId for sync purposes
        let localProfileId = local.profileId
        let profileDescriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate { $0.id == localProfileId }
        )
        guard let profile = try modelContext.fetch(profileDescriptor).first else {
            throw SupabaseError.notFound
        }

        // Update local fields
        local.accountName = account.accountName
        local.websiteURL = account.websiteURL
        local.username = account.username
        local.emailAddress = account.emailAddress
        local.phoneNumber = account.phoneNumber
        local.securityQuestionHint = account.securityQuestionHint
        local.recoveryHint = account.recoveryHint
        local.notes = account.notes
        local.category = account.category?.rawValue
        local.imageUrl = account.imageUrl
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let updated = try await remoteRepository.updateAccount(account)
                local.isSynced = true
                try modelContext.save()
                return updated
            } catch {
                print("[CachedImportantAccountRepo] Remote updateAccount failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "importantAccount",
            entityId: account.id,
            accountId: profile.accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Delete an important account
    /// Uses remote-first approach when online for immediate cross-device sync
    func deleteAccount(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalImportantAccount>(
            predicate: #Predicate { $0.id == id }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        // Look up the profile to get the accountId for sync purposes
        let localProfileId = local.profileId
        let profileDescriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate { $0.id == localProfileId }
        )
        guard let profile = try modelContext.fetch(profileDescriptor).first else {
            throw SupabaseError.notFound
        }

        local.locallyDeleted = true
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.deleteAccount(id: id)
                local.isSynced = true
                try modelContext.save()
                return
            } catch {
                print("[CachedImportantAccountRepo] Remote deleteAccount failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "importantAccount",
            entityId: id,
            accountId: profile.accountId,
            changeType: .delete
        )

        try modelContext.save()
    }
}
