import Foundation

/// Represents a single subtitle entry with timing and text content
public struct SubtitleCue: Identifiable, Equatable {
    public let id: UUID
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String

    public init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }

    /// Check if this cue should be displayed at the given time
    public func isActive(at time: TimeInterval) -> Bool {
        return time >= startTime && time < endTime
    }

    /// Duration of this subtitle cue in seconds
    public var duration: TimeInterval {
        return endTime - startTime
    }
}
