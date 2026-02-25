import SwiftUI
import SwiftData

// MARK: - Cached Profile Repository
/// Provides offline-first access to Profile data with background sync
@MainActor
final class CachedProfileRepository {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let remoteRepository: ProfileRepository
    private let syncEngine: SyncEngine
    private let networkMonitor: NetworkMonitor

    // MARK: - Initialization
    init(modelContext: ModelContext, remoteRepository: ProfileRepository, syncEngine: SyncEngine, networkMonitor: NetworkMonitor = .shared) {
        self.modelContext = modelContext
        self.remoteRepository = remoteRepository
        self.syncEngine = syncEngine
        self.networkMonitor = networkMonitor
    }

    // MARK: - Read Operations (Local First, Network Fallback)

    /// Get all profiles for an account from local cache, falling back to network if cache is empty
    func getProfiles(accountId: UUID) async throws -> [Profile] {
        let descriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted },
            sortBy: [SortDescriptor<LocalProfile>(\.sortOrder), SortDescriptor<LocalProfile>(\.fullName)]
        )

        let localProfiles = try modelContext.fetch(descriptor)

        // If cache is empty and we're online, fetch from network and cache
        if localProfiles.isEmpty && networkMonitor.isConnected {
            let remoteProfiles = try await remoteRepository.getProfiles(accountId: accountId)
            // Cache the fetched profiles (check for duplicates and locally-deleted entries)
            var filteredProfiles: [Profile] = []
            for remote in remoteProfiles {
                let remoteId = remote.id
                let existingDescriptor = FetchDescriptor<LocalProfile>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                let existing = try modelContext.fetch(existingDescriptor)
                if let existingLocal = existing.first {
                    // Skip profiles that have been locally deleted — don't resurrect them
                    if existingLocal.locallyDeleted {
                        continue
                    }
                } else {
                    let local = LocalProfile(from: remote)
                    modelContext.insert(local)
                }
                filteredProfiles.append(remote)
            }
            try? modelContext.save()
            return filteredProfiles
        }

        // Deduplicate: if multiple LocalProfile entries share the same id, remove extras
        var seenIds = Set<UUID>()
        var deduplicatedProfiles: [Profile] = []
        for local in localProfiles {
            if seenIds.contains(local.id) {
                // Duplicate - remove from SwiftData
                modelContext.delete(local)
                continue
            }
            seenIds.insert(local.id)
            deduplicatedProfiles.append(local.toRemote())
        }
        if deduplicatedProfiles.count < localProfiles.count {
            try? modelContext.save()
        }

        return deduplicatedProfiles
    }

    /// Force refresh profiles from network and update local cache
    /// Used when realtime sync notifies of remote changes
    func refreshProfiles(accountId: UUID) async throws -> [Profile] {
        guard networkMonitor.isConnected else {
            // If offline, just return local cache
            return try await getProfiles(accountId: accountId)
        }

        let remoteProfiles = try await remoteRepository.getProfiles(accountId: accountId)
        let remoteIds = Set(remoteProfiles.map { $0.id })

        // Update local cache with remote data
        for remote in remoteProfiles {
            let remoteId = remote.id
            let existingDescriptor = FetchDescriptor<LocalProfile>(
                predicate: #Predicate { $0.id == remoteId }
            )

            let existingLocals = try modelContext.fetch(existingDescriptor)

            if let existingLocal = existingLocals.first {
                // Skip profiles that have been locally deleted — don't resurrect them
                if existingLocal.locallyDeleted {
                    // Still remove duplicates
                    for duplicate in existingLocals.dropFirst() {
                        modelContext.delete(duplicate)
                    }
                    continue
                }

                // Update existing local profile with remote data
                existingLocal.update(from: remote)

                // Remove any duplicates with the same ID (keep only the first)
                for duplicate in existingLocals.dropFirst() {
                    modelContext.delete(duplicate)
                }
            } else {
                // Insert new profile
                let local = LocalProfile(from: remote)
                modelContext.insert(local)
            }
        }

        // Remove local profiles that no longer exist on the server (orphans/duplicates)
        // Only remove synced profiles that aren't pending local changes
        let allLocalDescriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate { $0.accountId == accountId && !$0.locallyDeleted }
        )
        let allLocalProfiles = try modelContext.fetch(allLocalDescriptor)

        // Deduplicate: group by ID and remove extras
        var seenIds = Set<UUID>()
        for local in allLocalProfiles {
            if seenIds.contains(local.id) {
                // Duplicate entry - remove it
                modelContext.delete(local)
                continue
            }
            seenIds.insert(local.id)

            // If this local profile's ID is not in the remote set and it's already synced,
            // it means it was deleted on the server
            if !remoteIds.contains(local.id) && local.isSynced {
                modelContext.delete(local)
            }
        }

        try? modelContext.save()
        return remoteProfiles
    }

    /// Get a specific profile from local cache
    func getProfile(id: UUID) async throws -> Profile? {
        let descriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate { $0.id == id && !$0.locallyDeleted }
        )

        return try modelContext.fetch(descriptor).first?.toRemote()
    }

    /// Get primary profile for an account
    func getPrimaryProfile(accountId: UUID) async throws -> Profile? {
        let descriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate {
                $0.accountId == accountId && $0.type == "primary" && !$0.locallyDeleted
            }
        )

        return try modelContext.fetch(descriptor).first?.toRemote()
    }

    /// Find profiles matching a given name or email in an account (for duplicate detection)
    func findMatchingProfiles(accountId: UUID, name: String?, email: String?) async throws -> [Profile] {
        try await remoteRepository.findMatchingProfiles(accountId: accountId, name: name, email: email)
    }

    /// Get profiles with birthdays
    func getProfilesWithBirthdays(accountId: UUID) async throws -> [Profile] {
        let descriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate {
                $0.accountId == accountId && $0.birthday != nil && !$0.locallyDeleted && !$0.isDeceased
            },
            sortBy: [SortDescriptor<LocalProfile>(\.fullName)]
        )

        return try modelContext.fetch(descriptor).map { (local: LocalProfile) in local.toRemote() }
    }

    /// Get upcoming birthdays within a specified number of days
    func getUpcomingBirthdays(accountId: UUID, days: Int = 30) async throws -> [Profile] {
        // Get all profiles with birthdays
        let profiles = try await getProfilesWithBirthdays(accountId: accountId)

        // Filter to those with upcoming birthdays within the specified days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return profiles.filter { profile in
            guard let birthday = profile.birthday else { return false }

            // Calculate next occurrence of this birthday
            var birthdayComponents = calendar.dateComponents([.month, .day], from: birthday)
            birthdayComponents.year = calendar.component(.year, from: today)

            guard let thisYearBirthday = calendar.date(from: birthdayComponents) else { return false }

            // If birthday already passed this year, check next year
            let nextBirthday: Date
            if thisYearBirthday < today {
                birthdayComponents.year = calendar.component(.year, from: today) + 1
                nextBirthday = calendar.date(from: birthdayComponents) ?? thisYearBirthday
            } else {
                nextBirthday = thisYearBirthday
            }

            // Check if within the specified days
            let daysUntilBirthday = calendar.dateComponents([.day], from: today, to: nextBirthday).day ?? 0
            return daysUntilBirthday <= days
        }.sorted { profile1, profile2 in
            // Sort by days until next birthday
            guard let birthday1 = profile1.birthday, let birthday2 = profile2.birthday else { return false }

            // Calculate days until next birthday for profile1
            var components1 = calendar.dateComponents([.month, .day], from: birthday1)
            components1.year = calendar.component(.year, from: today)
            var nextBirthday1 = calendar.date(from: components1) ?? today
            if nextBirthday1 < today {
                components1.year = calendar.component(.year, from: today) + 1
                nextBirthday1 = calendar.date(from: components1) ?? today
            }
            let days1 = calendar.dateComponents([.day], from: today, to: nextBirthday1).day ?? 0

            // Calculate days until next birthday for profile2
            var components2 = calendar.dateComponents([.month, .day], from: birthday2)
            components2.year = calendar.component(.year, from: today)
            var nextBirthday2 = calendar.date(from: components2) ?? today
            if nextBirthday2 < today {
                components2.year = calendar.component(.year, from: today) + 1
                nextBirthday2 = calendar.date(from: components2) ?? today
            }
            let days2 = calendar.dateComponents([.day], from: today, to: nextBirthday2).day ?? 0

            return days1 < days2
        }
    }

    // MARK: - Write Operations

    /// Create a new profile
    func createProfile(_ insert: ProfileInsert) async throws -> Profile {
        // Create locally first
        let local = LocalProfile(
            id: UUID(),
            accountId: insert.accountId,
            type: insert.type.rawValue,
            fullName: insert.fullName,
            preferredName: insert.preferredName,
            relationship: insert.relationship,
            connectedToProfileId: insert.connectedToProfileId,
            includeInFamilyTree: insert.includeInFamilyTree,
            birthday: insert.birthday,
            isDeceased: insert.isDeceased,
            dateOfDeath: insert.dateOfDeath,
            address: insert.address,
            phone: insert.phone,
            email: insert.email,
            isSynced: false
        )
        modelContext.insert(local)

        // Queue for sync
        syncEngine.queueChange(
            entityType: "profile",
            entityId: local.id,
            accountId: insert.accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update a profile
    func updateProfile(_ profile: Profile) async throws -> Profile {
        let profileId = profile.id
        let descriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate { $0.id == profileId }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.fullName = profile.fullName
            local.preferredName = profile.preferredName
            local.relationship = profile.relationship
            local.connectedToProfileId = profile.connectedToProfileId
            local.birthday = profile.birthday
            local.isDeceased = profile.isDeceased
            local.dateOfDeath = profile.dateOfDeath
            local.address = profile.address
            local.phone = profile.phone
            local.email = profile.email
            local.notes = profile.notes
            local.isFavourite = profile.isFavourite
            local.photoUrl = profile.photoUrl
            local.sortOrder = profile.sortOrder
            local.includeInFamilyTree = profile.includeInFamilyTree
            local.markAsModified()

            // Queue for sync
            syncEngine.queueChange(
                entityType: "profile",
                entityId: profile.id,
                accountId: profile.accountId,
                changeType: .update
            )

            try modelContext.save()
            return local.toRemote()
        }

        throw SupabaseError.notFound
    }

    /// Delete a profile
    func deleteProfile(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalProfile>(
            predicate: #Predicate { $0.id == id }
        )

        if let local = try modelContext.fetch(descriptor).first {
            local.locallyDeleted = true
            local.markAsModified()

            // Queue for sync
            syncEngine.queueChange(
                entityType: "profile",
                entityId: id,
                accountId: local.accountId,
                changeType: .delete
            )

            try modelContext.save()
        }
    }

    // MARK: - Profile Details

    /// Get details for a profile, falling back to network if cache is empty
    func getProfileDetails(profileId: UUID, category: DetailCategory? = nil) async throws -> [ProfileDetail] {
        var descriptor: FetchDescriptor<LocalProfileDetail>

        if let category = category {
            let categoryValue = category.rawValue
            descriptor = FetchDescriptor<LocalProfileDetail>(
                predicate: #Predicate {
                    $0.profileId == profileId && $0.category == categoryValue && !$0.locallyDeleted
                }
            )
        } else {
            descriptor = FetchDescriptor<LocalProfileDetail>(
                predicate: #Predicate { $0.profileId == profileId && !$0.locallyDeleted }
            )
        }

        let localDetails = try modelContext.fetch(descriptor)

        // If cache is empty and we're online, fetch from network and cache
        if localDetails.isEmpty && networkMonitor.isConnected {
            let remoteDetails: [ProfileDetail]
            if let category = category {
                remoteDetails = try await remoteRepository.getProfileDetails(profileId: profileId, category: category)
            } else {
                remoteDetails = try await remoteRepository.getProfileDetails(profileId: profileId)
            }
            for remote in remoteDetails {
                let remoteId = remote.id
                let existingDescriptor = FetchDescriptor<LocalProfileDetail>(
                    predicate: #Predicate { $0.id == remoteId }
                )
                if try modelContext.fetch(existingDescriptor).isEmpty {
                    let local = LocalProfileDetail(from: remote)
                    modelContext.insert(local)
                }
            }
            try? modelContext.save()
            return remoteDetails
        }

        return localDetails.map { (local: LocalProfileDetail) in local.toRemote() }
    }

    /// Force refresh profile details from network and update local cache
    /// Used when realtime sync notifies of remote changes
    func refreshProfileDetails(profileId: UUID, category: DetailCategory? = nil) async throws -> [ProfileDetail] {
        guard networkMonitor.isConnected else {
            return try await getProfileDetails(profileId: profileId, category: category)
        }

        let remoteDetails: [ProfileDetail]
        if let category = category {
            remoteDetails = try await remoteRepository.getProfileDetails(profileId: profileId, category: category)
        } else {
            remoteDetails = try await remoteRepository.getProfileDetails(profileId: profileId)
        }

        // Update local cache with remote data
        for remote in remoteDetails {
            let remoteId = remote.id
            let existingDescriptor = FetchDescriptor<LocalProfileDetail>(
                predicate: #Predicate { $0.id == remoteId }
            )

            if let existingLocal = try modelContext.fetch(existingDescriptor).first {
                existingLocal.update(from: remote)
            } else {
                let local = LocalProfileDetail(from: remote)
                modelContext.insert(local)
            }
        }

        // Remove any synced local details that no longer exist remotely
        // Only delete items that were previously synced — preserve unsynced local items
        // that haven't been pushed to the server yet
        let remoteIds = Set(remoteDetails.map { $0.id })
        var localDescriptor: FetchDescriptor<LocalProfileDetail>
        if let category = category {
            let categoryValue = category.rawValue
            localDescriptor = FetchDescriptor<LocalProfileDetail>(
                predicate: #Predicate { $0.profileId == profileId && $0.category == categoryValue && !$0.locallyDeleted }
            )
        } else {
            localDescriptor = FetchDescriptor<LocalProfileDetail>(
                predicate: #Predicate { $0.profileId == profileId && !$0.locallyDeleted }
            )
        }
        let localDetails = try modelContext.fetch(localDescriptor)
        var unsyncedDetails: [ProfileDetail] = []
        for local in localDetails {
            if !remoteIds.contains(local.id) {
                if local.isSynced {
                    // Previously synced but no longer on server — deleted remotely
                    modelContext.delete(local)
                } else {
                    // Not yet synced — preserve and include in results
                    unsyncedDetails.append(local.toRemote())
                }
            }
        }

        try? modelContext.save()
        return remoteDetails + unsyncedDetails
    }

    /// Create a profile detail from a ProfileDetailInsert struct
    func createProfileDetail(_ insert: ProfileDetailInsert) async throws -> ProfileDetail {
        return try await createProfileDetail(
            accountId: insert.accountId,
            profileId: insert.profileId,
            category: insert.category,
            label: insert.label,
            value: insert.value,
            status: insert.status,
            occasion: insert.occasion,
            metadata: insert.metadata
        )
    }

    /// Create a profile detail with individual parameters
    /// Uses remote-first approach when online for immediate cross-device sync
    func createProfileDetail(
        accountId: UUID,
        profileId: UUID,
        category: DetailCategory,
        label: String,
        value: String,
        status: String? = nil,
        occasion: String? = nil,
        metadata: [String: String]? = nil
    ) async throws -> ProfileDetail {
        // Build local data for fallback
        let metadataData: Data?
        if let metadata = metadata {
            metadataData = try? JSONEncoder().encode(metadata)
        } else {
            metadataData = nil
        }

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let insert = ProfileDetailInsert(
                    id: UUID(),
                    accountId: accountId,
                    profileId: profileId,
                    category: category,
                    label: label,
                    value: value,
                    status: status,
                    occasion: occasion,
                    metadata: metadata
                )
                let remote = try await remoteRepository.createProfileDetail(insert)

                // Cache the remote result locally
                let local = LocalProfileDetail(from: remote)
                modelContext.insert(local)
                try? modelContext.save()

                return remote
            } catch {
                // Remote failed — save locally and queue for sync so user's work isn't lost
                print("[CachedProfileRepo] Remote createProfileDetail failed: \(error)")
            }
        }

        // Offline or remote failed: create locally and queue for sync
        let local = LocalProfileDetail(
            id: UUID(),
            accountId: accountId,
            profileId: profileId,
            category: category.rawValue,
            label: label,
            value: value,
            status: status,
            occasion: occasion,
            metadata: metadataData,
            isSynced: false
        )
        modelContext.insert(local)

        // Queue for sync
        syncEngine.queueChange(
            entityType: "profileDetail",
            entityId: local.id,
            accountId: accountId,
            changeType: .create
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Update a profile detail
    /// Uses remote-first approach when online for immediate cross-device sync
    func updateProfileDetail(_ detail: ProfileDetail) async throws -> ProfileDetail {
        let detailId = detail.id
        let descriptor = FetchDescriptor<LocalProfileDetail>(
            predicate: #Predicate { $0.id == detailId }
        )

        guard let local = try modelContext.fetch(descriptor).first else {
            throw SupabaseError.notFound
        }

        // Update local fields
        local.label = detail.label
        local.value = detail.value
        local.status = detail.status
        local.occasion = detail.occasion
        if let metadata = detail.metadata {
            local.metadata = try? JSONEncoder().encode(metadata)
        } else {
            local.metadata = nil
        }
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                let updated = try await remoteRepository.updateProfileDetail(detail)
                local.isSynced = true
                try modelContext.save()
                return updated
            } catch {
                print("[CachedProfileRepo] Remote updateProfileDetail failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "profileDetail",
            entityId: detail.id,
            accountId: detail.accountId,
            changeType: .update
        )

        try modelContext.save()
        return local.toRemote()
    }

    /// Delete a profile detail
    /// Uses remote-first approach when online for immediate cross-device sync
    func deleteProfileDetail(id: UUID) async throws {
        let descriptor = FetchDescriptor<LocalProfileDetail>(
            predicate: #Predicate { $0.id == id }
        )

        guard let local = try modelContext.fetch(descriptor).first else { return }

        local.locallyDeleted = true
        local.markAsModified()

        // When online, try remote first with local fallback
        if networkMonitor.isConnected {
            do {
                try await remoteRepository.deleteProfileDetail(id: id)
                local.isSynced = true
                try modelContext.save()
                return
            } catch {
                print("[CachedProfileRepo] Remote deleteProfileDetail failed: \(error). Saving locally.")
            }
        }

        // Offline or remote failed: queue for sync
        syncEngine.queueChange(
            entityType: "profileDetail",
            entityId: id,
            accountId: local.accountId,
            changeType: .delete
        )

        try modelContext.save()
    }
}
