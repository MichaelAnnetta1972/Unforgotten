import Lottie
import SwiftUI

// MARK: - Touch Hint View
/// A Lottie animation view that shows a touch/tap hint at the bottom of carousel cards
struct TouchHintView: View {
    let isVisible: Bool

    var body: some View {
        LottieView {
            try await DotLottieFile.asset(named: "touch")
        }
        .looping()
        .resizable()
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.8)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        TouchHintView(isVisible: true)
            .frame(width: 60, height: 60)
    }
}
