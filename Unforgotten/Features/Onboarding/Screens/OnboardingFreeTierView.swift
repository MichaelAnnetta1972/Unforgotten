import SwiftUI

// MARK: - Onboarding Free Tier View
/// Screen 5: Show what's included in the free tier with option to upgrade
struct OnboardingFreeTierView: View {
    let accentColor: Color
    let onSeePremium: () -> Void
    let onContinueFree: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Feature data for easy iteration - updated with new free tier limits
    private let features: [(icon: String, title: String, description: String)] = [
        ("pill.fill", "5 Medications", "Track up to 5 medications with schedules and reminders"),
        ("calendar", "30 Days of Appointments", "Schedule appointments within the next 30 days"),
        ("person.2.fill", "2 Family Profiles", "Add up to 2 family members or friends"),
        ("checklist", "2 To-Do Lists", "Create up to 2 to-do lists to stay organized"),
        ("note.text", "5 Notes", "Keep up to 5 important notes for quick reference"),
        ("pin.fill", "5 Sticky Reminders", "Set up to 5 sticky reminders for important tasks"),
        ("phone.circle.fill", "5 Useful Contacts", "Store up to 5 important contacts"),
        ("calendar.badge.clock", "2 Countdowns", "Track up to 2 upcoming events or occasions"),
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

                    Text("Try out the features for yourself before committing to a subscription.")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)
                }
                .padding(.horizontal, AppDimensions.screenPadding)

                // Feature list with staggered animation
                VStack(spacing: 10) {
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
                            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05 + 0.2),
                            value: hasAppeared
                        )
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)

                // Upgrade note
                Text("Need more? Upgrade to Premium for unlimited everything, or Family Plus to share with caregivers.")
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
                        title: "See subscription options",
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
