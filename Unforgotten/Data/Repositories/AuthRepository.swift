import Foundation
import Supabase
import AuthenticationServices

// MARK: - Auth Repository Protocol
protocol AuthRepositoryProtocol {
    func signUp(email: String, password: String) async throws -> User
    func signIn(email: String, password: String) async throws -> User
    func signInWithMagicLink(email: String) async throws
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> User
    func signOut() async throws
    func deleteAccount() async throws
    func resetPassword(email: String) async throws
    func updatePassword(newPassword: String) async throws
    func getCurrentUser() async -> User?
    func observeAuthChanges() -> AsyncStream<AuthChangeEvent>
}

// MARK: - Auth Repository Implementation
final class AuthRepository: AuthRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client
    
 // MARK: - Sign Up
func signUp(email: String, password: String) async throws -> User {
    let response = try await supabase.auth.signUp(
        email: email,
        password: password
    )
    return response.user
}
    
    // MARK: - Sign In with Email/Password
    func signIn(email: String, password: String) async throws -> User {
        let session = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        
        return session.user
    }
    
    // MARK: - Sign In with Magic Link
    func signInWithMagicLink(email: String) async throws {
        try await supabase.auth.signInWithOTP(
            email: email,
            redirectTo: URL(string: "forgotten://auth/callback")
        )
    }
    
    // MARK: - Sign In with Apple
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> User {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw SupabaseError.invalidData
        }
        
        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: tokenString
            )
        )
        
        return session.user
    }
    
    // MARK: - Sign Out
    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    // MARK: - Delete Account
    /// Permanently deletes the authenticated user's account and all associated data.
    /// Calls the `delete_user_account` RPC which runs SECURITY DEFINER and uses
    /// `auth.uid()` internally, so no user id needs to be passed from the client.
    /// Required by App Store Review Guideline 5.1.1(v).
    func deleteAccount() async throws {
        try await supabase.rpc("delete_user_account").execute()
        // After the RPC deletes auth.users, the current session is invalid.
        // Sign out locally to clear cached tokens; ignore errors because the
        // user row no longer exists on the server.
        try? await supabase.auth.signOut()
    }
    
    // MARK: - Reset Password
    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
    
    // MARK: - Update Password
    func updatePassword(newPassword: String) async throws {
        try await supabase.auth.update(user: .init(password: newPassword))
    }
    
    // MARK: - Get Current User
    func getCurrentUser() async -> User? {
        try? await supabase.auth.session.user
    }
    
    // MARK: - Observe Auth Changes
    func observeAuthChanges() -> AsyncStream<AuthChangeEvent> {
        AsyncStream { continuation in
            Task {
                for await (event, _) in supabase.auth.authStateChanges {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }
}

// MARK: - Auth Change Event Extension
extension AuthChangeEvent {
    var isSignedIn: Bool {
        switch self {
        case .signedIn, .tokenRefreshed, .userUpdated:
            return true
        case .signedOut, .passwordRecovery, .initialSession, .mfaChallengeVerified, .userDeleted:
            return false
        }
    }
}
