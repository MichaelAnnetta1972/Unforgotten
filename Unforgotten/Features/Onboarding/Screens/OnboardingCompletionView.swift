import SwiftUI

// MARK: - Onboarding Completion View
/// Screen 8: Celebration and first action selection
struct OnboardingCompletionView: View {
    @Bindable var onboardingData: OnboardingData
    let accentColor: Color
    let isCompleting: Bool
    var errorMessage: String? = nil
    let onActionSelected: (OnboardingFirstAction) -> Void

    @State private var hasAppeared = false
    @State private var showConfetti = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Celebration section
            VStack(spacing: 24) {
                // Celebration visual
                celebrationVisual

                // Personalized headline
                VStack(spacing: 12) {
                    Text("You're all set, \(onboardingData.firstName)!")
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("What would you like to do first?")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)

            Spacer()
                .frame(height: 40)

            // Action cards
            VStack(spacing: 12) {
                ForEach(Array(OnboardingFirstAction.allCases.enumerated()), id: \.element.rawValue) { index, action in
                    OnboardingActionCard(
                        action: action,
                        accentColor: accentColor,
                        onSelect: {
                            onActionSelected(action)
                        }
                    )
                    .disabled(isCompleting)
                    .opacity(isCompleting ? 0.6 : 1)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1 + 0.2),
                        value: hasAppeared
                    )
                }
            }
            .padding(.horizontal, AppDimensions.screenPadding)

            Spacer()

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.appCaption)
                    .foregroundColor(.medicalRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.bottom, 16)
            }

            // Loading indicator when completing
            if isCompleting {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: accentColor))

                    Text("Setting up your account...")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
                .padding(.bottom, 48)
            }
        }
        .overlay(
            // Confetti overlay
            confettiOverlay
        )
        .onAppear {
            animateAppearance()
        }
    }

    // MARK: - Celebration Visual
    private var celebrationVisual: some View {
        ZStack {
            // Background circles
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 160, height: 160)

            Circle()
                .fill(accentColor.opacity(0.2))
                .frame(width: 120, height: 120)

            // Checkmark icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(accentColor)
                .scaleEffect(hasAppeared ? 1 : 0.5)
        }
    }

    // MARK: - Confetti Overlay
    @ViewBuilder
    private var confettiOverlay: some View {
        if showConfetti && !reduceMotion {
            ConfettiView(colors: [
                accentColor,
                Color(hex: "FF9F0A"),
                Color(hex: "f16690"),
                Color(hex: "6a863e")
            ])
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: - Animation
    private func animateAppearance() {
        guard !hasAppeared else { return }

        if reduceMotion {
            hasAppeared = true
        } else {
            // Staggered entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                hasAppeared = true
            }

            // Trigger confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true

                // Remove confetti after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showConfetti = false
                    }
                }
            }
        }
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    let colors: [Color]

    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiParticleView(particle: particle)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                animateParticles(screenHeight: geometry.size.height)
            }
        }
    }

    private func createParticles(in size: CGSize) {
        particles = (0..<50).map { _ in
            ConfettiParticle(
                color: colors.randomElement() ?? .accentYellow,
                size: CGFloat.random(in: 6...12),
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: -20
                ),
                rotation: Double.random(in: 0...360),
                opacity: 1,
                isCircle: Bool.random()
            )
        }
    }

    private func animateParticles(screenHeight: CGFloat) {
        for index in particles.indices {
            let delay = Double.random(in: 0...0.5)
            let duration = Double.random(in: 1.5...2.5)

            withAnimation(.easeOut(duration: duration).delay(delay)) {
                particles[index].position.y = screenHeight + 50
                particles[index].position.x += CGFloat.random(in: -100...100)
                particles[index].rotation += Double.random(in: 180...720)
                particles[index].opacity = 0
            }
        }
    }
}

// MARK: - Confetti Particle View
struct ConfettiParticleView: View {
    let particle: ConfettiParticle

    var body: some View {
        Group {
            if particle.isCircle {
                Circle()
                    .fill(particle.color)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(particle.color)
            }
        }
        .frame(width: particle.size, height: particle.size)
        .position(particle.position)
        .rotationEffect(Angle(degrees: particle.rotation))
        .opacity(particle.opacity)
    }
}

// MARK: - Confetti Particle
struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var position: CGPoint
    var rotation: Double
    var opacity: Double
    let isCircle: Bool
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        OnboardingCompletionView(
            onboardingData: {
                let data = OnboardingData()
                data.firstName = "John"
                return data
            }(),
            accentColor: Color(hex: "FFC93A"),
            isCompleting: false,
            onActionSelected: { _ in }
        )
    }
}
