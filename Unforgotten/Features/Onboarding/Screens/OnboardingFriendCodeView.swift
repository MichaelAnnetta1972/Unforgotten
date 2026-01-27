import SwiftUI

// MARK: - Onboarding Friend Code View
/// Screen 4: Optional friend code entry to connect with an existing account
/// Features a background image in the upper portion
struct OnboardingFriendCodeView: View {
    @Bindable var onboardingData: OnboardingData
    let accentColor: Color
    let onContinue: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var codeInput: String = ""
    @State private var isValidating = false
    @State private var validationError: String? = nil
    @State private var isConnected = false
    @State private var showInviteCodeInfo = false
    @State private var hasAppeared = false
    @FocusState private var isCodeFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    // Button gradient colors matching design
    private let buttonGradient = LinearGradient(
        colors: [Color(hex: "7BA4B5"), Color(hex: "A8C5D4")],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with image in top portion
                inviteBackground(geometry: geometry)

                // Content anchored to bottom
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer()

                        // Form content
                        VStack(spacing: isRegularWidth ? 32 : 24) {
                            // Header
                            VStack(spacing: 12) {
                                Text("Were you invited by a \nfamily or friend?")
                                    .font(.appLargeTitle)
                                    .foregroundColor(.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .opacity(hasAppeared ? 1 : 0)
                                    .offset(y: hasAppeared ? 0 : 10)

                                Text("If someone shared a code with you, enter it below to connect with them")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .opacity(hasAppeared ? 1 : 0)
                                    .offset(y: hasAppeared ? 0 : 10)
                            }
                            .padding(.horizontal, AppDimensions.screenPadding)
                            .animation(
                                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                                value: hasAppeared
                            )

                            // Content area
                            if isConnected {
                                connectedState
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                codeEntryState
                                    .opacity(hasAppeared ? 1 : 0)
                                    .offset(y: hasAppeared ? 0 : 20)
                                    .animation(
                                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.15),
                                        value: hasAppeared
                                    )
                            }

                            // Bottom buttons
                            VStack(spacing: isRegularWidth ? 20 : 16) {
                                if isConnected {
                                    Button(action: onContinue) {
                                        Text("Continue")
                                            .font(.appBodyMedium)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: AppDimensions.buttonHeight)
                                            .background(accentColor)
                                            .cornerRadius(AppDimensions.buttonCornerRadius)
                                    }
                                } else {
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
                                        .background(accentColor)
                                        .cornerRadius(AppDimensions.buttonCornerRadius)
                                    }
                                    .disabled(codeInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
                                 //   .opacity(codeInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)

                                    // Skip button
                                    Button {
                                        onContinue()
                                    } label: {
                                        Text("I don't have a code")
                                            .font(.appBodyMedium)
                                            .foregroundColor(.textSecondary)
                                    }
                                    .disabled(isValidating)
                                }
                            }
                            .frame(maxWidth: isRegularWidth ? 400 : .infinity)
                            .padding(.horizontal, AppDimensions.screenPadding)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(
                                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.25),
                                value: hasAppeared
                            )
                        }
                        .frame(maxWidth: isRegularWidth ? 500 : .infinity)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + (isRegularWidth ? 48 : 32))
                    }
                    .frame(minHeight: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Invite Background
    @ViewBuilder
    private func inviteBackground(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            // Base dark background
            Color.appBackground

            // Background image - aligned to top, fixed position
            Image("onboarding-invite-bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()

            // Gradient overlay for smooth transition to content area
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: geometry.size.height * 0.3)

                LinearGradient(
                    colors: [
                        Color.appBackground.opacity(0),
                        Color.appBackground.opacity(0.5),
                        Color.appBackground.opacity(0.9),
                        Color.appBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    // MARK: - Code Entry State
    private var codeEntryState: some View {
        VStack(spacing: 16) {
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
                        RoundedRectangle(cornerRadius: AppDimensions.textFieldHeight / 2)
                            .stroke(
                                validationError != nil ? Color.medicalRed :
                                    isCodeFieldFocused ? accentColor :
                                    Color.clear,
                                lineWidth: 2
                            )
                    )
                    .focused($isCodeFieldFocused)
                    .onChange(of: codeInput) { _, _ in
                        // Clear error when user types
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
            .padding(.horizontal, AppDimensions.screenPadding)

            // What's this? info
            Button {
                showInviteCodeInfo = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14))
                    Text("What's an invite code?")
                        .font(.appCaption)
                }
                .foregroundColor(.textSecondary)
            }
            .sheet(isPresented: $showInviteCodeInfo) {
                InviteCodeInfoSheet(accentColor: accentColor)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Connected State
    private var connectedState: some View {
        VStack(spacing: 20) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.badgeGreen)

            // Connection message
            VStack(spacing: 8) {
                if let accountName = onboardingData.connectedAccountName {
                    Text("You're connected with")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)

                    Text(accountName)
                        .font(.appTitle)
                        .foregroundColor(.textPrimary)
                }

                // Admin permission notice
                if onboardingData.hasAdminPermission {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(accentColor)

                        Text("You've been given permission to help manage this account")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(accentColor.opacity(0.1))
                    .cornerRadius(AppDimensions.smallCornerRadius)
                }
            }
        }
        .padding(.horizontal, AppDimensions.screenPadding)
        .padding(.vertical, 24)
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
                // Look up the invitation
                if let invitation = try await appState.invitationRepository.getInvitationByCode(trimmedCode) {
                    // Check if invitation is still active
                    if invitation.isActive {
                        // Get the account name for display
                        var accountName = "their account"
                        do {
                            let account = try await appState.accountRepository.getAccount(id: invitation.accountId)
                            accountName = account.displayName
                        } catch {
                            // Use default name if account lookup fails
                        }

                        await MainActor.run {
                            onboardingData.friendCode = trimmedCode
                            onboardingData.connectedInvitation = invitation
                            onboardingData.connectedAccountName = accountName
                            isConnected = true
                            isValidating = false
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
}

// MARK: - Invite Code Info Sheet
struct InviteCodeInfoSheet: View {
    let accentColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 50))
                    .foregroundColor(accentColor)

                Text("What's an invite code?")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)
            }
            .padding(.top, 24)

            // Explanation
            VStack(alignment: .leading, spacing: 16) {
                InfoRow(
                    icon: "person.2.fill",
                    title: "Connect with family",
                    description: "An invite code lets you join an existing Unforgotten account that a family member or friend has already set up.",
                    accentColor: accentColor
                )

                InfoRow(
                    icon: "square.and.arrow.up.fill",
                    title: "Shared by someone you know",
                    description: "The person who created the account can generate an invite code from their Settings and share it with you.",
                    accentColor: accentColor
                )

                InfoRow(
                    icon: "checkmark.shield.fill",
                    title: "No code? No problem!",
                    description: "If you don't have an invite code, just tap \"I don't have a code\" to create your own new account.",
                    accentColor: accentColor
                )
            }
            .padding(.horizontal, AppDimensions.screenPadding)

            Spacer()

            // Got it button
            Button {
                dismiss()
            } label: {
                Text("Got it")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Info Row
private struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                Text(description)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingFriendCodeView(
            onboardingData: OnboardingData(),
            accentColor: Color(hex: "FFC93A"),
            onContinue: {}
        )
        .environmentObject(AppState.forPreview())
    }
}

#Preview("Info Sheet") {
    InviteCodeInfoSheet(accentColor: Color(hex: "FFC93A"))
}
