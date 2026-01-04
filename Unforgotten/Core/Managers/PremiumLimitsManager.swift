import Foundation
import SwiftUI

// MARK: - Premium Limits Manager
/// Manages free tier limitations and premium access checks
@MainActor
final class PremiumLimitsManager: ObservableObject {
    static let shared = PremiumLimitsManager()

    // MARK: - Free Tier Limits
    /// Maximum number of items allowed on the free tier
    struct FreeTierLimits {
        static let friendProfiles = 1       // Friend/family profiles (excludes primary "My Card")
        static let stickyReminders = 1
        static let notes = 1
        static let todoLists = 1
        static let medications = 1
        static let appointments = 1
        static let usefulContacts = 1
        static let canInviteMembers = false
        static let canJoinOtherAccounts = false
    }

    private init() {}

    // MARK: - Check Premium Access

    /// Check if user has premium access (paid or complimentary)
    func hasPremiumAccess(appState: AppState) -> Bool {
        return appState.hasPremiumAccess
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

    /// Check if user can create another appointment
    func canCreateAppointment(appState: AppState, currentCount: Int) -> Bool {
        if hasPremiumAccess(appState: appState) { return true }
        return currentCount < FreeTierLimits.appointments
    }

    /// Check if user can create another useful contact
    func canCreateUsefulContact(appState: AppState, currentCount: Int) -> Bool {
        if hasPremiumAccess(appState: appState) { return true }
        return currentCount < FreeTierLimits.usefulContacts
    }

    /// Check if user can invite family members
    func canInviteMembers(appState: AppState) -> Bool {
        if hasPremiumAccess(appState: appState) { return true }
        return FreeTierLimits.canInviteMembers
    }

    /// Check if user can join another account
    func canJoinOtherAccounts(appState: AppState) -> Bool {
        if hasPremiumAccess(appState: appState) { return true }
        return FreeTierLimits.canJoinOtherAccounts
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
        case .appointments: return FreeTierLimits.appointments
        case .usefulContacts: return FreeTierLimits.usefulContacts
        }
    }

    // MARK: - Feature Enum

    enum LimitedFeature: String, CaseIterable {
        case friendProfiles = "Friend Profiles"
        case stickyReminders = "Sticky Reminders"
        case notes = "Notes"
        case todoLists = "To-Do Lists"
        case medications = "Medications"
        case appointments = "Appointments"
        case usefulContacts = "Useful Contacts"

        var icon: String {
            switch self {
            case .friendProfiles: return "person.2"
            case .stickyReminders: return "pin"
            case .notes: return "note.text"
            case .todoLists: return "checklist"
            case .medications: return "pill"
            case .appointments: return "calendar"
            case .usefulContacts: return "phone.circle"
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

                Text("You've reached the free limit of \(PremiumLimitsManager.shared.limitForFeature(feature)) \(feature.rawValue.lowercased()).")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)

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
                    case .appointments:
                        canCreate = PremiumLimitsManager.shared.canCreateAppointment(appState: appState, currentCount: currentCount)
                    case .usefulContacts:
                        canCreate = PremiumLimitsManager.shared.canCreateUsefulContact(appState: appState, currentCount: currentCount)
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
