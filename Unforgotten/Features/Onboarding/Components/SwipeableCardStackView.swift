import SwiftUI

// MARK: - Swipeable Card Stack View
/// A Tinder-style stack of feature cards. The top card can be dragged to rotate and fly off;
/// the next card cycles into place. Loops infinitely through `items`.
/// Inspired by https://github.com/Volorf/swipeable-cards
struct SwipeableCardStackView: View {
    let items: [CarouselItem]
    let onItemTap: (CarouselItem, CGRect) -> Void
    var onIndexChange: ((Int) -> Void)?

    /// Index into `items` for the current top card.
    @State private var topIndex: Int = 0
    /// Live drag translation applied to the top card.
    @State private var dragTranslation: CGSize = .zero
    /// True while the top card is animating off-screen after a commit swipe.
    @State private var isDismissing: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    // MARK: - Layout constants

    /// How many cards are rendered in the stack (including the top one).
    private let visibleStackDepth: Int = 3
    /// Vertical gap between stacked cards — enough that cards 2 and 3 peek out below the top.
    private let stackYStep: CGFloat = 28
    /// Scale reduction per step back in the stack.
    private let stackScaleStep: CGFloat = 0.05
    /// Alpha reduction per step back in the stack.
    private let stackAlphaStep: CGFloat = 0.12

    /// Card dimensions — mirror the old carousel so the page indicator / layout math holds.
    private var cardWidth: CGFloat { isRegularWidth ? 340 : 280 }
    private var cardHeight: CGFloat { isRegularWidth ? 480 : 420 }

    /// Max rotation in degrees when the card is dragged `cardWidth/2` horizontally.
    private let maxRotationDegrees: Double = 14
    /// Horizontal drag distance required to commit a dismiss.
    private var dismissThreshold: CGFloat { cardWidth * 0.35 }
    /// Horizontal velocity required to commit a dismiss regardless of distance.
    private let velocityThreshold: CGFloat = 600

    // MARK: - Body

    var body: some View {
        ZStack {
            ForEach(stackEntries, id: \.stackPosition) { entry in
                cardView(for: entry)
            }
        }
        .frame(height: cardHeight + CGFloat(visibleStackDepth - 1) * stackYStep)
    }

    // MARK: - Stack construction

    /// Represents a card currently rendered in the stack.
    /// `stackPosition` is 0 for the top card, 1 for the one behind, etc.
    private struct StackEntry {
        let item: CarouselItem
        let itemIndex: Int
        let stackPosition: Int
    }

    /// The cards currently visible in the stack, ordered back-to-front.
    private var stackEntries: [StackEntry] {
        guard !items.isEmpty else { return [] }
        let depth = min(visibleStackDepth, items.count)
        // Render back-to-front so the top card draws last (on top in the ZStack).
        return (0..<depth).reversed().map { position in
            let itemIndex = (topIndex + position) % items.count
            return StackEntry(
                item: items[itemIndex],
                itemIndex: itemIndex,
                stackPosition: position
            )
        }
    }

    // MARK: - Per-card rendering

    @ViewBuilder
    private func cardView(for entry: StackEntry) -> some View {
        let isTop = entry.stackPosition == 0
        let baseScale = 1.0 - CGFloat(entry.stackPosition) * stackScaleStep
        let baseYOffset = CGFloat(entry.stackPosition) * stackYStep
        let baseOpacity = 1.0 - CGFloat(entry.stackPosition) * stackAlphaStep

        FeatureCardView(
            item: entry.item,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            parallaxOffset: 0,
            isVisible: true,
            centeredness: isTop ? 1.0 : 0.0,
            useParallax: false
        )
        .scaleEffect(baseScale)
        .opacity(baseOpacity)
        .offset(
            x: isTop ? dragTranslation.width : 0,
            y: isTop ? dragTranslation.height + baseYOffset : baseYOffset
        )
        .rotationEffect(
            isTop ? .degrees(rotationDegrees(for: dragTranslation.width)) : .zero,
            anchor: .bottom
        )
        .animation(
            reduceMotion ? .none : .interactiveSpring(response: 0.45, dampingFraction: 0.75),
            value: dragTranslation
        )
        .animation(
            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.85),
            value: topIndex
        )
        .zIndex(Double(visibleStackDepth - entry.stackPosition))
        .allowsHitTesting(isTop && !isDismissing)
        .gesture(isTop ? dragGesture : nil)
        .onTapGesture {
            guard isTop, !isDismissing else { return }
            let frame = CGRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
            onItemTap(entry.item, frame)
        }
    }

    /// Rotation in degrees based on horizontal drag translation.
    private func rotationDegrees(for translationX: CGFloat) -> Double {
        let normalized = Double(translationX / (cardWidth / 2))
        let clamped = max(-1.5, min(1.5, normalized))
        return clamped * maxRotationDegrees
    }

    // MARK: - Drag gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isDismissing else { return }
                dragTranslation = value.translation
            }
            .onEnded { value in
                guard !isDismissing else { return }
                let horizontal = value.translation.width
                let velocity = value.velocity.width
                let shouldDismiss = abs(horizontal) > dismissThreshold
                    || abs(velocity) > velocityThreshold

                if shouldDismiss {
                    commitSwipe(direction: horizontal >= 0 ? 1 : -1)
                } else {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.7)) {
                        dragTranslation = .zero
                    }
                }
            }
    }

    /// Animate the top card off-screen, then advance `topIndex` and reset translation.
    private func commitSwipe(direction: CGFloat) {
        isDismissing = true
        let flyX = direction * (cardWidth * 2.5)
        let flyY = dragTranslation.height + 80

        withAnimation(reduceMotion ? .none : .easeIn(duration: 0.28)) {
            dragTranslation = CGSize(width: flyX, height: flyY)
        }

        let delay = reduceMotion ? 0.0 : 0.28
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Jump state without animating the reset — the new top card is already
            // sitting underneath at its stack position, so we swap indices and snap
            // the translation back to zero in a single non-animated transaction.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dragTranslation = .zero
                topIndex = (topIndex + 1) % max(items.count, 1)
            }
            isDismissing = false
            onIndexChange?(topIndex)
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        SwipeableCardStackView(
            items: CarouselConfiguration.items,
            onItemTap: { item, _ in
                print("Tapped: \(item.title)")
            },
            onIndexChange: { index in
                print("Top index: \(index)")
            }
        )
        .padding(.horizontal, 24)
    }
}
