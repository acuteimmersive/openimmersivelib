//
//  VideoPlayer.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 9/14/24.
//

import SwiftUI
import AVFoundation
import RealityKit

/// Video Player Controller interfacing the underlying `AVPlayer`, exposing states and controls to the UI.
// @MainActor ensures properties are published on the main thread
// which is critical for using them in SwiftUI Views
@MainActor
@Observable
public class VideoPlayer: Sendable {
    //MARK: Variables accessible to the UI
    /// The title of the current video (empty string if none).
    private(set) public var title: String = ""
    /// A short description of the current video, displayed under the title (empty string if none).
    private(set) public var description: String = ""
    /// The url of the current video.
    private(set) public var url: URL?
    /// The AVFoundation metadata of the current video.
    private(set) public var metadata: [AVMetadataIdentifier: String] = [:]
    /// A playback error, if any.
    private(set) public var error: Error?
    /// The duration in seconds of the current video (0 if none).
    private(set) public var duration: Double = 0
    /// `true` if playback is currently paused, or if playback has completed.
    private(set) public var paused: Bool = false
    /// `true` if playback is waiting to load the media.
    private(set) public var loading: Bool = false
    /// `true` if playback is temporarily interrupted due to buffering (HLS only).
    private(set) public var buffering: Bool = false
    /// `true` if playback reached the end of the video and is no longer playing.
    private(set) public var hasReachedEnd: Bool = false
    /// The callback to execute when playback reaches the end of the video.
    public var playbackEndedAction: CustomAction?
    /// The aspect ratio of the current media (width / height) (equirectangular projection only).
    private(set) public var aspectRatio: Float?
    /// The horizontal field of view for the current media (equirectangular projection only).
    private(set) public var horizontalFieldOfView: Float = 180.0
    /// The vertical field of view for the current media (equirectangular projection only).
    public var verticalFieldOfView: Float {
        get {
            // some 180/360 videos are originally encoded with non-square pixels, so don't use the aspect ratio for those.
            if self.horizontalFieldOfView >= 180.0 { return 180.0 }
            let aspectRatio = self.aspectRatio ?? 1.0
            return max(0, min(180, self.horizontalFieldOfView / aspectRatio))
        }
    }
    /// The bitrate of the current video stream (0 if none), only available if streaming from a HLS server (m3u8).
    private(set) public var bitrate: Double = 0
    /// Bitrate/resolution ladder available for the video stream, only available if streaming from a HLS server (m3u8).
    private(set) public var bitrateLadder: [BitrateRung] = []
    /// The currently selected bitrate rung index, if any. Only available if streaming from a HLS server (m3u8).
    private(set) public var selectedBitrateRungIndex: Int = -1
    /// Audio options available for the video stream, only available if streaming from a HLS server (m3u8) and with separate audio playlists.
    private(set) public var audioOptions: [AudioOption] = []
    /// The currently selected audio index, if any. Only available if streaming from a HLS server (m3u8).
    private(set) public var selectedAudioIndex: Int = -1
    /// `true` if the control panel should be visible to the user.
    private(set) public var shouldShowControlPanel: Bool = true
    /// `true` if the control panel should present resolution & audio options to the user.
    private(set) public var shouldShowPlaybackOptions: Bool = false
    /// `true` if the HLS stream has a bitrate ladder with at least 2 rungs and the custom configuration doesn't prevent user selection.
    public var canChooseResolution: Bool {
        bitrateLadder.count > 1 && Config.shared.controlPanelShowBitrateOptions
    }
    /// `true` if the HLS stream has at least 2 audio options and the custom configuration doesn't prevent user selection.
    public var canChooseAudio: Bool {
        audioOptions.count > 1 && Config.shared.controlPanelShowAudioOptions
    }
    /// The current volume of the underlying `AVPlayer`.
    public var volume: Float {
        get { player.volume }
        set {
            player.volume = newValue
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
          }
       }
    }
    
    //MARK: Private variables
    private var timeObserver: Any?
    private var durationObserver: NSKeyValueObservation?
    private var mediaStatusObserver: NSKeyValueObservation?
    private var bufferingObserver: NSKeyValueObservation?
    private var dismissControlPanelTask: Task<Void, Never>?
    private var playlistReader: PlaylistReader?
    private var delegate: PlaylistLoaderDelegate?
    
    //MARK: Immutable variables
    /// The video player
    public let player = AVPlayer()
    
    //MARK: Public methods
    /// Public initializer for visibility.
    public init() {
        configureAudio()
    }
    
    /// Instruct the UI to reveal the control panel.
    public func showControlPanel() {
        shouldShowPlaybackOptions = false
        withAnimation {
            shouldShowControlPanel = true
        }
        restartControlPanelTask()
    }
    
    /// Instruct the UI to hide the control panel.
    public func hideControlPanel() {
        withAnimation {
            shouldShowPlaybackOptions = false
            shouldShowControlPanel = false
        }
    }
    
    /// Instruct the UI to toggle the visibility of the control panel.
    public func toggleControlPanel() {
        if shouldShowControlPanel {
            hideControlPanel()
        } else {
            showControlPanel()
        }
    }
    
    /// Instruct the UI to toggle the visibility of resolutions and audio options.
    ///
    /// This will only do something if resolution or audio options are available.
    public func togglePlaybackOptions() {
        if bitrateLadder.count > 1 || audioOptions.count > 1 {
            withAnimation {
                shouldShowPlaybackOptions.toggle()
            }
            restartControlPanelTask()
        }
    }
    
    /// Configures the audio session for video playback.
    private func configureAudio() {
        do {
            // Configure the audio session for playback. Set the `moviePlayback` mode
            // to reduce the audio's dynamic range to help normalize audio levels.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
            try session.setIntendedSpatialExperience(
                .headTracked(soundStageSize: .automatic, anchoringStrategy: .automatic)
            )
        } catch {
            print("Error: failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    /// Load the indicated item (will stop playback).
    /// - Parameters:
    ///   - item: The object describing the video.
    public func openItem(_ item: VideoItem) {
        // Clean up the AVPlayer first, avoid bad states
        stop()
        
        url = item.url
        title = item.metadata[.commonIdentifierTitle] ?? ""
        description = item.metadata[.commonIdentifierDescription] ?? ""
        metadata = item.metadata
        
        guard let playerItem = makePlayerItem(item.url) else {
            return
        }
        player.replaceCurrentItem(with: playerItem)
        scrubState = .notScrubbing
        setupObservers()
        
        // If the video format is equirectangular, extract the field of view (horizontal & vertical) and aspect ratio
        if case .equirectangular(let fieldOfView, let forceFov) = item.projection {
            horizontalFieldOfView = max(0, min(360, fieldOfView))
            
            // Detect resolution and field of view, if available
            Task { [self] in
                guard let asset = playerItem.asset as? AVURLAsset,
                      let (resolution, horizontalFieldOfView) =
                        await VideoTools.getVideoDimensions(asset: asset) else {
                    return
                }
                self.aspectRatio = Float(resolution.width / resolution.height)
                if !forceFov, let horizontalFieldOfView {
                    self.horizontalFieldOfView = max(0, min(360, horizontalFieldOfView))
                }
            }
        }
        
        // if streaming from HLS, attempt to retrieve the bitrate ladder
        playlistReader = nil
        bitrateLadder = []
        selectedBitrateRungIndex = -1
        selectedAudioIndex = -1
        if item.url.host() != nil {
            playlistReader = PlaylistReader(url: item.url) { @MainActor reader in
                if case .success = reader.state {
                    if reader.bitrateLadder.count > 0 {
                        self.bitrateLadder = reader.bitrateLadder
                        let defaultResolution = reader.bitrateLadder.last!.size
                        self.aspectRatio = Float(defaultResolution.width / defaultResolution.height)
                    }
                    
                    if reader.audios.count > 0 {
                        self.audioOptions = reader.audios
                    }
                }
            }
        }
    }
    
    /// Load an HLS stream variant for the currently selected resolution and audio options, preserving other states.
    private func playSelectedVariant() {
        guard let url,
              let playerItem = makePlayerItem(url) else {
            return
        }
        
        withAnimation {
            shouldShowPlaybackOptions = false
        }
        
        // temporarily stop the observers to stop them from interfering in the state changes
        tearDownObservers()
        
        player.replaceCurrentItem(with: playerItem)
        
        // "simulating" a scrub end will seek the current time to the right spot
        scrubState = .scrubEnded
        
        setupObservers()
        
        if !paused {
            play()
        }
    }
    
    /// Generate the player item from the given URL.
    /// If the URL is for a root HLS playlist on a remote server, attach a PlaylistLoaderDelegate to its asset in order to enable resolution/audio selection.
    /// - Parameters:
    ///   - url: the URL to the media.
    private func makePlayerItem(_ url: URL) -> AVPlayerItem? {
        if url.host() == nil, url.pathExtension != "m3u8" {
            return AVPlayerItem(url: url)
        }
        
        // if streaming from a HLS playlist, use a delegate to optionally restrict video or audio options
        let bitrateRung = selectedBitrateRungIndex < 0 ? nil : bitrateLadder[selectedBitrateRungIndex]
        let audioOption = selectedAudioIndex < 0 ? nil : audioOptions[selectedAudioIndex]
        
        // tricky: persist and reuse the delegate object for it to be used by AVFoundation
        let delegate = {
            if let delegate = self.delegate {
                delegate.url = url
                delegate.bitrateRung = bitrateRung
                delegate.audioOption = audioOption
                return delegate
            }
            let delegate = PlaylistLoaderDelegate(url, bitrateRung: bitrateRung, audioOption: audioOption)
            self.delegate = delegate
            return delegate
        }()
        
        // tricky: replace http/https with a custom url scheme for the delegate object to be used by AVFoundation
        let playerAsset = AVURLAsset(url: delegate.customSchemeURL)
        playerAsset.resourceLoader.setDelegate(delegate, queue: .main)
        return AVPlayerItem(asset: playerAsset)
    }
    
    /// Load the bitrate rung for the given index, and play the corresponding video variant url if successful.
    /// - Parameters:
    ///   - index: the index of the bitrate rung, -1 for adaptive bitrate (default)
    public func selectBitrateRung(index: Int = -1) {
        guard index < bitrateLadder.count,
              index != selectedBitrateRungIndex
        else {
            return
        }
        
        selectedBitrateRungIndex = index
        playSelectedVariant()
    }
    
    /// Load the audio option for the given index, and play the corresponding audio variant url if successful.
    /// - Parameters:
    ///   - index: the index of the audio option, -1 for default.
    public func openAudioOption(index: Int = -1) {
        guard index < audioOptions.count,
              index != selectedAudioIndex
        else {
            return
        }
        
        selectedAudioIndex = index
        playSelectedVariant()
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

    /// Jump to a specific time in media playback.
    /// - Parameters:
    ///   - time: the playback time to jump to.
    ///   - toleranceBefore: an optional tolerance before the target time to allow.
    ///   - toleranceAfter: an optional tolerance after the target time to allow.
    ///
    /// See AVPlayer.seek() for details on the behavior of the tolerance parameters.
    public func seek(to time: CMTime,
                     toleranceBefore: CMTime = CMTime.positiveInfinity,
                     toleranceAfter: CMTime = CMTime.positiveInfinity) {
        hasReachedEnd = false
        player.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
        restartControlPanelTask()
    }
    
    /// Jump to a specific time in media playback.
    /// - Parameters:
    ///   - time: the playback time to jump to, in seconds from the start.
    public func seek(to time: Double) {
        seek(to: CMTime(seconds: time, preferredTimescale: 1000))
    }
    
    /// Jump to a specific time in media playback.
    /// - Parameters:
    ///   - newTime: the playback time to jump to, in seconds from the start.
    ///   - tolerance: the tolerance before and after the target time to allow, in seconds.
    ///
    /// A smaller tolerance may incur additional decoding delay which can impact seeking performance.
    public func seek(to time: Double, tolerance: Double) {
        let tolerance = CMTime(seconds: tolerance, preferredTimescale: 1000)
        seek(to: CMTime(seconds: time, preferredTimescale: 1000), toleranceBefore: tolerance, toleranceAfter: tolerance)
    }
    
    /// Jump back 15 seconds in media playback.
    public func minus15() {
        guard let time = player.currentItem?.currentTime() else {
            return
        }
        let newTime = time - CMTime(seconds: 15.0, preferredTimescale: 1000)
        seek(to: newTime)
    }
    
    /// Jump forward 15 seconds in media playback.
    public func plus15() {
        guard let time = player.currentItem?.currentTime() else {
            return
        }
        let newTime = time + CMTime(seconds: 15.0, preferredTimescale: 1000)
        seek(to: newTime)
    }
    
    /// Stop media playback and unload the current media.
    public func stop() {
        tearDownObservers()
        player.replaceCurrentItem(with: nil)
        title = ""
        description = ""
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
            let interval = CMTime(seconds: 0.005, preferredTimescale: 1000)
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: interval,
                queue: .main
            ) { [weak self] time in
                Task { @MainActor in
                    if let self {
                        let event = self.player.currentItem?.accessLog()?.events.last
                        // Average bitrate is supposed to be the most representative value
                        // but some HLS manifests only advertise bitrate.
                        if let event, event.indicatedAverageBitrate > 0 {
                            self.bitrate = event.indicatedAverageBitrate
                        } else if let event, event.indicatedBitrate > 0 {
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
        
        if mediaStatusObserver == nil, let currentItem = player.currentItem {
            mediaStatusObserver = currentItem.observe(
                \.status,
                 options: [.new, .initial]
            ) { [weak self] item, _ in
                Task { @MainActor in
                    self?.loading = item.status == .unknown
                    if item.status == .failed, let error = item.error {
                        print("Error: failed to load media: \(error.localizedDescription)")
                        self?.error = error
                    } else {
                        self?.error = nil
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
        mediaStatusObserver?.invalidate()
        mediaStatusObserver = nil
        bufferingObserver?.invalidate()
        bufferingObserver = nil
        
        NotificationCenter.default.removeObserver(
            self,
            name: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem
        )
    }
    
    /// Restarts a task with a 10-second timer to auto-hide the control panel.
    public func restartControlPanelTask() {
        cancelControlPanelTask()
        dismissControlPanelTask = Task {
            try? await Task.sleep(for: .seconds(10))
            let videoIsPlaying = error == nil && !loading && !paused && !hasReachedEnd && !buffering
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
