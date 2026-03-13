import SwiftUI

// MARK: - Join Account View
/// Allows authenticated users to enter an invite code and join another account
struct JoinAccountView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.sidePanelDismiss) private var sidePanelDismiss
    @Environment(\.appAccentColor) private var appAccentColor

    @State private var codeInput: String = ""
    @State private var isValidating = false
    @State private var isJoining = false
    @State private var validationError: String?
    @State private var invitation: AccountInvitation?
    @State private var accountName: String = ""
    @State private var showSuccess = false
    @State private var showDuplicateConfirm = false
    @State private var duplicateProfile: Profile?
    @FocusState private var isCodeFieldFocused: Bool

    /// Dismisses the view using side panel dismiss if available, otherwise standard dismiss
    private func dismissView() {
        if let sidePanelDismiss {
            sidePanelDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with Done button
            HStack {
                Text("Join an Account")
                    .font(.appTitle2)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("Done") {
                    dismissView()
                }
                .font(.appBody)
                .foregroundColor(appAccentColor)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(appAccentColor)

                        Text("Join an Account")
                            .font(.appTitle)
                            .foregroundColor(.textPrimary)

                        Text("Enter the invite code shared with you to connect with a family member or friend")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    if let invitation = invitation {
                        // Show invitation details
                        invitationDetailView(invitation: invitation)
                    } else {
                        // Code entry
                        codeEntryView
                    }

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.appBackground)
        .alert("Account Joined!", isPresented: $showSuccess) {
            Button("OK") {
                dismissView()
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

    // MARK: - Code Entry View
    private var codeEntryView: some View {
        VStack(spacing: 20) {
            // Code input field
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter your invite code", text: $codeInput)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 20)
                    .frame(height: AppDimensions.textFieldHeight)
                    .background(Color.cardBackground.opacity(0.8))
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(
                                validationError != nil ? Color.medicalRed :
                                    isCodeFieldFocused ? appAccentColor :
                                    Color.clear,
                                lineWidth: 2
                            )
                    )
                    .focused($isCodeFieldFocused)
                    .onChange(of: codeInput) { _, _ in
                        validationError = nil
                    }

                // Error message
                if let error = validationError {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 14))
                        Text(error)
                            .font(.appCaption)
                    }
                    .foregroundColor(.medicalRed)
                    .padding(.horizontal, 4)
                }
            }

            // Connect button
            Button(action: validateCode) {
                HStack {
                    if isValidating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Connect")
                            .font(.appBodyMedium)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDimensions.buttonHeight)
                .background(appAccentColor)
                .cornerRadius(AppDimensions.buttonCornerRadius)
            }
            .disabled(codeInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
        }
    }

    // MARK: - Invitation Detail View
    private func invitationDetailView(invitation: AccountInvitation) -> some View {
        VStack(spacing: 20) {
            // Account info card
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.badgeGreen)

                Text("You've been invited to join")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)

                Text(accountName)
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                Text("You'll be added as a \(invitation.role.displayName) with access to shared information.")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)

            if let error = validationError {
                Text(error)
                    .font(.appCaption)
                    .foregroundColor(.medicalRed)
            }

            // Action buttons
            VStack(spacing: 12) {
                PrimaryButton(title: "Join Account", isLoading: isJoining) {
                    Task { await joinAccount(invitation: invitation) }
                }

                Button {
                    // Reset to code entry
                    self.invitation = nil
                    self.accountName = ""
                    self.codeInput = ""
                    self.validationError = nil
                } label: {
                    Text("Cancel")
                        .font(.appBodyMedium)
                        .foregroundColor(.textSecondary)
                }
            }
        }
    }

    // MARK: - Validate Code
    private func validateCode() {
        let trimmedCode = codeInput.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmedCode.isEmpty else { return }

        isValidating = true
        validationError = nil
        isCodeFieldFocused = false

        Task {
            do {
                if let inv = try await appState.invitationRepository.getInvitationByCode(trimmedCode) {
                    if inv.isActive {
                        // Use RPC to get account name (bypasses RLS for non-members)
                        var name = "their account"
                        if let rpcName = try? await appState.invitationRepository.getAccountNameForInvitation(code: trimmedCode) {
                            name = rpcName
                        }
                        await MainActor.run {
                            self.invitation = inv
                            self.accountName = name
                            self.isValidating = false
                        }
                    } else {
                        await MainActor.run {
                            validationError = "This code has expired. Please ask for a new one."
                            isValidating = false
                        }
                    }
                } else {
                    await MainActor.run {
                        validationError = "We couldn't find that code. Please check and try again."
                        isValidating = false
                    }
                }
            } catch {
                await MainActor.run {
                    validationError = "Something went wrong. Please try again."
                    isValidating = false
                }
                #if DEBUG
                print("Error validating code: \(error)")
                #endif
            }
        }
    }

    // MARK: - Join Account
    private func joinAccount(invitation: AccountInvitation, existingProfileId: UUID? = nil) async {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            validationError = "You must be signed in."
            return
        }

        isJoining = true
        validationError = nil

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

            // Check for duplicate profiles if we haven't already
            if existingProfileId == nil {
                if let profileId = acceptorProfileId, let acceptorProfile = try? await appState.profileRepository.getProfile(id: profileId) {
                    let matches = try await appState.profileRepository.findMatchingProfiles(
                        accountId: invitation.accountId,
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
            #if DEBUG
            print("🔗 Accept: userId=\(userId), acceptorProfileId=\(acceptorProfileId?.uuidString ?? "nil"), acceptorAccountId=\(acceptorAccountId?.uuidString ?? "nil"), existingProfileId=\(existingProfileId?.uuidString ?? "nil")")
            #endif
            do {
                let syncResult = try await appState.invitationRepository.acceptInvitationWithSync(
                    invitation: invitation,
                    userId: userId,
                    acceptorProfileId: acceptorProfileId,
                    acceptorAccountId: acceptorAccountId,
                    existingProfileId: existingProfileId
                )

                #if DEBUG
                print("🔗 Sync result: success=\(syncResult.success), syncId=\(syncResult.syncId?.uuidString ?? "nil"), debug=\(syncResult.debug ?? "none")")
                #endif

                if !syncResult.success {
                    print("⚠️ Sync RPC returned success=false, debug: \(syncResult.debug ?? "no debug info")")
                }

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
                validationError = "Failed to join account: \(error.localizedDescription)"
            }
        }
    }
}
