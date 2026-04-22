import SwiftUI

// MARK: - Invite Accept Modal
/// Modal presented when an authenticated user taps an invitation deep link.
/// This is the only way authenticated users can accept invites (no Settings path).
/// Flow: Validate → Show invitation → Show sharing preferences → Accept with sync
struct InviteAcceptModal: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    @State private var isLoading = true
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var invitation: AccountInvitation?
    @State private var accountName: String = ""
    @State private var showSuccess = false
    @State private var newProfileCreated = false
    @State private var showSharingPreferences = false
    @State private var sharingPreferences: [SharingCategoryKey: Bool] = {
        var prefs: [SharingCategoryKey: Bool] = [:]
        for category in SharingCategoryKey.allCases {
            prefs[category] = category != .importantAccounts
        }
        return prefs
    }()

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Spacer()
                Button {
                    dismissModal()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.top, 16)

            if isLoading {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: appAccentColor))
                Text("Validating invite code...")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                Spacer()
            } else if showSharingPreferences, let invitation = invitation {
                // Sharing preferences screen
                sharingPreferencesContent(invitation: invitation)
            } else if let invitation = invitation {
                // Invitation details
                invitationContent(invitation: invitation)
            } else {
                // Error state
                errorContent
            }
        }
        .background(Color.appBackground)
        .task {
            await validateCode()
        }
        .alert("Connected!", isPresented: $showSuccess) {
            Button("OK") {
                dismissModal()
            }
        } message: {
            if newProfileCreated {
                Text("You are now connected with \"\(accountName)\" on Unforgotten.\n\nNo matching profile was found, so a new profile was created for you in their account.")
            } else {
                Text("You are now connected with \"\(accountName)\" on Unforgotten.")
            }
        }
    }

    // MARK: - Invitation Content
    @ViewBuilder
    private func invitationContent(invitation: AccountInvitation) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(appAccentColor)

            Text("You've been invited!")
                .font(.appTitle)
                .foregroundColor(.textPrimary)

            Text("Join \"\(accountName)\" on Unforgotten")
                .font(.appBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Text("You'll be added as a Viewer with access to shared information.")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppDimensions.screenPadding)
        }

        Spacer()

        if let error = errorMessage {
            Text(error)
                .font(.appCaption)
                .foregroundColor(.medicalRed)
                .padding(.horizontal, AppDimensions.screenPadding)
        }

        // Action buttons
        VStack(spacing: 12) {
            PrimaryButton(title: "Join Account", isLoading: false) {
                withAnimation {
                    showSharingPreferences = true
                }
            }

            Button {
                dismissModal()
            } label: {
                Text("Cancel")
                    .font(.appBodyMedium)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, AppDimensions.screenPadding)
        .padding(.bottom, 32)
    }

    // MARK: - Sharing Preferences Content
    @ViewBuilder
    private func sharingPreferencesContent(invitation: AccountInvitation) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 36))
                        .foregroundColor(appAccentColor)

                    Text("Your Sharing Preferences")
                        .font(.appTitle)
                        .foregroundColor(.textPrimary)

                    Text("Choose what information from your profile you'd like to share with \"\(accountName)\". You can change these later.")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)

                // Sharing Toggles
                VStack(alignment: .leading, spacing: 12) {
                    Text("SHARING PREFERENCES")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    ForEach(SharingCategoryKey.allCases, id: \.self) { category in
                        SharingToggleRow(
                            category: category,
                            isEnabled: Binding(
                                get: { sharingPreferences[category] ?? true },
                                set: { sharingPreferences[category] = $0 }
                            ),
                            accentColor: appAccentColor
                        )
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.appCaption)
                        .foregroundColor(.medicalRed)
                }

                PrimaryButton(title: "Connect", isLoading: isJoining) {
                    Task { await joinAccount(invitation: invitation) }
                }

                Button {
                    withAnimation {
                        showSharingPreferences = false
                    }
                } label: {
                    Text("Back")
                        .font(.appBodyMedium)
                        .foregroundColor(.textSecondary)
                }

                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
        }
    }

    // MARK: - Error Content
    @ViewBuilder
    private var errorContent: some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.medicalRed)

            Text(errorMessage ?? "Invalid or expired invite code.")
                .font(.appBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        Spacer()

        Button {
            dismissModal()
        } label: {
            Text("Close")
                .font(.appBodyMedium)
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.buttonCornerRadius)
        }
        .padding(.horizontal, AppDimensions.screenPadding)
        .padding(.bottom, 32)
    }

    // MARK: - Validate the pending invite code
    private func validateCode() async {
        guard let code = appState.pendingInviteCode, !code.isEmpty else {
            errorMessage = "No invite code found."
            isLoading = false
            return
        }

        do {
            if let inv = try await appState.invitationRepository.getInvitationByCode(code) {
                if inv.isActive {
                    // Use RPC to get account name (bypasses RLS for non-members)
                    var name = "their account"
                    if let rpcName = try? await appState.invitationRepository.getAccountNameForInvitation(code: code) {
                        name = rpcName
                    }
                    await MainActor.run {
                        self.invitation = inv
                        self.accountName = name
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "This invitation has expired or is no longer valid."
                        isLoading = false
                    }
                }
            } else {
                await MainActor.run {
                    errorMessage = "We couldn't find that invite code. Please check and try again."
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Something went wrong: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    // MARK: - Join the account
    private func joinAccount(invitation: AccountInvitation) async {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            errorMessage = "You must be signed in."
            return
        }

        isJoining = true
        errorMessage = nil

        do {
            // Get acceptor's info for profile sync
            let acceptorAccountId = appState.currentAccount?.id
            var acceptorProfileId: UUID? = nil
            if let account = appState.currentAccount {
                if let primaryProfile = try? await appState.profileRepository.getPrimaryProfile(accountId: account.id) {
                    // Use the primary profile if it belongs to this user, or if it's the only primary profile
                    let linkedId = primaryProfile.linkedUserId ?? primaryProfile.sourceUserId
                    if linkedId == userId || linkedId == nil {
                        acceptorProfileId = primaryProfile.id
                    }
                }
            }

            // Accept with sync, passing the acceptor's sharing preferences
            #if DEBUG
            print("🔗 Accept: userId=\(userId), acceptorProfileId=\(acceptorProfileId?.uuidString ?? "nil"), acceptorAccountId=\(acceptorAccountId?.uuidString ?? "nil")")
            #endif
            do {
                let syncResult = try await appState.invitationRepository.acceptInvitationWithSync(
                    invitation: invitation,
                    userId: userId,
                    acceptorProfileId: acceptorProfileId,
                    acceptorAccountId: acceptorAccountId,
                    acceptorSharingPreferences: sharingPreferences
                )

                #if DEBUG
                print("🔗 Sync result: success=\(syncResult.success), syncId=\(syncResult.syncId?.uuidString ?? "nil"), debug=\(syncResult.debug ?? "none")")
                print("🔗   inviterSyncedProfileId=\(syncResult.inviterSyncedProfileId?.uuidString ?? "nil")")
                print("🔗   acceptorSyncedProfileId=\(syncResult.acceptorSyncedProfileId?.uuidString ?? "nil")")
                #endif

                if !syncResult.success {
                    #if DEBUG
                    print("⚠️ Sync RPC returned success=false, debug: \(syncResult.debug ?? "no debug info")")
                    #endif
                }

                newProfileCreated = syncResult.newProfileCreated ?? false

                if let syncId = syncResult.syncId {
                    NotificationCenter.default.post(
                        name: .profileSyncDidChange,
                        object: nil,
                        userInfo: ["syncId": syncId, "action": "created"]
                    )
                }
            } catch {
                #if DEBUG
                print("❌ Sync RPC failed: \(error)")
                print("❌ Falling back to regular acceptance (NO profile sync)")
                #endif
                // Fallback to basic acceptance without sync
                try await appState.invitationRepository.acceptInvitation(invitation: invitation, userId: userId)
            }

            // Reload account data, then force-refresh profiles so the new synced profiles
            // created by the RPC are pulled into the local cache and the UI re-renders.
            await appState.loadAccountData()
            if let accountId = acceptorAccountId {
                _ = try? await appState.profileRepository.refreshProfiles(accountId: accountId)
            }
            if let accountId = appState.currentAccount?.id, accountId != acceptorAccountId {
                _ = try? await appState.profileRepository.refreshProfiles(accountId: accountId)
            }
            NotificationCenter.default.post(name: .profilesDidChange, object: nil)

            await MainActor.run {
                isJoining = false
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                isJoining = false
                errorMessage = "Failed to join account: \(error.localizedDescription)"
            }
        }
    }

    private func dismissModal() {
        appState.pendingInviteCode = nil
        appState.showInviteAcceptModal = false
    }
}
