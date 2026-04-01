import Foundation
import Supabase

// MARK: - Profile Group Repository Protocol
protocol ProfileGroupRepositoryProtocol {
    // Group CRUD
    func getGroups(accountId: UUID) async throws -> [ProfileGroup]
    func createGroup(accountId: UUID, name: String) async throws -> ProfileGroup
    func updateGroup(id: UUID, name: String) async throws -> ProfileGroup
    func deleteGroup(id: UUID) async throws

    // Group Members
    func getGroupMembers(groupId: UUID) async throws -> [ProfileGroupMember]
    func getMembersForAllGroups(accountId: UUID) async throws -> [ProfileGroupMember]
    func addMemberToGroup(groupId: UUID, profileId: UUID) async throws -> ProfileGroupMember
    func removeMemberFromGroup(groupId: UUID, profileId: UUID) async throws
    func setGroupMembers(groupId: UUID, profileIds: [UUID]) async throws
}

// MARK: - Profile Group Repository Implementation
final class ProfileGroupRepository: ProfileGroupRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client

    // MARK: - Get Groups
    func getGroups(accountId: UUID) async throws -> [ProfileGroup] {
        let groups: [ProfileGroup] = try await supabase
            .from(TableName.profileGroups)
            .select()
            .eq("account_id", value: accountId)
            .order("name")
            .execute()
            .value

        return groups
    }

    // MARK: - Create Group
    func createGroup(accountId: UUID, name: String) async throws -> ProfileGroup {
        let insert = ProfileGroupInsert(accountId: accountId, name: name)

        let group: ProfileGroup = try await supabase
            .from(TableName.profileGroups)
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return group
    }

    // MARK: - Update Group
    func updateGroup(id: UUID, name: String) async throws -> ProfileGroup {
        let update = ProfileGroupUpdate(name: name)

        let group: ProfileGroup = try await supabase
            .from(TableName.profileGroups)
            .update(update)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value

        return group
    }

    // MARK: - Delete Group
    func deleteGroup(id: UUID) async throws {
        // Members will be cascade deleted due to FK constraint
        try await supabase
            .from(TableName.profileGroups)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Get Group Members
    func getGroupMembers(groupId: UUID) async throws -> [ProfileGroupMember] {
        let members: [ProfileGroupMember] = try await supabase
            .from(TableName.profileGroupMembers)
            .select()
            .eq("group_id", value: groupId)
            .execute()
            .value

        return members
    }

    // MARK: - Get Members for All Groups
    func getMembersForAllGroups(accountId: UUID) async throws -> [ProfileGroupMember] {
        // Join through profile_groups to filter by account
        let members: [ProfileGroupMember] = try await supabase
            .from(TableName.profileGroupMembers)
            .select("*, profile_groups!inner(account_id)")
            .eq("profile_groups.account_id", value: accountId)
            .execute()
            .value

        return members
    }

    // MARK: - Add Member to Group
    func addMemberToGroup(groupId: UUID, profileId: UUID) async throws -> ProfileGroupMember {
        let insert = ProfileGroupMemberInsert(groupId: groupId, profileId: profileId)

        let member: ProfileGroupMember = try await supabase
            .from(TableName.profileGroupMembers)
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return member
    }

    // MARK: - Remove Member from Group
    func removeMemberFromGroup(groupId: UUID, profileId: UUID) async throws {
        try await supabase
            .from(TableName.profileGroupMembers)
            .delete()
            .eq("group_id", value: groupId)
            .eq("profile_id", value: profileId)
            .execute()
    }

    // MARK: - Set Group Members
    /// Replaces all members of a group with the given profile IDs
    func setGroupMembers(groupId: UUID, profileIds: [UUID]) async throws {
        // Delete existing members
        try await supabase
            .from(TableName.profileGroupMembers)
            .delete()
            .eq("group_id", value: groupId)
            .execute()

        // Add new members
        if !profileIds.isEmpty {
            let inserts = profileIds.map { ProfileGroupMemberInsert(groupId: groupId, profileId: $0) }
            try await supabase
                .from(TableName.profileGroupMembers)
                .insert(inserts)
                .execute()
        }
    }
}

// MARK: - Insert/Update Types
private struct ProfileGroupInsert: Encodable {
    let accountId: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case name
    }
}

private struct ProfileGroupUpdate: Encodable {
    let name: String

    enum CodingKeys: String, CodingKey {
        case name
    }
}

private struct ProfileGroupMemberInsert: Encodable {
    let groupId: UUID
    let profileId: UUID

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case profileId = "profile_id"
    }
}
