import SwiftUI

// MARK: - Invite Share View
/// Panel for sending an invitation with sharing preference toggles and native share sheet
struct InviteShareView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.sidePanelDismiss) private var sidePanelDismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(HeaderStyleManager.self) private var headerStyleManager

    let profileEmail: String
    var onDismiss: (() -> Void)?

    @State private var sharingPreferences: [SharingCategoryKey: Bool] = {
        var prefs: [SharingCategoryKey: Bool] = [:]
        for category in SharingCategoryKey.allCases {
            prefs[category] = true
        }
        return prefs
    }()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var shareMessage: String = ""
    @State private var isCheckmarkPressed = false

    private var effectiveAccentColor: Color {
        if userPreferences.hasCustomAccentColor {
            return userPreferences.accentColor
        } else {
            return headerStyleManager.defaultAccentColor
        }
    }

    private func dismissView() {
        if let sidePanelDismiss {
            sidePanelDismiss()
        } else if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(effectiveAccentColor)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(effectiveAccentColor.opacity(0.15))
                        )

                    Text("Send Invitation")
                        .font(.appTitle)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCheckmarkPressed = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(150))
                        guard !Task.isCancelled else { return }
                        dismissView()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.appBody.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(15)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.15))
                        )
                        .scaleEffect(isCheckmarkPressed ? 0.85 : 1.0)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

            ScrollView {
                VStack(spacing: 24) {
                    // Explanation
                    Text("Choose what information to share with the person you're inviting. They will join as a Viewer and can see the categories you enable below.")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .padding(.top, 12)

                    // Sharing Toggles Section
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
                                accentColor: effectiveAccentColor
                            )
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                    }

                    // Share Invitation Button
                    PrimaryButton(title: "Share Invitation", isLoading: isLoading) {
                        Task { await createAndShare() }
                    }

                    Spacer()
                        .frame(height: 80)
                }
                .padding(AppDimensions.screenPadding)
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareMessage])
                .onDisappear {
                    dismissView()
                }
        }
    }

    // MARK: - Create Invitation and Show Share Sheet
    private func createAndShare() async {
        guard let account = appState.currentAccount,
              let userId = await SupabaseManager.shared.currentUserId else {
            errorMessage = "Unable to send invitation. Please try again."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let invitation = try await appState.invitationRepository.createInvitation(
                accountId: account.id,
                email: profileEmail,
                invitedBy: userId,
                sharingPreferences: sharingPreferences
            )

            let code = invitation.inviteCode
            let deepLink = "unforgotten://invite/\(code)"
            let accountName = account.displayName

            shareMessage = """
            You've been invited to join "\(accountName)" on Unforgotten!

            Use this code to connect: \(code)

            Or tap this link to open the app: \(deepLink)

            Don't have the app yet? Download Unforgotten from the App Store and enter the code during setup.
            """

            isLoading = false
            showShareSheet = true
        } catch {
            isLoading = false
            errorMessage = "Failed to create invitation: \(error.localizedDescription)"
        }
    }
}

// MARK: - Sharing Toggle Row
private struct SharingToggleRow: View {
    let category: SharingCategoryKey
    @Binding var isEnabled: Bool
    let accentColor: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.displayName)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                Text(category.description)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .tint(accentColor)
                .labelsHidden()
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}
