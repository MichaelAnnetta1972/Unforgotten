import SwiftUI

// MARK: - Onboarding Activation View
/// Screen 8: Final activation screen with animated checklist
/// Shows features being "activated" one by one before completing onboarding
/// Cards appear in staggered formation as they are checked
struct OnboardingActivationView: View {
    @Bindable var onboardingData: OnboardingData
    let accentColor: Color
    let isCompleting: Bool
    var errorMessage: String? = nil
    let onComplete: () -> Void

    @State private var hasAppeared = false
    @State private var visibleFeatures: Set<Int> = []
    @State private var activatedFeatures: Set<Int> = []
    @State private var allFeaturesActivated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    /// Features to activate - includes required features plus user-selected features
    private var features: [String] {
        var featureNames: [String] = []

        // Always include required features first
        for feature in Feature.requiredFeatures {
            featureNames.append(feature.displayName)
        }

        // Add user-selected features (sorted for consistent order)
        let selectedFeatures = onboardingData.selectedFeatures
            .sorted { $0.rawValue < $1.rawValue }

        for feature in selectedFeatures {
            featureNames.append(feature.displayName)
        }

        return featureNames
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: isRegularWidth ? 80 : 60)

                // Header
                Text("Activating your workspace")
                    .font(.appLargeTitle)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                        value: hasAppeared
                    )

                Spacer()
                    .frame(height: isRegularWidth ? 48 : 40)

                // Feature checklist - cards appear one at a time as they're checked
                VStack(spacing: isRegularWidth ? 12 : 8) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        ActivationFeatureRow(
                            title: feature,
                            isActivated: activatedFeatures.contains(index),
                            accentColor: accentColor
                        )
                        .opacity(visibleFeatures.contains(index) ? 1 : 0)
                        .offset(y: visibleFeatures.contains(index) ? 0 : 20)
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                            value: visibleFeatures.contains(index)
                        )
                    }
                }
                .frame(maxWidth: isRegularWidth ? 500 : .infinity)
                .padding(.horizontal, AppDimensions.screenPadding)

                Spacer()
                    .frame(height: isRegularWidth ? 48 : 40)

                // Completion message and button
                VStack(spacing: isRegularWidth ? 32 : 24) {
                    if allFeaturesActivated {
                        Text("You're all set up")
                            .font(.appTitle)
                            .foregroundColor(.textPrimary)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppDimensions.screenPadding)
                    }

                    // Let's go button (only shown when all features activated)
                    if allFeaturesActivated {
                        Button(action: onComplete) {
                            HStack {
                                if isCompleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Let's go!")
                                        .font(.appBodyMedium)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppDimensions.buttonHeight)
                            .background(accentColor)
                            .cornerRadius(AppDimensions.buttonCornerRadius)
                        }
                        .disabled(isCompleting)
                        .frame(maxWidth: isRegularWidth ? 400 : .infinity)
                        .padding(.horizontal, AppDimensions.screenPadding)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.bottom, isRegularWidth ? 64 : 48)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: allFeaturesActivated)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            startActivationAnimation()
        }
    }

    // MARK: - Activation Animation
    private func startActivationAnimation() {
        guard !reduceMotion else {
            // If reduce motion is enabled, show and activate all at once
            for index in features.indices {
                visibleFeatures.insert(index)
                activatedFeatures.insert(index)
            }
            allFeaturesActivated = true
            return
        }

        // Stagger the appearance and activation of each feature
        for index in features.indices {
            // First, make the card visible (fade in and up)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2 + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    visibleFeatures.insert(index)
                }

                // Then activate it (check it) shortly after it appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        activatedFeatures.insert(index)
                    }

                    // Haptic feedback for each activation
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()

                    // Check if all features are activated
                    if activatedFeatures.count == features.count {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                allFeaturesActivated = true
                            }

                            // Success haptic
                            let notificationFeedback = UINotificationFeedbackGenerator()
                            notificationFeedback.notificationOccurred(.success)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Activation Feature Row
struct ActivationFeatureRow: View {
    let title: String
    let isActivated: Bool
    let accentColor: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.appBodyMedium)
                .foregroundColor(.textPrimary)

            Spacer()

            // Checkmark circle
            ZStack {
                Circle()
                    .fill(isActivated ? accentColor : Color.clear)
                    .frame(width: 28, height: 28)

                if isActivated {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay(
                Circle()
                    .stroke(isActivated ? accentColor : Color.textSecondary.opacity(0.3), lineWidth: 2)
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.buttonCornerRadius)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingActivationView(
            onboardingData: OnboardingData(),
            accentColor: Color(hex: "FFC93A"),
            isCompleting: false,
            onComplete: {}
        )
    }
}

#Preview("Blue Theme") {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingActivationView(
            onboardingData: OnboardingData(),
            accentColor: Color(hex: "7BA4B5"),
            isCompleting: false,
            onComplete: {}
        )
    }
}
