//
//  PlaylistWriter.swift
//  OpenImmersive
//
//  Created by Anthony Maës on 6/11/25.
//

import Foundation

/// Maintains a local m3u8 playlist and outputs a filtered version of it to enable user selection of audio and video variants.
public actor PlaylistWriter {
    /// Errors specific to Playlist Writer
    public enum PlaylistWriterError: Error {
        /// The playlist could not be written.
        case WriteError
        /// The playlist raw data could not be parsed into text.
        case ParsingError
        /// The specified resolution could not be selected.
        case ResolutionFilterError
        /// The specified audio could not be selected.
        case AudioFilterError
    }
    
    /// Text copy of the original playlist, assumed to be a valid HLS m3u8.
    public let rawText: String
    
    /// Base url of the original playlist.
    public let baseURL: URL
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - rawText: the text copy of the original playlist.
    ///   - baseURL: the base url of the original playlist.
    public init(from rawData: Data, baseURL: URL) throws {
        guard let text = String(data: rawData, encoding: .utf8) else {
            throw PlaylistWriterError.ParsingError
        }
        
        self.rawText = text
        self.baseURL = baseURL
    }
    
    /// Write a variant of the original playlist with the specified options.
    /// - Parameters:
    ///   - bitrateRung: the optional bitrate/resolution rung that should be the one to keep.
    ///   - audioOption: the optional audio that should be the one to keep.
    ///   - absoluteURLs: set to true to convert all URLs in the playlist to absolute URLs.
    ///   - completionAction: the optional callback to execute after writing the playlist file succeeds.
    /// - Returns: Data object with the filtered playlist.
    public func makeVariant(withBitrateRung bitrateRung: BitrateRung? = nil,
                            withAudio audioOption: AudioOption? = nil,
                            absoluteURLs: Bool = false,
                            completionAction: ((Data) -> Void)? = nil) throws -> Data {
        var lines = rawText.components(separatedBy: .newlines)
        
        if let bitrateRung {
            try filterResolution(&lines, bitrateRung)
        }
        
        if let audioOption {
            try filterAudio(&lines, audioOption)
        }
        
        if absoluteURLs {
            try makeURLsAbsolute(&lines)
        }
        
        let filteredText = lines.joined(separator: "\n")
        guard let data = filteredText.data(using: .utf8) else {
            throw PlaylistWriterError.WriteError
        }
        
        completionAction?(data)
        
        return data
    }
    
    /// Remove all the video resolution/quality variants other than the one provided.
    /// - Parameters:
    ///   - lines: the lines of the playlist file.
    ///   - resolution: the selected resolution variant.
    private func filterResolution(_ lines: inout [String], _ resolution: BitrateRung) throws {
        var filteredLines: [String] = []
        var skipNext = false
        
        for (index, line) in lines.enumerated() {
            if skipNext {
                skipNext = false
                continue
            }
            
            let nextLine = {
                let line = index + 1 < lines.count ? lines[index + 1] : ""
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }()
            
            if line.starts(with: "#EXT-X-STREAM-INF:"),
               !nextLine.isEmpty,
               !nextLine.contains(resolution.url.relativePath) {
                skipNext = true
                continue
            }
            
            filteredLines.append(line)
        }
        
        lines = filteredLines
        guard lines.contains(where: { $0.starts(with: "#EXT-X-STREAM-INF:") }) else {
            throw PlaylistWriterError.ResolutionFilterError
        }
    }
    
    /// Remove all the audio variants other than the one provided.
    /// - Parameters:
    ///   - lines: the lines of the playlist file.
    ///   - audio: the selected audio variant.
    private func filterAudio(_ lines: inout [String], _ audio: AudioOption) throws {
        let uriSearch = /URI="(?<url>[^"]+)"/
        let uriMatches = { (line: String) -> Bool in
            if let uri = try? uriSearch.firstMatch(in: line) {
                return String(uri.url).contains(audio.url.relativePath)
            }
            return false
        }
        
        lines.removeAll { line in
            line.starts(with: "#EXT-X-MEDIA:TYPE=AUDIO") && !uriMatches(line)
        }
        guard lines.contains(where: { $0.starts(with: "#EXT-X-MEDIA:TYPE=AUDIO") }) else {
            throw PlaylistWriterError.AudioFilterError
        }
    }
    
    /// Update all the URLs to ensure they are absolute URLs.
    /// - Parameters:
    ///   - lines: the lines of the playlist file.
    private func makeURLsAbsolute(_ lines: inout [String]) throws {
        //TODO: throw an error if?
        
        let uriSearch = /URI="(?<url>[^"]+)"/
        
        for (index, line) in lines.enumerated() {
            // Make URLs absolute for video segments & playlists
            let previousLine = index > 0 ? lines[index - 1] : ""
            if previousLine.starts(with: "#EXT-X-STREAM-INF:") {
                // then the current line is always a URL but might be relative
                lines[index] = absoluteURL(from: line).absoluteString
            }
            
            // Make URLs absolute for others (audio, subtitles, etc.)
            if let uri = try? uriSearch.firstMatch(in: line) {
                let string = String(uri.url)
                lines[index] = line.replacingOccurrences(of: string, with: absoluteURL(from: string).absoluteString)
            }
        }
    }
    
    /// Assembles an absolute URL to a resource from a string that may be a relative or absolute URL.
    /// - Parameters:
    ///   - string: the input string, which is assumed to be an absolute URL or a relative path.
    /// - Returns: a URL object to an absolute URL that's either the input string (if already absolute) or the path appended to the base URL otherwise.
    private func absoluteURL(from string: String) -> URL {
        // testing for host() ensures that the URL is absolute
        if let url = URL(string: string), url.host() != nil {
            url
        } else {
            // the URL is a relative path
            URL(filePath: string, relativeTo: baseURL)
        }
    }
}
