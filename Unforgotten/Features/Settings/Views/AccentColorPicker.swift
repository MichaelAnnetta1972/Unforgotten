import SwiftUI

// MARK: - Accent Color Picker
struct AccentColorPicker: View {
    @Environment(UserPreferences.self) private var userPreferences
    @State private var selectedColor: AccentColorOption?

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("Accent Color")
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Text("Choose a color for buttons and highlights")
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            // Color grid
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(AccentColorOption.allCases) { option in
                    AccentColorButton(
                        option: option,
                        isSelected: userPreferences.selectedAccentColor == option,
                        action: {
                            userPreferences.selectColor(option)
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    )
                }
            }

            // Selected color name
            HStack {
                Circle()
                    .fill(userPreferences.accentColor)
                    .frame(width: 16, height: 16)

                Text("Selected: \(userPreferences.selectedAccentColor.name)")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Accent Color Button
struct AccentColorButton: View {
    let option: AccentColorOption
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Color circle
                    Circle()
                        .fill(option.color)
                        .frame(width: 44, height: 44)

                    // Selection ring
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 3)
                            .frame(width: 44, height: 44)

                        // Checkmark
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)

                // Color name
                Text(option.name)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? option.color : .textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Compact Accent Color Picker (for inline use)
struct CompactAccentColorPicker: View {
    @Environment(UserPreferences.self) private var userPreferences

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AccentColorOption.allCases) { option in
                    Button {
                        userPreferences.selectColor(option)
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(option.color)
                                .frame(width: 36, height: 36)

                            if userPreferences.selectedAccentColor == option {
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 2)
                                    .frame(width: 36, height: 36)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 24) {
            AccentColorPicker()

            CompactAccentColorPicker()
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(12)
        }
        .padding()
    }
    .environment(UserPreferences())
}
