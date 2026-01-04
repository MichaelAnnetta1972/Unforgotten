import SwiftUI

// MARK: - Onboarding Action Card
/// A card for selecting the first action on the completion screen
struct OnboardingActionCard: View {
    let action: OnboardingFirstAction
    let accentColor: Color
    let onSelect: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onSelect()
        }) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: action.icon)
                    .font(.system(size: 24))
                    .foregroundColor(accentColor)
                    .frame(width: 56, height: 56)
                    .background(accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    Text(action.description)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
        .accessibilityLabel(action.title)
        .accessibilityHint(action.description)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 16) {
            ForEach(OnboardingFirstAction.allCases, id: \.rawValue) { action in
                OnboardingActionCard(
                    action: action,
                    accentColor: Color(hex: "FFC93A"),
                    onSelect: {}
                )
            }
        }
        .padding()
    }
}
