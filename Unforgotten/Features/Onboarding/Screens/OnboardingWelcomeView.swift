import SwiftUI

// MARK: - Onboarding Welcome View
/// Screen 1: Welcome screen with hero image and value proposition
struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Default theme accent color (before user selects)
    private let defaultAccentColor = Color(hex: "FFC93A")

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero section
            VStack(spacing: 24) {
                // Hero image placeholder
                heroImage
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                        value: hasAppeared
                    )

                // App logo
                Image("unforgotten-logo-stacked")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.1),
                        value: hasAppeared
                    )

                // Headlines
                VStack(spacing: 12) {
                    Text("Never forget what matters most")
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Keep track of medications, birthdays, appointments,\n and the people you care most about...\nall in the one place.")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.2),
                    value: hasAppeared
                )
            }

            Spacer()
            Spacer()

            // Get Started button
            PrimaryButton(
                title: "Get Started",
                backgroundColor: defaultAccentColor,
                action: onContinue
            )
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.bottom, 48)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(
                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.3),
                value: hasAppeared
            )
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

    // MARK: - Hero Video
    private var heroImage: some View {
        LoopingVideoPlayerView(
            videoName: "welcome-hero",
            videoExtension: "mp4",
            isMuted: true,
            shouldLoop: true,
            gravity: .resizeAspectFill
        )
        .frame(width: 280, height: 200)
        .cornerRadius(24)
        .clipped()
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.9)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingWelcomeView(onContinue: {})
    }
}
