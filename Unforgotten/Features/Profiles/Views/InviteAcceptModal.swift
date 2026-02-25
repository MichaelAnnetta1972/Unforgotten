import SwiftUI

// MARK: - Invite Accept Modal
/// Modal presented when an authenticated user taps an invitation deep link.
/// This is the only way authenticated users can accept invites (no Settings path).
struct InviteAcceptModal: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    @State private var isLoading = true
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var invitation: AccountInvitation?
    @State private var accountName: String = ""
    @State private var showSuccess = false
    @State private var showDuplicateConfirm = false
    @State private var duplicateProfile: Profile?

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
            } else if let invitation = invitation {
                // Invitation details
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
                    PrimaryButton(title: "Join Account", isLoading: isJoining) {
                        Task { await joinAccount(invitation: invitation) }
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

            } else {
                // Error state
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
        }
        .background(Color.appBackground)
        .task {
            await validateCode()
        }
        .alert("Account Joined!", isPresented: $showSuccess) {
            Button("OK") {
                dismissModal()
            }
        } message: {
            Text("You have successfully joined \"\(accountName)\". You can switch to this account from Settings.")
        }
        .alert("Existing Profile Found", isPresented: $showDuplicateConfirm) {
            Button("Use Existing") {
                guard let invitation = invitation else { return }
                Task { await joinAccount(invitation: invitation, existingProfileId: duplicateProfile?.id) }
            }
            Button("Create New", role: .cancel) {
                guard let invitation = invitation else { return }
                Task { await joinAccount(invitation: invitation) }
            }
        } message: {
            if let profile = duplicateProfile {
                Text("A profile for \"\(profile.fullName)\" already exists in this account. Would you like to link to it? The existing profile will be updated with your information.")
            }
        }
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
                    let account = try await appState.accountRepository.getAccount(id: inv.accountId)
                    await MainActor.run {
                        self.invitation = inv
                        self.accountName = account.displayName
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
    private func joinAccount(invitation: AccountInvitation, existingProfileId: UUID? = nil) async {
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
                    if (primaryProfile.linkedUserId ?? primaryProfile.sourceUserId) == userId {
                        acceptorProfileId = primaryProfile.id
                    }
                }
            }

            // Check for duplicate profiles if we haven't already
            if existingProfileId == nil {
                if let profileId = acceptorProfileId, let acceptorProfile = try? await appState.profileRepository.getProfile(id: profileId) {
                    let matches = try await appState.profileRepository.findMatchingProfiles(
                        accountId: invitation.accountId,
                        name: acceptorProfile.fullName,
                        email: acceptorProfile.email
                    )
                    if let match = matches.first {
                        await MainActor.run {
                            duplicateProfile = match
                            showDuplicateConfirm = true
                            isJoining = false
                        }
                        return
                    }
                }
            }

            // Accept with sync
            do {
                let syncResult = try await appState.invitationRepository.acceptInvitationWithSync(
                    invitation: invitation,
                    userId: userId,
                    acceptorProfileId: acceptorProfileId,
                    acceptorAccountId: acceptorAccountId,
                    existingProfileId: existingProfileId
                )

                if let syncId = syncResult.syncId {
                    NotificationCenter.default.post(
                        name: .profileSyncDidChange,
                        object: nil,
                        userInfo: ["syncId": syncId, "action": "created"]
                    )
                }
            } catch {
                #if DEBUG
                print("Sync RPC failed: \(error), falling back to regular acceptance")
                #endif
                try await appState.invitationRepository.acceptInvitation(invitation: invitation, userId: userId)
            }

            // Reload data
            await appState.loadAccountData()

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
