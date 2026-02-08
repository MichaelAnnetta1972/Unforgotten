import SwiftUI

// MARK: - Onboarding Feature Selection View
/// Screen after Theme Selection: Let user select which features they want on their home screen
/// Features checkboxes for each toggleable feature
struct OnboardingFeatureSelectionView: View {
    @Bindable var onboardingData: OnboardingData
    let accentColor: Color
    let onContinue: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    /// Features that can be toggled (excludes locked/required features)
    private var toggleableFeatures: [Feature] {
        Feature.allCases.filter { $0.canBeHidden }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: isRegularWidth ? 80 : 60)

                // Header
                VStack(spacing: 12) {
                    Text("Customise your home")
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 15)

                    Text("Select the features you'd like on your home screen")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 15)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                    value: hasAppeared
                )

                Spacer()
                    .frame(height: isRegularWidth ? 32 : 24)

                // Feature list
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Array(toggleableFeatures.enumerated()), id: \.element.id) { index, feature in
                            FeatureSelectionToggleRow(
                                feature: feature,
                                isSelected: onboardingData.selectedFeatures.contains(feature),
                                accentColor: accentColor,
                                onToggle: {
                                    toggleFeature(feature)
                                }
                            )
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(
                                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05),
                                value: hasAppeared
                            )
                        }
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.cardCornerRadius)
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.bottom, 24)
                    .frame(maxWidth: isRegularWidth ? 500 : .infinity)
                }

                Spacer()
                    .frame(height: isRegularWidth ? 24 : 16)

                // Helper text
                Text("You can change these anytime in Settings")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.3),
                        value: hasAppeared
                    )

                Spacer()
                    .frame(height: isRegularWidth ? 24 : 16)

                // Continue button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.appBodyMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDimensions.buttonHeight)
                        .background(accentColor)
                        .cornerRadius(AppDimensions.buttonCornerRadius)
                }
                .frame(maxWidth: isRegularWidth ? 400 : .infinity)
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.bottom, geometry.safeAreaInsets.bottom + (isRegularWidth ? 48 : 32))
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.4),
                    value: hasAppeared
                )
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.appBackground)
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

    // MARK: - Toggle Feature
    private func toggleFeature(_ feature: Feature) {
        if onboardingData.selectedFeatures.contains(feature) {
            onboardingData.selectedFeatures.remove(feature)
        } else {
            onboardingData.selectedFeatures.insert(feature)
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Feature Selection Toggle Row
struct FeatureSelectionToggleRow: View {
    let feature: Feature
    let isSelected: Bool
    let accentColor: Color
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Feature icon
                Image(systemName: feature.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? accentColor : .textSecondary)
                    .frame(width: 32)

                // Feature name
                Text(feature.displayName)
                    .font(.appBody)
                    .foregroundColor(isSelected ? .textPrimary : .textSecondary)

                Spacer()

                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? accentColor : Color.clear)
                        .frame(width: 24, height: 24)

                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? accentColor : Color.textSecondary.opacity(0.4), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
            .background(Color.cardBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(feature.displayName), \(isSelected ? "selected" : "not selected")")
        .accessibilityHint("Double tap to toggle")
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingFeatureSelectionView(
            onboardingData: OnboardingData(),
            accentColor: Color(hex: "FFC93A"),
            onContinue: {}
        )
    }
}

#Preview("Blue Theme") {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingFeatureSelectionView(
            onboardingData: OnboardingData(),
            accentColor: Color(hex: "7BA4B5"),
            onContinue: {}
        )
    }
}
