import SwiftUI

// MARK: - Onboarding Welcome View
/// Screen 1: Welcome screen with feature carousel and value proposition
struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @State private var hasAppeared = false
    @State private var currentCarouselIndex = 0
    @State private var expandedItem: CarouselItem?
    @State private var expandedSourceFrame: CGRect = .zero

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

                    // Page indicators
                    pageIndicator

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
        FeatureCarouselView(
            items: CarouselConfiguration.items,
            onItemTap: { item, frame in
                // Convert frame to screen coordinates and show expanded view
                expandedSourceFrame = CGRect(
                    x: frame.origin.x,
                    y: frame.origin.y + geometry.safeAreaInsets.top + (isRegularWidth ? 156 : 120),
                    width: frame.width,
                    height: frame.height
                )
                expandedItem = item
            },
            onIndexChange: { index in
                currentCarouselIndex = index
            }
        )
        .opacity(hasAppeared ? 1 : 0)
        .animation(
            reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.2),
            value: hasAppeared
        )
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<CarouselConfiguration.itemCount, id: \.self) { index in
                Circle()
                    .fill(index == currentCarouselIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(
            reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8).delay(0.3),
            value: hasAppeared
        )
    }

    // MARK: - Bottom Section

    private func bottomSection(in geometry: GeometryProxy) -> some View {
        VStack(spacing: isRegularWidth ? 32 : 24) {

            Text("Scroll through our huge range of features")
                .font(.system(size: isRegularWidth ? 18 : 16, weight: .medium))
                .foregroundColor(.textSecondary)

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
