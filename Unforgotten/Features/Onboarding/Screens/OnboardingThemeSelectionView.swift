import SwiftUI

// MARK: - Onboarding Theme Selection View
/// Screen 3: Let user select their preferred theme with live preview
/// Features a large preview card with sample reminder row and swipeable theme carousel
struct OnboardingThemeSelectionView: View {
    @Bindable var themeManager: OnboardingThemeManager
    let onContinue: () -> Void

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    private let styles = HeaderStyle.allStyles

    // Button gradient colors matching design
    private let buttonGradient = LinearGradient(
        colors: [Color(hex: "79A5D7"), Color(hex: "8CBFD3")],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geometry in
            let previewWidth = min(geometry.size.width - (isRegularWidth ? 120 : 48), isRegularWidth ? 420 : 380)
            let previewHeight = previewWidth * 1.5

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: isRegularWidth ? 80 : 60)

                // Theme preview card with sample reminder
                themePreviewCard(width: previewWidth, height: previewHeight)
                    .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: themeManager.selectedStyle.id)

                // Page indicator dots
                pageIndicator
                    .padding(.top, 8)

                Spacer()
                    .frame(height: 20)

                // Header and description
                VStack(spacing: 12) {
                    Text("Choose a Theme")
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("You can change this any time in the Settings")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppDimensions.screenPadding)

                Spacer()

                // Continue button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.appBodyMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDimensions.buttonHeight)
                        .background(themeManager.accentColor)
                        .cornerRadius(AppDimensions.buttonCornerRadius)
                }
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: themeManager.accentColor)
                .frame(maxWidth: isRegularWidth ? 400 : .infinity)
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.bottom, isRegularWidth ? 64 : 48)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let dragThreshold: CGFloat = 50
                        let translation = value.translation.width
                        let velocity = value.predictedEndTranslation.width - translation

                        var newIndex = currentIndex

                        // Determine direction based on drag distance or velocity
                        if translation < -dragThreshold || velocity < -200 {
                            // Swiped left - go to next
                            newIndex = min(currentIndex + 1, styles.count - 1)
                        } else if translation > dragThreshold || velocity > 200 {
                            // Swiped right - go to previous
                            newIndex = max(currentIndex - 1, 0)
                        }

                        // Reset drag offset
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }

                        // Update index if changed
                        if newIndex != currentIndex {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentIndex = newIndex
                            }
                            updateTheme()
                        }
                    }
            )
        }
        .onAppear {
            if let index = styles.firstIndex(where: { $0.id == themeManager.selectedStyle.id }) {
                currentIndex = index
            }
        }
    }

    // MARK: - Theme Preview Card
    @ViewBuilder
    private func themePreviewCard(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Header image area
            ZStack {
                // Theme background image
                if let uiImage = UIImage(named: themeManager.selectedStyle.previewImageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height * 0.65)
                        .clipped()
                } else {
                    // Fallback gradient
                    LinearGradient(
                        colors: [
                            themeManager.accentColor.opacity(0.8),
                            themeManager.accentColor.opacity(0.4),
                            Color.cardBackground
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: width, height: height * 0.65)
                }
            }
            .frame(height: height * 0.65)

            // Sample reminder row
            HStack(spacing: 12) {
                // Calendar icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.accentColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "calendar")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    )

                // Reminder text
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sarah's Birthday")
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    Text("8:00 AM")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Checkbox circle
                Circle()
                    .stroke(themeManager.accentColor, lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.cardBackground)
        }
        .frame(width: width)
        .background(Color.cardBackground)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
    }

    // MARK: - Update Theme
    private func updateTheme() {
        guard currentIndex >= 0, currentIndex < styles.count else { return }

        if themeManager.selectedStyle.id != styles[currentIndex].id {
            themeManager.selectStyle(styles[currentIndex])

            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }

    // MARK: - Page Indicator
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<styles.count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? themeManager.accentColor : Color.cardBackgroundSoft)
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                    .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: currentIndex)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentIndex = index
                        }
                        updateTheme()
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Theme \(currentIndex + 1) of \(styles.count)")
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingThemeSelectionView(
            themeManager: OnboardingThemeManager(),
            onContinue: {}
        )
    }
}
