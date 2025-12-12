//
//  AudioOption.swift
//  OpenImmersive
//
//  Created by Zachary Handshoe on 2/23/25.
//
import Foundation

/// Simple structure describing an audio option for an HLS video stream.
public struct AudioOption: Codable, Sendable {
    /// URL to a m3u8 HLS media playlist file.
    public let url: URL
    /// Group id for the audio
    public let groupId: String
    /// Name for the audio
    public let name: String
    /// Language for the audio
    public let language: String
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - url: URL to a m3u8 HLS media playlist file.
    ///   - groupId: Group ID of the audio
    ///   - name: Name of the audio
    ///   - language: Language of the audio.
    public init(url: URL, groupId: String, name: String, language: String) {
        self.url = url
        self.groupId = groupId
        self.name = name
        self.language = language
    }
    
    /// A textual description of the Audio Option.
    public var description: String {
        "\(languageString ?? name)"
    }
    
    /// A string value for the Language.
    public var languageString: String? {
        Locale.current.localizedString(forLanguageCode: language)
    }
}

extension AudioOption: Identifiable {
    public var id: String { url.absoluteString }
}

extension AudioOption: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(language)
        hasher.combine(groupId)
        hasher.combine(name)
        hasher.combine(url)
    }
}

extension AudioOption: Equatable {
    public static func == (lhs: AudioOption, rhs: AudioOption) -> Bool {
        lhs.id == rhs.id &&
        lhs.language == rhs.language &&
        lhs.groupId == rhs.groupId &&
        lhs.name == rhs.name &&
        lhs.url == rhs.url
    }
}

extension AudioOption: Comparable {
    public static func < (lhs: AudioOption, rhs: AudioOption) -> Bool {
        if lhs.groupId == rhs.groupId {
            lhs.description < rhs.description
        } else {
            lhs.groupId < rhs.groupId
        }
    }
}
