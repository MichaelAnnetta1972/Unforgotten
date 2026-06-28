import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
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
        !currentPassword.isEmpty &&
        newPassword.count >= 6 &&
        newPassword == confirmPassword &&
        newPassword != currentPassword &&
        !isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 44))
                            .foregroundColor(.accentYellow)
                            .padding(.top, 24)

                        Text(didSucceed ? "Password updated" : "Change password")
                            .font(.appLargeTitle)
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)

                        if didSucceed {
                            Text("Your password has been updated. Use the new one next time you sign in.")
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
                            Text("Enter your current password, then choose a new one.")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            AuthTextField(placeholder: "Current password", text: $currentPassword, isSecure: true)
                                .textContentType(.password)

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
                                Task { await changePassword() }
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }

    private func changePassword() async {
        errorMessage = nil

        guard newPassword.count >= 6 else {
            errorMessage = "New password must be at least 6 characters."
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords don't match."
            return
        }
        guard newPassword != currentPassword else {
            errorMessage = "New password must be different from your current one."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await appState.authRepository.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            didSucceed = true
        } catch {
            // Most common error here is wrong current password.
            // Supabase returns "Invalid login credentials" — make it friendlier.
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("invalid login credentials") ||
                message.localizedCaseInsensitiveContains("invalid_credentials") {
                errorMessage = "Current password is incorrect."
            } else {
                errorMessage = message
            }
        }
    }
}
