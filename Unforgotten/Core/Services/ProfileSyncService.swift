import Foundation

/// Service that manages profile sync operations between connected users
@MainActor
final class ProfileSyncService: ObservableObject {
    static let shared = ProfileSyncService()

    private let profileSyncRepository = ProfileSyncRepository()
    private let profileRepository = ProfileRepository()

    private init() {}

    // MARK: - Source Profile Information

    /// Get the display name of the source user for a synced profile
    /// - Parameter profile: The synced profile to get source info for
    /// - Returns: The display name of the source profile owner, or nil if not found
    func getSourceProfileName(for profile: Profile) async -> String? {
        guard profile.isSyncedProfile,
              let syncConnectionId = profile.syncConnectionId else {
            return nil
        }

        do {
            guard let sync = try await profileSyncRepository.getSyncById(id: syncConnectionId) else {
                return nil
            }

            // Determine which source profile to look up based on the sourceUserId
            let sourceProfileId: UUID?
            if sync.inviterUserId == profile.sourceUserId {
                sourceProfileId = sync.inviterSourceProfileId
            } else if sync.acceptorUserId == profile.sourceUserId {
                sourceProfileId = sync.acceptorSourceProfileId
            } else {
                return nil
            }

            guard let profileId = sourceProfileId else { return nil }

            let sourceProfile = try await profileRepository.getProfile(id: profileId)
            return sourceProfile.displayName
        } catch {
            #if DEBUG
            print("Error fetching source profile name: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Profile Matching

    /// Find an existing profile in an account that matches by email
    /// - Parameters:
    ///   - email: The email address to match
    ///   - accountId: The account to search in
    /// - Returns: The matching profile, or nil if not found
    func findExistingProfile(email: String, in accountId: UUID) async -> Profile? {
        guard !email.isEmpty else { return nil }

        do {
            let profiles = try await profileRepository.getProfiles(accountId: accountId)
            return profiles.first { $0.email?.lowercased() == email.lowercased() }
        } catch {
            #if DEBUG
            print("Error finding existing profile by email: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Connection Management

    /// Sever a sync connection, converting synced profiles to local-only
    /// - Parameter syncId: The ID of the profile sync to sever
    func severConnection(syncId: UUID) async throws {
        try await profileSyncRepository.severSync(syncId: syncId)
        NotificationCenter.default.post(name: .profilesDidChange, object: nil)
        NotificationCenter.default.post(name: .profileSyncDidChange, object: nil, userInfo: ["syncId": syncId])
    }

    /// Get all active sync connections for the current user
    /// - Parameter userId: The user ID to get syncs for
    /// - Returns: Array of active profile syncs
    func getActiveSyncs(for userId: UUID) async throws -> [ProfileSync] {
        try await profileSyncRepository.getSyncsForUser(userId: userId)
    }

    // MARK: - Detail Sync Checking

    /// Check if a profile detail is a synced copy
    /// - Parameter detailId: The detail ID to check
    /// - Returns: True if the detail is synced from another user's profile
    func isDetailSynced(detailId: UUID) async -> Bool {
        do {
            return try await profileSyncRepository.isDetailSynced(detailId: detailId)
        } catch {
            #if DEBUG
            print("Error checking if detail is synced: \(error)")
            #endif
            return false
        }
    }

    /// Get source detail information for a synced detail
    /// - Parameter detailId: The synced detail ID
    /// - Returns: The source detail ID, or nil if not synced
    func getSourceDetailId(for detailId: UUID) async -> UUID? {
        do {
            return try await profileSyncRepository.getSourceDetailId(for: detailId)
        } catch {
            return nil
        }
    }

    // MARK: - Sync Status Helpers

    /// Get the sync status for a profile
    /// - Parameter profile: The profile to check
    /// - Returns: A human-readable sync status description
    func getSyncStatusDescription(for profile: Profile) -> String {
        if profile.isSyncedProfile {
            return "Synced from connected user"
        } else if profile.isLocalOnly {
            return "Previously synced, now local only"
        } else {
            return "Local profile"
        }
    }

    /// Check if a profile can be edited (non-synced fields only for synced profiles)
    /// - Parameters:
    ///   - profile: The profile to check
    ///   - fieldName: The field name to check editability for
    /// - Returns: True if the field can be edited
    func canEditField(_ fieldName: String, on profile: Profile) -> Bool {
        // If not a synced profile, all fields are editable
        guard profile.isSyncedProfile else { return true }

        // Local fields are always editable
        let localOnlyFields = ["relationship", "notes", "is_favourite", "sort_order"]
        if localOnlyFields.contains(fieldName) {
            return true
        }

        // Synced fields cannot be edited
        return !profile.isFieldSynced(fieldName)
    }
}

// MARK: - Profile Comparison for Merge

extension ProfileSyncService {
    /// Compare two profiles and return the differences in syncable fields
    /// - Parameters:
    ///   - existing: The existing local profile
    ///   - incoming: The incoming synced profile data
    /// - Returns: Dictionary of field names to (oldValue, newValue) tuples
    func compareProfiles(existing: Profile, incoming: Profile) -> [String: (old: String?, new: String?)] {
        var differences: [String: (old: String?, new: String?)] = [:]

        // Compare each syncable field
        if existing.fullName != incoming.fullName {
            differences["full_name"] = (existing.fullName, incoming.fullName)
        }

        if existing.preferredName != incoming.preferredName {
            differences["preferred_name"] = (existing.preferredName, incoming.preferredName)
        }

        let existingBirthday = existing.birthday?.formatted(date: .abbreviated, time: .omitted)
        let incomingBirthday = incoming.birthday?.formatted(date: .abbreviated, time: .omitted)
        if existingBirthday != incomingBirthday {
            differences["birthday"] = (existingBirthday, incomingBirthday)
        }

        if existing.phone != incoming.phone {
            differences["phone"] = (existing.phone, incoming.phone)
        }

        if existing.email != incoming.email {
            differences["email"] = (existing.email, incoming.email)
        }

        if existing.address != incoming.address {
            differences["address"] = (existing.address, incoming.address)
        }

        if existing.photoUrl != incoming.photoUrl {
            differences["photo_url"] = (existing.photoUrl, incoming.photoUrl)
        }

        return differences
    }

    /// Get a human-readable label for a field name
    static func fieldDisplayName(for fieldName: String) -> String {
        switch fieldName {
        case "full_name": return "Full Name"
        case "preferred_name": return "Preferred Name"
        case "birthday": return "Birthday"
        case "phone": return "Phone"
        case "email": return "Email"
        case "address": return "Address"
        case "photo_url": return "Photo"
        default: return fieldName.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
