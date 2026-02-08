import SwiftUI
import AVKit

// MARK: - Expanded Feature View
/// Full-screen view for expanded carousel item
struct ExpandedFeatureView: View {
    let item: CarouselItem
    let sourceFrame: CGRect
    let useIPadMedia: Bool // Passed from parent to handle split view correctly
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var player: AVPlayer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen background
                Color.black
                    .ignoresSafeArea()

                // Media content - fills entire screen
                mediaContent(in: geometry)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                // Close button overlay
                VStack {
                    HStack {
                        Spacer()
                        closeButton
                    }
                    .padding(.top, geometry.safeAreaInsets.top + 16)
                    .padding(.trailing, 20)
                    Spacer()
                }
            }
            .opacity(isVisible ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(reduceMotion ? .none : .easeIn(duration: 0.25)) {
                isVisible = true
            }
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    // MARK: - Media Content

    @ViewBuilder
    private func mediaContent(in geometry: GeometryProxy) -> some View {
        switch item.expandedMedia {
        case .image(let imageName):
            // Use appropriate image variant based on size class
            if let uiImage = imageForCurrentSizeClass(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }

        case .video(let videoName):
            videoPlayer(named: videoName)
        }
    }

    /// Returns a UIImage for the current size class
    /// Uses separate image sets: base name for iPhone, -ipad suffix for iPad
    private func imageForCurrentSizeClass(named imageName: String) -> UIImage? {
        if useIPadMedia {
            // Try iPad-specific image first
            let iPadName = "\(imageName)-ipad"
            if let iPadImage = UIImage(named: iPadName) {
                return iPadImage
            }
            // Fallback to base image if no iPad version exists
            return UIImage(named: imageName)
        } else {
            // Use the base image name (iPhone version)
            return UIImage(named: imageName)
        }
    }

    @ViewBuilder
    private func videoPlayer(named videoName: String) -> some View {
        if let url = videoURL(for: videoName) {
            VideoPlayerView(url: url, shouldPlay: $isVisible)
        } else {
            // Fallback to card image if video not found
            Image(item.cardImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }

    /// Returns the appropriate video URL based on current size class
    /// Looks for videos with -ipad suffix for regular width, falls back to base name if not found
    private func videoURL(for baseName: String) -> URL? {
        if useIPadMedia {
            // Try iPad-specific video first
            if let iPadURL = Bundle.main.url(forResource: "\(baseName)-ipad", withExtension: "mp4") {
                return iPadURL
            }
        }

        // Fall back to base video (iPhone or universal)
        return Bundle.main.url(forResource: baseName, withExtension: "mp4")
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: dismissView) {
            ZStack {
                // Semi-transparent dark background circle
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 48, height: 48)

                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeIn(duration: 0.2).delay(0.2), value: isVisible)
    }

    // MARK: - Actions

    private func dismissView() {
        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.2)) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 0.2)) {
            onDismiss()
        }
    }

    private func cleanupPlayer() {
        player?.pause()
        player = nil
    }
}

// MARK: - Video Player View
/// Custom video player that auto-plays and loops
struct VideoPlayerView: View {
    let url: URL
    @Binding var shouldPlay: Bool

    @State private var player: AVPlayer?

    var body: some View {
        GeometryReader { geometry in
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true) // Prevent controls from showing
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onChange(of: shouldPlay) { _, newValue in
            if newValue {
                player?.play()
            } else {
                player?.pause()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.isMuted = true

        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            player?.play()
        }

        // Start playing after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if shouldPlay {
                player?.play()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ExpandedFeatureView(
        item: CarouselConfiguration.items[0],
        sourceFrame: CGRect(x: 50, y: 200, width: 280, height: 420),
        useIPadMedia: false,
        onDismiss: {}
    )
}
