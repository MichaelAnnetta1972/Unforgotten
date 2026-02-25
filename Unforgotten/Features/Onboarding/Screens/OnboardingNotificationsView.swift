import SwiftUI

// MARK: - Onboarding Notifications View
/// Screen 7: Request notification permissions with value explanation
/// Features a background image at the top with content anchored to the bottom
struct OnboardingNotificationsView: View {
    @Bindable var onboardingData: OnboardingData
    let accentColor: Color
    let onContinue: () -> Void

    @State private var isRequesting = false
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with image at top
                notificationsBackground(geometry: geometry)

                // Content anchored to bottom
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer()

                        // Form content
                        VStack(spacing: isRegularWidth ? 32 : 24) {
                            // Headlines
                            VStack(spacing: 12) {
                                Text("Stay on top of what matters")
                                    .font(.appLargeTitle)
                                    .foregroundColor(.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .opacity(hasAppeared ? 1 : 0)
                                    .offset(y: hasAppeared ? 0 : 10)

                                Text("Get timely reminders for medications, birthdays, and appointments")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .opacity(hasAppeared ? 1 : 0)
                                    .offset(y: hasAppeared ? 0 : 10)
                            }
                            .padding(.horizontal, AppDimensions.screenPadding)
                            .animation(
                                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                                value: hasAppeared
                            )

                            // Notification examples
                            VStack(spacing: isRegularWidth ? 16 : 12) {
                                notificationExampleAnimated(
                                    icon: "pills.fill",
                                    title: "Time for your vitamins",
                                    subtitle: "Tap to mark as taken",
                                    delay: 0.1
                                )

                                notificationExampleAnimated(
                                    icon: "calendar",
                                    title: "Doctor's appointment tomorrow",
                                    subtitle: "10:00 AM at City Medical Center",
                                    delay: 0.2
                                )

                                notificationExampleAnimated(
                                    icon: "gift.fill",
                                    title: "Sarah's birthday is today!",
                                    subtitle: "Don't forget to wish her well",
                                    delay: 0.3
                                )
                            }
                            .frame(maxWidth: isRegularWidth ? 500 : .infinity)
                            .padding(.horizontal, AppDimensions.screenPadding)

                            // Bottom buttons
                            VStack(spacing: isRegularWidth ? 20 : 16) {
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
                            .frame(maxWidth: isRegularWidth ? 400 : .infinity)
                            .padding(.horizontal, AppDimensions.screenPadding)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(
                                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.4),
                                value: hasAppeared
                            )
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom + (isRegularWidth ? 48 : 32))
                    }
                    .frame(minHeight: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                    .frame(maxWidth: .infinity)
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

    // MARK: - Background
    @ViewBuilder
    private func notificationsBackground(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            // Base dark background
            Color.appBackground

            // Background image - aligned to top
            Image("onboarding-notifications-bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()

            // Gradient overlay for smooth transition to content area
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: geometry.size.height * 0.3)

                LinearGradient(
                    colors: [
                        Color.appBackground.opacity(0),
                        Color.appBackground.opacity(0.5),
                        Color.appBackground.opacity(0.9),
                        Color.appBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
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
                // Persist the in-app notification preference based on user's choice
                NotificationService.shared.allowNotifications = granted
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
