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

        // 3. Handle friend code connection
        if let invitation = data.connectedInvitation {
            // Accept the invitation
            if let userId = await supabase.currentUserId {
                try await appState.invitationRepository.acceptInvitation(
                    invitation: invitation,
                    userId: userId
                )
            }

            // The user is joining an existing account, not creating a new one
            // Load the account they're joining
            await appState.loadAccountData()
        } else {
            // Create new account and profile
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
        }

        // 4. Store subscription status locally (subscription tier persisted via StoreKit receipts)
        if data.isPremium {
            // Save the subscription tier
            UserDefaults.standard.set(data.subscriptionTier.rawValue, forKey: "user_subscription_tier")
            if let productId = data.subscriptionProductId {
                UserDefaults.standard.set(productId, forKey: "user_subscription_product_id")
            }
        }

        // 5. Notification status is already handled by NotificationService
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
