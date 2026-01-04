import SwiftUI

// MARK: - Header Style Picker
/// A 2x2 grid picker for selecting header styles
struct HeaderStylePicker: View {
    @Environment(HeaderStyleManager.self) private var headerStyleManager
    @Environment(UserPreferences.self) private var userPreferences

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("Header Style")
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Text("Choose a visual style for page headers")
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            // Style grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(HeaderStyle.allStyles) { style in
                    HeaderStyleCell(
                        style: style,
                        isSelected: headerStyleManager.currentStyle.id == style.id,
                        onSelect: {
                            selectStyle(style)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    private func selectStyle(_ style: HeaderStyle) {
        // Update the header style
        headerStyleManager.selectStyle(style)

        // Reset to style's default accent color when changing themes
        userPreferences.resetToStyleDefault()
        userPreferences.syncToStyleDefault(hex: style.defaultAccentColorHex)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Header Style Cell
struct HeaderStyleCell: View {
    let style: HeaderStyle
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Preview image
                ZStack {
                    // Try to load the preview image, fall back to a gradient
                    if let uiImage = UIImage(named: style.previewImageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 100)
                            .clipped()
                    } else {
                        // Fallback gradient using the style's accent color
                        LinearGradient(
                            colors: [style.defaultAccentColor.opacity(0.8), style.defaultAccentColor.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 100)
                        .overlay(
                            Text(style.name)
                                .font(.appCaption)
                                .foregroundColor(.white)
                        )
                    }

                    // Selection overlay
                    if isSelected {
                        Color.black.opacity(0.3)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                .frame(height: 100)
                .cornerRadius(AppDimensions.smallCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDimensions.smallCornerRadius)
                        .stroke(isSelected ? style.defaultAccentColor : Color.clear, lineWidth: 3)
                )

                // Style name
                Text(style.name)
                    .font(.appCaption)
                    .foregroundColor(isSelected ? style.defaultAccentColor : .textSecondary)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        HeaderStylePicker()
            .padding()
    }
    .environment(HeaderStyleManager())
    .environment(UserPreferences())
}
