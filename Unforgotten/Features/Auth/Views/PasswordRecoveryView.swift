import SwiftUI

struct PasswordRecoveryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    private let buttonGradient = LinearGradient(
        colors: [Color(hex: "79A5D7"), Color(hex: "8CBFD3")],
        startPoint: .leading,
        endPoint: .trailing
    )

    private var canSubmit: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword && !isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Image("unforgotten-logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 70)
                            .padding(.top, 24)
                            .padding(.bottom, 8)

                        Text(didSucceed ? "Password updated" : "Set a new password")
                            .font(.appLargeTitle)
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)

                        if didSucceed {
                            Text("You can now use this password to sign in.")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button {
                                dismiss()
                            } label: {
                                Text("Done")
                                    .font(.appBodyMedium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: AppDimensions.buttonHeight)
                                    .background(buttonGradient)
                                    .cornerRadius(AppDimensions.buttonHeight / 2)
                            }
                            .padding(.top, 8)
                        } else {
                            Text("Choose a new password for your Unforgotten account.")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            AuthTextField(placeholder: "New password", text: $newPassword, isSecure: true)
                                .textContentType(.newPassword)

                            AuthTextField(placeholder: "Confirm new password", text: $confirmPassword, isSecure: true)
                                .textContentType(.newPassword)

                            if let error = errorMessage {
                                Text(error)
                                    .font(.appCaption)
                                    .foregroundColor(.medicalRed)
                                    .multilineTextAlignment(.center)
                            }

                            Button {
                                Task { await updatePassword() }
                            } label: {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Update Password")
                                            .font(.appBodyMedium)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: AppDimensions.buttonHeight)
                                .background(buttonGradient)
                                .cornerRadius(AppDimensions.buttonHeight / 2)
                            }
                            .disabled(!canSubmit)
                            .opacity(canSubmit ? 1 : 0.6)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.bottom, 32)
                    .frame(maxWidth: 500)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar {
                if !didSucceed {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(.textSecondary)
                            .disabled(isLoading)
                    }
                }
            }
            .interactiveDismissDisabled(isLoading)
            .onDisappear {
                // If the user dismissed without completing the reset, sign them out.
                // The recovery email grants a one-shot session for the purpose of
                // setting a new password — it must not become a way to sign in.
                if !didSucceed {
                    Task { await appState.signOut() }
                }
            }
        }
    }

    private func updatePassword() async {
        errorMessage = nil

        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await appState.authRepository.updatePassword(newPassword: newPassword)
            didSucceed = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
