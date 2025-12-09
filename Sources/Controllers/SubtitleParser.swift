import Foundation
import SwiftSubtitles

/// Wrapper around SwiftSubtitles library for parsing subtitle files
public class SubtitleParser {

    public enum SubtitleFormat: String {
        case srt = "srt"
        case webvtt = "vtt"
        case sbv = "sbv"
        case ssa = "ssa"
        case ass = "ass"

        public static func from(fileExtension: String) -> SubtitleFormat? {
            switch fileExtension.lowercased() {
            case "srt": return .srt
            case "vtt", "webvtt": return .webvtt
            case "sbv": return .sbv
            case "ssa": return .ssa
            case "ass": return .ass
            default: return nil
            }
        }
    }

    public enum ParserError: Error, LocalizedError {
        case unsupportedFormat(String)
        case fileReadError(Error)
        case parsingError(Error)
        case invalidURL
        case networkError(Error)

        public var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let ext):
                return "Unsupported subtitle format: .\(ext)"
            case .fileReadError(let error):
                return "Failed to read subtitle file: \(error.localizedDescription)"
            case .parsingError(let error):
                return "Failed to parse subtitle file: \(error.localizedDescription)"
            case .invalidURL:
                return "Invalid subtitle file URL"
            case .networkError(let error):
                return "Failed to download subtitle file: \(error.localizedDescription)"
            }
        }
    }

    public init() {}

    /// Parse a subtitle file and return an array of SubtitleCue objects
    public func parse(fileURL: URL) throws -> [SubtitleCue] {
        // Validate file extension
        let fileExtension = fileURL.pathExtension
        guard SubtitleFormat.from(fileExtension: fileExtension) != nil else {
            throw ParserError.unsupportedFormat(fileExtension)
        }

        // Parse using SwiftSubtitles (automatically detects format)
        let subtitles: Subtitles
        do {
            subtitles = try Subtitles(fileURL: fileURL, encoding: .utf8)
        } catch {
            throw ParserError.parsingError(error)
        }

        // Convert to our SubtitleCue model
        return subtitles.cues.map { cue in
            SubtitleCue(
                startTime: cue.startTime.timeInSeconds,
                endTime: cue.endTime.timeInSeconds,
                text: cue.text
            )
        }
    }

    /// Parse subtitle data from a string
    public func parse(string: String, format: SubtitleFormat = .srt) throws -> [SubtitleCue] {
        let subtitles: Subtitles
        do {
            let coder = coder(for: format)
            guard let data = string.data(using: .utf8) else {
                throw ParserError.parsingError(NSError(domain: "SubtitleParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not encode string as UTF-8"]))
            }
            subtitles = try coder.decode(data, encoding: .utf8)
        } catch {
            throw ParserError.parsingError(error)
        }

        return subtitles.cues.map { cue in
            SubtitleCue(
                startTime: cue.startTime.timeInSeconds,
                endTime: cue.endTime.timeInSeconds,
                text: cue.text
            )
        }
    }

    /// Parse subtitles from a URL (supports both local files and remote URLs)
    /// - Parameters:
    ///   - url: URL to the subtitle file (local file URL or remote http/https URL)
    /// - Returns: Array of SubtitleCue objects
    public func parse(url: URL) async throws -> [SubtitleCue] {
        let fileExtension = url.pathExtension
        guard let format = SubtitleFormat.from(fileExtension: fileExtension) else {
            throw ParserError.unsupportedFormat(fileExtension)
        }

        // Check if this is a remote URL
        if url.scheme == "http" || url.scheme == "https" {
            return try await parseRemote(url: url, format: format)
        } else {
            // Local file - use existing synchronous parsing
            return try parse(fileURL: url)
        }
    }

    /// Parse subtitles from a remote URL
    private func parseRemote(url: URL, format: SubtitleFormat) async throws -> [SubtitleCue] {
        let data: Data
        do {
            let (downloadedData, _) = try await URLSession.shared.data(from: url)
            data = downloadedData
        } catch {
            throw ParserError.networkError(error)
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw ParserError.parsingError(NSError(domain: "SubtitleParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not decode subtitle data as UTF-8"]))
        }

        return try parse(string: content, format: format)
    }

    /// Get the appropriate coder for a subtitle format
    private func coder(for format: SubtitleFormat) -> SubtitlesCodable {
        switch format {
        case .srt:
            return Subtitles.Coder.SRT.Create()
        case .webvtt:
            return Subtitles.Coder.VTT.Create()
        case .sbv:
            return Subtitles.Coder.SBV.Create()
        case .ssa:
            return Subtitles.Coder.SubStationAlpha.Create()
        case .ass:
            return Subtitles.Coder.AdvancedSSA.Create()
        }
    }
}
