import SwiftUI
import AuthenticationServices

// MARK: - Auth View
struct AuthView: View {
    @State private var showSignUp = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 80))
                                .foregroundColor(.accentYellow)
                            
                            Text("Don't Forget")
                                .font(.appLargeTitle)
                                .foregroundColor(.textPrimary)
                            
                            Text("Remember what matters most")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.top, 60)
                        
                        // Auth Form
                        if showSignUp {
                            SignUpForm(showSignUp: $showSignUp)
                        } else {
                            SignInForm(showSignUp: $showSignUp)
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
        }
    }
}

// MARK: - Sign In Form
struct SignInForm: View {
    @EnvironmentObject var appState: AppState
    @Binding var showSignUp: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMagicLinkSent = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Email field
            AppTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
            
            // Password field
            AppTextField(placeholder: "Password", text: $password, isSecure: true)
                .textContentType(.password)
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.appCaption)
                    .foregroundColor(.medicalRed)
                    .multilineTextAlignment(.center)
            }
            
            // Sign in button
            PrimaryButton(title: "Sign In", isLoading: isLoading) {
                Task { await signIn() }
            }
            .disabled(email.isBlank || password.isBlank)
            
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
            
            // Magic link button
            SecondaryButton(title: "Sign in with Magic Link") {
                Task { await sendMagicLink() }
            }
            .disabled(email.isBlank)
            
            // Apple Sign In
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                Task { await handleAppleSignIn(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: AppDimensions.buttonHeight)
            .cornerRadius(AppDimensions.buttonCornerRadius)
            
            // Switch to sign up
            Button {
                withAnimation {
                    showSignUp = true
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundColor(.textSecondary)
                    Text("Sign Up")
                        .foregroundColor(.accentYellow)
                }
                .font(.appBody)
            }
            .padding(.top, 8)
            
            // Forgot password
            Button {
                Task { await resetPassword() }
            } label: {
                Text("Forgot Password?")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
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
    @Binding var showSignUp: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Email field
            AppTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
            
            // Password field
            AppTextField(placeholder: "Password", text: $password, isSecure: true)
                .textContentType(.newPassword)
            
            // Confirm password field
            AppTextField(placeholder: "Confirm Password", text: $confirmPassword, isSecure: true)
                .textContentType(.newPassword)
            
            // Password requirements
            VStack(alignment: .leading, spacing: 4) {
                PasswordRequirement(text: "At least 8 characters", isMet: password.count >= 8)
                PasswordRequirement(text: "Passwords match", isMet: !password.isEmpty && password == confirmPassword)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.appCaption)
                    .foregroundColor(.medicalRed)
                    .multilineTextAlignment(.center)
            }
            
            // Sign up button
            PrimaryButton(title: "Create Account", isLoading: isLoading) {
                Task { await signUp() }
            }
            .disabled(!isFormValid)
            
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
            
            // Apple Sign Up
            SignInWithAppleButton(.signUp) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                Task { await handleAppleSignUp(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: AppDimensions.buttonHeight)
            .cornerRadius(AppDimensions.buttonCornerRadius)
            
            // Switch to sign in
            Button {
                withAnimation {
                    showSignUp = false
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundColor(.textSecondary)
                    Text("Sign In")
                        .foregroundColor(.accentYellow)
                }
                .font(.appBody)
            }
            .padding(.top, 8)
        }
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

// MARK: - Preview
#Preview {
    AuthView()
        .environmentObject(AppState())
}
