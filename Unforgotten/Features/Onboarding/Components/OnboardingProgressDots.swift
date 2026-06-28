import SwiftUI

// MARK: - Onboarding Progress Dots
/// Progress indicator showing dots for each step in the onboarding flow
struct OnboardingProgressDots: View {
    let currentScreen: OnboardingScreen
    let accentColor: Color

    /// Total number of dots to display
    private let totalDots = OnboardingScreen.progressStepCount

    // Dot sizing
    private let dotSize: CGFloat = 12
    private let currentDotWidth: CGFloat = 28

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalDots, id: \.self) { index in
                Capsule()
                    .fill(dotColor(for: index))
                    .frame(width: width(for: index), height: dotSize)
                    .animation(.easeInOut(duration: 0.25), value: currentScreen)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Private Helpers

    private func width(for index: Int) -> CGFloat {
        index == currentScreen.progressIndex ? currentDotWidth : dotSize
    }

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
