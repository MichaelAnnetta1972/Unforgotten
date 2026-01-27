import SwiftUI
import SwiftData

// MARK: - Cached Account Repository
/// Provides offline-first access to Account data with background sync
@MainActor
final class CachedAccountRepository {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let remoteRepository: AccountRepository
    private let syncEngine: SyncEngine

    // MARK: - Initialization
    init(modelContext: ModelContext, remoteRepository: AccountRepository, syncEngine: SyncEngine) {
        self.modelContext = modelContext
        self.remoteRepository = remoteRepository
        self.syncEngine = syncEngine
    }

    // MARK: - Read Operations (Local First)

    /// Get all accounts the user has access to from local cache
    func getAllUserAccounts() async throws -> [AccountWithRole] {
        // First return from cache
        let descriptor = FetchDescriptor<LocalAccount>(
            predicate: #Predicate { !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalAccount>(\.displayName)]
        )
        let localAccounts = try modelContext.fetch(descriptor)

        // If we have cached data, return it
        if !localAccounts.isEmpty {
            // Get member roles from cache
            var accountsWithRoles: [AccountWithRole] = []
            guard let userId = await SupabaseManager.shared.currentUserId else {
                return []
            }

            for localAccount in localAccounts {
                let localAccountId = localAccount.id
                let memberDescriptor = FetchDescriptor<LocalAccountMember>(
                    predicate: #Predicate {
                        $0.accountId == localAccountId && $0.userId == userId && !$0.locallyDeleted
                    }
                )

                if let member = try modelContext.fetch(memberDescriptor).first {
                    let isOwner = localAccount.ownerUserId == userId
                    accountsWithRoles.append(AccountWithRole(
                        account: localAccount.toRemote(),
                        role: member.memberRole,
                        isOwner: isOwner
                    ))
                }
            }

            // Sort: owned accounts first, then by display name
            return accountsWithRoles.sorted { first, second in
                if first.isOwner != second.isOwner {
                    return first.isOwner
                }
                return first.displayName.localizedCaseInsensitiveCompare(second.displayName) == .orderedAscending
            }
        }

        // No cache - need to fetch from remote
        let remoteAccounts = try await remoteRepository.getAllUserAccounts()

        // Cache the results
        for accountWithRole in remoteAccounts {
            let localAccount = LocalAccount(from: accountWithRole.account)
            modelContext.insert(localAccount)

            // Also cache the member record
            guard let userId = await SupabaseManager.shared.currentUserId else { continue }
            let localMember = LocalAccountMember(
                accountId: accountWithRole.account.id,
                userId: userId,
                role: accountWithRole.role.rawValue,
                isSynced: true
            )
            modelContext.insert(localMember)
        }

        try modelContext.save()
        return remoteAccounts
    }

    /// Get a specific account from local cache
    func getAccount(id: UUID) async throws -> Account? {
        let descriptor = FetchDescriptor<LocalAccount>(
            predicate: #Predicate { $0.id == id && !$0.locallyDeleted }
        )

        if let local = try modelContext.fetch(descriptor).first {
            return local.toRemote()
        }

        // Not in cache - try remote
        let remote = try await remoteRepository.getAccount(id: id)
        let local = LocalAccount(from: remote)
        modelContext.insert(local)
        try modelContext.save()
        return remote
    }

    /// Get current user's role for an account
    func getCurrentUserRole(accountId: UUID) async throws -> MemberRole? {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            return nil
        }

        let descriptor = FetchDescriptor<LocalAccountMember>(
            predicate: #Predicate {
                $0.accountId == accountId && $0.userId == userId && !$0.locallyDeleted
            }
        )

        if let local = try modelContext.fetch(descriptor).first {
            return local.memberRole
        }

        // Not in cache - try remote
        let role = try await remoteRepository.getCurrentUserRole(accountId: accountId)

        if let role = role {
            let local = LocalAccountMember(
                accountId: accountId,
                userId: userId,
                role: role.rawValue,
                isSynced: true
            )
            modelContext.insert(local)
            try modelContext.save()
        }

        return role
    }

    // MARK: - Write Operations

    /// Create a new account (requires network for first-time creation)
    func createAccount(displayName: String) async throws -> Account {
        // Account creation requires network
        let remote = try await remoteRepository.createAccount(displayName: displayName)

        // Cache the new account
        let local = LocalAccount(from: remote)
        modelContext.insert(local)

        // Also cache the owner member record
        if let userId = await SupabaseManager.shared.currentUserId {
            let localMember = LocalAccountMember(
                accountId: remote.id,
                userId: userId,
                role: MemberRole.owner.rawValue,
                isSynced: true
            )
            modelContext.insert(localMember)
        }

        try modelContext.save()
        return remote
    }

    /// Update an account
    func updateAccount(_ account: Account) async throws -> Account {
        // Update local cache
        let accountId = account.id
        let descriptor = FetchDescriptor<LocalAccount>(
            predicate: #Predicate { $0.id == accountId }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.displayName = account.displayName
            local.markAsModified()

            // Queue for sync
            syncEngine.queueChange(
                entityType: "account",
                entityId: account.id,
                accountId: account.id,
                changeType: .update
            )
        }

        try modelContext.save()
        return account
    }

    // MARK: - Cache from Remote

    /// Cache accounts fetched from remote
    func cacheAccounts(_ accounts: [AccountWithRole]) async throws {
        guard let userId = await SupabaseManager.shared.currentUserId else { return }

        for accountWithRole in accounts {
            let accountId = accountWithRole.account.id
            let accountDescriptor = FetchDescriptor<LocalAccount>(
                predicate: #Predicate { $0.id == accountId }
            )

            if let existing = try modelContext.fetch(accountDescriptor).first {
                existing.update(from: accountWithRole.account)
            } else {
                let local = LocalAccount(from: accountWithRole.account)
                modelContext.insert(local)
            }

            // Cache member
            let memberDescriptor = FetchDescriptor<LocalAccountMember>(
                predicate: #Predicate {
                    $0.accountId == accountId && $0.userId == userId
                }
            )

            if try modelContext.fetch(memberDescriptor).isEmpty {
                let localMember = LocalAccountMember(
                    accountId: accountWithRole.account.id,
                    userId: userId,
                    role: accountWithRole.role.rawValue,
                    isSynced: true
                )
                modelContext.insert(localMember)
            }
        }

        try modelContext.save()
    }
}
