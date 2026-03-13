import SwiftUI

// MARK: - Sharing Preferences View
/// Standalone view for managing what a connected user can see on your profile.
/// Shown from the Profile Detail screen for synced (connected) profiles.
///
/// Supports bidirectional role management:
/// - Inviter sees: "Their Role in Your Account" (editable)
/// - Acceptor sees: "Your Role in Their Account" (read-only) + "Their Role in Your Account" (editable)
struct SharingPreferencesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    let profile: Profile
    let onDismiss: () -> Void

    @State private var sharingPreferences: [SharingCategoryKey: Bool] = [:]
    @State private var isSharingLoading: SharingCategoryKey? = nil
    @State private var myPrimaryProfileId: UUID? = nil
    @State private var errorMessage: String?
    @State private var showUpgradePrompt = false

    // Role management state — "their role in MY account"
    @State private var theirRoleInMyAccount: MemberRole?
    @State private var theirMemberIdInMyAccount: UUID?
    @State private var canEditTheirRole = false
    @State private var isTheirRoleLoading = false

    // Role display state — "my role in THEIR account" (read-only for acceptor)
    @State private var myRoleInTheirAccount: MemberRole?

    // Sync context
    @State private var iAmInviter = false
    @State private var syncRecord: ProfileSync?
    @State private var connectedUserName: String = ""

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
                    // MARK: - Role Sections

                    // For acceptor: show their read-only role in inviter's account first
                    if !iAmInviter, let myRole = myRoleInTheirAccount {
                        myRoleInfoSection(role: myRole)
                    }

                    // Editable role section: "Their Role in Your Account"
                    if let theirRole = theirRoleInMyAccount {
                        editableRoleSection(currentRole: theirRole)
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                    }

                    // MARK: - Sharing Preferences Section

                    VStack(alignment: .leading, spacing: 8) {
                        Text("SHARING PREFERENCES")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        Text("Control what \(connectedUserName) can see on your profile. Turning off a category will hide that data from this user.")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 8)

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
            connectedUserName = profile.preferredName ?? profile.fullName
            await loadSyncContext()
            await loadMyPrimaryProfile()
            await loadSharingPreferences()
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
        }
    }

    // MARK: - Role UI Components

    /// Read-only info section showing the current user's role in the connected user's account
    @ViewBuilder
    private func myRoleInfoSection(role: MemberRole) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR ROLE IN THEIR ACCOUNT")
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            HStack {
                Image(systemName: "person.badge.shield.checkmark")
                    .font(.system(size: 16))
                    .foregroundColor(appAccentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(role.displayName)
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)
                    Text(role.description)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.cardBackgroundSoft)
            .cornerRadius(AppDimensions.buttonCornerRadius)

            Text("\(connectedUserName) controls this role. Contact them if you need different access.")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
        }
        .padding(.top, 8)
    }

    /// Editable role selector for the connected user's role in the current user's account
    @ViewBuilder
    private func editableRoleSection(currentRole: MemberRole) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(iAmInviter ? "\(connectedUserName.uppercased())'S ROLE IN YOUR ACCOUNT" : "THEIR ROLE IN YOUR ACCOUNT")
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            if !iAmInviter {
                Text("Grant \(connectedUserName) access to help manage your account.")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            ForEach([MemberRole.admin, .helper, .viewer], id: \.self) { role in
                Button {
                    guard canEditTheirRole else {
                        errorMessage = "You don't have permission to change roles."
                        return
                    }
                    if role != .viewer && !hasFamilyAccess {
                        showUpgradePrompt = true
                    } else {
                        Task { await updateTheirRole(to: role) }
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
                        if isTheirRoleLoading {
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
                .disabled(isTheirRoleLoading)
            }
        }
        .padding(.top, 8)
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

    /// Load sync context to determine inviter/acceptor relationship and set up both role sections
    private func loadSyncContext() async {
        guard let connectedUserId = profile.linkedUserId ?? profile.sourceUserId,
              let syncConnectionId = profile.syncConnectionId,
              let myAccountId = appState.currentAccount?.id,
              let myUserId = await SupabaseManager.shared.currentUserId else { return }

        do {
            guard let sync = try await appState.profileSyncRepository.getSyncById(id: syncConnectionId) else { return }
            syncRecord = sync
            iAmInviter = sync.isInviter(myUserId)

            if iAmInviter {
                // I'm the inviter — the connected user (acceptor) is a member of MY account
                // Load their role in my account (editable)
                if let member = try await appState.accountRepository.getAccountMember(accountId: sync.inviterAccountId, userId: connectedUserId) {
                    await MainActor.run {
                        theirRoleInMyAccount = member.role
                        theirMemberIdInMyAccount = member.id
                        canEditTheirRole = true
                    }
                }
            } else {
                // I'm the acceptor
                // 1. Load MY role in THEIR account (read-only display)
                if let myMember = try await appState.accountRepository.getAccountMember(accountId: sync.inviterAccountId, userId: myUserId) {
                    await MainActor.run {
                        myRoleInTheirAccount = myMember.role
                    }
                }

                // 2. Load THEIR role in MY account (editable — bidirectional)
                if let theirMember = try await appState.accountRepository.getAccountMember(accountId: myAccountId, userId: connectedUserId) {
                    await MainActor.run {
                        theirRoleInMyAccount = theirMember.role
                        theirMemberIdInMyAccount = theirMember.id
                        canEditTheirRole = true
                    }
                }
            }
        } catch {
            #if DEBUG
            print("Failed to load sync context: \(error)")
            #endif
        }
    }

    private func updateTheirRole(to newRole: MemberRole) async {
        guard let memberId = theirMemberIdInMyAccount,
              let connectedUserId = connectedUserId else { return }

        isTheirRoleLoading = true
        do {
            let updated = try await appState.accountRepository.updateMemberRole(memberId: memberId, role: newRole)
            await MainActor.run {
                theirRoleInMyAccount = updated.role
                isTheirRoleLoading = false
                errorMessage = nil
            }

            // Send push notification to the connected user
            let accountName = appState.currentAccount?.displayName ?? "your account"
            let myName: String
            if let accountId = appState.currentAccount?.id,
               let primaryProfile = try? await appState.profileRepository.getPrimaryProfile(accountId: accountId) {
                myName = primaryProfile.preferredName ?? primaryProfile.fullName
            } else {
                myName = "Someone"
            }

            await PushNotificationService.shared.sendRoleChangeNotification(
                targetUserId: connectedUserId,
                newRole: newRole,
                accountName: accountName,
                changedByName: myName
            )
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update role: \(error.localizedDescription)"
                isTheirRoleLoading = false
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
