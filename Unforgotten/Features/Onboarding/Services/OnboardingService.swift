import SwiftUI
import UIKit

// MARK: - Onboarding Service
/// Service for handling onboarding-related operations including photo upload and data sync
final class OnboardingService {
    static let shared = OnboardingService()

    private let supabase = SupabaseManager.shared

    private init() {}

    // MARK: - Photo Upload

    /// Uploads a profile photo and returns the public URL
    /// - Parameter image: The UIImage to upload
    /// - Returns: The public URL of the uploaded image, or nil if upload fails
    func uploadProfilePhoto(_ image: UIImage) async throws -> String? {
        // Compress and resize the image
        guard let processedImage = processImage(image),
              let imageData = processedImage.jpegData(compressionQuality: 0.8) else {
            return nil
        }

        // Generate a unique filename
        let filename = "\(UUID().uuidString).jpg"
        let path = "profile-photos/\(filename)"

        // Upload to Supabase Storage
        try await supabase.client.storage
            .from("profile-photos")
            .upload(
                path: filename,
                file: imageData,
                options: .init(contentType: "image/jpeg")
            )

        // Get the public URL
        let publicURL = try supabase.client.storage
            .from("profile-photos")
            .getPublicURL(path: filename)

        return publicURL.absoluteString
    }

    /// Process image for upload (resize and compress)
    private func processImage(_ image: UIImage) -> UIImage? {
        let maxDimension: CGFloat = 800

        let size = image.size
        var newSize: CGSize

        if size.width > size.height {
            if size.width <= maxDimension { return image }
            let ratio = maxDimension / size.width
            newSize = CGSize(width: maxDimension, height: size.height * ratio)
        } else {
            if size.height <= maxDimension { return image }
            let ratio = maxDimension / size.height
            newSize = CGSize(width: size.width * ratio, height: maxDimension)
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage
    }

    // MARK: - Friend Code Validation

    /// Validates a friend code and returns invitation details
    /// - Parameters:
    ///   - code: The invitation code to validate
    ///   - invitationRepository: The repository for invitation operations
    ///   - accountRepository: The repository for account operations
    /// - Returns: A tuple containing the invitation and account name, or nil if invalid
    func validateFriendCode(
        _ code: String,
        invitationRepository: InvitationRepository,
        accountRepository: AccountRepository
    ) async throws -> (invitation: AccountInvitation, accountName: String)? {
        let trimmedCode = code.trimmingCharacters(in: .whitespaces).uppercased()

        guard let invitation = try await invitationRepository.getInvitationByCode(trimmedCode) else {
            return nil
        }

        guard invitation.isActive else {
            return nil
        }

        var accountName = "their account"
        do {
            let account = try await accountRepository.getAccount(id: invitation.accountId)
            accountName = account.displayName
        } catch {
            // Use default name if account lookup fails
        }

        return (invitation, accountName)
    }

    // MARK: - Complete Onboarding

    /// Complete the onboarding process and sync all data
    /// - Parameters:
    ///   - data: The collected onboarding data
    ///   - appState: The app state for repository access
    ///   - headerStyleManager: The header style manager to update
    ///   - userPreferences: The user preferences to update
    func completeOnboarding(
        data: OnboardingData,
        appState: AppState,
        headerStyleManager: HeaderStyleManager,
        userPreferences: UserPreferences
    ) async throws {
        // 1. Upload profile photo if present
        var photoURL: String? = nil
        if let photo = data.profilePhoto {
            photoURL = try await uploadProfilePhoto(photo)
        }

        // 2. Apply theme settings
        await MainActor.run {
            headerStyleManager.selectStyle(data.selectedHeaderStyle)
            userPreferences.resetToStyleDefault()
        }

        // 3. ALWAYS create the user's own account and profile first
        // This ensures they have their own account for profile sync to work
        try await appState.completeOnboarding(
            accountName: data.accountName,
            primaryProfileName: data.fullName,
            birthday: nil
        )

        // Update profile with photo URL if we uploaded one
        if let url = photoURL {
            // Access main actor-isolated property
            let account = await MainActor.run { appState.currentAccount }
            if let account = account {
                // Get the primary profile and update it
                let profiles = try await appState.profileRepository.getProfiles(accountId: account.id)
                if let primaryProfile = profiles.first(where: { $0.type == .primary }) {
                    var updatedProfile = primaryProfile
                    updatedProfile.photoUrl = url
                    try await appState.profileRepository.updateProfile(updatedProfile)
                }
            }
        }

        // 4. Handle friend code connection AFTER creating the user's own account
        // This allows profile sync to copy the inviter's profile to the new user's account
        if let invitation = data.connectedInvitation {
            if let userId = await supabase.currentUserId {
                #if DEBUG
                print("🔗 Profile Sync: Starting invitation acceptance...")
                print("🔗 Profile Sync: Invitation ID: \(invitation.id)")
                print("🔗 Profile Sync: User ID: \(userId)")
                print("🔗 Profile Sync: Invited by: \(invitation.invitedBy)")
                print("🔗 Profile Sync: Account to join: \(invitation.accountId)")
                #endif

                // Get the acceptor's account ID and primary profile ID from their newly created account
                let acceptorAccountId = await MainActor.run { appState.currentAccount?.id }
                let acceptorProfileId = await getAcceptorPrimaryProfileId(appState: appState, userId: userId)

                #if DEBUG
                print("🔗 Profile Sync: Acceptor account ID: \(acceptorAccountId?.uuidString ?? "NOT FOUND")")
                print("🔗 Profile Sync: Acceptor profile ID: \(acceptorProfileId?.uuidString ?? "NOT FOUND")")
                if acceptorProfileId == nil {
                    let currentAccount = await MainActor.run { appState.currentAccount }
                    print("🔗 Profile Sync: currentAccount = \(currentAccount?.id.uuidString ?? "nil")")
                }
                #endif

                // Check for duplicate profiles in the inviter's account
                var existingProfileId: UUID? = nil
                if let profileId = acceptorProfileId, let acceptorProfile = try? await appState.profileRepository.getProfile(id: profileId) {
                    let matches = try await appState.profileRepository.findMatchingProfiles(
                        accountId: invitation.accountId,
                        name: acceptorProfile.fullName,
                        email: acceptorProfile.email
                    )
                    if let match = matches.first {
                        existingProfileId = match.id
                        #if DEBUG
                        print("🔗 Profile Sync: Found existing matching profile: \(match.fullName) (\(match.id))")
                        #endif
                    }
                }

                // Use the sync-enabled acceptance method
                do {
                    #if DEBUG
                    print("🔗 Profile Sync: Calling acceptInvitationWithSync RPC...")
                    #endif

                    let syncResult = try await appState.invitationRepository.acceptInvitationWithSync(
                        invitation: invitation,
                        userId: userId,
                        acceptorProfileId: acceptorProfileId,
                        acceptorAccountId: acceptorAccountId,
                        existingProfileId: existingProfileId
                    )

                    #if DEBUG
                    print("🔗 Profile Sync: RPC completed successfully!")
                    print("🔗 Profile Sync: success = \(syncResult.success)")
                    print("🔗 Profile Sync: syncId = \(syncResult.syncId?.uuidString ?? "nil")")
                    print("🔗 Profile Sync: inviterSyncedProfileId = \(syncResult.inviterSyncedProfileId?.uuidString ?? "nil")")
                    print("🔗 Profile Sync: acceptorSyncedProfileId = \(syncResult.acceptorSyncedProfileId?.uuidString ?? "nil")")
                    #endif

                    // Post notification about the new sync
                    if let syncId = syncResult.syncId {
                        NotificationCenter.default.post(
                            name: .profileSyncDidChange,
                            object: nil,
                            userInfo: ["syncId": syncId, "action": "created"]
                        )
                    }
                } catch {
                    // Fall back to regular invitation acceptance if sync RPC isn't available
                    #if DEBUG
                    print("🔗 Profile Sync: RPC FAILED with error: \(error)")
                    print("🔗 Profile Sync: Falling back to regular acceptance...")
                    #endif
                    try await appState.invitationRepository.acceptInvitation(
                        invitation: invitation,
                        userId: userId
                    )
                }
            }

            // Reload account data to include the newly joined account
            await appState.loadAccountData()
        }

        // 5. Store subscription status locally (subscription tier persisted via StoreKit receipts)
        if data.isPremium {
            // Save the subscription tier
            UserDefaults.standard.set(data.subscriptionTier.rawValue, forKey: "user_subscription_tier")
            if let productId = data.subscriptionProductId {
                UserDefaults.standard.set(productId, forKey: "user_subscription_product_id")
            }
        }

        // 6. Notification status is already handled by NotificationService
    }
}

// MARK: - Profile Sync Helpers
extension OnboardingService {
    /// Get the acceptor's primary profile ID if they have an existing account
    /// This is used for bidirectional profile syncing when accepting an invitation
    private func getAcceptorPrimaryProfileId(appState: AppState, userId: UUID) async -> UUID? {
        // Check if the user already has an account (they might be joining another account
        // while already having their own)
        let currentAccount = await MainActor.run { appState.currentAccount }

        #if DEBUG
        print("🔍 getAcceptorPrimaryProfileId: Looking for profile...")
        print("🔍 getAcceptorPrimaryProfileId: currentAccount = \(currentAccount?.id.uuidString ?? "nil")")
        print("🔍 getAcceptorPrimaryProfileId: userId = \(userId.uuidString)")
        #endif

        guard let account = currentAccount else {
            #if DEBUG
            print("🔍 getAcceptorPrimaryProfileId: No current account found")
            #endif
            return nil
        }

        // Try to find their primary profile
        do {
            if let primaryProfile = try await appState.profileRepository.getPrimaryProfile(accountId: account.id) {
                #if DEBUG
                print("🔍 getAcceptorPrimaryProfileId: Found profile: \(primaryProfile.id)")
                print("🔍 getAcceptorPrimaryProfileId: linkedUserId = \(primaryProfile.linkedUserId?.uuidString ?? "nil")")
                #endif

                // During onboarding, we just created this profile for the current user
                // The linkedUserId check is a safety measure, but during onboarding we trust the profile
                // because we just created it moments ago
                if primaryProfile.linkedUserId == userId || primaryProfile.linkedUserId == nil {
                    #if DEBUG
                    print("🔍 getAcceptorPrimaryProfileId: Returning profile ID: \(primaryProfile.id)")
                    #endif
                    return primaryProfile.id
                } else {
                    #if DEBUG
                    print("🔍 getAcceptorPrimaryProfileId: linkedUserId mismatch - expected \(userId), got \(primaryProfile.linkedUserId?.uuidString ?? "nil")")
                    #endif
                }
            } else {
                #if DEBUG
                print("🔍 getAcceptorPrimaryProfileId: No primary profile found")
                #endif
            }
        } catch {
            #if DEBUG
            print("🔍 getAcceptorPrimaryProfileId: Error: \(error)")
            #endif
        }

        return nil
    }
}

// MARK: - Subscription Status
extension OnboardingService {
    /// Check if user has an active premium subscription (Premium or Family Plus)
    var isPremiumUser: Bool {
        if let tierString = UserDefaults.standard.string(forKey: "user_subscription_tier"),
           let tier = SubscriptionTier(rawValue: tierString) {
            return tier.hasPremiumFeatures
        }
        // Fallback to legacy key for migration
        return UserDefaults.standard.bool(forKey: "user_has_premium")
    }

    /// Get the current subscription tier
    var subscriptionTier: SubscriptionTier {
        if let tierString = UserDefaults.standard.string(forKey: "user_subscription_tier"),
           let tier = SubscriptionTier(rawValue: tierString) {
            return tier
        }
        // Fallback to legacy key for migration
        if UserDefaults.standard.bool(forKey: "user_has_premium") {
            return .premium
        }
        return .free
    }

    /// Get the current subscription product ID
    var subscriptionProductId: String? {
        UserDefaults.standard.string(forKey: "user_subscription_product_id")
    }
}
