//
//  AvatarView.swift
//  HabitPet
//
//  Created by Janice C on 9/17/25.
//

import SwiftUI
import AVKit

struct AvatarView: View {
    let state: AvatarState
    @Binding var showFeedingEffect: Bool   // drives sparkles overlay
    var onFeedingComplete: (() -> Void)? = nil
    var size: CGFloat = 120
    var character: CharacterType = .avatar
    
    var body: some View {
        ZStack {
            // Avatar video based on state
            if character == .avatar {
            AvatarVideoPlayer(
                videoName: videoName(for: state),
                size: size
            )

            } else {
                Image(character.imageName).resizable().scaledToFit().frame(width: size, height: size)
            }

            // Sparkles overlay (Lottie or SwiftUI particles). You already added SparkleView.
            if showFeedingEffect {
                SparkleView() // this is your Lottie-based or particle sparkle view
                    .frame(width: size, height: size)
                    .transition(.opacity)
                    .onAppear {
                        // auto-complete after ~1.2s (tweak to match your Lottie length)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            showFeedingEffect = false
                            onFeedingComplete?()
                        }
                    }
            }
        }
    }

    private func videoName(for state: AvatarState) -> String {
        switch state {
        case .sad: return "avatar-sad"
        case .neutral: return "avatar-neutral"
        case .happy: return "avatar-happy"
        case .strong: return "avatar-strong"
        case .overweight: return "avatar-overweight"
        }
    }
    
}

// MARK: - Avatar Video Player
struct AvatarVideoPlayer: View {
    let videoName: String
    let size: CGFloat
    @State private var player: AVPlayer?
    
    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                // Fallback image while video loads
                Image("habitpet")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
        .onAppear {
            setupVideo()
        }
        .onChange(of: videoName) { _, _ in
            setupVideo()
        }
    }
    
    private func setupVideo() {
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            print("Could not find \(videoName).mp4")
            return
        }
        
        // Clean up previous player and observers
        if let existingPlayer = player {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: existingPlayer.currentItem)
        }
        
        let newPlayer = AVPlayer(url: url)
        newPlayer.actionAtItemEnd = .none
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }
        
        self.player = newPlayer
        newPlayer.play()
    }
}
