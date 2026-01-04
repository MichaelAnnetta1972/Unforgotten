import SwiftUI

// MARK: - Onboarding Theme Manager
/// Manages theme state during the onboarding flow
/// Provides dynamic accent colors and header images that update as the user selects themes
@Observable
class OnboardingThemeManager {
    // MARK: - Properties

    /// The currently selected header style
    var selectedStyle: HeaderStyle = .defaultStyle

    // MARK: - Computed Properties

    /// The accent color for the currently selected style
    var accentColor: Color {
        selectedStyle.defaultAccentColor
    }

    /// The accent color hex string for the currently selected style
    var accentColorHex: String {
        selectedStyle.defaultAccentColorHex
    }

    /// The preview image name for the style picker
    var previewImageName: String {
        selectedStyle.previewImageName
    }

    /// The home header asset for the current style
    var homeHeaderAsset: HeaderAsset {
        selectedStyle.assets.home
    }

    // MARK: - Methods

    /// Select a new header style with animation
    /// - Parameter style: The header style to select
    func selectStyle(_ style: HeaderStyle) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedStyle = style
        }
    }

    /// Apply the selected theme to the main app's theme managers
    /// - Parameters:
    ///   - headerStyleManager: The app's header style manager
    ///   - userPreferences: The app's user preferences
    func applyToMainTheme(
        headerStyleManager: HeaderStyleManager,
        userPreferences: UserPreferences
    ) {
        // Update the main header style manager
        headerStyleManager.selectStyle(selectedStyle)

        // Reset user preferences to use the style's default accent color
        userPreferences.resetToStyleDefault()
    }

    /// Reset to the default style
    func reset() {
        selectedStyle = .defaultStyle
    }
}

// MARK: - Environment Key
/// Environment key for accessing the onboarding theme manager
private struct OnboardingThemeManagerKey: EnvironmentKey {
    static let defaultValue: OnboardingThemeManager? = nil
}

extension EnvironmentValues {
    var onboardingThemeManager: OnboardingThemeManager? {
        get { self[OnboardingThemeManagerKey.self] }
        set { self[OnboardingThemeManagerKey.self] = newValue }
    }
}

// MARK: - Onboarding Accent Color Key
/// Environment key for the onboarding accent color
/// This allows screens to react to theme changes during onboarding
private struct OnboardingAccentColorKey: EnvironmentKey {
    static let defaultValue: Color = Color(hex: "FFC93A") // Default yellow
}

extension EnvironmentValues {
    var onboardingAccentColor: Color {
        get { self[OnboardingAccentColorKey.self] }
        set { self[OnboardingAccentColorKey.self] = newValue }
    }
}
