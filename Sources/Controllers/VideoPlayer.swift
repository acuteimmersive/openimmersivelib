//
//  VideoPlayer.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 9/14/24.
//

import SwiftUI
import AVFoundation
import RealityFoundation

/// Video Player Controller interfacing the underlying `AVPlayer`, exposing states and controls to the UI.
// @MainActor ensures properties are published on the main thread
// which is critical for using them in SwiftUI Views
@MainActor
@Observable
public class VideoPlayer: Sendable {
    //MARK: Variables accessible to the UI
    /// The title of the current video (empty string if none).
    private(set) var title: String = ""
    /// A short description of the current video (empty string if none).
    private(set) var details: String = ""
    /// The duration in seconds of the current video (0 if none).
    private(set) var duration: Double = 0
    /// `true` if playback is currently paused, or if playback has completed.
    private(set) var paused: Bool = false
    /// `true` if playback is temporarily interrupted due to buffering.
    private(set) var buffering: Bool = false
    /// `true` if playback reached the end of the video and is no longer playing.
    private(set) var hasReachedEnd: Bool = false
    /// The callback to execute when playback reaches the end of the video.
    public var playbackEndedAction: (() -> Void)?
    /// The aspect ratio of the current media (width / height) (equirectangular projection only).
    private(set) var aspectRatio: Float = 1.0
    /// The horizontal field of view for the current media (equirectangular projection only).
    private(set) var horizontalFieldOfView: Float = 180.0
    /// The vertical field of view for the current media (equirectangular projection only).
    public var verticalFieldOfView: Float {
        get {
            // some 180/360 videos are originally encoded with non-square pixels, so don't use the aspect ratio for those.
            if self.horizontalFieldOfView >= 180.0 { return 180.0 }
            return max(0, min(180, self.horizontalFieldOfView / aspectRatio))
        }
    }
    /// The bitrate of the current video stream (0 if none), only available if streaming from a HLS server (m3u8).
    private(set) var bitrate: Double = 0
    /// Resolution options available for the video stream, only available if streaming from a HLS server (m3u8).
    private(set) var resolutionOptions: [ResolutionOption] = []
    /// `true` if the control panel should be visible to the user.
    private(set) var shouldShowControlPanel: Bool = true {
        didSet {
            if shouldShowControlPanel {
                restartControlPanelTask()
            }
        }
    }
    /// `true` if the control panel should present resolution options to the user.
    private(set) var shouldShowResolutionOptions: Bool = false {
        didSet {
            restartControlPanelTask()
        }
    }
    
    /// The current time in seconds of the current video (0 if none).
    ///
    /// This variable is updated by video playback but can be overwritten by a scrubber, in conjunction with `scrubState`.
    public var currentTime: Double = 0
    public enum ScrubState {
        /// The scrubber is not active and reflects the video's current playback time.
        case notScrubbing
        /// The scrubber is active and the user is actively dragging it.
        case scrubStarted
        /// The scrubber is no longer active, the user just stopped dragging it and video playback should resume from the indicated time.
        case scrubEnded
    }
    /// The current state of the scrubber.
    public var scrubState: ScrubState = .notScrubbing {
       didSet {
          switch scrubState {
          case .notScrubbing:
              break
          case .scrubStarted:
              cancelControlPanelTask()
              break
          case .scrubEnded:
              let seekTime = CMTime(seconds: currentTime, preferredTimescale: 1000)
              player.seek(to: seekTime) { [weak self] finished in
                  guard finished else {
                      return
                  }
                  Task { @MainActor in
                      self?.scrubState = .notScrubbing
                      self?.restartControlPanelTask()
                  }
              }
              hasReachedEnd = false
              break
          }
       }
    }
    
    //MARK: Private variables
    private var timeObserver: Any?
    private var durationObserver: NSKeyValueObservation?
    private var bufferingObserver: NSKeyValueObservation?
    private var dismissControlPanelTask: Task<Void, Never>?
    private var playlistReader: PlaylistReader?
    
    //MARK: Immutable variables
    /// The video player
    public let player = AVPlayer()
    
    //MARK: Public methods
    /// Public initializer for visibility.
    public init(title: String = "", details: String = "", duration: Double = 0, paused: Bool = false, buffering: Bool = false, hasReachedEnd: Bool = false, playbackEndedAction: (() -> Void)? = nil, aspectRatio: Float? = nil, horizontalFieldOfView: Float? = nil, bitrate: Double = 0, shouldShowControlPanel: Bool = true, currentTime: Double = 0, scrubState: VideoPlayer.ScrubState = .notScrubbing, timeObserver: Any? = nil, durationObserver: NSKeyValueObservation? = nil, bufferingObserver: NSKeyValueObservation? = nil, dismissControlPanelTask: Task<Void, Never>? = nil) {
        self.title = title
        self.details = details
        self.duration = duration
        self.paused = paused
        self.buffering = buffering
        self.hasReachedEnd = hasReachedEnd
        self.playbackEndedAction = playbackEndedAction
        if let aspectRatio { self.aspectRatio = aspectRatio }
        if let horizontalFieldOfView { self.horizontalFieldOfView = horizontalFieldOfView }
        self.bitrate = bitrate
        self.shouldShowControlPanel = shouldShowControlPanel
        self.currentTime = currentTime
        self.scrubState = scrubState
        self.timeObserver = timeObserver
        self.durationObserver = durationObserver
        self.bufferingObserver = bufferingObserver
        self.dismissControlPanelTask = dismissControlPanelTask
    }
    
    /// Instruct the UI to reveal the control panel.
    public func showControlPanel() {
        withAnimation {
            shouldShowControlPanel = true
        }
    }
    
    /// Instruct the UI to hide the control panel.
    public func hideControlPanel() {
        withAnimation {
            shouldShowControlPanel = false
        }
    }
    
    /// Instruct the UI to toggle the visibility of the control panel.
    public func toggleControlPanel() {
        withAnimation {
            shouldShowControlPanel.toggle()
        }
    }
    
    /// Instruct the UI to toggle the visibility of resolutions options.
    ///
    /// This will only do something if resolution options are available.
    public func toggleResolutionOptions() {
        if resolutionOptions.count > 1 {
            withAnimation {
                shouldShowResolutionOptions.toggle()
            }
        }
    }
    
    /// Load the indicated stream (will stop playback).
    /// - Parameters:
    ///   - stream: The model describing the stream.
    public func openStream(_ stream: StreamModel) {
        // Clean up the AVPlayer first, avoid bad states
        stop()
        
        title = stream.title
        details = stream.details
        
        let asset = AVURLAsset(url: stream.url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredPeakBitRate = 200_000_000 // 200 Mbps LFG!
        player.replaceCurrentItem(with: playerItem)
        scrubState = .notScrubbing
        setupObservers()
        
        // If the video format is equirectangular, extract the field of view (horizontal & vertical) and aspect ratio
        if case .equirectangular(let fieldOfView, let forceFov) = stream.projection {
            horizontalFieldOfView = max(0, min(360, fieldOfView))
            
            // Detect resolution and field of view, if available
            Task { [self] in
                guard let (resolution, horizontalFieldOfView) =
                        await VideoTools.getVideoDimensions(asset: asset) else {
                    return
                }
                self.aspectRatio = Float(resolution.width / resolution.height)
                if !forceFov, let horizontalFieldOfView {
                    self.horizontalFieldOfView = max(0, min(360, horizontalFieldOfView))
                }
            }
        }
        
        // if streaming from HLS, attempt to retrieve the resolution options
        playlistReader = nil
        resolutionOptions = []
        if stream.url.host() != nil {
            playlistReader = PlaylistReader(url: stream.url) { reader in
                Task { @MainActor in
                    if case .success = reader.state,
                       reader.resolutions.count > 0 {
                        self.resolutionOptions = reader.resolutions
                        let defaultResolution = reader.resolutions.first!.size
                        self.aspectRatio = Float(defaultResolution.width / defaultResolution.height)
                    }
                }
            }
        }
    }
    
    /// Load the corresponding stream variant from a resolution option, preserving other states.
    /// - Parameters:
    ///   - url: the url to the stream variant.
    private func openStreamVariant(_ url: URL) {
        guard let asset = player.currentItem?.asset as? AVURLAsset else {
            // nothing is currently playing
            return
        }
        
        guard asset.url != url else {
            // already playing the correct url
            return
        }
        
        withAnimation {
            shouldShowResolutionOptions = false
        }
        
        // temporarily stop the observers to stop them from interfering in the state changes
        tearDownObservers()
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        // "simulating" a scrub end will seek the current time to the right spot
        scrubState = .scrubEnded
        setupObservers()
        if !paused {
            play()
        }
    }
    
    /// Load the resolution option for the given index, and open the corresponding url if successful.
    /// - Parameters:
    ///   - index: the index of the resolution option, -1 for adaptive bitrate (default)
    public func openResolutionOption(index: Int = -1) {
        guard let playlistReader,
              index < resolutionOptions.count
        else {
            return
        }
        
        // index -1 is automatic, that is to say the original URL parsed by the playlist reader
        let selectedUrl = index < 0 ? playlistReader.url : resolutionOptions[index].url
        
        openStreamVariant(selectedUrl)
    }
    
    /// Play or unpause media playback.
    ///
    /// If playback has reached the end of the video (`hasReachedEnd` is true), play from the beginning.
    public func play() {
        if hasReachedEnd {
            player.seek(to: CMTime.zero)
        }
        player.play()
        paused = false
        hasReachedEnd = false
        restartControlPanelTask()
    }
    
    /// Pause media playback.
    public func pause() {
        player.pause()
        paused = true
        restartControlPanelTask()
    }
    
    /// Jump back 15 seconds in media playback.
    public func minus15() {
        guard let time = player.currentItem?.currentTime() else {
            return
        }
        let newTime = time - CMTime(seconds: 15.0, preferredTimescale: 1000)
        hasReachedEnd = false
        player.seek(to: newTime)
        restartControlPanelTask()
    }
    
    /// Jump forward 15 seconds in media playback.
    public func plus15() {
        guard let time = player.currentItem?.currentTime() else {
            return
        }
        let newTime = time + CMTime(seconds: 15.0, preferredTimescale: 1000)
        hasReachedEnd = false
        player.seek(to: newTime)
        restartControlPanelTask()
    }
    
    /// Stop media playback and unload the current media.
    public func stop() {
        tearDownObservers()
        player.replaceCurrentItem(with: nil)
        title = ""
        details = ""
        duration = 0
        currentTime = 0
        bitrate = 0
    }
    
    //MARK: Private methods
    /// Callback for the end of playback. Reveals the control panel if it was hidden.
    @objc private func onPlayReachedEnd() {
        Task { @MainActor in
            hasReachedEnd = true
            paused = true
            showControlPanel()
            self.playbackEndedAction?()
        }
    }
    
    // Observers are needed to extract the current playback time and total duration of the media
    // Tricky: the observer callback closures must capture a weak self for safety, and execute on the MainActor
    /// Set up observers to register current media duration, current playback time, current bitrate, playback end event.
    private func setupObservers() {
        if timeObserver == nil {
            let interval = CMTime(seconds: 0.1, preferredTimescale: 1000)
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: interval,
                queue: .main
            ) { [weak self] time in
                Task { @MainActor in
                    if let self {
                        if let event = self.player.currentItem?.accessLog()?.events.last {
                            self.bitrate = event.indicatedBitrate
                        } else {
                            self.bitrate = 0
                        }
                        
                        switch self.scrubState {
                        case .notScrubbing:
                            self.currentTime = time.seconds
                            break
                        case .scrubStarted: return
                        case .scrubEnded: return
                        }
                    }
                }
            }
        }
        
        if durationObserver == nil, let currentItem = player.currentItem {
            durationObserver = currentItem.observe(
                \.duration,
                 options: [.new, .initial]
            ) { [weak self] item, _ in
                let duration = CMTimeGetSeconds(item.duration)
                if !duration.isNaN {
                    Task { @MainActor in
                        self?.duration = duration
                    }
                }
            }
        }
        
        if bufferingObserver == nil {
            bufferingObserver = player.observe(
                \.timeControlStatus,
                 options: [.new, .old, .initial]
            ) { [weak self] player, status in
                Task { @MainActor in
                    self?.buffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                    // buffering doesn't bring up the control panel but prevents auto dismiss.
                    // auto dismiss after play resumed.
                    if (status.oldValue, status.newValue) == (.waitingToPlayAtSpecifiedRate, .playing) {
                        self?.restartControlPanelTask()
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPlayReachedEnd),
            name: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem
        )
    }
    
    /// Tear down observers set up in `setupObservers()`.
    private func tearDownObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        durationObserver?.invalidate()
        durationObserver = nil
        bufferingObserver?.invalidate()
        bufferingObserver = nil
        
        NotificationCenter.default.removeObserver(
            self,
            name: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem
        )
    }
    
    /// Restarts a task with a 10-second timer to auto-hide the control panel.
    private func restartControlPanelTask() {
        cancelControlPanelTask()
        dismissControlPanelTask = Task {
            try? await Task.sleep(for: .seconds(10))
            let videoIsPlaying = !paused && !hasReachedEnd && !buffering
            if !Task.isCancelled, videoIsPlaying {
                hideControlPanel()
            }
        }
    }
    
    /// Cancels the current task to dismiss the control panel, if any.
    private func cancelControlPanelTask() {
        dismissControlPanelTask?.cancel()
        dismissControlPanelTask = nil
    }
}
