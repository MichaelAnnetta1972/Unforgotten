import SwiftUI

// MARK: - Group Assignment Sheet
/// Sheet shown when tapping the group icon on a profile row.
/// Allows assigning/removing the profile from existing groups or creating a new group.
struct GroupAssignmentSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let profile: Profile

    @State private var groups: [ProfileGroup] = []
    @State private var allMembers: [ProfileGroupMember] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showCreateGroup = false
    @State private var newGroupName = ""

    /// Which groups this profile currently belongs to
    private var assignedGroupIds: Set<UUID> {
        Set(allMembers.filter { $0.profileId == profile.id }.map { $0.groupId })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundLight.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        if isLoading {
                            ProgressView()
                                .tint(appAccentColor)
                                .padding(.top, 40)
                        } else if groups.isEmpty {
                            emptyState
                        } else {
                            groupSelectionList
                        }
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Groups for \(profile.displayName)")
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
                        await createGroupAndAssign(name: newGroupName.trimmingCharacters(in: .whitespaces))
                        newGroupName = ""
                    }
                }
            } message: {
                Text("Create a new group and add \(profile.displayName) to it.")
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 40))
                .foregroundColor(.textSecondary)

            Text("No Groups Yet")
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Text("Create a group to organize your family and friends.")
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
        .padding(.top, 40)
    }

    // MARK: - Group Selection List
    private var groupSelectionList: some View {
        VStack(spacing: AppDimensions.cardSpacing) {
            Text("Tap a group to add or remove \(profile.displayName).")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(groups) { group in
                let isAssigned = assignedGroupIds.contains(group.id)

                Button {
                    Task {
                        await toggleGroup(group, isCurrentlyAssigned: isAssigned)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 16))
                            .foregroundColor(appAccentColor)
                            .frame(width: 36, height: 36)
                            .background(appAccentColor.opacity(0.15))
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.name)
                                .font(.appBody)
                                .foregroundColor(.textPrimary)

                            let memberCount = allMembers.filter { $0.groupId == group.id }.count
                            Text("\(memberCount) member\(memberCount == 1 ? "" : "s")")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        Image(systemName: isAssigned ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundColor(isAssigned ? appAccentColor : .textSecondary)
                    }
                    .padding(AppDimensions.cardPadding)
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.cardCornerRadius)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Actions

    private func loadData() async {
        guard let account = appState.currentAccount else {
            isLoading = false
            return
        }

        do {
            groups = try await appState.profileGroupRepository.getGroups(accountId: account.id)
            if !groups.isEmpty {
                allMembers = try await appState.profileGroupRepository.getMembersForAllGroups(accountId: account.id)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func toggleGroup(_ group: ProfileGroup, isCurrentlyAssigned: Bool) async {
        do {
            if isCurrentlyAssigned {
                try await appState.profileGroupRepository.removeMemberFromGroup(groupId: group.id, profileId: profile.id)
                allMembers.removeAll { $0.groupId == group.id && $0.profileId == profile.id }
            } else {
                let member = try await appState.profileGroupRepository.addMemberToGroup(groupId: group.id, profileId: profile.id)
                allMembers.append(member)
            }
            NotificationCenter.default.post(name: .profileGroupsDidChange, object: nil)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func createGroupAndAssign(name: String) async {
        guard let account = appState.currentAccount else { return }

        do {
            let group = try await appState.profileGroupRepository.createGroup(accountId: account.id, name: name)
            let member = try await appState.profileGroupRepository.addMemberToGroup(groupId: group.id, profileId: profile.id)
            groups.append(group)
            groups.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            allMembers.append(member)
            NotificationCenter.default.post(name: .profileGroupsDidChange, object: nil)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
