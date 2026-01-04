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

    // MARK: - Notifications (Screen 7)
    var notificationsEnabled: Bool = false

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
        notificationsEnabled = false
    }
}

// MARK: - Onboarding Screen
/// Enum representing each screen in the onboarding flow
enum OnboardingScreen: Int, CaseIterable {
    case welcome = 0
    case profileSetup = 1
    case themeSelection = 2
    case friendCode = 3
    case freeTier = 4
    case premium = 5
    case notifications = 6
    case completion = 7

    /// The total number of progress steps (excluding welcome and completion)
    static let progressStepCount = 6

    /// Whether this screen shows progress dots
    var showsProgressDots: Bool {
        switch self {
        case .welcome, .completion:
            return false
        default:
            return true
        }
    }

    /// The progress step index (0-based) for screens that show progress
    /// Premium is a branch from freeTier, so it shares the same progress index
    var progressIndex: Int? {
        switch self {
        case .welcome, .completion:
            return nil
        case .profileSetup:
            return 0
        case .themeSelection:
            return 1
        case .friendCode:
            return 2
        case .freeTier, .premium:
            return 3
        case .notifications:
            return 4
        }
    }

    /// Whether this screen allows back navigation
    var canGoBack: Bool {
        switch self {
        case .welcome, .completion:
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
        case .friendCode:
            return .themeSelection
        case .freeTier:
            return .friendCode
        case .premium:
            return .freeTier
        case .notifications:
            return .freeTier // Skip premium when going back
        case .completion:
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
