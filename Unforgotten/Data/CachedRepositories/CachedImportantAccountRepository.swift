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

    // MARK: - Write Operations

    /// Create a new important account
    func createAccount(_ insert: ImportantAccountInsert) async throws -> ImportantAccount {
        // Look up the profile to get the accountId for sync purposes
        let profileId = insert.profileId
        let profileDescriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate { $0.id == profileId }
        )
        guard let profile = try modelContext.fetch(profileDescriptor).first else {
            throw SupabaseError.notFound
        }

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
    func updateAccount(_ account: ImportantAccount) async throws -> ImportantAccount {
        let importantAccountId = account.id
        let descriptor = FetchDescriptor<LocalImportantAccount>(
            predicate: #Predicate { $0.id == importantAccountId }
        )

        if let local = try modelContext.fetch(descriptor).first {
            // Look up the profile to get the accountId for sync purposes
            let profileId = local.profileId
            let profileDescriptor = FetchDescriptor<LocalProfile>(
                predicate: #Predicate { $0.id == profileId }
            )
            guard let profile = try modelContext.fetch(profileDescriptor).first else {
                throw SupabaseError.notFound
            }

            local.accountName = account.accountName
            local.websiteURL = account.websiteURL
            local.username = account.username
            local.emailAddress = account.emailAddress
            local.phoneNumber = account.phoneNumber
            local.securityQuestionHint = account.securityQuestionHint
            local.recoveryHint = account.recoveryHint
            local.notes = account.notes
            local.category = account.category?.rawValue
            local.markAsModified()

            syncEngine.queueChange(
                entityType: "importantAccount",
                entityId: account.id,
                accountId: profile.accountId,
                changeType: .update
            )

            try modelContext.save()
            return local.toRemote()
        }

        throw SupabaseError.notFound
    }

    /// Delete an important account
    func deleteAccount(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalImportantAccount>(
            predicate: #Predicate { $0.id == id }
        )

        if let local = try modelContext.fetch(descriptor).first {
            // Look up the profile to get the accountId for sync purposes
            let profileId = local.profileId
            let profileDescriptor = FetchDescriptor<LocalProfile>(
                predicate: #Predicate { $0.id == profileId }
            )
            guard let profile = try modelContext.fetch(profileDescriptor).first else {
                throw SupabaseError.notFound
            }

            local.locallyDeleted = true
            local.markAsModified()

            syncEngine.queueChange(
                entityType: "importantAccount",
                entityId: id,
                accountId: profile.accountId,
                changeType: .delete
            )

            try modelContext.save()
        }
    }
}
