import SwiftUI

// MARK: - Onboarding Container View
/// Main container that manages the onboarding flow state and navigation
struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(HeaderStyleManager.self) private var headerStyleManager
    @Environment(UserPreferences.self) private var userPreferences

    // MARK: - State
    @State private var currentScreen: OnboardingScreen = .welcome
    @State private var onboardingData = OnboardingData()
    @State private var themeManager = OnboardingThemeManager()
    @State private var slideDirection: OnboardingSlideDirection = .forward
    @State private var isCompleting = false
    @State private var completionError: String? = nil
    @State private var showCancelConfirmation = false

    // Reduce motion preference
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // Screen content - full width for background images
            screenContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Navigation bar overlay (so it floats on top of content)
            VStack {
                if currentScreen.showsProgressDots {
                    navigationBar
                        .padding(.horizontal, AppDimensions.screenPadding)
                        .padding(.top, 8)
                        .frame(maxWidth: 650)
                } else if currentScreen == .welcome {
                    // Close button only for welcome screen - positioned on right
                    HStack {
                        Spacer()
                        closeButton
                            .padding(.trailing, AppDimensions.screenPadding)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: 650)
                }
                Spacer()
            }
        }
        .environment(\.onboardingAccentColor, themeManager.accentColor)
        .tint(themeManager.accentColor)
        .gesture(swipeGesture)
        .alert("Cancel Setup?", isPresented: $showCancelConfirmation) {
            Button("Continue Setup", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                cancelOnboarding()
            }
        } message: {
            Text("Are you sure you want to cancel? You'll need to sign in again to continue.")
        }
    }

    // MARK: - Close Button
    private var closeButton: some View {
        Button {
            showCancelConfirmation = true
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Cancel setup")
    }

    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack {
            // Back button (chevron) - now on left
            if currentScreen.canGoBack {
                Button {
                    navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Go back")
            } else {
                Spacer()
                    .frame(width: 44)
            }

            Spacer()

            // Progress dots
            OnboardingProgressDots(
                currentScreen: currentScreen,
                accentColor: themeManager.accentColor
            )

            Spacer()

            // Close button - now on right
            closeButton
        }
        .frame(height: 44)
    }

    // MARK: - Screen Content
    @ViewBuilder
    private var screenContent: some View {
        Group {
            switch currentScreen {
            case .welcome:
                OnboardingWelcomeView(onContinue: {
                    navigateTo(.profileSetup)
                })

            case .profileSetup:
                OnboardingProfileSetupView(
                    onboardingData: onboardingData,
                    accentColor: themeManager.accentColor,
                    onContinue: {
                        navigateTo(.themeSelection)
                    }
                )

            case .themeSelection:
                OnboardingThemeSelectionView(
                    themeManager: themeManager,
                    onContinue: {
                        navigateTo(.friendCode)
                    }
                )

            case .friendCode:
                OnboardingFriendCodeView(
                    onboardingData: onboardingData,
                    accentColor: themeManager.accentColor,
                    onContinue: {
                        navigateTo(.premium)
                    }
                )

            case .premium:
                OnboardingPremiumView(
                    onboardingData: onboardingData,
                    accentColor: themeManager.accentColor,
                    onContinue: {
                        // If user subscribed, go to notifications; if "Maybe Later", go to freeTier
                        if onboardingData.isPremium {
                            navigateTo(.notifications)
                        } else {
                            navigateTo(.freeTier)
                        }
                    }
                )

            case .freeTier:
                OnboardingFreeTierView(
                    accentColor: themeManager.accentColor,
                    onSeePremium: {
                        navigateTo(.premium)
                    },
                    onContinueFree: {
                        navigateTo(.notifications)
                    }
                )

            case .notifications:
                OnboardingNotificationsView(
                    onboardingData: onboardingData,
                    accentColor: themeManager.accentColor,
                    onContinue: {
                        navigateTo(.activation)
                    }
                )

            case .activation:
                OnboardingActivationView(
                    onboardingData: onboardingData,
                    accentColor: themeManager.accentColor,
                    isCompleting: isCompleting,
                    errorMessage: completionError,
                    onComplete: {
                        completionError = nil
                        completeOnboarding()
                    }
                )
            }
        }
        .transition(screenTransition)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: currentScreen)
    }

    // MARK: - Navigation

    private func navigateTo(_ screen: OnboardingScreen) {
        slideDirection = screen.rawValue > currentScreen.rawValue ? .forward : .backward
        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
            currentScreen = screen
        }
    }

    private func navigateBack() {
        guard let previous = currentScreen.previous else { return }
        slideDirection = .backward
        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
            currentScreen = previous
        }
    }

    private var screenTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        switch slideDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                // Only allow swipe back, not forward
                if value.translation.width > 50 && currentScreen.canGoBack {
                    navigateBack()
                }
            }
    }

    // MARK: - Cancel Onboarding

    private func cancelOnboarding() {
        Task {
            await appState.signOut()
        }
    }

    // MARK: - Complete Onboarding

    private func completeOnboarding() {
        guard !isCompleting else { return }
        isCompleting = true

        Task {
            do {
                // Apply theme to main app
                themeManager.applyToMainTheme(
                    headerStyleManager: headerStyleManager,
                    userPreferences: userPreferences
                )

                // Complete onboarding in AppState
                try await appState.completeOnboarding(
                    accountName: onboardingData.accountName,
                    primaryProfileName: onboardingData.fullName,
                    birthday: nil, // Birthday not collected in new flow
                    firstAction: .exploreApp // Default action - go to home
                )

                // The RootView will automatically show MainAppView

            } catch {
                #if DEBUG
                print("❌ Onboarding completion error: \(error)")
                #endif
                await MainActor.run {
                    completionError = "Failed to set up your account. Please try again. (\(error.localizedDescription))"
                    isCompleting = false
                }
            }
        }
    }
}

// MARK: - Onboarding Slide Direction
private enum OnboardingSlideDirection {
    case forward
    case backward
}

// MARK: - Preview
#Preview {
    OnboardingContainerView()
        .environmentObject(AppState.forPreview())
        .environment(HeaderStyleManager())
        .environment(UserPreferences())
}
