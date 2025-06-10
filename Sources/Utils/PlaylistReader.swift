//
//  PlaylistReader.swift
//  SpatialGen
//
//  Created by Zachary Handshoe on 8/28/24.
//

import Foundation

/// Fetches the m3u8 HLS media playlist file at the specified URL and parses information such as available resolutions.
public actor PlaylistReader {
    /// Errors specific to Playlist Reader
    public enum PlaylistReaderError: Error {
        /// The URL could not be read as a UTF8 text file.
        case ParsingError
        /// No resolution information was parsed from the URL.
        case NoAvailableResolutionError
    }
    
    public enum State {
        /// Waiting to access the data at the provided URL.
        case fetching
        /// Resolution options could not be parsed from the provided URL.
        case error(error: Error)
        /// Resolution options were successfully parsed from the playlist file at the provided URL.
        case success
    }
    
    /// The URL to a m3u8 HLS media playlist file to be parsed.
    @MainActor
    public let url: URL
    /// Current state of the Playlist Reader.
    @MainActor
    private(set) public var state: State = .fetching
    /// Resolution options parsed from the playlist resource at `url`.
    @MainActor
    private(set) public var resolutions: [ResolutionOption] = []
    /// Error that caused `state` to be set to `.error`. Will be `nil` if `state` is not `.error`.
    @MainActor
    public var error: Error? {
        get {
            switch state {
            case .error(let error):
                return error
            default:
                return nil
            }
        }
    }
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - url: the URL to the m3u8 playlist file to be parsed.
    ///   - completionAction: the callback to execute after parsing the playlist file succeeds or fails.
    public init(
        url: URL,
        completionAction: (@Sendable (PlaylistReader) -> Void)?
    ) {
        self.url = url
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try await parseData(data)
                await setState(.success)
            }
            catch {
                await setState(.error(error: error))
            }
            
            completionAction?(self)
        }
    }
    
    /// Thread safe setter for the current state of the Playlist Reader
    @MainActor
    private func setState(_ state: State) {
        self.state = state
    }
    
    /// Thread safe setter for the resolution of the Playlist Reader
    @MainActor
    private func setResolutions(_ resolutions: [ResolutionOption]) {
        self.resolutions = resolutions
    }
    
    /// Parses raw data to populate the Playlist Reader's properties.
    /// - Parameters:
    ///   - data: raw data to be parsed, likely the response of a web request,
    ///   expected to be contents of a m3u8 HLS media playlist file.
    ///
    ///   Throws an error if the data is not text, or if no resolutions are found.
    private func parseData(_ data: Data) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw PlaylistReaderError.ParsingError
        }
        
        let resolutions = parseResolutions(from: text)
        
        if resolutions.isEmpty {
            throw PlaylistReaderError.NoAvailableResolutionError
        }
        
        Task {
            await setResolutions(resolutions)
        }
    }
    
    /// Parses a list of Resolution Options from
    /// - Parameters:
    ///   - text: text to be parsed, expected to be the contents of a m3u8 HLS media playlist file.
    /// - Returns: a list of Resolution Options, sorted from highest to lowest.
    private func parseResolutions(from text: String) -> [ResolutionOption] {
        var resolutions: [ResolutionOption] = []
        let resolutionSearch = /RESOLUTION=(?<width>\d+)x(?<height>\d+),/
        let averageBandwidthSearch = /AVERAGE-BANDWIDTH=(?<averageBandwidth>\d+),/
        let bandwidthSearch = /BANDWIDTH=(?<bandwidth>\d+),/
        
        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let averageBandwidth = (try? averageBandwidthSearch.firstMatch(in: line))?.averageBandwidth ?? "0"
            let peakBandwidth = (try? bandwidthSearch.firstMatch(in: line)?.bandwidth) ?? "0"
            if let resolution = try? resolutionSearch.firstMatch(in: line),
               let width = Int(resolution.width),
               let height = Int(resolution.height),
               let averageBitrate = Int(averageBandwidth),
               let peakBitrate = Int(peakBandwidth),
               averageBitrate > 0 || peakBitrate > 0,
               index + 1 < lines.count {
                let url = {
                    // testing for host() ensures that the URL is absolute
                    if let playlistUrl = URL(string: lines[index + 1]),
                        let _ = playlistUrl.host() {
                        return playlistUrl
                    } else {
                        // we got a relative path
                        return URL(filePath: lines[index + 1], relativeTo: self.url)
                    }
                }()
                
                let option = ResolutionOption(
                    size: CGSize(width: width, height: height),
                    averageBitrate: averageBitrate,
                    peakBitrate: peakBitrate,
                    url: url
                )
                resolutions.append(option)
            }
        }
        
        return resolutions.sorted { $0.size.width > $1.size.width }
    }
}
