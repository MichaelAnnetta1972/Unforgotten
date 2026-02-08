import SwiftUI

// MARK: - Feature Card View
/// Individual carousel card with parallax background image and animated text
struct FeatureCardView: View {
    let item: CarouselItem
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let parallaxOffset: CGFloat
    let isVisible: Bool
    let centeredness: CGFloat // 0.0 = edge, 1.0 = perfectly centered

    @State private var textAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Extra width for parallax movement (wider to allow parallax shift in both directions)
    private var parallaxImageWidth: CGFloat { cardWidth * 1.4 }

    /// Base offset to center the oversized image within the card frame
    private var baseImageOffset: CGFloat { (parallaxImageWidth - cardWidth) / 2 }

    /// Threshold for when card is considered "centered" enough to show text
    private let centerThreshold: CGFloat = 0.7

    /// Whether the card is close enough to center to show text
    private var isCentered: Bool { centeredness >= centerThreshold }

    /// Scale based on centeredness (non-centered cards are slightly smaller)
    private var cardScale: CGFloat {
        let minScale: CGFloat = 0.92
        let maxScale: CGFloat = 1.0
        return minScale + (maxScale - minScale) * centeredness
    }

    var body: some View {
        ZStack {
            // Background image with parallax effect - centered horizontally when card is centered
            // The image is wider than the card, so we offset it to center, then apply parallax
            Image(item.cardImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: parallaxImageWidth)
                .frame(width: cardWidth, height: cardHeight, alignment: .top)
                .offset(x: -baseImageOffset - parallaxOffset)
                .clipped()

            // Gradient overlay for text readability (top and bottom)
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: cardHeight * 0.4)

                Spacer()

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: cardHeight * 0.25)
            }

            // Text content at top
            VStack(spacing: 8) {
                // Title
                Text(item.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(textAppeared ? 1 : 0)
                    .offset(y: textAppeared ? 0 : 15)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.1),
                        value: textAppeared
                    )

                // Subtitle
                Text(item.subtitle)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(textAppeared ? 1 : 0)
                    .offset(y: textAppeared ? 0 : 15)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.2),
                        value: textAppeared
                    )

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: cardWidth, alignment: .center)

            // Touch hint animation at bottom
            VStack {
                Spacer()

                TouchHintView(isVisible: textAppeared)
                    .frame(width: 50, height: 50)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .scaleEffect(cardScale)
        .animation(.easeOut(duration: 0.2), value: cardScale)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onChange(of: isCentered) { _, newValue in
            if newValue {
                // Trigger text animation when card becomes centered
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    textAppeared = true
                }
            } else {
                // Reset text when card leaves center
                withAnimation(.easeOut(duration: 0.2)) {
                    textAppeared = false
                }
            }
        }
        .onAppear {
            // Initial appearance - show text if already centered
            if isCentered {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        textAppeared = true
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        FeatureCardView(
            item: CarouselConfiguration.items[0],
            cardWidth: 280,
            cardHeight: 460,
            parallaxOffset: 0,
            isVisible: true,
            centeredness: 1.0
        )
    }
}
