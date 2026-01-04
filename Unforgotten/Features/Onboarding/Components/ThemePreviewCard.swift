import SwiftUI

// MARK: - Theme Preview Card
/// A mini preview of the home screen showing how the selected theme will look
struct ThemePreviewCard: View {
    let headerStyle: HeaderStyle
    let accentColor: Color

    var body: some View {
        VStack(spacing: 0) {
            // Header image
            headerImage
                .frame(height: 100)
                .clipped()

            // Mock content
            VStack(spacing: 12) {
                // Today header
                HStack {
                    Text("Today")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                }

                // Mock medication reminder
                mockMedicationRow

                // Mock birthday
                mockBirthdayRow
            }
            .padding(12)
            .background(Color.cardBackground)
        }
        .background(Color.appBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.cardBackgroundLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    // MARK: - Header Image
    private var headerImage: some View {
        Group {
            // Try to load the preview image
            if let uiImage = UIImage(named: headerStyle.previewImageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Fallback gradient
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.6),
                        accentColor.opacity(0.3),
                        Color.cardBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    // MARK: - Mock Medication Row
    private var mockMedicationRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "pills.fill")
                .font(.system(size: 12))
                .foregroundColor(accentColor)
                .frame(width: 24, height: 24)
                .background(accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text("Morning vitamins")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textPrimary)
                Text("8:00 AM")
                    .font(.system(size: 9))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Circle()
                .stroke(accentColor, lineWidth: 1.5)
                .frame(width: 18, height: 18)
        }
        .padding(8)
        .background(Color.cardBackgroundSoft)
        .cornerRadius(8)
    }

    // MARK: - Mock Birthday Row
    private var mockBirthdayRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.system(size: 12))
                .foregroundColor(accentColor)
                .frame(width: 24, height: 24)
                .background(accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text("Sarah's Birthday")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textPrimary)
                Text("Turns 65 today")
                    .font(.system(size: 9))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.textSecondary)
        }
        .padding(8)
        .background(Color.cardBackgroundSoft)
        .cornerRadius(8)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 24) {
            ThemePreviewCard(
                headerStyle: .styleOne,
                accentColor: HeaderStyle.styleOne.defaultAccentColor
            )
            .frame(width: 240)

            ThemePreviewCard(
                headerStyle: .styleThree,
                accentColor: HeaderStyle.styleThree.defaultAccentColor
            )
            .frame(width: 240)
        }
        .padding()
    }
}
