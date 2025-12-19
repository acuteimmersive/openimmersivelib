import SwiftUI

/// Displays subtitle text overlaid on the immersive video player
public struct SubtitleOverlay: View {
    let videoPlayer: VideoPlayer

    public init(videoPlayer: VideoPlayer) {
        self.videoPlayer = videoPlayer
    }

    public var body: some View {
        if let subtitle = videoPlayer.currentSubtitle, !subtitle.isEmpty {
            Text(subtitle)
                .font(.title)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.75))
                }
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                .frame(maxWidth: 600)
        }
    }
}
