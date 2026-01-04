import SwiftUI

// MARK: - Onboarding Theme Selection View
/// Screen 3: Let user select their preferred theme with live preview
struct OnboardingThemeSelectionView: View {
    @Bindable var themeManager: OnboardingThemeManager
    let onContinue: () -> Void

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let styles = HeaderStyle.allStyles

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width * 0.75, 380)
            let selectedCardHeight: CGFloat = 240
            let unselectedCardHeight: CGFloat = 200
            let cardSpacing: CGFloat = 12

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Choose your theme")
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("You can change this anytime in Settings")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.top, 24)

                Spacer()
                    .frame(height: 24)

                // Live preview
                ThemePreviewCard(
                    headerStyle: themeManager.selectedStyle,
                    accentColor: themeManager.accentColor
                )
                .frame(width: min(280, geometry.size.width * 0.7))
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: themeManager.selectedStyle.id)

                Spacer()
                    .frame(height: 24)

                // Theme carousel with visible adjacent cards
                ZStack {
                    ForEach(Array(styles.enumerated()), id: \.element.id) { index, style in
                        let isSelected = index == currentIndex
                        let offset = cardOffset(for: index, cardWidth: cardWidth, spacing: cardSpacing, screenWidth: geometry.size.width)
                        let cardHeight = isSelected ? selectedCardHeight : unselectedCardHeight

                        ThemeCarouselCard(
                            headerStyle: style,
                            isSelected: isSelected,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            onSelect: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentIndex = index
                                    updateTheme()
                                }
                            }
                        )
                        .zIndex(isSelected ? 10 : Double(styles.count - abs(index - currentIndex)))
                        .offset(x: offset + dragOffset)
                        .animation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
                    }
                }
                .frame(height: selectedCardHeight + 20)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 20)
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

                            // Reset drag offset first
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }

                            // Update index separately to ensure it takes effect
                            if newIndex != currentIndex {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentIndex = newIndex
                                }
                                updateTheme()
                            }
                        }
                )

                // Page indicator dots
                pageIndicator
                    .padding(.top, 16)

                Spacer()

                // Continue button
                PrimaryButton(
                    title: "Continue",
                    backgroundColor: themeManager.accentColor,
                    action: onContinue
                )
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: themeManager.accentColor)
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            if let index = styles.firstIndex(where: { $0.id == themeManager.selectedStyle.id }) {
                currentIndex = index
            }
        }
    }

    // MARK: - Card Offset Calculation
    private func cardOffset(for index: Int, cardWidth: CGFloat, spacing: CGFloat, screenWidth: CGFloat) -> CGFloat {
        let indexDiff = CGFloat(index - currentIndex)
        return indexDiff * (cardWidth + spacing)
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

// MARK: - Theme Carousel Card
struct ThemeCarouselCard: View {
    let headerStyle: HeaderStyle
    let isSelected: Bool
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottom) {
                // Background image
                backgroundImage

                // Gradient overlay for text readability
                LinearGradient(
                    colors: [
                        .clear,
                        .clear,
                        .black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Content overlay
                VStack(spacing: 8) {
                    Spacer()

                    // Theme name
                    Text(headerStyle.name)
                        .font(.appTitle)
                        .foregroundColor(.white)

                    // Accent color indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(headerStyle.defaultAccentColor)
                            .frame(width: 12, height: 12)

                        Text("Accent Color")
                            .font(.appCaption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 16)
                }

                // Selection indicator
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(headerStyle.defaultAccentColor)
                                .background(
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 24, height: 24)
                                )
                                .padding(12)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? headerStyle.defaultAccentColor : Color.clear,
                        lineWidth: 3
                    )
            )
            .shadow(
                color: isSelected ? headerStyle.defaultAccentColor.opacity(0.4) : .black.opacity(0.2),
                radius: isSelected ? 16 : 8,
                x: 0,
                y: isSelected ? 8 : 4
            )
            .opacity(isSelected ? 1.0 : 0.7)
            .scaleEffect(isSelected ? 1.0 : 0.95)
        }
        .buttonStyle(.plain)
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
                    .frame(width: cardWidth, height: cardHeight)
            } else {
                // Fallback gradient
                LinearGradient(
                    colors: [
                        headerStyle.defaultAccentColor.opacity(0.8),
                        headerStyle.defaultAccentColor.opacity(0.4),
                        Color.cardBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: cardWidth, height: cardHeight)
            }
        }
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
