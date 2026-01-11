import SwiftUI
import AVKit
import AVFoundation

// MARK: - Audio Session Configuration
/// Configure audio session to not interrupt other apps' audio
private func configureAudioSession() {
    do {
        // Use ambient category with mixWithOthers to avoid interrupting other audio
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: .mixWithOthers)
        try AVAudioSession.sharedInstance().setActive(true)
    } catch {
        #if DEBUG
        print("Failed to configure audio session: \(error)")
        #endif
    }
}

// MARK: - Looping Video Player View
/// A SwiftUI view that plays a video from the app bundle, with options for looping and muting
struct LoopingVideoPlayerView: UIViewRepresentable {
    let videoName: String
    let videoExtension: String
    var isMuted: Bool = true
    var shouldLoop: Bool = true
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        let view = LoopingPlayerUIView(
            videoName: videoName,
            videoExtension: videoExtension,
            isMuted: isMuted,
            shouldLoop: shouldLoop,
            gravity: gravity
        )
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.updateMuted(isMuted)
    }
}

// MARK: - Looping Player UIView
class LoopingPlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer?
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    private var tempFileURL: URL?
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?

    init(videoName: String, videoExtension: String, isMuted: Bool, shouldLoop: Bool, gravity: AVLayerVideoGravity) {
        super.init(frame: .zero)
        setupPlayer(videoName: videoName, videoExtension: videoExtension, isMuted: isMuted, shouldLoop: shouldLoop, gravity: gravity)
        setupAppLifecycleObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // Remove lifecycle observers
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        // Clean up temp file if we created one
        if let tempURL = tempFileURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    private func setupAppLifecycleObservers() {
        // Resume playback when app comes to foreground
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.play()
        }

        // Pause playback when app goes to background
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pause()
        }
    }

    private func setupPlayer(videoName: String, videoExtension: String, isMuted: Bool, shouldLoop: Bool, gravity: AVLayerVideoGravity) {
        // Configure audio session to not interrupt other apps
        configureAudioSession()

        var videoURL: URL?

        // First, try to find the video in the bundle directly (for files not in Asset Catalog)
        if let path = Bundle.main.path(forResource: videoName, ofType: videoExtension) {
            videoURL = URL(fileURLWithPath: path)
        }
        // Then, try to load from Asset Catalog (NSDataAsset)
        else if let dataAsset = NSDataAsset(name: videoName) {
            // NSDataAsset requires writing to a temp file for AVPlayer
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(videoName).\(videoExtension)")
            do {
                // Remove existing temp file if it exists
                try? FileManager.default.removeItem(at: tempURL)
                try dataAsset.data.write(to: tempURL)
                videoURL = tempURL
                self.tempFileURL = tempURL
            } catch {
                #if DEBUG
                print("Failed to write video data to temp file: \(error)")
                #endif
            }
        }

        guard let url = videoURL else {
            #if DEBUG
            print("Video not found: \(videoName).\(videoExtension)")
            #endif
            return
        }

        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        if shouldLoop {
            // Use AVQueuePlayer with AVPlayerLooper for seamless looping
            let queuePlayer = AVQueuePlayer(playerItem: item)
            self.queuePlayer = queuePlayer
            self.playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)

            let playerLayer = AVPlayerLayer(player: queuePlayer)
            playerLayer.videoGravity = gravity
            self.playerLayer = playerLayer
            layer.addSublayer(playerLayer)

            queuePlayer.isMuted = isMuted
            queuePlayer.play()
        } else {
            // Single play without looping
            let player = AVPlayer(playerItem: item)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = gravity
            self.playerLayer = playerLayer
            layer.addSublayer(playerLayer)

            player.isMuted = isMuted
            player.play()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    func updateMuted(_ isMuted: Bool) {
        queuePlayer?.isMuted = isMuted
        playerLayer?.player?.isMuted = isMuted
    }

    func pause() {
        queuePlayer?.pause()
        playerLayer?.player?.pause()
    }

    func play() {
        queuePlayer?.play()
        playerLayer?.player?.play()
    }
}

// MARK: - One-Time Video Player View
/// A video player that plays once and calls a completion handler when finished
struct OneTimeVideoPlayerView: UIViewControllerRepresentable {
    let videoName: String
    let videoExtension: String
    var showsPlaybackControls: Bool = false
    var onVideoFinished: (() -> Void)?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        // Configure audio session to not interrupt other apps
        configureAudioSession()

        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = showsPlaybackControls
        controller.videoGravity = .resizeAspectFill

        if let path = Bundle.main.path(forResource: videoName, ofType: videoExtension) {
            let url = URL(fileURLWithPath: path)
            let player = AVPlayer(url: url)
            controller.player = player

            // Observe when video finishes
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                onVideoFinished?()
            }

            player.play()
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

// MARK: - Intro Video View
/// Full-screen intro video that plays once after splash screen
struct IntroVideoView: View {
    let videoName: String
    let videoExtension: String
    let onFinished: () -> Void

    @State private var showSkipButton = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            OneTimeVideoPlayerView(
                videoName: videoName,
                videoExtension: videoExtension,
                showsPlaybackControls: false,
                onVideoFinished: onFinished
            )
            .ignoresSafeArea()

            // Skip button (appears after a short delay)
            if showSkipButton {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            onFinished()
                        } label: {
                            Text("Skip")
                                .font(.appBodyMedium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(20)
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 60)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            // Show skip button after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSkipButton = true
                }
            }
        }
    }
}

// MARK: - Video Header View
/// A header view with a looping video background instead of a static image
struct VideoHeaderView: View {
    let videoName: String
    let videoExtension: String
    let title: String
    var subtitle: String? = nil
    var showBackButton: Bool = false
    var backAction: (() -> Void)? = nil
    var showSettingsButton: Bool = false
    var settingsAction: (() -> Void)? = nil
    var showEditButton: Bool = false
    var editAction: (() -> Void)? = nil
    var editButtonPosition: HeaderButtonPosition = .topRight
    var showAddButton: Bool = false
    var addAction: (() -> Void)? = nil
    var showReorderButton: Bool = false
    var isReordering: Bool = false
    var reorderAction: (() -> Void)? = nil

    @State private var settingsButtonPressed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Video background
            LoopingVideoPlayerView(
                videoName: videoName,
                videoExtension: videoExtension,
                isMuted: true,
                shouldLoop: true,
                gravity: .resizeAspectFill
            )
            .frame(height: AppDimensions.headerHeight)
            .clipped()

            // Gradient overlay for text readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content
            VStack {
                // Top row - Back button and Settings/Edit buttons
                HStack {
                    if showBackButton, let backAction = backAction {
                        HeaderActionButton(icon: "chevron.left", action: backAction)
                    }

                    Spacer()

                    // Top right buttons
                    HStack(spacing: 12) {
                        if showEditButton && editButtonPosition == .topRight, let editAction = editAction {
                            HeaderActionButton(icon: "pencil", action: editAction)
                        }
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.top, 60)

                Spacer()

                // Bottom row - Title and bottom-right buttons
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let subtitle = subtitle {
                            Text(subtitle.uppercased())
                                .font(.appCaption)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Text(title)
                            .font(.appLargeTitle)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Bottom right buttons
                    HStack(spacing: 12) {
                        if showReorderButton, let reorderAction = reorderAction {
                            Button {
                                reorderAction()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                                    Text(isReordering ? "Done" : "Reorder")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isReordering ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isReordering ? Color.accentYellow : Color.white.opacity(0.2))
                                .cornerRadius(16)
                            }
                        }

                        if showAddButton, let addAction = addAction {
                            HeaderBottomActionButton(icon: "plus", label: nil, action: addAction)
                        }

                        if showEditButton && editButtonPosition == .bottomRight, let editAction = editAction {
                            HeaderBottomActionButton(icon: "pencil", label: "Edit", action: editAction)
                        }

                        if showSettingsButton, let settingsAction = settingsAction {
                            Button {
                                settingsAction()
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                                    .scaleEffect(settingsButtonPressed ? 0.9 : 1.0)
                                    .opacity(settingsButtonPressed ? 0.8 : 1.0)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: settingsButtonPressed)
                            }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in settingsButtonPressed = true }
                                    .onEnded { _ in settingsButtonPressed = false }
                            )
                        }
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.bottom, AppDimensions.screenPadding)
            }
        }
        .frame(height: AppDimensions.headerHeight)
    }
}

// MARK: - Preview
#Preview("Video Header") {
    VideoHeaderView(
        videoName: "header-splash-video",
        videoExtension: "mp4",
        title: "Unforgotten",
        showSettingsButton: true,
        settingsAction: {}
    )
}
