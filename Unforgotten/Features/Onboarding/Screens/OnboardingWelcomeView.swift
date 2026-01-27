import SwiftUI

// MARK: - Welcome Background View
/// Separate background view matching AuthBackgroundView pattern
struct WelcomeBackgroundView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Base dark background
                Color.appBackground

                // Background image (family silhouette) - fills entire screen
                Image("onboarding-welcome-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipped()

                // Gradient overlay for text readability at bottom
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: geometry.size.height * 0.5)

                    LinearGradient(
                        colors: [
                            Color.appBackground.opacity(0),
                            Color.appBackground.opacity(0.7),
                            Color.appBackground.opacity(0.95),
                            Color.appBackground
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Onboarding Welcome View
/// Screen 1: Welcome screen with full-screen background image and value proposition
struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    // Default theme accent color (before user selects)
    private let defaultAccentColor = Color(hex: "FFC93A")

    // Button gradient colors matching design
    private let buttonGradient = LinearGradient(
        colors: [Color(hex: "79A5D7"), Color(hex: "8CBFD3")],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen background
                WelcomeBackgroundView()
                    .ignoresSafeArea()

                // Content overlay - all content anchored to bottom
                VStack(spacing: 0) {
                    Spacer()

                    // Bottom content section with logo
                    VStack(spacing: isRegularWidth ? 72 : 60) {
                        // Logo above title
                        Image("unforgotten-logo-stacked")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: isRegularWidth ? 120 : 100)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(
                                reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.1),
                                value: hasAppeared
                            )

                        // Headlines
                        VStack(spacing: 12) {
                        //    Text("Never forget what matters most")
                        //        .font(.appLargeTitle)
                        //        .foregroundColor(.textPrimary)
                        //        .multilineTextAlignment(.center)

                            Text("Keep track of medications, birthdays, appointments and the people you care most about... all in the one place")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, isRegularWidth ? 48 : 32)
                        .frame(maxWidth: isRegularWidth ? 500 : .infinity)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.2),
                            value: hasAppeared
                        )

                        // Get Started button
                        Button(action: onContinue) {
                            Text("Get started")
                                .font(.appBodyMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: AppDimensions.buttonHeight)
                                .background(buttonGradient)
                                .cornerRadius(AppDimensions.buttonCornerRadius)
                        }
                        .frame(maxWidth: isRegularWidth ? 400 : .infinity)
                        .padding(.horizontal, isRegularWidth ? 48 : 32)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.3),
                            value: hasAppeared
                        )
                    }
                    .padding(.bottom, (isRegularWidth ? 80 : 60) + geometry.safeAreaInsets.bottom)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation {
                    hasAppeared = true
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingWelcomeView(onContinue: {})
}
