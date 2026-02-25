import SwiftUI

// MARK: - Activation Feature Model
private struct ActivationFeature: Identifiable {
    let id: Int
    let displayName: String
    let icon: String
}

// MARK: - Onboarding Activation View
/// Screen 8: Final activation screen with drum-roller spinner animation
/// Features scroll into focus one at a time, get "activated" with a circular
/// progress ring and checkmark, then the roller advances to the next feature
struct OnboardingActivationView: View {
    @Bindable var onboardingData: OnboardingData
    let accentColor: Color
    let isCompleting: Bool
    var errorMessage: String? = nil
    let onComplete: () -> Void

    // Animation state
    @State private var hasAppeared = false
    @State private var currentIndex: Int = 0
    @State private var drumOffset: CGFloat = 0
    @State private var activatedFeatures: Set<Int> = []
    @State private var checkProgress: CGFloat = 0
    @State private var checkmarkScale: CGFloat = 0
    @State private var allFeaturesActivated = false
    @State private var hapticTrigger: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    // MARK: - Layout Constants

    private var focusedCardHeight: CGFloat { isRegularWidth ? 100 : 84 }
    private var unfocusedCardHeight: CGFloat { isRegularWidth ? 64 : 52 }
    private var itemSpacing: CGFloat { isRegularWidth ? 14 : 10 }
    private var itemStride: CGFloat { unfocusedCardHeight + itemSpacing }
    private var viewportHeight: CGFloat {
        focusedCardHeight + 4 * unfocusedCardHeight + 4 * itemSpacing
    }
    private var maxContentWidth: CGFloat { isRegularWidth ? 500 : .infinity }

    // MARK: - Features List

    private var features: [ActivationFeature] {
        var items: [ActivationFeature] = []
        var index = 0

        for feature in Feature.requiredFeatures {
            items.append(ActivationFeature(id: index, displayName: feature.displayName, icon: feature.icon))
            index += 1
        }

        let selectedFeatures = onboardingData.selectedFeatures
            .sorted { $0.rawValue < $1.rawValue }

        for feature in selectedFeatures {
            items.append(ActivationFeature(id: index, displayName: feature.displayName, icon: feature.icon))
            index += 1
        }

        return items
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: isRegularWidth ? 80 : 60)

            // Header
            Text("Activating your workspace")
                .font(.appLargeTitle)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                    value: hasAppeared
                )

            Spacer()
                .frame(height: isRegularWidth ? 48 : 40)

            // Drum roller
            drumRollerView
                .frame(height: viewportHeight)
                .frame(maxWidth: maxContentWidth)
                .padding(.horizontal, AppDimensions.screenPadding)

            Spacer()
                .frame(height: isRegularWidth ? 48 : 40)

            // Completion message and button
            completionView

            Spacer()
        }
        .sensoryFeedback(.selection, trigger: hapticTrigger)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            startActivationSequence()
        }
    }

    // MARK: - Drum Roller View

    @ViewBuilder
    private var drumRollerView: some View {
        GeometryReader { geo in
            let centerY = geo.size.height / 2
            let centerX = geo.size.width / 2

            ZStack {
                ForEach(features) { feature in
                    let index = feature.id
                    let rawY = CGFloat(index) * itemStride - drumOffset
                    let normalizedDistance = rawY / itemStride
                    let absNormalized = abs(normalizedDistance)

                    // Scale: 1.0 at center, down to 0.65 at 2+ slots away
                    let scale = max(0.65, 1.0 - absNormalized * 0.175)
                    // Opacity: 1.0 at center, fading out beyond 2 slots
                    let opacity = max(0.0, 1.0 - absNormalized * 0.4)
                    let isFocused = absNormalized < 0.5

                    DrumRollerFeatureCard(
                        feature: feature,
                        isFocused: isFocused,
                        isActivated: activatedFeatures.contains(index),
                        checkProgress: index == currentIndex ? checkProgress : (activatedFeatures.contains(index) ? 1.0 : 0.0),
                        checkmarkScale: index == currentIndex ? checkmarkScale : (activatedFeatures.contains(index) ? 1.0 : 0.0),
                        accentColor: accentColor,
                        focusedHeight: focusedCardHeight,
                        unfocusedHeight: unfocusedCardHeight,
                        isRegularWidth: isRegularWidth
                    )
                    .frame(width: geo.size.width)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .position(x: centerX, y: centerY + rawY)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(feature.displayName), \(activatedFeatures.contains(index) ? "activated" : "activating")")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Gradient mask for smooth fade at top and bottom edges
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white, location: 0.18),
                        .init(color: .white, location: 0.82),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Completion View

    @ViewBuilder
    private var completionView: some View {
        VStack(spacing: isRegularWidth ? 32 : 24) {
            if allFeaturesActivated {
                Text("You're all set up")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if let error = errorMessage {
                Text(error)
                    .font(.appCaption)
                    .foregroundColor(.medicalRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppDimensions.screenPadding)
            }

            if allFeaturesActivated {
                Button(action: onComplete) {
                    HStack {
                        if isCompleting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Let's go!")
                                .font(.appBodyMedium)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDimensions.buttonHeight)
                    .background(accentColor)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                }
                .disabled(isCompleting)
                .frame(maxWidth: isRegularWidth ? 400 : .infinity)
                .padding(.horizontal, AppDimensions.screenPadding)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.bottom, isRegularWidth ? 64 : 48)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: allFeaturesActivated)
    }

    // MARK: - Activation Animation Sequence

    private func startActivationSequence() {
        guard !reduceMotion else {
            for feature in features {
                activatedFeatures.insert(feature.id)
            }
            checkProgress = 1.0
            checkmarkScale = 1.0
            if let lastFeature = features.last {
                drumOffset = CGFloat(lastFeature.id) * itemStride
                currentIndex = lastFeature.id
            }
            allFeaturesActivated = true
            return
        }

        activateFeature(at: 0)
    }

    private func activateFeature(at index: Int) {
        guard index < features.count else {
            // All features activated - show completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    allFeaturesActivated = true
                }
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
            }
            return
        }

        currentIndex = index

        // Phase 1: Pause to let user see the focused feature
        let pauseDuration: Double = index == 0 ? 0.8 : 0.6

        DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
            // Phase 2: Animate the circular progress ring
            withAnimation(.easeInOut(duration: 0.5)) {
                checkProgress = 1.0
            }

            // Phase 3: After ring completes, pop in the checkmark
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    checkmarkScale = 1.0
                }
                activatedFeatures.insert(index)
                hapticTrigger += 1

                // Phase 4: Settle, then scroll to next
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    // Reset check state for next item
                    checkProgress = 0
                    checkmarkScale = 0

                    let nextIndex = index + 1
                    if nextIndex < features.count {
                        // Scroll up to bring next item to center
                        withAnimation(.easeInOut(duration: 0.5)) {
                            drumOffset = CGFloat(nextIndex) * itemStride
                        }

                        // After scroll completes, activate next feature
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                            activateFeature(at: nextIndex)
                        }
                    } else {
                        // Last feature done
                        activateFeature(at: nextIndex)
                    }
                }
            }
        }
    }
}

// MARK: - Drum Roller Feature Card
private struct DrumRollerFeatureCard: View {
    let feature: ActivationFeature
    let isFocused: Bool
    let isActivated: Bool
    let checkProgress: CGFloat
    let checkmarkScale: CGFloat
    let accentColor: Color
    let focusedHeight: CGFloat
    let unfocusedHeight: CGFloat
    let isRegularWidth: Bool

    var body: some View {
        HStack(spacing: isFocused ? 16 : 12) {
            // Icon (visible when focused)
            if isFocused {
                Image(systemName: feature.icon)
                    .font(.system(size: isRegularWidth ? 28 : 24, weight: .medium))
                    .foregroundColor(accentColor)
                    .frame(width: isRegularWidth ? 44 : 36)
                    .transition(.scale.combined(with: .opacity))
            }

            Text(feature.displayName)
                .font(isFocused ? .appCardTitle : .appBody)
                .foregroundColor(isFocused ? .textPrimary : .textSecondary)
                .lineLimit(1)

            Spacer()

            CircularCheckmarkView(
                progress: checkProgress,
                checkmarkScale: checkmarkScale,
                accentColor: accentColor,
                size: isFocused ? (isRegularWidth ? 32 : 28) : (isRegularWidth ? 26 : 22)
            )
        }
        .padding(.horizontal, isFocused ? 20 : 16)
        .frame(height: isFocused ? focusedHeight : unfocusedHeight)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                .fill(isFocused ? Color.cardBackground : Color.cardBackground.opacity(0.6))
        )
        .animation(.easeInOut(duration: 0.3), value: isFocused)
    }
}

// MARK: - Circular Checkmark View
private struct CircularCheckmarkView: View {
    let progress: CGFloat
    let checkmarkScale: CGFloat
    let accentColor: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background circle (empty state border)
            Circle()
                .stroke(Color.textSecondary.opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)

            // Progress ring (draws clockwise)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Filled circle (appears when progress completes)
            if progress >= 1.0 {
                Circle()
                    .fill(accentColor)
                    .frame(width: size - 4, height: size - 4)
                    .transition(.scale.combined(with: .opacity))
            }

            // Checkmark (pops in after fill)
            if checkmarkScale > 0 {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(checkmarkScale)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingActivationView(
            onboardingData: OnboardingData(),
            accentColor: Color(hex: "FFC93A"),
            isCompleting: false,
            onComplete: {}
        )
    }
}

#Preview("Blue Theme") {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingActivationView(
            onboardingData: OnboardingData(),
            accentColor: Color(hex: "7BA4B5"),
            isCompleting: false,
            onComplete: {}
        )
    }
}
