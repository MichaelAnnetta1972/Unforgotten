import SwiftUI

// MARK: - Theme Option Card
/// A selectable card representing a header style option in the theme picker
struct ThemeOptionCard: View {
    let headerStyle: HeaderStyle
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onSelect()
        }) {
            ZStack(alignment: .bottomLeading) {
                // Background image
                backgroundImage

                // Gradient overlay for text readability
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Theme name
                Text(headerStyle.name)
                    .font(.appBodyMedium)
                    .foregroundColor(.white)
                    .padding(12)

                // Selection indicator
                if isSelected {
                    selectionOverlay
                }
            }
            .aspectRatio(1.2, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(
                        isSelected ? headerStyle.defaultAccentColor : Color.clear,
                        lineWidth: 3
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
        .accessibilityLabel("\(headerStyle.name) theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Background Image
    private var backgroundImage: some View {
        Group {
            if let uiImage = UIImage(named: headerStyle.previewImageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Fallback gradient
                LinearGradient(
                    colors: [
                        headerStyle.defaultAccentColor.opacity(0.8),
                        headerStyle.defaultAccentColor.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    // MARK: - Selection Overlay
    private var selectionOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(headerStyle.defaultAccentColor)
                    .background(
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                    )
                    .padding(12)
            }
            Spacer()
        }
    }
}

// MARK: - Press Events Modifier
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ThemeOptionCard(
                headerStyle: .styleOne,
                isSelected: true,
                onSelect: {}
            )

            ThemeOptionCard(
                headerStyle: .styleTwo,
                isSelected: false,
                onSelect: {}
            )

            ThemeOptionCard(
                headerStyle: .styleThree,
                isSelected: false,
                onSelect: {}
            )

            ThemeOptionCard(
                headerStyle: .styleFour,
                isSelected: false,
                onSelect: {}
            )
        }
        .padding()
    }
}
