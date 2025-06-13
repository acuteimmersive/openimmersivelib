//
//  PlaylistWriter.swift
//  OpenImmersive
//
//  Created by Anthony Maës on 6/11/25.
//

import Foundation

/// Maintains a local m3u8 playlist to enable user selection of audio and video variants.
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
    ///   - resolutionOption: the optional resolution that should be the one to keep.
    ///   - audioOption: the optional audio that should be the one to keep.
    ///   - absoluteURLs: set to true to convert all URLs in the playlist to absolute URLs.
    ///   - completionAction: the optional callback to execute after writing the playlist file succeeds.
    /// - Returns: Data object with the filtered playlist.
    public func makeVariant(withResolution resolutionOption: ResolutionOption? = nil,
                            withAudio audioOption: AudioOption? = nil,
                            absoluteURLs: Bool = false,
                            completionAction: ((Data) -> Void)? = nil) throws -> Data {
        var lines = rawText.components(separatedBy: .newlines)
        
        if absoluteURLs {
            try makeURLsAbsolute(&lines)
        }
        
        if let resolutionOption {
            try filterResolution(&lines, resolutionOption)
        }
        
        if let audioOption {
            try filterAudio(&lines, audioOption)
        }
        
        let filteredText = lines.joined(separator: "\n")
        print("makeVariant:\n\(filteredText)\n")
        guard let data = filteredText.data(using: .utf8) else {
            throw PlaylistWriterError.WriteError
        }
        
        completionAction?(data)
        
        return data
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
                lines[index] = absoluteURL(from: line, relativeTo: baseURL).absoluteString
            }
            
            // Make URLs absolute for others (audio, subtitles, etc.)
            if let uri = try? uriSearch.firstMatch(in: line) {
                let string = String(uri.url)
                lines[index] = line.replacingOccurrences(of: string, with: absoluteURL(from: string, relativeTo: baseURL).absoluteString)
            }
        }
    }
    
    /// Remove all the video resolution/quality variants other than the one provided.
    /// - Parameters:
    ///   - lines: the lines of the playlist file.
    ///   - resolution: the selected resolution variant.
    private func filterResolution(_ lines: inout [String], _ resolution: ResolutionOption) throws {
        //TODO: throw an error if all the resolution options are thrown away
        
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
               resolution.url.absoluteString != nextLine {
                skipNext = true
                continue
            }
            
            filteredLines.append(line)
        }
        
        lines = filteredLines
    }
    
    /// Remove all the audio variants other than the one provided.
    /// - Parameters:
    ///   - lines: the lines of the playlist file.
    ///   - audio: the selected audio variant.
    private func filterAudio(_ lines: inout [String], _ audio: AudioOption) throws {
        //TODO: throw an error if all the audio options are thrown away
        
        let uriSearch = /URI="(?<url>[^"]+)"/
        let uriMatches = { (line: String) -> Bool in
            if let uri = try? uriSearch.firstMatch(in: line) {
                return audio.url.absoluteString == String(uri.url)
            }
            return false
        }
        
        lines.removeAll { line in
            line.starts(with: "#EXT-X-MEDIA:TYPE=AUDIO") && !uriMatches(line)
        }
    }
}
