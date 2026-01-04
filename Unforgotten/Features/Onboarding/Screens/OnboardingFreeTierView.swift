import SwiftUI

// MARK: - Onboarding Free Tier View
/// Screen 5: Show what's included in the free tier with option to upgrade
struct OnboardingFreeTierView: View {
    let accentColor: Color
    let onSeePremium: () -> Void
    let onContinueFree: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Feature data for easy iteration
    private let features: [(icon: String, title: String, description: String)] = [
        ("person.fill", "Add one Friend profile", "Add one family member or friend to your network"),
        ("bell.fill", "Add a Reminder", "Set up a Sticky Reminder to help you remember important tasks"),
        ("note.text", "Make one Note", "Keep one important note for quick reference"),
        ("pills.fill", "Add one Medication", "Track one medication with schedule and history"),
        ("paintpalette.fill", "All themes included", "Personalize the app with any theme you like")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 24)

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "gift.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(accentColor)
                        .scaleEffect(hasAppeared ? 1 : 0.5)
                        .opacity(hasAppeared ? 1 : 0)

                    Text("Start with our Free plan")
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)

                    Text("Try out all of the features for yourself before committing to a subscription.")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)
                }
                .padding(.horizontal, AppDimensions.screenPadding)

                // Feature list with staggered animation
                VStack(spacing: 12) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        OnboardingFeatureRow(
                            icon: feature.icon,
                            title: feature.title,
                            description: feature.description,
                            accentColor: accentColor
                        )
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1 + 0.2),
                            value: hasAppeared
                        )
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)

                // Upgrade note
                Text("Ready for more? Upgrade anytime to add unlimited friends, reminders, and more.")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 15)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.7),
                        value: hasAppeared
                    )

                Spacer()
                    .frame(minHeight: 40)

                // Bottom buttons
                VStack(spacing: 12) {
                    // See Premium button
                    PrimaryButton(
                        title: "See Premium options",
                        backgroundColor: accentColor,
                        action: onSeePremium
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.8),
                        value: hasAppeared
                    )

                    // Continue Free button
                    Button {
                        onContinueFree()
                    } label: {
                        Text("Continue with Free")
                            .font(.appBodyMedium)
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppDimensions.buttonHeight)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.9),
                        value: hasAppeared
                    )
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    hasAppeared = true
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingFreeTierView(
            accentColor: Color(hex: "FFC93A"),
            onSeePremium: {},
            onContinueFree: {}
        )
    }
}
