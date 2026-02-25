import Foundation
import SwiftUI

// MARK: - Subscription Tier
/// Represents the user's subscription level
enum SubscriptionTier: String, Codable, CaseIterable {
    case free
    case premium
    case familyPlus

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .familyPlus: return "Family Plus"
        }
    }

    /// Whether this tier includes premium features (unlimited items)
    var hasPremiumFeatures: Bool {
        self == .premium || self == .familyPlus
    }

    /// Whether this tier includes family features (invite/join/manage members)
    var hasFamilyFeatures: Bool {
        self == .familyPlus
    }
}

// MARK: - Premium Limits Manager
/// Manages subscription tier limitations and premium access checks
@MainActor
final class PremiumLimitsManager: ObservableObject {
    static let shared = PremiumLimitsManager()

    // MARK: - Free Tier Limits
    /// Maximum number of items allowed on the free tier
    struct FreeTierLimits {
        static let friendProfiles = 2       // Friend/family profiles (excludes primary "My Card")
        static let stickyReminders = 5
        static let notes = 5
        static let todoLists = 2
        static let medications = 5
        static let usefulContacts = 5
        static let countdowns = 2
        static let appointmentDaysLimit = 30 // Appointments limited to next 30 days
    }

    private init() {}

    // MARK: - Get Subscription Tier

    /// Get the user's current subscription tier
    func getSubscriptionTier(appState: AppState) -> SubscriptionTier {
        return appState.subscriptionTier
    }

    // MARK: - Check Premium Access

    /// Check if user has premium access (Premium or Family Plus tier)
    func hasPremiumAccess(appState: AppState) -> Bool {
        return appState.subscriptionTier.hasPremiumFeatures
    }

    /// Check if user has family features (Family Plus tier only)
    func hasFamilyAccess(appState: AppState) -> Bool {
        return appState.subscriptionTier.hasFamilyFeatures
    }

    // MARK: - Limit Checks

    /// Check if user can create another friend/family profile
    func canCreateFriendProfile(appState: AppState, currentCount: Int) -> Bool {
        if hasPremiumAccess(appState: appState) { return true }
        return currentCount < FreeTierLimits.friendProfiles
    }

    /// Check if user can create another sticky reminder
    func canCreateStickyReminder(appState: AppState, currentCount: Int) -> Bool {
        if hasPremiumAccess(appState: appState) { return true }
        return currentCount < FreeTierLimits.stickyReminders
    }

    /// Check if user can create another note
    func canCreateNote(appState: AppState, currentCount: Int) -> Bool {
        if hasPremiumAccess(appState: appState) { return true }
        return currentCount < FreeTierLimits.notes
    }

    /// Check if user can create another to-do list
    func canCreateToDoList(appState: AppState, currentCount: Int) -> Bool {
        if hasPremiumAccess(appState: appState) { return true }
        return currentCount < FreeTierLimits.todoLists
    }

    /// Check if user can create another medication
    func canCreateMedication(appState: AppState, currentCount: Int) -> Bool {
        if hasPremiumAccess(appState: appState) { return true }
        return currentCount < FreeTierLimits.medications
    }

    /// Check if user can create an appointment on the given date
    /// Free tier is limited to appointments within the next 30 days
    func canCreateAppointment(appState: AppState, forDate date: Date? = nil) -> Bool {
        if hasPremiumAccess(appState: appState) { return true }

        guard let date = date else { return true } // If no date specified, allow (will check later)

        let daysFromNow = Calendar.current.dateComponents([.day], from: Date().startOfDay, to: date.startOfDay).day ?? 0
        return daysFromNow <= FreeTierLimits.appointmentDaysLimit
    }

    /// Check if a date is within the free tier appointment limit
    func isDateWithinAppointmentLimit(date: Date) -> Bool {
        let daysFromNow = Calendar.current.dateComponents([.day], from: Date().startOfDay, to: date.startOfDay).day ?? 0
        return daysFromNow <= FreeTierLimits.appointmentDaysLimit
    }

    /// Check if user can create another useful contact
    func canCreateUsefulContact(appState: AppState, currentCount: Int) -> Bool {
        if hasPremiumAccess(appState: appState) { return true }
        return currentCount < FreeTierLimits.usefulContacts
    }

    /// Check if user can create another countdown
    func canCreateCountdown(appState: AppState, currentCount: Int) -> Bool {
        if hasPremiumAccess(appState: appState) { return true }
        return currentCount < FreeTierLimits.countdowns
    }

    /// Check if user can invite family members (available to all tiers)
    func canInviteMembers(appState: AppState) -> Bool {
        return true
    }

    /// Check if user can join another account (available to all tiers)
    func canJoinOtherAccounts(appState: AppState) -> Bool {
        return true
    }

    /// Check if user can use custom header images (Premium or Family Plus)
    func canUseCustomHeaderImages(appState: AppState) -> Bool {
        return hasPremiumAccess(appState: appState)
    }

    // MARK: - Remaining Count Helpers

    /// Get remaining friend profiles that can be created
    func remainingFriendProfiles(appState: AppState, currentCount: Int) -> Int {
        if hasPremiumAccess(appState: appState) { return Int.max }
        return max(0, FreeTierLimits.friendProfiles - currentCount)
    }

    /// Get the limit for a feature (for display purposes)
    func limitForFeature(_ feature: LimitedFeature) -> Int {
        switch feature {
        case .friendProfiles: return FreeTierLimits.friendProfiles
        case .stickyReminders: return FreeTierLimits.stickyReminders
        case .notes: return FreeTierLimits.notes
        case .todoLists: return FreeTierLimits.todoLists
        case .medications: return FreeTierLimits.medications
        case .usefulContacts: return FreeTierLimits.usefulContacts
        case .countdowns: return FreeTierLimits.countdowns
        case .appointments: return FreeTierLimits.appointmentDaysLimit
        }
    }

    // MARK: - Feature Enum

    enum LimitedFeature: String, CaseIterable {
        case friendProfiles = "Family Profiles"
        case stickyReminders = "Sticky Reminders"
        case notes = "Notes"
        case todoLists = "To-Do Lists"
        case medications = "Medications"
        case usefulContacts = "Useful Contacts"
        case countdowns = "Countdowns"
        case appointments = "Appointments"

        var icon: String {
            switch self {
            case .friendProfiles: return "person.2"
            case .stickyReminders: return "pin"
            case .notes: return "note.text"
            case .todoLists: return "checklist"
            case .medications: return "pill"
            case .usefulContacts: return "phone.circle"
            case .countdowns: return "calendar.badge.clock"
            case .appointments: return "calendar"
            }
        }

        var limitDescription: String {
            let limit = self.freeLimit
            switch self {
            case .appointments:
                return "next \(limit) days"
            default:
                return "\(limit)"
            }
        }

        /// The free tier limit for this feature (accessed without MainActor)
        var freeLimit: Int {
            switch self {
            case .friendProfiles: return PremiumLimitsManager.FreeTierLimits.friendProfiles
            case .stickyReminders: return PremiumLimitsManager.FreeTierLimits.stickyReminders
            case .notes: return PremiumLimitsManager.FreeTierLimits.notes
            case .todoLists: return PremiumLimitsManager.FreeTierLimits.todoLists
            case .medications: return PremiumLimitsManager.FreeTierLimits.medications
            case .usefulContacts: return PremiumLimitsManager.FreeTierLimits.usefulContacts
            case .countdowns: return PremiumLimitsManager.FreeTierLimits.countdowns
            case .appointments: return PremiumLimitsManager.FreeTierLimits.appointmentDaysLimit
            }
        }

        /// The tier required to unlock unlimited access to this feature
        var requiredTierForUnlimited: SubscriptionTier {
            return .premium
        }
    }

    // MARK: - Family Feature Enum

    enum FamilyFeature: String, CaseIterable {
        case inviteMembers = "Invite Family Members"
        case manageMembers = "Manage Members"

        var icon: String {
            switch self {
            case .inviteMembers: return "person.badge.plus"
            case .manageMembers: return "person.2"
            }
        }
    }
}

// MARK: - Premium Upgrade Prompt View
/// A reusable view to show when user hits a free tier limit
struct PremiumUpgradePrompt: View {
    @Environment(\.appAccentColor) private var appAccentColor

    let feature: PremiumLimitsManager.LimitedFeature
    let currentCount: Int
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(appAccentColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundColor(appAccentColor)
            }

            // Title and message
            VStack(spacing: 8) {
                Text("Upgrade to Premium")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                if feature == .appointments {
                    Text("Free accounts can only create appointments within the next \(PremiumLimitsManager.FreeTierLimits.appointmentDaysLimit) days.")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("You've reached the free limit of \(PremiumLimitsManager.shared.limitForFeature(feature)) \(feature.rawValue.lowercased()).")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Text("Upgrade to Premium for unlimited \(feature.rawValue.lowercased()) and more!")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Buttons
            VStack(spacing: 12) {
                PrimaryButton(title: "Upgrade Now", backgroundColor: appAccentColor) {
                    onUpgrade()
                }

                Button("Maybe Later") {
                    onDismiss()
                }
                .font(.appBody)
                .foregroundColor(.textSecondary)
            }
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .padding(.horizontal, AppDimensions.screenPadding)
    }
}

// MARK: - Family Plus Upgrade Prompt View
/// A view to show when user tries to access a Family Plus feature
struct FamilyPlusUpgradePrompt: View {
    @Environment(\.appAccentColor) private var appAccentColor

    let feature: PremiumLimitsManager.FamilyFeature
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.purple)
            }

            // Title and message
            VStack(spacing: 8) {
                Text("Upgrade to Family Plus")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                Text("The \(feature.rawValue.lowercased()) feature is available with Family Plus.")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Share your Unforgotten account with family members and caregivers.")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Buttons
            VStack(spacing: 12) {
                PrimaryButton(title: "Upgrade Now", backgroundColor: .purple) {
                    onUpgrade()
                }

                Button("Maybe Later") {
                    onDismiss()
                }
                .font(.appBody)
                .foregroundColor(.textSecondary)
            }
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .padding(.horizontal, AppDimensions.screenPadding)
    }
}

// MARK: - Premium Feature Lock View
/// Inline view shown where a "create" button would be when limit is reached
struct PremiumFeatureLockBanner: View {
    @Environment(\.appAccentColor) private var appAccentColor

    let feature: PremiumLimitsManager.LimitedFeature
    let onUpgrade: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 20))
                .foregroundColor(appAccentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Free limit reached")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                Text("Upgrade for unlimited \(feature.rawValue.lowercased())")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Button {
                onUpgrade()
            } label: {
                Text("Upgrade")
                    .font(.appCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(appAccentColor)
                    .cornerRadius(16)
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Family Plus Feature Lock Banner
/// Inline view for family features requiring Family Plus
struct FamilyPlusFeatureLockBanner: View {
    let feature: PremiumLimitsManager.FamilyFeature
    let onUpgrade: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 2) {
                Text("Family Plus Feature")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                Text("Upgrade to \(feature.rawValue.lowercased())")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Button {
                onUpgrade()
            } label: {
                Text("Upgrade")
                    .font(.appCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple)
                    .cornerRadius(16)
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Premium Required View Modifier
/// Shows an upgrade sheet when trying to access a premium-only feature
struct PremiumRequiredModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    let feature: PremiumLimitsManager.LimitedFeature
    let currentCount: Int

    @State private var showUpgradeSheet = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showUpgradeSheet) {
                UpgradeView()
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    let canCreate: Bool
                    switch feature {
                    case .friendProfiles:
                        canCreate = PremiumLimitsManager.shared.canCreateFriendProfile(appState: appState, currentCount: currentCount)
                    case .stickyReminders:
                        canCreate = PremiumLimitsManager.shared.canCreateStickyReminder(appState: appState, currentCount: currentCount)
                    case .notes:
                        canCreate = PremiumLimitsManager.shared.canCreateNote(appState: appState, currentCount: currentCount)
                    case .todoLists:
                        canCreate = PremiumLimitsManager.shared.canCreateToDoList(appState: appState, currentCount: currentCount)
                    case .medications:
                        canCreate = PremiumLimitsManager.shared.canCreateMedication(appState: appState, currentCount: currentCount)
                    case .usefulContacts:
                        canCreate = PremiumLimitsManager.shared.canCreateUsefulContact(appState: appState, currentCount: currentCount)
                    case .countdowns:
                        canCreate = PremiumLimitsManager.shared.canCreateCountdown(appState: appState, currentCount: currentCount)
                    case .appointments:
                        canCreate = PremiumLimitsManager.shared.canCreateAppointment(appState: appState)
                    }

                    if !canCreate {
                        isPresented = false
                        showUpgradeSheet = true
                    }
                }
            }
    }
}

extension View {
    /// Adds premium limit checking to a sheet presentation
    func premiumRequired(
        isPresented: Binding<Bool>,
        feature: PremiumLimitsManager.LimitedFeature,
        currentCount: Int
    ) -> some View {
        modifier(PremiumRequiredModifier(
            isPresented: isPresented,
            feature: feature,
            currentCount: currentCount
        ))
    }
}
