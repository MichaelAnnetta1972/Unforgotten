import SwiftUI

// MARK: - Sharing Preferences View
/// Standalone view for managing what a connected user can see on your profile.
/// Shown from the Profile Detail screen for synced (connected) profiles.
struct SharingPreferencesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    let profile: Profile
    let onDismiss: () -> Void

    @State private var sharingPreferences: [SharingCategoryKey: Bool] = [:]
    @State private var isSharingLoading: SharingCategoryKey? = nil
    @State private var myPrimaryProfileId: UUID? = nil
    @State private var memberRole: MemberRole?
    @State private var accountMemberId: UUID?
    @State private var isRoleLoading = false
    @State private var errorMessage: String?
    @State private var showUpgradePrompt = false
    /// Whether the current user's subscription supports assigning Admin/Helper roles
    private var hasFamilyAccess: Bool {
        PremiumLimitsManager.shared.hasFamilyAccess(appState: appState)
    }

    /// The target user ID for sharing preferences (the connected user behind this synced profile)
    private var connectedUserId: UUID? {
        profile.linkedUserId ?? profile.sourceUserId
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.cardBackground)
                        .clipShape(Circle())
                }

                Spacer()

                Text("Sharing Preferences")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Invisible spacer to balance the X button
                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackgroundLight)

            ScrollView {
                VStack(spacing: 16) {
                    // Role selector
                    if let currentRole = memberRole {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MEMBER ROLE")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            ForEach([MemberRole.admin, .helper, .viewer], id: \.self) { role in
                                Button {
                                    // Admin and Helper require Family Plus subscription
                                    if role != .viewer && !hasFamilyAccess {
                                        showUpgradePrompt = true
                                    } else {
                                        Task { await updateMemberRole(to: role) }
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(role.displayName)
                                                .font(.appBodyMedium)
                                                .foregroundColor(.textPrimary)
                                            Text(role.description)
                                                .font(.appCaption)
                                                .foregroundColor(.textSecondary)
                                        }
                                        Spacer()
                                        if isRoleLoading {
                                            ProgressView()
                                                .tint(.textSecondary)
                                        } else {
                                            Image(systemName: currentRole == role ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(currentRole == role ? appAccentColor : .textSecondary)
                                        }
                                    }
                                    .padding()
                                    .background(currentRole == role ? appAccentColor.opacity(0.1) : Color.cardBackgroundSoft)
                                    .cornerRadius(AppDimensions.buttonCornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                                            .stroke(currentRole == role ? appAccentColor : Color.clear, lineWidth: 2)
                                    )
                                }
                                .disabled(isRoleLoading)
                            }
                        }
                        .padding(.top, 8)
                    }

                    // Explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SHARING PREFERENCES")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        Text("Control what \(profile.preferredName ?? profile.fullName) can see on your profile. Turning off a category will hide that data from this user.")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 8)

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                    }

                    // Category toggles
                    ForEach(SharingCategoryKey.allCases, id: \.self) { category in
                        HStack(spacing: 12) {
                            Image(systemName: iconForCategory(category))
                                .font(.system(size: 16))
                                .foregroundColor(appAccentColor)
                                .frame(width: 32, height: 32)
                                .background(appAccentColor.opacity(0.15))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.displayName)
                                    .font(.appBodyMedium)
                                    .foregroundColor(.textPrimary)

                                Text(category.description)
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            if isSharingLoading == category {
                                ProgressView()
                                    .tint(.textSecondary)
                            } else {
                                Toggle("", isOn: Binding(
                                    get: { sharingPreferences[category] ?? true },
                                    set: { newValue in
                                        toggleSharingPreference(category: category, newValue: newValue)
                                    }
                                ))
                                .tint(appAccentColor)
                                .labelsHidden()
                            }
                        }
                        .padding(AppDimensions.cardPadding)
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                    }

                    Spacer()
                        .frame(height: 40)
                }
                .padding(AppDimensions.screenPadding)
            }
        }
        .background(Color.appBackgroundLight)
        .task {
            await loadMemberRole()
            await loadMyPrimaryProfile()
            await loadSharingPreferences()
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
        }
    }

    // MARK: - Helpers

    private func iconForCategory(_ category: SharingCategoryKey) -> String {
        switch category {
        case .profileFields: return "person.text.rectangle"
        case .medical: return "cross.case"
        case .giftIdea: return "gift"
        case .clothing: return "tshirt"
        case .hobby: return "star"
        case .activityIdea: return "figure.run"
        case .importantAccounts: return "key.fill"
        }
    }

    private func loadMyPrimaryProfile() async {
        guard let accountId = appState.currentAccount?.id else { return }
        do {
            if let primaryProfile = try await appState.profileRepository.getPrimaryProfile(accountId: accountId) {
                myPrimaryProfileId = primaryProfile.id
            }
        } catch {
            #if DEBUG
            print("Failed to load primary profile: \(error)")
            #endif
        }
    }

    private func loadMemberRole() async {
        guard let connectedUserId = profile.linkedUserId ?? profile.sourceUserId,
              let syncConnectionId = profile.syncConnectionId,
              let myAccountId = appState.currentAccount?.id else { return }

        do {
            // The connected user should be a member of MY account (reciprocal membership)
            if let member = try await appState.accountRepository.getAccountMember(accountId: myAccountId, userId: connectedUserId) {
                await MainActor.run {
                    memberRole = member.role
                    accountMemberId = member.id
                }
                return
            }

            // Fallback: check the inviter's account (for connections created before reciprocal membership)
            guard let sync = try await appState.profileSyncRepository.getSyncById(id: syncConnectionId) else { return }

            let fallbackAccountId = sync.inviterAccountId
            if fallbackAccountId != myAccountId,
               let member = try await appState.accountRepository.getAccountMember(accountId: fallbackAccountId, userId: connectedUserId) {
                await MainActor.run {
                    memberRole = member.role
                    accountMemberId = member.id
                }
            }
        } catch {
            #if DEBUG
            print("Failed to load member role: \(error)")
            #endif
        }
    }

    private func updateMemberRole(to newRole: MemberRole) async {
        guard let memberId = accountMemberId else { return }

        isRoleLoading = true
        do {
            let updated = try await appState.accountRepository.updateMemberRole(memberId: memberId, role: newRole)
            await MainActor.run {
                memberRole = updated.role
                isRoleLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update role: \(error.localizedDescription)"
                isRoleLoading = false
            }
        }
    }

    private func loadSharingPreferences() async {
        guard let sourceProfileId = myPrimaryProfileId,
              let targetUserId = connectedUserId else { return }
        do {
            let prefs = try await appState.profileSharingPreferencesRepository.getPreferences(
                profileId: sourceProfileId,
                targetUserId: targetUserId
            )
            var dict: [SharingCategoryKey: Bool] = [:]
            for pref in prefs {
                if let key = SharingCategoryKey(rawValue: pref.category) {
                    dict[key] = pref.isShared
                }
            }
            sharingPreferences = dict
        } catch {
            #if DEBUG
            print("Failed to load sharing preferences: \(error)")
            #endif
        }
    }

    private func toggleSharingPreference(category: SharingCategoryKey, newValue: Bool) {
        guard let targetUserId = connectedUserId else {
            errorMessage = "Unable to identify connected user"
            return
        }

        sharingPreferences[category] = newValue
        isSharingLoading = category

        Task {
            do {
                if myPrimaryProfileId == nil {
                    await loadMyPrimaryProfile()
                }
                guard let sourceProfileId = myPrimaryProfileId else {
                    sharingPreferences[category] = !newValue
                    errorMessage = "Unable to find your primary profile"
                    isSharingLoading = nil
                    return
                }

                try await appState.profileSharingPreferencesRepository.updatePreference(
                    profileId: sourceProfileId,
                    category: category,
                    isShared: newValue,
                    targetUserId: targetUserId
                )
                errorMessage = nil
                NotificationCenter.default.post(
                    name: .profileSharingPreferencesDidChange,
                    object: nil,
                    userInfo: ["profileId": sourceProfileId, "category": category.rawValue, "targetUserId": targetUserId.uuidString]
                )
            } catch {
                sharingPreferences[category] = !newValue
                errorMessage = "Failed to update sharing: \(error.localizedDescription)"
            }
            isSharingLoading = nil
        }
    }
}
