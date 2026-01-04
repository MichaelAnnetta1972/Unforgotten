import SwiftUI

// MARK: - Onboarding Notifications View
/// Screen 7: Request notification permissions with value explanation
struct OnboardingNotificationsView: View {
    @Bindable var onboardingData: OnboardingData
    let accentColor: Color
    let onContinue: () -> Void

    @State private var isRequesting = false
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Content
            VStack(spacing: 32) {
                // Illustration placeholder
                illustrationView
                    .opacity(hasAppeared ? 1 : 0)
                    .scaleEffect(hasAppeared ? 1 : 0.8)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                        value: hasAppeared
                    )

                // Headlines
                VStack(spacing: 12) {
                    Text("Stay on top of what matters")
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Get timely reminders for medications, birthdays, and appointments")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 15)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.1),
                    value: hasAppeared
                )

                // Notification examples
                VStack(spacing: 12) {
                    notificationExampleAnimated(
                        icon: "pills.fill",
                        title: "Time for your vitamins",
                        subtitle: "Tap to mark as taken",
                        delay: 0.2
                    )

                    notificationExampleAnimated(
                        icon: "calendar",
                        title: "Doctor's appointment tomorrow",
                        subtitle: "10:00 AM at City Medical Center",
                        delay: 0.3
                    )

                    notificationExampleAnimated(
                        icon: "gift.fill",
                        title: "Sarah's birthday is today!",
                        subtitle: "Don't forget to wish her well",
                        delay: 0.4
                    )
                }
                .padding(.horizontal, AppDimensions.screenPadding)
            }

            Spacer()
            Spacer()

            // Bottom buttons
            VStack(spacing: 16) {
                PrimaryButton(
                    title: "Enable Notifications",
                    isLoading: isRequesting,
                    backgroundColor: accentColor,
                    action: requestNotifications
                )

                Button {
                    onContinue()
                } label: {
                    Text("Not now")
                        .font(.appBodyMedium)
                        .foregroundColor(.textSecondary)
                }
                .disabled(isRequesting)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.bottom, 48)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(
                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.5),
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

    // MARK: - Illustration View
    private var illustrationView: some View {
        // Placeholder illustration - replace with actual asset
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: 140, height: 140)

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(accentColor)
        }
    }

    // MARK: - Notification Example (Animated)
    private func notificationExampleAnimated(icon: String, title: String, subtitle: String, delay: Double) -> some View {
        notificationExample(icon: icon, title: title, subtitle: subtitle)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(
                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(delay),
                value: hasAppeared
            )
    }

    // MARK: - Notification Example
    private func notificationExample(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            // App icon placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(accentColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("now")
                .font(.system(size: 11))
                .foregroundColor(.textMuted)
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Request Notifications
    private func requestNotifications() {
        isRequesting = true

        Task {
            let granted = await NotificationService.shared.requestPermission()

            await MainActor.run {
                onboardingData.notificationsEnabled = granted
                isRequesting = false
                onContinue()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingNotificationsView(
            onboardingData: OnboardingData(),
            accentColor: Color(hex: "FFC93A"),
            onContinue: {}
        )
    }
}
