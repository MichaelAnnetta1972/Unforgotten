import SwiftUI

// MARK: - Onboarding Free Tier View
/// Screen 5: Show what's included in the free tier with option to upgrade
/// Features a clean list design with blue accent dots
struct OnboardingFreeTierView: View {
    let accentColor: Color
    let onSeePremium: () -> Void
    let onContinueFree: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    // Feature data with titles and descriptions
    private let features: [(title: String, description: String)] = [
        ("5 Medications", "Track up to 5 medications with schedules and reminders"),
        ("30 days of Appointments", "Schedule appointments within the next 30 days"),
        ("2 Family Profiles", "Set up 2 Family or Friends profiles"),
        ("5 Notes, Sticky Reminders and Useful Contacts", "Get started by setting up some key features"),
        ("2 To Do Lists", "Have fun with lists!")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: isRegularWidth ? 32 : 24) {
                Spacer()
                    .frame(height: isRegularWidth ? 60 : 40)

                // Header
                VStack(spacing: 12) {
                    Text("Start with a Free Plan")
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)

                    Text("Try out the features for yourself before committing to a subscription")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                    value: hasAppeared
                )

                // Free Plan section with background
                VStack(alignment: .leading, spacing: 20) {
                    Text("Free Plan")
                        .font(.appTitle)
                        .foregroundColor(.textPrimary)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 15)
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.1),
                            value: hasAppeared
                        )

                    // Feature list
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                            FreeTierFeatureRow(
                                title: feature.title,
                                description: feature.description,
                                accentColor: accentColor
                            )
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(
                                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05 + 0.15),
                                value: hasAppeared
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(isRegularWidth ? 28 : 20)
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
                .frame(maxWidth: isRegularWidth ? 500 : .infinity)
                .padding(.horizontal, AppDimensions.screenPadding)

                // Upgrade note
                Text("Need more? Upgrade to Premium for unlimited everything, or Family Plus to connect with family or friends")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 15)
                    .frame(maxWidth: isRegularWidth ? 500 : .infinity)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.5),
                        value: hasAppeared
                    )

                // Bottom buttons
                VStack(spacing: isRegularWidth ? 16 : 12) {
                    // See subscription options button
                    Button(action: onSeePremium) {
                        Text("See subscription options")
                            .font(.appBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppDimensions.buttonHeight)
                            .background(accentColor)
                            .cornerRadius(AppDimensions.buttonCornerRadius)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.55),
                        value: hasAppeared
                    )

                    // Continue Free button
                    Button(action: onContinueFree) {
                        Text("Continue with Free")
                            .font(.appBodyMedium)
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppDimensions.buttonHeight)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.6),
                        value: hasAppeared
                    )
                }
                .frame(maxWidth: isRegularWidth ? 400 : .infinity)
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.bottom, isRegularWidth ? 64 : 48)
            }
            .frame(maxWidth: .infinity)
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

// MARK: - Free Tier Feature Row
struct FreeTierFeatureRow: View {
    let title: String
    let description: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Accent color dot indicator
            Circle()
                .fill(accentColor)
                .frame(width: 12, height: 12)
                .padding(.top, 4)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                Text(description)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
