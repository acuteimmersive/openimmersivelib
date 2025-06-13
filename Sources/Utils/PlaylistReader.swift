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
    /// Text copy of the playlist.
    @MainActor
    private(set) public var rawText: String = ""
    /// Resolution options parsed from the playlist resource at `url`.
    @MainActor
    private(set) public var resolutions: [ResolutionOption] = []
    /// AudioOptions parsed from the playest resource at `url`.
    @MainActor
    private(set) public var audios: [AudioOption] = []
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
        completionAction: (@MainActor (PlaylistReader) -> Void)?
    ) {
        self.url = url
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try await parseData(data)
                await Task { @MainActor in
                    state = .success
                }
            }
            catch {
                await Task { @MainActor in
                    state = .error(error: error)
                }
            }
            
            Task { @MainActor in
                completionAction?(self)
            }
        }
    }
    
    /// Parses raw data to populate the Playlist Reader's properties.
    /// - Parameters:
    ///   - data: raw data to be parsed, likely the response of a web request,
    ///   expected to be contents of a m3u8 HLS media playlist file.
    ///
    ///   Throws an error if the data is not text.
    private func parseData(_ data: Data) async throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw PlaylistReaderError.ParsingError
        }
        
        async let parseResolutions = parseResolutions(from: text)
        async let parseAudioOptions = parseAudioOptions(from: text)
        async let setRawText = Task { @MainActor in
            rawText = text
        }
        
        // Run the tasks in parallel
        await (parseResolutions, parseAudioOptions, setRawText)
    }
    
    /// Parses a list of Resolution Options from the playlist.
    /// - Parameters:
    ///   - text: text to be parsed, expected to be the contents of a m3u8 HLS media playlist file.
    private func parseResolutions(from text: String) async {
        var resolutionOptions: [ResolutionOption] = []
        
        let resolutionSearch = /RESOLUTION=(?<width>\d+)x(?<height>\d+),/
        let averageBandwidthSearch = /AVERAGE-BANDWIDTH=(?<averageBandwidth>\d+),/
        let bandwidthSearch = /BANDWIDTH=(?<bandwidth>\d+),/
        
        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let averageBandwidth = (try? averageBandwidthSearch.firstMatch(in: line))?.averageBandwidth ?? "0"
            let peakBandwidth = (try? bandwidthSearch.firstMatch(in: line)?.bandwidth) ?? "0"
            
            guard let resolution = try? resolutionSearch.firstMatch(in: line),
                  let width = Int(resolution.width),
                  let height = Int(resolution.height),
                  let averageBitrate = Int(averageBandwidth),
                  let peakBitrate = Int(peakBandwidth),
                  averageBitrate > 0 || peakBitrate > 0,
                  index + 1 < lines.count
            else { continue }
            
            let option = ResolutionOption(
                size: CGSize(width: width, height: height),
                averageBitrate: averageBitrate,
                peakBitrate: peakBitrate,
                url: hlsURL(from: absoluteURL(from: lines[index + 1], relativeTo: url))
            )
        
            resolutionOptions.append(option)
        }
        
        await Task { @MainActor in
            resolutions = resolutionOptions.sorted()
        }
    }
    
    /// Parses a list of Audio Options from the playlist.
    /// - Parameters:
    ///   - text: text to be parsed, expected to be the contents of an HLS m3u8 playlist file.
    private func parseAudioOptions(from text: String) async {
        var audioOptions: [AudioOption] = []
        
        let audioSearch = /#EXT-X-MEDIA:TYPE=AUDIO,(?<attributes>.+)/
        let groupIdSearch = /GROUP-ID="(?<groupId>[^"]+)"/
        let nameSearch = /NAME="(?<name>[^"]+)"/
        let languageSearch = /LANGUAGE="(?<language>[^"]+)"/
        let uriSearch = /URI="(?<url>[^"]+)"/

        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            guard let audio = try? audioSearch.firstMatch(in: line),
                  let groupId = try? groupIdSearch.firstMatch(in: audio.attributes),
                  let uri = try? uriSearch.firstMatch(in: audio.attributes)
            else { continue }
            
            var language = ""
            if let match = try? languageSearch.firstMatch(in: audio.attributes) {
                language = String(match.language)
            }
            
            var name = ""
            if let match = try? nameSearch.firstMatch(in: audio.attributes) {
                name = String(match.name)
            }
            
            let option = AudioOption(
                url: hlsURL(from: absoluteURL(from: String(uri.url), relativeTo: url)),
                groupId: String(groupId.groupId),
                name: name,
                language: language
            )
            
            audioOptions.append(option)
        }
        
        await Task { @MainActor in
            audios = audioOptions.sorted()
        }
    }
}
