import SwiftUI
import AVKit
import AVFoundation

// MARK: - Tutorial Video Player
/// Presents a self-hosted tutorial video in a fullscreen portrait player with a close button.
struct FullscreenVideoPlayerView: View {
    let tutorial: Tutorial
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                    }
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Close button — top right, in safe area
            VStack {
                HStack {
                    Spacer()
                    Button {
                        player?.pause()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.6))
                            )
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
        .onAppear {
            // Override silent switch so tutorial audio is always audible
            configureTutorialAudioSession()
            if let url = URL(string: tutorial.videoURL) {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
            // Restore ambient audio session so other parts of the app don't interrupt audio
            restoreAmbientAudioSession()
        }
    }

    private func configureTutorialAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("Failed to configure tutorial audio session: \(error)")
            #endif
        }
    }

    private func restoreAmbientAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("Failed to restore ambient audio session: \(error)")
            #endif
        }
    }
}
