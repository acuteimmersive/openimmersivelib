import Foundation

/// Manages subtitle cues and provides efficient time-based lookups during playback
@Observable
public class SubtitleController {
    private var cues: [SubtitleCue]
    private var currentIndex: Int = 0

    public init(cues: [SubtitleCue]) {
        // Sort cues by start time to ensure they're in chronological order
        self.cues = cues.sorted { $0.startTime < $1.startTime }
    }

    /// Get the subtitle cue that should be displayed at the given time
    /// Returns nil if no cue is active at the specified time
    public func cue(at time: TimeInterval) -> SubtitleCue? {
        // Fast path: Check if current index is still valid
        if currentIndex < cues.count {
            let current = cues[currentIndex]
            if current.isActive(at: time) {
                return current
            }
        }

        // Search forward from current position
        if currentIndex < cues.count {
            for i in currentIndex..<cues.count {
                let cue = cues[i]
                if cue.isActive(at: time) {
                    currentIndex = i
                    return cue
                }
                // If we've passed the time, no need to continue
                if cue.startTime > time {
                    break
                }
            }
        }

        // Search backward (in case of seek backward)
        if currentIndex > 0 {
            for i in (0..<currentIndex).reversed() {
                let cue = cues[i]
                if cue.isActive(at: time) {
                    currentIndex = i
                    return cue
                }
                // If we've gone too far back, stop
                if cue.endTime < time {
                    break
                }
            }
        }

        // No active cue at this time
        return nil
    }

    /// Reset the controller (useful when seeking to start or loading new subtitles)
    public func reset() {
        currentIndex = 0
    }

    /// Get all cues (for debugging or UI purposes)
    public func allCues() -> [SubtitleCue] {
        return cues
    }

    /// Total number of cues
    public var cueCount: Int {
        return cues.count
    }

    /// Duration of the entire subtitle track (from first cue start to last cue end)
    public var totalDuration: TimeInterval? {
        guard let first = cues.first, let last = cues.last else {
            return nil
        }
        return last.endTime - first.startTime
    }
}
