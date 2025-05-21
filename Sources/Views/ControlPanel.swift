//
//  ControlPanel.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 9/20/24.
//

import SwiftUI
import RealityKit

/// A simple horizontal view presenting the user with video playback controls.
public struct ControlPanel: View {
    /// The singleton video player control interface.
    @Binding var videoPlayer: VideoPlayer
    
    /// The callback to execute when the user closes the immersive player.
    let closeAction: (() -> Void)?
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - videoPlayer: the singleton video player control interface.
    ///   - closeAction: the optional callback to execute when the user closes the immersive player.
    public init(videoPlayer: Binding<VideoPlayer>, closeAction: (() -> Void)? = nil) {
        self._videoPlayer = videoPlayer
        self.closeAction = closeAction
    }
    
    public var body: some View {
        if videoPlayer.shouldShowControlPanel {
            VStack {
                HStack {
                    Button("", systemImage: "chevron.backward") {
                        closeAction?()
                    }
                    .controlSize(.extraLarge)
                    .tint(.clear)
                    .frame(width: 100)
                    
                    MediaInfo(videoPlayer: $videoPlayer)
                }
                
                HStack {
                    PlaybackButtons(videoPlayer: videoPlayer)
                    
                    Scrubber(videoPlayer: $videoPlayer)
                    
                    TimeText(videoPlayer: videoPlayer)
                }
            }
            .padding()
            .glassBackgroundEffect()
        }
    }
}

/// A simple horizontal view with a dark background presenting video title, description, and a bitrate readout.
fileprivate struct MediaInfo: View {
    /// The singleton video player control interface.
    @Binding var videoPlayer: VideoPlayer
    
    var body: some View {
        let config = Config.shared
        
        HStack {
            let hasResolutionOptions = videoPlayer.resolutionOptions.count > 1  && config.controlPanelShowResolutionOptions
            let showingResolutionOptions = hasResolutionOptions && videoPlayer.shouldShowResolutionOptions
            let showingBitrate = videoPlayer.bitrate > 0 && !showingResolutionOptions && config.controlPanelShowBitrate
            
            if !showingResolutionOptions {
                // extra padding to keep the stack centered when the bitrate is visible
                let extraPadding: () -> CGFloat = {
                    var padding: CGFloat = 0
                    if showingBitrate {
                        padding += 120
                    }
                    if hasResolutionOptions {
                        padding += 100
                    }
                    if showingBitrate && hasResolutionOptions {
                        padding += 10
                    }
                    return padding
                }
                
                Spacer()
                VStack {
                    Text(videoPlayer.title.isEmpty ? "No Video Selected" : videoPlayer.title)
                        .font(.title)
                    
                    Text(videoPlayer.details)
                        .font(.headline)
                }
                .padding(.leading, extraPadding())
                Spacer()

                if showingBitrate {
                    Text("\(videoPlayer.bitrate/1_000_000, specifier: "%.1f") Mbps")
                        .frame(width: 120)
                        .monospacedDigit()
                        .foregroundStyle(color(for: videoPlayer.bitrate, ladder: videoPlayer.resolutionOptions).opacity(0.8))
                }
            }
            
            if hasResolutionOptions {
                ResolutionSelector(videoPlayer: $videoPlayer)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(20)
    }
    
    /// Evaluates the font color for the bitrate label depending on bitrate value.
    /// - Parameters:
    ///   - bitrate: the bitrate value as an `Double`
    ///   - ladder: the resolution options for the stream
    ///   - tolerance: the tolerance for color threshold (default 1.2Mbps)
    /// - Returns: White if top bitrate for the stream, yellow if second best, orange if third best, red otherwise.
    private func color(for bitrate: Double, ladder options: [ResolutionOption], tolerance: Int = 1_200_000) -> Color {
        if options.count > 3 && bitrate < Double(options[2].bitrate - tolerance) {
            .red
        } else if options.count > 2 && bitrate < Double(options[1].bitrate - tolerance) {
            .orange
        } else if options.count > 1 && bitrate < Double(options[0].bitrate - tolerance) {
            .yellow
        } else {
            .white
        }
    }
}

fileprivate struct ResolutionSelector: View {
    @Binding var videoPlayer: VideoPlayer
    
    var body: some View {
        HStack {
            if videoPlayer.shouldShowResolutionOptions {
                Spacer()
                
                Button {
                    videoPlayer.openResolutionOption(index: -1)
                } label: {
                    Text("Auto")
                        .font(.headline)
                }
                
                let options = videoPlayer.resolutionOptions
                let zippedOptions = Array(zip(options.indices, options))
                ForEach(zippedOptions, id: \.0) { index, option in
                    Button {
                        videoPlayer.openResolutionOption(index: index)
                    } label: {
                        Text(option.resolutionString)
                            .font(.subheadline)
                        Text(option.bitrateString)
                            .font(.caption)
                    }
                }
            }
            
            Button("", systemImage: "gearshape.fill") {
                videoPlayer.toggleResolutionOptions()
            }
            .frame(width: 100)
        }
    }
}


/// A simple horizontal view presenting the user with video playback control buttons.
fileprivate struct PlaybackButtons: View {
    var videoPlayer: VideoPlayer
    
    var body: some View {
        HStack {
            Button("", systemImage: "gobackward.15") {
                videoPlayer.minus15()
            }
            .controlSize(.extraLarge)
            .tint(.clear)
            .frame(width: 100)
            
            if videoPlayer.paused {
                Button("", systemImage: "play") {
                    videoPlayer.play()
                }
                .controlSize(.extraLarge)
                .tint(.clear)
                .frame(width: 100)
            } else {
                Button("", systemImage: "pause") {
                    videoPlayer.pause()
                }
                .controlSize(.extraLarge)
                .tint(.clear)
                .frame(width: 100)
            }
            
            Button("", systemImage: "goforward.15") {
                videoPlayer.plus15()
            }
            .controlSize(.extraLarge)
            .tint(.clear)
            .frame(width: 100)
        }
    }
}

/// A video scrubber made of a slider, which uses a simple state machine contained in `videoPlayer`.
/// Allows users to set the video to a specific time, while otherwise reflecting the current position in playback.
fileprivate struct Scrubber: View {
    @Binding var videoPlayer: VideoPlayer
    let config = Config.shared
    
    var body: some View {
        Slider(value: $videoPlayer.currentTime, in: 0...videoPlayer.duration) { scrubbing in
            if scrubbing {
                videoPlayer.scrubState = .scrubStarted
            } else {
                videoPlayer.scrubState = .scrubEnded
            }
        }
        .controlSize(.extraLarge)
        .tint(config.controlPanelScrubberTint)
        .background(Color.white.opacity(0.5), in: .capsule)
        .padding()
    }
}

/// A label view printing the current time and total duration of a video.
fileprivate struct TimeText: View {
    var videoPlayer: VideoPlayer
    
    var body: some View {
        Text(timeString)
            .font(.headline)
            .monospacedDigit()
            .frame(width: frameWidth)
    }
    
    var timeString: String {
        guard videoPlayer.duration > 0 else {
            return "--:-- / --:--"
        }
        let timeFormat: Duration.TimeFormatStyle = videoPlayer.duration >= 3600 ? .time(pattern: .hourMinuteSecond) : .time(pattern: .minuteSecond)
        
        let currentTime = Duration
            .seconds(videoPlayer.currentTime)
            .formatted(timeFormat)
        let duration = Duration
            .seconds(videoPlayer.duration)
            .formatted(timeFormat)
        
        return "\(currentTime) / \(duration)"
    }
    
    var frameWidth: CGFloat {
        get {
            if videoPlayer.duration >= 36_000 {
                return 200
            }
            if videoPlayer.duration >= 3600 {
                return 180
            }
            return 150
        }
    }
}

//#Preview(windowStyle: .automatic, traits: .fixedLayout(width: 1200, height: 45)) {
//    ControlPanel(videoPlayer: .constant(VideoPlayer()))
//}

#Preview {
    RealityView { content, attachments in
        if let entity = attachments.entity(for: "ControlPanel") {
            content.add(entity)
        }
    } attachments: {
        Attachment(id: "ControlPanel") {
            ControlPanel(videoPlayer: .constant(VideoPlayer()))
        }
    }
}
