import SwiftUI

// MARK: - Onboarding Progress Dots
/// Progress indicator showing dots for each step in the onboarding flow
struct OnboardingProgressDots: View {
    let currentScreen: OnboardingScreen
    let accentColor: Color

    /// Total number of dots to display
    private let totalDots = OnboardingScreen.progressStepCount

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalDots, id: \.self) { index in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentScreen)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Private Helpers

    private func dotColor(for index: Int) -> Color {
        guard let currentIndex = currentScreen.progressIndex else {
            return Color.cardBackgroundSoft
        }

        if index <= currentIndex {
            return accentColor
        } else {
            return Color.cardBackgroundSoft
        }
    }

    private var accessibilityLabel: String {
        guard let currentIndex = currentScreen.progressIndex else {
            return "Onboarding progress"
        }
        return "Step \(currentIndex + 1) of \(totalDots)"
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 32) {
            OnboardingProgressDots(
                currentScreen: .profileSetup,
                accentColor: Color(hex: "FFC93A")
            )

            OnboardingProgressDots(
                currentScreen: .themeSelection,
                accentColor: Color(hex: "FF9F0A")
            )

            OnboardingProgressDots(
                currentScreen: .friendCode,
                accentColor: Color(hex: "f16690")
            )

            OnboardingProgressDots(
                currentScreen: .notifications,
                accentColor: Color(hex: "6a863e")
            )
        }
    }
}
