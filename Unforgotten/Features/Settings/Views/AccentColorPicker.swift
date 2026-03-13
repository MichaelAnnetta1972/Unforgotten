import SwiftUI

// MARK: - Accent Color Picker
struct AccentColorPicker: View {
    @Environment(UserPreferences.self) private var userPreferences
    @State private var pickerColor: Color = .yellow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("Accent Colour")
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Text("Choose a colour for buttons and highlights")
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            // Native ColorPicker
            ColorPicker(selection: $pickerColor, supportsOpacity: false) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(pickerColor)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )

                    Text("Tap to choose")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
            }
            .onChange(of: pickerColor) { _, newColor in
                userPreferences.selectColor(newColor)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
        .onAppear {
            pickerColor = userPreferences.accentColor
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        AccentColorPicker()
            .padding()
    }
    .environment(UserPreferences())
}
