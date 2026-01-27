import SwiftUI

// MARK: - Feature Visibility View
struct FeatureVisibilityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sidePanelDismiss) private var sidePanelDismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(FeatureVisibilityManager.self) private var featureVisibility

    /// Dismisses the view using side panel dismiss if available, otherwise standard dismiss
    private func dismissView() {
        if let sidePanelDismiss {
            sidePanelDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with Done button
            HStack {
                Text("Features")
                    .font(.appTitle2)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("Done") {
                    dismissView()
                }
                .font(.appBody)
                .foregroundColor(appAccentColor)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        //Image(systemName: "square.grid.2x2")
                        //    .font(.system(size: 50))
                        //    .foregroundColor(appAccentColor)

                        Text("Show/Hide Features")
                            .font(.appTitle)
                            .foregroundColor(.textPrimary)

                        Text("Choose which features appear on your home screen. Hidden features can still be accessed from this menu.")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, AppDimensions.screenPadding)

                    // Feature toggles
                    VStack(spacing: 1) {
                        ForEach(Feature.allCases) { feature in
                            FeatureToggleRow(feature: feature)
                        }
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.cardCornerRadius)
                    .padding(.horizontal, AppDimensions.screenPadding)

                    // Reset button
                    Button {
                        withAnimation {
                            featureVisibility.resetToDefaults()
                        }
                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } label: {
                        Text("Reset to Defaults")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 8)

                    Spacer()
                        .frame(height: 40)
                }
            }
        }
        .background(Color.appBackground)
    }
}

// MARK: - Feature Toggle Row
struct FeatureToggleRow: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(FeatureVisibilityManager.self) private var featureVisibility
    let feature: Feature

    private var isVisible: Bool {
        featureVisibility.isVisible(feature)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Feature icon
            Image(systemName: feature.icon)
                .font(.system(size: 20))
                .foregroundColor(isVisible ? appAccentColor : .textSecondary)
                .frame(width: 32)

            // Feature name
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.displayName)
                    .font(.appBody)
                    .foregroundColor(isVisible ? .textPrimary : .textSecondary)

                if !feature.canBeHidden {
                    Text("Required")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            // Toggle
            if feature.canBeHidden {
                Toggle("", isOn: Binding(
                    get: { isVisible },
                    set: { newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            featureVisibility.setVisibility(feature, isVisible: newValue)
                        }
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                ))
                .tint(appAccentColor)
                .labelsHidden()
            } else {
                // Always visible indicator
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(Color.cardBackground)
    }
}

// MARK: - Preview
#Preview {
    FeatureVisibilityView()
        .environment(FeatureVisibilityManager())
}
