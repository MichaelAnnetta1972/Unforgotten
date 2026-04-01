import SwiftUI

// MARK: - Manage Groups View
/// Full screen view for managing profile groups - create, rename, delete groups and manage their members
struct ManageGroupsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    @StateObject private var viewModel = ManageGroupsViewModel()
    @State private var showCreateGroup = false
    @State private var newGroupName = ""
    @State private var editingGroup: ProfileGroup?
    @State private var editGroupName = ""
    @State private var groupToDelete: ProfileGroup?
    @State private var showDeleteConfirmation = false
    @State private var selectedGroup: ProfileGroup?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundLight.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        if viewModel.isLoading && viewModel.groups.isEmpty {
                            LoadingView(message: "Loading groups...")
                                .padding(.top, 40)
                        } else if viewModel.groups.isEmpty {
                            emptyState
                        } else {
                            groupsList
                        }
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Manage Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(appAccentColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newGroupName = ""
                        showCreateGroup = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(appAccentColor)
                    }
                }
            }
            .alert("New Group", isPresented: $showCreateGroup) {
                TextField("Group name", text: $newGroupName)
                Button("Cancel", role: .cancel) { newGroupName = "" }
                Button("Create") {
                    guard !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Task {
                        await viewModel.createGroup(name: newGroupName.trimmingCharacters(in: .whitespaces), appState: appState)
                        newGroupName = ""
                    }
                }
            } message: {
                Text("Enter a name for the new group.")
            }
            .alert("Rename Group", isPresented: .init(
                get: { editingGroup != nil },
                set: { if !$0 { editingGroup = nil } }
            )) {
                TextField("Group name", text: $editGroupName)
                Button("Cancel", role: .cancel) { editingGroup = nil }
                Button("Save") {
                    guard let group = editingGroup,
                          !editGroupName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Task {
                        await viewModel.renameGroup(id: group.id, name: editGroupName.trimmingCharacters(in: .whitespaces), appState: appState)
                        editingGroup = nil
                    }
                }
            } message: {
                Text("Enter a new name for the group.")
            }
            .alert("Delete Group", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { groupToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let group = groupToDelete {
                        Task {
                            await viewModel.deleteGroup(id: group.id, appState: appState)
                            groupToDelete = nil
                        }
                    }
                }
            } message: {
                if let group = groupToDelete {
                    Text("Are you sure you want to delete \"\(group.name)\"? This won't delete any profiles.")
                }
            }
            .sheet(item: $selectedGroup) { group in
                GroupMembersSheet(
                    group: group,
                    allProfiles: viewModel.profiles,
                    memberProfileIds: viewModel.memberProfileIds(for: group.id),
                    onSave: { profileIds in
                        Task {
                            await viewModel.setGroupMembers(groupId: group.id, profileIds: profileIds, appState: appState)
                        }
                    }
                )
                .environmentObject(appState)
            }
        }
        .task {
            await viewModel.load(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileGroupsDidChange)) { _ in
            Task { await viewModel.load(appState: appState) }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundColor(.textSecondary)

            Text("No Groups Yet")
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Text("Create groups to quickly select multiple family members when sharing.")
                .font(.appBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                newGroupName = ""
                showCreateGroup = true
            } label: {
                Text("Create Group")
                    .font(.appBodyMedium)
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(appAccentColor)
                    .cornerRadius(AppDimensions.pillCornerRadius)
            }
        }
        .padding(.top, 60)
    }

    // MARK: - Groups List
    private var groupsList: some View {
        VStack(spacing: AppDimensions.cardSpacing) {
            ForEach(viewModel.groups) { group in
                GroupCard(
                    group: group,
                    memberProfiles: viewModel.memberProfiles(for: group.id),
                    accentColor: appAccentColor,
                    onTapMembers: {
                        selectedGroup = group
                    },
                    onRename: {
                        editGroupName = group.name
                        editingGroup = group
                    },
                    onDelete: {
                        groupToDelete = group
                        showDeleteConfirmation = true
                    }
                )
            }
        }
    }
}

// MARK: - Group Card
private struct GroupCard: View {
    let group: ProfileGroup
    let memberProfiles: [Profile]
    let accentColor: Color
    let onTapMembers: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 18))
                    .foregroundColor(accentColor)
                    .frame(width: 36, height: 36)
                    .background(accentColor.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)

                    Text("\(memberProfiles.count) member\(memberProfiles.count == 1 ? "" : "s")")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Expand/collapse
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())

                // Context menu
                Menu {
                    Button { onTapMembers() } label: {
                        Label("Edit Members", systemImage: "person.badge.plus")
                    }
                    Button { onRename() } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Delete Group", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(AppDimensions.cardPadding)

            // Expanded member list
            if isExpanded {
                Divider()
                    .background(Color.textMuted.opacity(0.3))

                if memberProfiles.isEmpty {
                    Text("No members yet. Tap the menu to add members.")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                        .padding(AppDimensions.cardPadding)
                } else {
                    VStack(spacing: 0) {
                        ForEach(memberProfiles) { profile in
                            HStack(spacing: 10) {
                                AsyncProfileImage(url: profile.photoUrl, size: 32)

                                Text(profile.displayName)
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                if let relationship = profile.relationship {
                                    Text(relationship)
                                        .font(.appCaption)
                                        .foregroundColor(.textSecondary)
                                }
                            }
                            .padding(.horizontal, AppDimensions.cardPadding)
                            .padding(.vertical, 8)
                        }
                    }
                }

                // Edit members button
                Button { onTapMembers() } label: {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                        Text("Edit Members")
                            .font(.appCaption)
                    }
                    .foregroundColor(accentColor)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(accentColor.opacity(0.08))
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Group Members Sheet
/// Sheet for selecting which profiles belong to a group
struct GroupMembersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let group: ProfileGroup
    let allProfiles: [Profile]
    let memberProfileIds: Set<UUID>
    let onSave: (Set<UUID>) -> Void

    @State private var selectedIds: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundLight.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Quick actions
                        HStack(spacing: 12) {
                            Button {
                                selectedIds = Set(allProfiles.map { $0.id })
                            } label: {
                                Text("Select All")
                                    .font(.appCaption)
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.cardBackgroundSoft)
                                    .cornerRadius(AppDimensions.pillCornerRadius)
                            }

                            Button {
                                selectedIds = []
                            } label: {
                                Text("Clear")
                                    .font(.appCaption)
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.cardBackgroundSoft)
                                    .cornerRadius(AppDimensions.pillCornerRadius)
                            }

                            Spacer()
                        }

                        ForEach(allProfiles) { profile in
                            Button {
                                if selectedIds.contains(profile.id) {
                                    selectedIds.remove(profile.id)
                                } else {
                                    selectedIds.insert(profile.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    AsyncProfileImage(url: profile.photoUrl, size: 40)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.displayName)
                                            .font(.appBody)
                                            .foregroundColor(.textPrimary)

                                        if let relationship = profile.relationship {
                                            Text(relationship)
                                                .font(.appCaption)
                                                .foregroundColor(.textSecondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: selectedIds.contains(profile.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedIds.contains(profile.id) ? appAccentColor : .textSecondary)
                                }
                                .padding(AppDimensions.cardPadding)
                                .background(Color.cardBackground)
                                .cornerRadius(AppDimensions.cardCornerRadius)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Members of \(group.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedIds)
                        dismiss()
                    }
                    .foregroundColor(appAccentColor)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            selectedIds = memberProfileIds
        }
    }
}

// MARK: - Manage Groups View Model
@MainActor
class ManageGroupsViewModel: ObservableObject {
    @Published var groups: [ProfileGroup] = []
    @Published var profiles: [Profile] = []
    @Published var allMembers: [ProfileGroupMember] = []
    @Published var isLoading = false
    @Published var error: String?

    func load(appState: AppState) async {
        guard let account = appState.currentAccount else { return }
        isLoading = true

        do {
            async let groupsTask = appState.profileGroupRepository.getGroups(accountId: account.id)
            async let profilesTask = appState.profileRepository.getProfiles(accountId: account.id)

            let (loadedGroups, loadedProfiles) = try await (groupsTask, profilesTask)

            groups = loadedGroups
            profiles = loadedProfiles.filter { $0.type != .primary }

            // Load all members across groups
            if !loadedGroups.isEmpty {
                allMembers = try await appState.profileGroupRepository.getMembersForAllGroups(accountId: account.id)
            } else {
                allMembers = []
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func memberProfileIds(for groupId: UUID) -> Set<UUID> {
        Set(allMembers.filter { $0.groupId == groupId }.map { $0.profileId })
    }

    func memberProfiles(for groupId: UUID) -> [Profile] {
        let ids = memberProfileIds(for: groupId)
        return profiles.filter { ids.contains($0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func createGroup(name: String, appState: AppState) async {
        guard let account = appState.currentAccount else { return }
        do {
            let group = try await appState.profileGroupRepository.createGroup(accountId: account.id, name: name)
            groups.append(group)
            groups.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            NotificationCenter.default.post(name: .profileGroupsDidChange, object: nil)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func renameGroup(id: UUID, name: String, appState: AppState) async {
        do {
            let updated = try await appState.profileGroupRepository.updateGroup(id: id, name: name)
            if let idx = groups.firstIndex(where: { $0.id == id }) {
                groups[idx] = updated
            }
            groups.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            NotificationCenter.default.post(name: .profileGroupsDidChange, object: nil)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteGroup(id: UUID, appState: AppState) async {
        do {
            try await appState.profileGroupRepository.deleteGroup(id: id)
            groups.removeAll { $0.id == id }
            allMembers.removeAll { $0.groupId == id }
            NotificationCenter.default.post(name: .profileGroupsDidChange, object: nil)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setGroupMembers(groupId: UUID, profileIds: Set<UUID>, appState: AppState) async {
        do {
            try await appState.profileGroupRepository.setGroupMembers(groupId: groupId, profileIds: Array(profileIds))
            // Reload members
            if let account = appState.currentAccount {
                allMembers = try await appState.profileGroupRepository.getMembersForAllGroups(accountId: account.id)
            }
            NotificationCenter.default.post(name: .profileGroupsDidChange, object: nil)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
