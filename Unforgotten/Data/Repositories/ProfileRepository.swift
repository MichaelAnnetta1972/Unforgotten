import Foundation
import Supabase

// MARK: - Profile Repository Protocol
protocol ProfileRepositoryProtocol {
    func getProfiles(accountId: UUID) async throws -> [Profile]
    func getProfile(id: UUID) async throws -> Profile
    func getPrimaryProfile(accountId: UUID) async throws -> Profile?
    func createProfile(_ profile: ProfileInsert) async throws -> Profile
    func updateProfile(_ profile: Profile) async throws -> Profile
    func deleteProfile(id: UUID) async throws
    func updateSortOrders(_ updates: [SortOrderUpdate]) async throws

    // Profile Details
    func getProfileDetails(profileId: UUID) async throws -> [ProfileDetail]
    func getProfileDetails(profileId: UUID, category: DetailCategory) async throws -> [ProfileDetail]
    func createProfileDetail(_ detail: ProfileDetailInsert) async throws -> ProfileDetail
    func updateProfileDetail(_ detail: ProfileDetail) async throws -> ProfileDetail
    func deleteProfileDetail(id: UUID) async throws

    // Birthdays
    func getUpcomingBirthdays(accountId: UUID, days: Int) async throws -> [Profile]
    func getTodaysBirthdays(accountId: UUID) async throws -> [Profile]
}

// MARK: - Sort Order Update
struct SortOrderUpdate {
    let id: UUID
    let sortOrder: Int
}

// MARK: - Profile Repository Implementation
final class ProfileRepository: ProfileRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Get All Profiles
    func getProfiles(accountId: UUID) async throws -> [Profile] {
        let profiles: [Profile] = try await supabase
            .from(TableName.profiles)
            .select()
            .eq("account_id", value: accountId)
            .order("sort_order")
            .order("full_name")
            .execute()
            .value

        return profiles
    }
    
    // MARK: - Get Single Profile
    func getProfile(id: UUID) async throws -> Profile {
        let profile: Profile = try await supabase
            .from(TableName.profiles)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        
        return profile
    }
    
    // MARK: - Get Primary Profile
    func getPrimaryProfile(accountId: UUID) async throws -> Profile? {
        let profiles: [Profile] = try await supabase
            .from(TableName.profiles)
            .select()
            .eq("account_id", value: accountId)
            .eq("type", value: ProfileType.primary.rawValue)
            .limit(1)
            .execute()
            .value
        
        return profiles.first
    }
    
    // MARK: - Create Profile
    func createProfile(_ profile: ProfileInsert) async throws -> Profile {
        let created: Profile = try await supabase
            .from(TableName.profiles)
            .insert(profile)
            .select()
            .single()
            .execute()
            .value
        
        return created
    }
    
    // MARK: - Update Profile
    func updateProfile(_ profile: Profile) async throws -> Profile {
        let update = ProfileUpdate(
            fullName: profile.fullName,
            preferredName: profile.preferredName,
            relationship: profile.relationship,
            connectedToProfileId: profile.connectedToProfileId,
            includeInFamilyTree: profile.includeInFamilyTree,
            birthday: profile.birthday,
            isDeceased: profile.isDeceased,
            dateOfDeath: profile.dateOfDeath,
            address: profile.address,
            phone: profile.phone,
            email: profile.email,
            notes: profile.notes,
            isFavourite: profile.isFavourite,
            photoUrl: profile.photoUrl
        )
        
        let updated: Profile = try await supabase
            .from(TableName.profiles)
            .update(update)
            .eq("id", value: profile.id)
            .select()
            .single()
            .execute()
            .value
        
        return updated
    }
    
    // MARK: - Delete Profile
    func deleteProfile(id: UUID) async throws {
        try await supabase
            .from(TableName.profiles)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Update Sort Orders
    func updateSortOrders(_ updates: [SortOrderUpdate]) async throws {
        for update in updates {
            try await supabase
                .from(TableName.profiles)
                .update(["sort_order": update.sortOrder])
                .eq("id", value: update.id)
                .execute()
        }
    }

    // MARK: - Get Profile Details
    func getProfileDetails(profileId: UUID) async throws -> [ProfileDetail] {
        let details: [ProfileDetail] = try await supabase
            .from(TableName.profileDetails)
            .select()
            .eq("profile_id", value: profileId)
            .order("label")
            .execute()
            .value
        
        return details
    }
    
    // MARK: - Get Profile Details by Category
    func getProfileDetails(profileId: UUID, category: DetailCategory) async throws -> [ProfileDetail] {
        let details: [ProfileDetail] = try await supabase
            .from(TableName.profileDetails)
            .select()
            .eq("profile_id", value: profileId)
            .eq("category", value: category.rawValue)
            .order("label")
            .execute()
            .value
        
        return details
    }
    
    // MARK: - Create Profile Detail
    func createProfileDetail(_ detail: ProfileDetailInsert) async throws -> ProfileDetail {
        let created: ProfileDetail = try await supabase
            .from(TableName.profileDetails)
            .insert(detail)
            .select()
            .single()
            .execute()
            .value
        
        return created
    }
    
    // MARK: - Update Profile Detail
    func updateProfileDetail(_ detail: ProfileDetail) async throws -> ProfileDetail {
        let update = ProfileDetailUpdate(
            label: detail.label,
            value: detail.value,
            status: detail.status,
            occasion: detail.occasion,
            metadata: detail.metadata
        )
        
        let updated: ProfileDetail = try await supabase
            .from(TableName.profileDetails)
            .update(update)
            .eq("id", value: detail.id)
            .select()
            .single()
            .execute()
            .value
        
        return updated
    }
    
    // MARK: - Delete Profile Detail
    func deleteProfileDetail(id: UUID) async throws {
        try await supabase
            .from(TableName.profileDetails)
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Get Upcoming Birthdays
    func getUpcomingBirthdays(accountId: UUID, days: Int = 30) async throws -> [Profile] {
        #if DEBUG
        print("🔍 Fetching profiles with birthdays for account: \(accountId)")
        #endif

        // Get all profiles with birthdays
        let profiles: [Profile] = try await supabase
            .from(TableName.profiles)
            .select()
            .eq("account_id", value: accountId)
            .not("birthday", operator: .is, value: "null")
            .execute()
            .value

        #if DEBUG
        print("🔍 Query returned \(profiles.count) profiles with birthdays")
        profiles.forEach { profile in
            print("🔍 Profile: \(profile.fullName), Birthday: \(profile.birthday?.description ?? "nil")")
        }
        #endif

        // Filter to those within the specified days
        let filtered = profiles.filter { profile in
            guard let birthday = profile.birthday else { return false }
            let daysUntil = birthday.daysUntilNextOccurrence()
            let included = daysUntil >= 0 && daysUntil <= days
            #if DEBUG
            print("🔍 \(profile.fullName): \(daysUntil) days until birthday, included: \(included)")
            #endif
            return included
        }.sorted { profile1, profile2 in
            let days1 = profile1.birthday?.daysUntilNextOccurrence() ?? Int.max
            let days2 = profile2.birthday?.daysUntilNextOccurrence() ?? Int.max
            return days1 < days2
        }

        #if DEBUG
        print("🔍 After filtering: \(filtered.count) upcoming birthdays")
        #endif
        return filtered
    }
    
    // MARK: - Get Today's Birthdays
    func getTodaysBirthdays(accountId: UUID) async throws -> [Profile] {
        let profiles: [Profile] = try await supabase
            .from(TableName.profiles)
            .select()
            .eq("account_id", value: accountId)
            .not("birthday", operator: .is, value: "null")
            .execute()
            .value
        
        let calendar = Calendar.current
        let today = Date()
        let todayMonth = calendar.component(.month, from: today)
        let todayDay = calendar.component(.day, from: today)
        
        return profiles.filter { profile in
            guard let birthday = profile.birthday else { return false }
            let month = calendar.component(.month, from: birthday)
            let day = calendar.component(.day, from: birthday)
            return month == todayMonth && day == todayDay
        }
    }
}

// MARK: - Insert/Update Types
struct ProfileInsert: Encodable {
    let accountId: UUID
    let type: ProfileType
    let fullName: String
    let preferredName: String?
    let relationship: String?
    let connectedToProfileId: UUID?
    let includeInFamilyTree: Bool
    let birthday: Date?
    let isDeceased: Bool
    let dateOfDeath: Date?
    let address: String?
    let phone: String?
    let email: String?
    let notes: String?
    let isFavourite: Bool
    let linkedUserId: UUID?
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case type
        case fullName = "full_name"
        case preferredName = "preferred_name"
        case relationship
        case connectedToProfileId = "connected_to_profile_id"
        case includeInFamilyTree = "include_in_family_tree"
        case birthday
        case isDeceased = "is_deceased"
        case dateOfDeath = "date_of_death"
        case address
        case phone
        case email
        case notes
        case isFavourite = "is_favourite"
        case linkedUserId = "linked_user_id"
        case photoUrl = "photo_url"
    }

    init(
        accountId: UUID,
        type: ProfileType = .relative,
        fullName: String,
        preferredName: String? = nil,
        relationship: String? = nil,
        connectedToProfileId: UUID? = nil,
        includeInFamilyTree: Bool = true,
        birthday: Date? = nil,
        isDeceased: Bool = false,
        dateOfDeath: Date? = nil,
        address: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        notes: String? = nil,
        isFavourite: Bool = false,
        linkedUserId: UUID? = nil,
        photoUrl: String? = nil
    ) {
        self.accountId = accountId
        self.type = type
        self.fullName = fullName
        self.preferredName = preferredName
        self.relationship = relationship
        self.connectedToProfileId = connectedToProfileId
        self.includeInFamilyTree = includeInFamilyTree
        self.birthday = birthday
        self.isDeceased = isDeceased
        self.dateOfDeath = dateOfDeath
        self.address = address
        self.phone = phone
        self.email = email
        self.notes = notes
        self.isFavourite = isFavourite
        self.linkedUserId = linkedUserId
        self.photoUrl = photoUrl
    }
}

private struct ProfileUpdate: Encodable {
    let fullName: String
    let preferredName: String?
    let relationship: String?
    let connectedToProfileId: UUID?
    let includeInFamilyTree: Bool
    let birthday: Date?
    let isDeceased: Bool
    let dateOfDeath: Date?
    let address: String?
    let phone: String?
    let email: String?
    let notes: String?
    let isFavourite: Bool
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case preferredName = "preferred_name"
        case relationship
        case connectedToProfileId = "connected_to_profile_id"
        case includeInFamilyTree = "include_in_family_tree"
        case birthday
        case isDeceased = "is_deceased"
        case dateOfDeath = "date_of_death"
        case address
        case phone
        case email
        case notes
        case isFavourite = "is_favourite"
        case photoUrl = "photo_url"
    }

    // Custom encoder to explicitly send null for nil values (required by Supabase to clear fields)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(preferredName, forKey: .preferredName)
        try container.encode(relationship, forKey: .relationship)
        try container.encode(connectedToProfileId, forKey: .connectedToProfileId)
        try container.encode(includeInFamilyTree, forKey: .includeInFamilyTree)
        try container.encode(birthday, forKey: .birthday)
        try container.encode(isDeceased, forKey: .isDeceased)
        try container.encode(dateOfDeath, forKey: .dateOfDeath)
        try container.encode(address, forKey: .address)
        try container.encode(phone, forKey: .phone)
        try container.encode(email, forKey: .email)
        try container.encode(notes, forKey: .notes)
        try container.encode(isFavourite, forKey: .isFavourite)
        try container.encode(photoUrl, forKey: .photoUrl)
    }
}

struct ProfileDetailInsert: Encodable {
    let accountId: UUID
    let profileId: UUID
    let category: DetailCategory
    let label: String
    let value: String
    let status: String?
    let occasion: String?
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case profileId = "profile_id"
        case category
        case label
        case value
        case status
        case occasion
        case metadata
    }

    init(
        accountId: UUID,
        profileId: UUID,
        category: DetailCategory,
        label: String,
        value: String,
        status: String? = nil,
        occasion: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.accountId = accountId
        self.profileId = profileId
        self.category = category
        self.label = label
        self.value = value
        self.status = status
        self.occasion = occasion
        self.metadata = metadata
    }
}

private struct ProfileDetailUpdate: Encodable {
    let label: String
    let value: String
    let status: String?
    let occasion: String?
    let metadata: [String: String]?
}

// MARK: - Profile Connection Methods
extension ProfileRepository {
    /// Get all connections for a profile
    func getConnections(profileId: UUID) async throws -> [ProfileConnection] {
        let connections: [ProfileConnection] = try await supabase
            .from(TableName.profileConnections)
            .select()
            .eq("from_profile_id", value: profileId)
            .execute()
            .value

        return connections
    }

    /// Get connections with profile data
    func getConnectionsWithProfiles(profileId: UUID) async throws -> [ConnectionWithProfile] {
        let connections = try await getConnections(profileId: profileId)

        var result: [ConnectionWithProfile] = []
        for connection in connections {
            do {
                let profile = try await getProfile(id: connection.toProfileId)
                result.append(ConnectionWithProfile(connection: connection, connectedProfile: profile))
            } catch {
                // Skip connections where the profile no longer exists
                #if DEBUG
                print("Could not load profile for connection: \(error)")
                #endif
            }
        }

        return result
    }

    /// Create a connection (with optional bidirectional)
    func createConnection(_ insert: ProfileConnectionInsert, bidirectional: Bool = true) async throws -> ProfileConnection {
        // Create the primary connection
        let created: ProfileConnection = try await supabase
            .from(TableName.profileConnections)
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        // Create the inverse connection if bidirectional
        if bidirectional {
            let inverseInsert = ProfileConnectionInsert(
                accountId: insert.accountId,
                fromProfileId: insert.toProfileId,
                toProfileId: insert.fromProfileId,
                relationshipType: insert.relationshipType.inverse
            )

            _ = try? await supabase
                .from(TableName.profileConnections)
                .insert(inverseInsert)
                .execute()
        }

        return created
    }

    /// Delete a connection (and its inverse if bidirectional)
    func deleteConnection(id: UUID, bidirectional: Bool = true) async throws {
        // Get the connection first to find the inverse
        if bidirectional {
            let connection: ProfileConnection = try await supabase
                .from(TableName.profileConnections)
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value

            // Delete the inverse connection
            _ = try? await supabase
                .from(TableName.profileConnections)
                .delete()
                .eq("from_profile_id", value: connection.toProfileId)
                .eq("to_profile_id", value: connection.fromProfileId)
                .execute()
        }

        // Delete the primary connection
        try await supabase
            .from(TableName.profileConnections)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Profile Connection Insert
struct ProfileConnectionInsert: Encodable {
    let accountId: UUID
    let fromProfileId: UUID
    let toProfileId: UUID
    let relationshipType: ConnectionType

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case fromProfileId = "from_profile_id"
        case toProfileId = "to_profile_id"
        case relationshipType = "relationship_type"
    }
}
