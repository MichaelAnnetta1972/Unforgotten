import SwiftUI
import AuthenticationServices

// MARK: - Auth View
struct AuthView: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showSignUp = false

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background - stays fixed
                    AuthBackgroundView()
                        .ignoresSafeArea(.keyboard)

                    // Content with logo at top, form at bottom
                    ScrollView {
                        VStack(spacing: 0) {
                            // Logo at top
                            Image("unforgotten-logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: isRegularWidth ? 100 : 80)
                                .padding(.top, geometry.safeAreaInsets.top + (isRegularWidth ? 60 : 40))

                            Spacer(minLength: isRegularWidth ? 60 : 40)

                            // Auth Form content
                            VStack(spacing: isRegularWidth ? 32 : 24) {
                                if showSignUp {
                                    SignUpForm(showSignUp: $showSignUp)
                                } else {
                                    SignInForm(showSignUp: $showSignUp)
                                }
                            }
                            .padding(.horizontal, AppDimensions.screenPadding)
                            .padding(.bottom, geometry.safeAreaInsets.bottom + (isRegularWidth ? 48 : 32))
                            .frame(maxWidth: isRegularWidth ? 500 : 550)
                        }
                        .frame(minHeight: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDismissesKeyboard(.interactively)
                }
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Auth Background View
struct AuthBackgroundView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Base dark background
                Color.appBackground

                // Background image - aligned to top
                Image("onboarding-auth-bg")
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
        .ignoresSafeArea()
    }
}

// MARK: - Sign In Form
struct SignInForm: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var showSignUp: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMagicLinkSent = false

    // Button gradient colors matching design
    private let buttonGradient = LinearGradient(
        colors: [Color(hex: "79A5D7"), Color(hex: "8CBFD3")],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Sign in to get started")
                .font(.appLargeTitle)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            // Email field
            AuthTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)

            // Password field
            AuthTextField(placeholder: "Password", text: $password, isSecure: true)
                .textContentType(.password)

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.appCaption)
                    .foregroundColor(.medicalRed)
                    .multilineTextAlignment(.center)
            }

            // Sign in button
            Button {
                Task { await signIn() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign in")
                            .font(.appBodyMedium)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDimensions.buttonHeight)
                .background(buttonGradient)
                .cornerRadius(AppDimensions.buttonHeight / 2)
            }
            .disabled(email.isBlank || password.isBlank || isLoading)
            .opacity(email.isBlank || password.isBlank ? 0.6 : 1)

            // Forgot password
            Button {
                Task { await resetPassword() }
            } label: {
                Text("Forgot Password?")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.top, 8)


            // Divider
            HStack {
                Rectangle()
                    .fill(Color.textSecondary.opacity(0.3))
                    .frame(height: 1)

                Text("or")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                Rectangle()
                    .fill(Color.textSecondary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)

            // Magic link button
        //    Button {
        //        Task { await sendMagicLink() }
        //    } label: {
        //        Text("Sign in with Magic Link")
        //            .font(.appBodyMedium)
        //            .foregroundColor(.white)
        //            .frame(maxWidth: .infinity)
        //            .frame(height: AppDimensions.buttonHeight)
        //            .background(Color.black)
        //            .cornerRadius(AppDimensions.buttonHeight / 2)
        //            .overlay(
        //                RoundedRectangle(cornerRadius: AppDimensions.buttonHeight / 2)
        //                    .stroke(Color.white, lineWidth: 1)
        //            )
        //    }
        //    .disabled(email.isBlank)
        //    .opacity(email.isBlank ? 0.6 : 1)

            // Apple Sign In
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                Task { await handleAppleSignIn(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: AppDimensions.buttonHeight)
            .cornerRadius(AppDimensions.buttonHeight / 2)



            // Switch to sign up
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSignUp = true
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundColor(.textSecondary)
                    Text("Sign Up")
                        .foregroundColor(Color(hex: "79A5D7"))
                }
                .font(.appBody)
            }

        }
        .alert("Magic Link Sent", isPresented: $showMagicLinkSent) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Check your email for a sign-in link.")
        }
    }
    
    // MARK: - Sign In
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await appState.authRepository.signIn(email: email, password: password)
            await appState.checkAuthState()
        } catch {
            errorMessage = "Invalid email or password"
        }
        
        isLoading = false
    }
    
    // MARK: - Magic Link
    private func sendMagicLink() async {
        guard email.isValidEmail else {
            errorMessage = "Please enter a valid email"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await appState.authRepository.signInWithMagicLink(email: email)
            showMagicLinkSent = true
        } catch {
            errorMessage = "Failed to send magic link"
        }
        
        isLoading = false
    }
    
    // MARK: - Apple Sign In
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                isLoading = true
                do {
                    _ = try await appState.authRepository.signInWithApple(credential: credential)
                    await appState.checkAuthState()
                } catch {
                    errorMessage = "Apple Sign In failed"
                }
                isLoading = false
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Reset Password
    private func resetPassword() async {
        guard email.isValidEmail else {
            errorMessage = "Please enter your email first"
            return
        }
        
        do {
            try await appState.authRepository.resetPassword(email: email)
            errorMessage = "Password reset email sent"
        } catch {
            errorMessage = "Failed to send reset email"
        }
    }
}

// MARK: - Sign Up Form
struct SignUpForm: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var showSignUp: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Button gradient colors matching design
    private let buttonGradient = LinearGradient(
        colors: [Color(hex: "79A5D7"), Color(hex: "8CBFD3")],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Let's get you signed up")
                .font(.appLargeTitle)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            // Email field
            AuthTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)

            // Password field
            AuthTextField(placeholder: "Password", text: $password, isSecure: true)
                .textContentType(.newPassword)

            // Confirm password field
            AuthTextField(placeholder: "Confirm Password", text: $confirmPassword, isSecure: true)
                .textContentType(.newPassword)

            // Password requirements (only show when typing)
            if !password.isEmpty || !confirmPassword.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    PasswordRequirement(text: "At least 8 characters", isMet: password.count >= 8)
                    PasswordRequirement(text: "Passwords match", isMet: !password.isEmpty && password == confirmPassword)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.appCaption)
                    .foregroundColor(.medicalRed)
                    .multilineTextAlignment(.center)
            }

            // Create Account button
            Button {
                Task { await signUp() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Create Account")
                            .font(.appBodyMedium)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDimensions.buttonHeight)
                .background(buttonGradient)
                .cornerRadius(AppDimensions.buttonHeight / 2)
            }
            .disabled(!isFormValid || isLoading)
            .opacity(!isFormValid ? 0.6 : 1)

            // Divider
            HStack {
                Rectangle()
                    .fill(Color.textSecondary.opacity(0.3))
                    .frame(height: 1)

                Text("or")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                Rectangle()
                    .fill(Color.textSecondary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)

            // Apple Sign Up
            SignInWithAppleButton(.signUp) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                Task { await handleAppleSignUp(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: AppDimensions.buttonHeight)
            .cornerRadius(AppDimensions.buttonHeight / 2)

            // Switch to sign in
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSignUp = false
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundColor(.textSecondary)
                    Text("Sign In")
                        .foregroundColor(Color(hex: "79A5D7"))
                }
                .font(.appBody)
            }
            .padding(.top, 8)
        }
        .animation(.easeInOut(duration: 0.2), value: password.isEmpty && confirmPassword.isEmpty)
    }
    
    private var isFormValid: Bool {
        email.isValidEmail &&
        password.count >= 8 &&
        password == confirmPassword
    }
    
    // MARK: - Sign Up
    private func signUp() async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await appState.authRepository.signUp(email: email, password: password)
            await appState.checkAuthState()
        } catch {
            errorMessage = "Failed to create account. Email may already be in use."
        }
        
        isLoading = false
    }
    
    // MARK: - Apple Sign Up
    private func handleAppleSignUp(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                isLoading = true
                do {
                    _ = try await appState.authRepository.signInWithApple(credential: credential)
                    await appState.checkAuthState()
                } catch {
                    errorMessage = "Apple Sign Up failed"
                }
                isLoading = false
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Password Requirement
struct PasswordRequirement: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .badgeGreen : .textSecondary)
                .font(.caption)

            Text(text)
                .font(.appCaption)
                .foregroundColor(isMet ? .textPrimary : .textSecondary)
        }
    }
}

// MARK: - Auth Text Field
/// Custom text field styled for auth screens with lighter grey background
struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    // Lighter grey background color
    private let fieldBackground = Color(hex: "DDDDDD")
    private let placeholderColor = Color(hex: "666666")

    var body: some View {
        ZStack(alignment: .leading) {
            // Custom placeholder
            if text.isEmpty {
                Text(placeholder)
                    .font(.appBody)
                    .foregroundColor(placeholderColor)
                    .padding(.horizontal, 20)
            }

            // Actual text field
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboardType)
                }
            }
            .font(.appBody)
            .foregroundColor(.black)
            .padding(.horizontal, 20)
        }
        .frame(height: AppDimensions.textFieldHeight)
        .background(fieldBackground)
        .cornerRadius(AppDimensions.buttonCornerRadius)
    }
}

// MARK: - Preview
#Preview {
    AuthView()
        .environmentObject(AppState.forPreview())
}
