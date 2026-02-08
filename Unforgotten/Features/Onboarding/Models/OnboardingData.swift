import SwiftUI
import UIKit

// MARK: - Onboarding Data
/// Observable class that holds all data collected during the onboarding flow
@Observable
class OnboardingData {
    // MARK: - Profile Setup (Screen 2)
    var firstName: String = ""
    var lastName: String = ""
    var profilePhoto: UIImage? = nil
    var photoURL: String? = nil

    // MARK: - Theme Selection (Screen 3)
    var selectedHeaderStyle: HeaderStyle = .defaultStyle

    // MARK: - Friend Code (Screen 4)
    var friendCode: String? = nil
    var connectedInvitation: AccountInvitation? = nil
    var connectedAccountName: String? = nil

    // MARK: - Subscription (Screen 6)
    var isPremium: Bool = false
    var subscriptionProductId: String? = nil
    var subscriptionTier: SubscriptionTier = .free

    // MARK: - Notifications (Screen 7)
    var notificationsEnabled: Bool = false

    // MARK: - Feature Selection
    /// Features the user has selected to show on their home screen
    /// Defaults to all toggleable features selected
    var selectedFeatures: Set<Feature> = Set(Feature.allCases.filter { $0.canBeHidden })

    // MARK: - Computed Properties

    /// Full name combining first and last name
    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    /// Account name derived from first name
    var accountName: String {
        guard !firstName.isBlank else { return "My Account" }
        return "\(firstName)'s Account"
    }

    /// Whether the profile setup is valid (both names filled)
    var isProfileValid: Bool {
        !firstName.isBlank && !lastName.isBlank
    }

    /// Whether the user connected via a friend code
    var hasConnectedViaCode: Bool {
        connectedInvitation != nil
    }

    /// Whether the connected invitation grants admin permissions
    var hasAdminPermission: Bool {
        guard let invitation = connectedInvitation else { return false }
        return invitation.role == .admin || invitation.role == .owner
    }

    // MARK: - Methods

    /// Reset all data to initial state
    func reset() {
        firstName = ""
        lastName = ""
        profilePhoto = nil
        photoURL = nil
        selectedHeaderStyle = .defaultStyle
        friendCode = nil
        connectedInvitation = nil
        connectedAccountName = nil
        isPremium = false
        subscriptionProductId = nil
        subscriptionTier = .free
        notificationsEnabled = false
        selectedFeatures = Set(Feature.allCases.filter { $0.canBeHidden })
    }
}

// MARK: - Onboarding Screen
/// Enum representing each screen in the onboarding flow
enum OnboardingScreen: Int, CaseIterable {
    case welcome = 0
    case profileSetup = 1
    case themeSelection = 2
    case featureSelection = 3
    case friendCode = 4
    case premium = 5
    case freeTier = 6
    case notifications = 7
    case activation = 8

    /// The total number of progress steps (excluding welcome and activation)
    /// Includes: 6 main screens (profile, theme, features, friendCode, premium/freeTier, notifications)
    static let progressStepCount = 6

    /// Whether this screen shows progress dots
    var showsProgressDots: Bool {
        switch self {
        case .welcome, .activation:
            return false
        default:
            return true
        }
    }

    /// The progress step index (0-based) for screens that show progress
    /// Premium and freeTier share the same progress index as they are alternate paths
    var progressIndex: Int? {
        switch self {
        case .welcome, .activation:
            return nil
        case .profileSetup:
            return 0
        case .themeSelection:
            return 1
        case .featureSelection:
            return 2
        case .friendCode:
            return 3
        case .premium, .freeTier:
            return 4
        case .notifications:
            return 5
        }
    }

    /// Whether this screen allows back navigation
    var canGoBack: Bool {
        switch self {
        case .welcome, .activation:
            return false
        default:
            return true
        }
    }

    /// The previous screen in the flow
    var previous: OnboardingScreen? {
        switch self {
        case .welcome:
            return nil
        case .profileSetup:
            return .welcome
        case .themeSelection:
            return .profileSetup
        case .featureSelection:
            return .themeSelection
        case .friendCode:
            return .featureSelection
        case .premium:
            return .friendCode
        case .freeTier:
            return .premium
        case .notifications:
            return .premium // Skip freeTier when going back
        case .activation:
            return .notifications
        }
    }
}

// MARK: - First Action
/// The action the user chooses on the completion screen
enum OnboardingFirstAction: String, CaseIterable {
    case addFriend
    case createReminder
    case updateDetails
    case exploreApp

    var title: String {
        switch self {
        case .addFriend:
            return "Add a friend"
        case .createReminder:
            return "Create a reminder"
        case .updateDetails:
            return "Update your details"
        case .exploreApp:
            return "Explore the app"
        }
    }

    var description: String {
        switch self {
        case .addFriend:
            return "Add family members or friends to your care network"
        case .createReminder:
            return "Set up a Sticky Reminder to help you remember things to do"
        case .updateDetails:
            return "Add more information to your personal profile"
        case .exploreApp:
            return "Take a look around and discover all features"
        }
    }

    var icon: String {
        switch self {
        case .addFriend:
            return "person.badge.plus"
        case .createReminder:
            return "bell.badge"
        case .updateDetails:
            return "person.text.rectangle"
        case .exploreApp:
            return "sparkles"
        }
    }
}
