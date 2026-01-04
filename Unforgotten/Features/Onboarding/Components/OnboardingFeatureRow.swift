import SwiftUI

// MARK: - Onboarding Feature Row
/// A row displaying a feature with icon, title, and optional description
struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String?
    let accentColor: Color

    init(
        icon: String,
        title: String,
        description: String? = nil,
        accentColor: Color
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.accentColor = accentColor
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(accentColor)
                .frame(width: 44, height: 44)
                .background(accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                if let description = description {
                    Text(description)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Onboarding Feature Check Row
/// A compact row with checkmark for feature lists
struct OnboardingFeatureCheckRow: View {
    let text: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(accentColor)

            Text(text)
                .font(.appBody)
                .foregroundColor(.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 16) {
            OnboardingFeatureRow(
                icon: "person.2.fill",
                title: "1 Friend profile",
                description: "Add one family member or friend",
                accentColor: Color(hex: "FFC93A")
            )

            OnboardingFeatureRow(
                icon: "bell.fill",
                title: "1 Reminder",
                accentColor: Color(hex: "FFC93A")
            )

            Divider()

            OnboardingFeatureCheckRow(
                text: "Unlimited friends",
                accentColor: Color(hex: "FFC93A")
            )

            OnboardingFeatureCheckRow(
                text: "Unlimited reminders",
                accentColor: Color(hex: "FFC93A")
            )
        }
        .padding()
    }
}
