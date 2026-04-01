import SwiftUI

// MARK: - Family Member Info
/// Lightweight struct representing a connected family member for sharing
struct FamilyMemberInfo: Identifiable {
    let id: UUID // profile ID
    let userId: UUID // the connected user's auth ID
    let displayName: String
    let photoUrl: String?
}

// MARK: - Family Sharing Sheet
/// A sheet that allows users to select which family members can see an event in the family calendar
struct FamilySharingSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    @Binding var isEnabled: Bool
    @Binding var selectedMemberIds: Set<UUID>
    var onDismiss: (() -> Void)? = nil

    @State private var members: [FamilyMemberInfo] = []
    @State private var groups: [ProfileGroup] = []
    @State private var groupMembers: [ProfileGroupMember] = []
    @State private var allProfiles: [Profile] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var expandedGroupIds: Set<UUID> = []

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                            )
                    }

                    Spacer()

                    Text("Share to Family")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(appAccentColor)
                            )
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        // Enable sharing toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add to Family Calendar")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Text("Share this event with family members")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            Toggle("", isOn: $isEnabled)
                                .labelsHidden()
                                .tint(appAccentColor)
                        }
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)

                        // Member selection (shown when enabled)
                        if isEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Who can see this event?")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                                    .padding(.horizontal, 4)

                                if isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .tint(appAccentColor)
                                        Spacer()
                                    }
                                    .padding(.vertical, 20)
                                } else if let errorMessage = error {
                                    Text(errorMessage)
                                        .font(.appCaption)
                                        .foregroundColor(.medicalRed)
                                        .padding()
                                } else if members.isEmpty {
                                    Text("No other family members to share with.")
                                        .font(.appBody)
                                        .foregroundColor(.textSecondary)
                                        .padding()
                                } else {
                                    // Groups section
                                    if !groups.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Groups")
                                                .font(.appCaption)
                                                .foregroundColor(.textSecondary)
                                                .padding(.horizontal, 4)

                                            ForEach(groups) { group in
                                                FamilyGroupCard(
                                                    group: group,
                                                    memberInfos: groupMemberInfos(for: group.id),
                                                    isExpanded: expandedGroupIds.contains(group.id),
                                                    allSelected: isGroupFullySelected(group.id),
                                                    accentColor: appAccentColor,
                                                    onToggleExpand: {
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                            if expandedGroupIds.contains(group.id) {
                                                                expandedGroupIds.remove(group.id)
                                                            } else {
                                                                expandedGroupIds.insert(group.id)
                                                            }
                                                        }
                                                    },
                                                    onToggleGroup: {
                                                        toggleGroup(group.id)
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.bottom, 8)
                                    }

                                    // Quick actions
                                    HStack(spacing: 12) {
                                        Text("Individual Members")
                                            .font(.appCaption)
                                            .foregroundColor(.textSecondary)

                                        Spacer()

                                        Button {
                                            selectedMemberIds = Set(members.map { $0.userId })
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
                                            selectedMemberIds = []
                                        } label: {
                                            Text("Clear")
                                                .font(.appCaption)
                                                .foregroundColor(.textPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.cardBackgroundSoft)
                                                .cornerRadius(AppDimensions.pillCornerRadius)
                                        }
                                    }

                                    // Member list
                                    ForEach(members) { member in
                                        FamilyMemberRow(
                                            member: member,
                                            isSelected: selectedMemberIds.contains(member.userId),
                                            accentColor: appAccentColor
                                        ) {
                                            toggleMember(member.userId)
                                        }
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .background(Color.appBackground)
            .navigationBarHidden(true)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackgroundLight)
        .toolbarBackground(.clear, for: .navigationBar)
        .containerBackground(.clear, for: .navigation)
        .task {
            await loadMembers()
        }
    }

    // MARK: - Actions

    private func toggleMember(_ userId: UUID) {
        if selectedMemberIds.contains(userId) {
            selectedMemberIds.remove(userId)
        } else {
            selectedMemberIds.insert(userId)
        }
    }

    /// Get the FamilyMemberInfo objects for profiles in a group (only those that are connected members)
    private func groupMemberInfos(for groupId: UUID) -> [FamilyMemberInfo] {
        let profileIds = Set(groupMembers.filter { $0.groupId == groupId }.map { $0.profileId })
        return members.filter { member in
            // Match member's profile ID (from FamilyMemberInfo.id which is the profile ID)
            profileIds.contains(member.id)
        }
    }

    /// Check if all members of a group are currently selected
    private func isGroupFullySelected(_ groupId: UUID) -> Bool {
        let infos = groupMemberInfos(for: groupId)
        guard !infos.isEmpty else { return false }
        return infos.allSatisfy { selectedMemberIds.contains($0.userId) }
    }

    /// Toggle all members of a group on or off
    private func toggleGroup(_ groupId: UUID) {
        let infos = groupMemberInfos(for: groupId)
        if isGroupFullySelected(groupId) {
            // Deselect all group members
            for info in infos {
                selectedMemberIds.remove(info.userId)
            }
        } else {
            // Select all group members
            for info in infos {
                selectedMemberIds.insert(info.userId)
            }
        }
    }

    private func loadMembers() async {
        guard let account = appState.currentAccount else {
            error = "No account found"
            isLoading = false
            return
        }

        do {
            // Load all profiles in the account
            let loadedProfiles = try await appState.profileRepository.getProfiles(accountId: account.id)
            allProfiles = loadedProfiles

            // Filter to connected/synced profiles (profiles that represent other users)
            // These have sourceUserId set and are not local-only
            let connectedProfiles = loadedProfiles.filter { profile in
                let connectedUserId = profile.linkedUserId ?? profile.sourceUserId
                return connectedUserId != nil && !profile.isLocalOnly
            }

            // Build member info from connected profiles, deduplicating by userId
            var seenUserIds = Set<UUID>()
            var memberInfos: [FamilyMemberInfo] = []

            for profile in connectedProfiles {
                guard let userId = profile.linkedUserId ?? profile.sourceUserId else { continue }
                guard !seenUserIds.contains(userId) else { continue }
                seenUserIds.insert(userId)

                memberInfos.append(FamilyMemberInfo(
                    id: profile.id,
                    userId: userId,
                    displayName: profile.displayName,
                    photoUrl: profile.photoUrl
                ))
            }

            members = memberInfos.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            // Load groups and their members
            groups = try await appState.profileGroupRepository.getGroups(accountId: account.id)
            if !groups.isEmpty {
                groupMembers = try await appState.profileGroupRepository.getMembersForAllGroups(accountId: account.id)
            }

            // Filter groups to only those that have at least one connected member
            groups = groups.filter { group in
                !groupMemberInfos(for: group.id).isEmpty
            }

            isLoading = false
        } catch {
            self.error = "Failed to load members: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Family Member Row
struct FamilyMemberRow: View {
    let member: FamilyMemberInfo
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(accentColor.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(member.displayName.prefix(1).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(accentColor)
                    )

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? accentColor : .textSecondary)
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// MARK: - Family Group Card
/// A card representing a profile group in the sharing sheet, with expand/collapse to show members
struct FamilyGroupCard: View {
    let group: ProfileGroup
    let memberInfos: [FamilyMemberInfo]
    let isExpanded: Bool
    let allSelected: Bool
    let accentColor: Color
    let onToggleExpand: () -> Void
    let onToggleGroup: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Group select button
                Button(action: onToggleGroup) {
                    Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(allSelected ? accentColor : .textSecondary)
                }
                .buttonStyle(PlainButtonStyle())

                Image(systemName: "person.3.fill")
                    .font(.system(size: 14))
                    .foregroundColor(accentColor)
                    .frame(width: 32, height: 32)
                    .background(accentColor.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    Text("\(memberInfos.count) member\(memberInfos.count == 1 ? "" : "s")")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Expand/collapse
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(AppDimensions.cardPadding)

            // Expanded member list
            if isExpanded {
                Divider()
                    .background(Color.textMuted.opacity(0.3))

                VStack(spacing: 0) {
                    ForEach(memberInfos) { member in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(accentColor.opacity(0.3))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text(member.displayName.prefix(1).uppercased())
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(accentColor)
                                )

                            Text(member.displayName)
                                .font(.appCaption)
                                .foregroundColor(.textPrimary)

                            Spacer()
                        }
                        .padding(.horizontal, AppDimensions.cardPadding)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Preview
#Preview {
    FamilySharingSheet(
        isEnabled: .constant(true),
        selectedMemberIds: .constant([])
    )
    .environmentObject(AppState.forPreview())
}
