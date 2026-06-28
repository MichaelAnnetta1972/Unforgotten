import SwiftUI

// MARK: - Onboarding Welcome View
/// Screen 1: Welcome screen with feature carousel and value proposition
struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @State private var hasAppeared = false
    @State private var expandedItem: CarouselItem?
    @State private var expandedSourceFrame: CGRect = .zero
    @State private var activeTutorial: Tutorial?
    @State private var arrowsPulsing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.onboardingAccentColor) private var accentColor

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    // Button colors matching design reference
    private let buttonColor = Color(hex: "79A5D7")

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color.appBackground
                    .ignoresSafeArea()

                // Main content
                VStack(spacing: 0) {
                    // Top section: Logo
                    logoSection
                        .padding(.top, geometry.safeAreaInsets.top + 16)

                    Spacer()
                        .frame(height: isRegularWidth ? 40 : 24)

                    // Middle section: Carousel
                    carouselSection(in: geometry)

                    Spacer()
                        .frame(height: isRegularWidth ? 32 : 20)

                    // Swipe hint
                    swipeHint

                    Spacer()

                    // Bottom section: Headline and button
                    bottomSection(in: geometry)
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $expandedItem) { item in
            ExpandedFeatureView(
                item: item,
                sourceFrame: expandedSourceFrame,
                useIPadMedia: isRegularWidth,
                onDismiss: {
                    expandedItem = nil
                }
            )
            .background(ClearBackgroundView())
        }
        .fullScreenCover(item: $activeTutorial) { tutorial in
            FullscreenVideoPlayerView(tutorial: tutorial)
        }
        .onAppear {
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: 12) {
            Image("unforgotten-logo-stacked")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: isRegularWidth ? 100 : 80)

            // Headline - centered, wrapped over 2 lines
            // Text("Never forget\nwhat matters most")
            //     .font(.system(size: isRegularWidth ? 28 : 24, weight: .medium))
            //     .foregroundColor(.textPrimary)
            //     .multilineTextAlignment(.center)
            //     .opacity(hasAppeared ? 1 : 0)
            //     .offset(y: hasAppeared ? 0 : 20)
            //     .animation(
            //         reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.4),
            //         value: hasAppeared
            //     )


        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -20)
        .animation(
            reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.1),
            value: hasAppeared
        )
    }

    // MARK: - Carousel Section

    private func carouselSection(in geometry: GeometryProxy) -> some View {
        SwipeableCardStackView(
            items: CarouselConfiguration.items,
            onItemTap: { item, frame in
                if let tutorialId = item.tutorialId,
                   let tutorial = Tutorial.allTutorials.first(where: { $0.id == tutorialId }) {
                    activeTutorial = tutorial
                } else {
                    expandedSourceFrame = CGRect(
                        x: frame.origin.x,
                        y: frame.origin.y + geometry.safeAreaInsets.top + (isRegularWidth ? 156 : 120),
                        width: frame.width,
                        height: frame.height
                    )
                    expandedItem = item
                }
            }
        )
        .opacity(hasAppeared ? 1 : 0)
        .animation(
            reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.2),
            value: hasAppeared
        )
    }

    // MARK: - Page Indicator

    private var swipeHint: some View {
        let pulseDistance: CGFloat = 8

        return HStack(spacing: 28) {
            Image(systemName: "chevron.left")
                .offset(x: arrowsPulsing ? -pulseDistance : 0)
                .opacity(arrowsPulsing ? 1.0 : 0.6)
            Text("Swipe")
            Image(systemName: "chevron.right")
                .offset(x: arrowsPulsing ? pulseDistance : 0)
                .opacity(arrowsPulsing ? 1.0 : 0.6)
        }
        .font(.system(size: isRegularWidth ? 28 : 24, weight: .semibold))
        .foregroundColor(.white.opacity(0.85))
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
            value: arrowsPulsing
        )
        .opacity(hasAppeared ? 1 : 0)
        .animation(
            reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.3),
            value: hasAppeared
        )
        .accessibilityLabel("Swipe left or right to browse features")
        .onAppear {
            guard !reduceMotion else { return }
            arrowsPulsing = true
        }
    }

    // MARK: - Bottom Section

    private func bottomSection(in geometry: GeometryProxy) -> some View {
        VStack(spacing: isRegularWidth ? 32 : 24) {

            // Text("Swipe through our huge range of features")
            //     .font(.system(size: isRegularWidth ? 18 : 16, weight: .medium))
            //     .foregroundColor(.textSecondary)
            Spacer()
            // Get Started button
            Button(action: onContinue) {
                Text("Get started")
                    .font(.appBodyMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDimensions.buttonHeight)
                    .background(buttonColor)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: isRegularWidth ? 320 : 280)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(
                reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.5),
                value: hasAppeared
            )
        }
        .padding(.horizontal, isRegularWidth ? 48 : 32)
        .padding(.bottom, (isRegularWidth ? 60 : 48) + geometry.safeAreaInsets.bottom)
    }
}

// MARK: - Clear Background View
/// Helper to make fullScreenCover background transparent for hero animation effect
struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Preview
#Preview {
    OnboardingWelcomeView(onContinue: {})
}
