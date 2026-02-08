import SwiftUI

// MARK: - Feature Carousel View
/// An infinite-loop carousel with parallax effects for showcasing app features
struct FeatureCarouselView: View {
    let items: [CarouselItem]
    let onItemTap: (CarouselItem, CGRect) -> Void
    var onIndexChange: ((Int) -> Void)?

    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var autoScrollTimer: Timer?
    @State private var currentIndex: Int = 0
    @State private var lastDragValue: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Configuration

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    /// Card dimensions
    private var cardWidth: CGFloat { isRegularWidth ? 340 : 280 }
    private var cardHeight: CGFloat { isRegularWidth ? 480 : 420 }
    private var cardSpacing: CGFloat { 16 }

    /// Total width of one card including spacing
    private var cardTotalWidth: CGFloat { cardWidth + cardSpacing }

    /// Auto-scroll speed (points per second) - slow and smooth
    private let autoScrollSpeed: CGFloat = 30

    /// Number of duplicated sets for infinite scroll illusion
    private let duplicateSets = 3

    /// Total items including duplicates
    private var totalItems: [CarouselItem] {
        // Duplicate items for seamless infinite scroll
        Array(repeating: items, count: duplicateSets).flatMap { $0 }
    }

    /// Content width for all items
    private var totalContentWidth: CGFloat {
        CGFloat(totalItems.count) * cardTotalWidth
    }

    /// Width of one complete set of items
    private var oneSetWidth: CGFloat {
        CGFloat(items.count) * cardTotalWidth
    }

    /// Width of the edge fade effect - more aggressive on iPad to constrain visible area
    private var edgeFadeWidth: CGFloat { isRegularWidth ? 200 : 40 }

    /// Maximum visible width for carousel content (limits how far cards extend on wide screens)
    private var maxVisibleWidth: CGFloat { isRegularWidth ? 900 : .infinity }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            ZStack {
                // Carousel content
                HStack(spacing: cardSpacing) {
                    ForEach(Array(totalItems.enumerated()), id: \.offset) { index, item in
                        let centeredness = calculateCenteredness(forIndex: index, screenWidth: screenWidth)

                        FeatureCardView(
                            item: item,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            parallaxOffset: calculateParallaxOffset(
                                forIndex: index,
                                screenWidth: screenWidth
                            ),
                            isVisible: isCardVisible(index: index, screenWidth: screenWidth),
                            centeredness: centeredness
                        )
                        .onTapGesture {
                            handleCardTap(item: item, index: index, in: geometry)
                        }
                    }
                }
                .offset(x: calculateHStackOffset(screenWidth: screenWidth))
            }
            .frame(height: cardHeight)
            .mask(edgeFadeMask(screenWidth: screenWidth))
            .gesture(dragGesture(screenWidth: screenWidth))
            .onAppear {
                // Start from the middle set to allow scrolling in both directions
                scrollOffset = oneSetWidth
                startAutoScroll()
            }
            .onDisappear {
                stopAutoScroll()
            }
            .onChange(of: isDragging) { _, newValue in
                if !newValue {
                    // Resume auto-scroll after user stops dragging
                    startAutoScroll()
                }
            }
        }
        .frame(height: cardHeight)
    }

    // MARK: - Edge Fade Mask

    /// Creates a horizontal gradient mask that fades edges to transparent
    /// On iPad, this creates a more aggressive fade to constrain visible content
    private func edgeFadeMask(screenWidth: CGFloat) -> some View {
        let effectiveWidth = min(screenWidth, maxVisibleWidth)
        let fadeStart = (screenWidth - effectiveWidth) / 2 + edgeFadeWidth
        let fadeEnd = screenWidth - fadeStart

        // Gradient stops: transparent -> opaque -> opaque -> transparent
        let leftFadeStart = fadeStart - edgeFadeWidth
        let leftFadeEnd = fadeStart
        let rightFadeStart = fadeEnd
        let rightFadeEnd = fadeEnd + edgeFadeWidth

        return Canvas { context, size in
            // Create gradient with proper stops for both edges
            let stops: [Gradient.Stop] = [
                .init(color: .clear, location: leftFadeStart / size.width),
                .init(color: .white, location: leftFadeEnd / size.width),
                .init(color: .white, location: rightFadeStart / size.width),
                .init(color: .clear, location: rightFadeEnd / size.width)
            ]

            let gradient = Gradient(stops: stops)
            let rect = CGRect(origin: .zero, size: size)

            context.fill(
                Path(rect),
                with: .linearGradient(
                    gradient,
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                )
            )
        }
    }

    // MARK: - Offset Calculations

    /// Calculate the HStack offset to center cards and apply scroll
    private func calculateHStackOffset(screenWidth: CGFloat) -> CGFloat {
        let centeringOffset = (screenWidth - cardWidth) / 2
        return centeringOffset - scrollOffset
    }

    /// Calculate parallax offset for a card based on its position
    private func calculateParallaxOffset(forIndex index: Int, screenWidth: CGFloat) -> CGFloat {
        let cardCenterX = CGFloat(index) * cardTotalWidth + cardWidth / 2 - scrollOffset
        let screenCenterX = screenWidth / 2
        let distanceFromCenter = cardCenterX - screenCenterX

        // Parallax factor - image moves slower than card for depth effect
        let parallaxFactor: CGFloat = 0.15
        return distanceFromCenter * parallaxFactor
    }

    /// Check if a card is visible on screen (for performance)
    private func isCardVisible(index: Int, screenWidth: CGFloat) -> Bool {
        let cardStartX = CGFloat(index) * cardTotalWidth - scrollOffset
        let cardEndX = cardStartX + cardWidth
        let buffer = cardWidth // Extra buffer for smooth appearance
        return cardEndX > -buffer && cardStartX < screenWidth + buffer
    }

    /// Calculate how centered a card is (0.0 = edge, 1.0 = perfectly centered)
    private func calculateCenteredness(forIndex index: Int, screenWidth: CGFloat) -> CGFloat {
        let cardCenterX = CGFloat(index) * cardTotalWidth + cardWidth / 2 - scrollOffset + (screenWidth - cardWidth) / 2
        let screenCenterX = screenWidth / 2
        let distanceFromCenter = abs(cardCenterX - screenCenterX)

        // Normalize: 0 distance = 1.0, cardTotalWidth distance = 0.0
        let maxDistance = cardTotalWidth
        let centeredness = max(0, 1 - (distanceFromCenter / maxDistance))
        return centeredness
    }

    // MARK: - Gestures

    private func dragGesture(screenWidth: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    lastDragValue = 0
                    stopAutoScroll()
                }
                // Calculate the delta from last drag position
                let delta = value.translation.width - lastDragValue
                lastDragValue = value.translation.width

                // Apply 1:1 scrolling (scroll follows finger directly)
                scrollOffset -= delta
            }
            .onEnded { value in
                // Add gentle momentum based on velocity
                let velocity = value.velocity.width
                withAnimation(.easeOut(duration: 0.4)) {
                    scrollOffset -= velocity * 0.15
                }

                // Reset drag tracking
                lastDragValue = 0

                // Normalize scroll position for infinite loop
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    normalizeScrollPosition()
                    isDragging = false
                }
            }
    }

    // MARK: - Auto Scroll

    private func startAutoScroll() {
        guard !reduceMotion else { return }
        stopAutoScroll()

        // Use display link timing for smooth animation
        let interval: TimeInterval = 1.0 / 60.0 // 60 FPS
        let incrementPerFrame = autoScrollSpeed * interval

        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            guard !isDragging else { return }

            // Scroll right to left (increase offset)
            scrollOffset += incrementPerFrame

            // Normalize when we've scrolled past one full set
            if scrollOffset >= oneSetWidth * 2 {
                scrollOffset -= oneSetWidth
            }

            // Update current index for page indicator
            updateCurrentIndex()
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    private func normalizeScrollPosition() {
        // Keep scroll position within bounds for seamless looping
        while scrollOffset >= oneSetWidth * 2 {
            scrollOffset -= oneSetWidth
        }
        while scrollOffset < oneSetWidth {
            scrollOffset += oneSetWidth
        }
    }

    private func updateCurrentIndex() {
        let adjustedOffset = scrollOffset.truncatingRemainder(dividingBy: oneSetWidth)
        let rawIndex = Int(round(adjustedOffset / cardTotalWidth))
        let newIndex = rawIndex % items.count
        if newIndex != currentIndex {
            currentIndex = newIndex
            onIndexChange?(newIndex)
        }
    }

    // MARK: - Card Interaction

    private func handleCardTap(item: CarouselItem, index: Int, in geometry: GeometryProxy) {
        // Calculate card frame for hero animation
        let cardX = CGFloat(index) * cardTotalWidth - scrollOffset + (geometry.size.width - cardWidth) / 2
        let cardFrame = CGRect(
            x: cardX,
            y: 0,
            width: cardWidth,
            height: cardHeight
        )
        onItemTap(item, cardFrame)
    }
}

// MARK: - Page Indicator
struct CarouselPageIndicator: View {
    let itemCount: Int
    @Binding var currentIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<itemCount, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        FeatureCarouselView(
            items: CarouselConfiguration.items
        ) { item, frame in
            print("Tapped: \(item.title)")
        }
    }
}
