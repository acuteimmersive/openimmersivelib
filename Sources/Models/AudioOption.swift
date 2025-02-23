//
//  AudioOption.swift
//  OpenImmersive
//
//  Created by Zachary Handshoe on 2/23/25.
//
import Foundation

/// Simple structure describing an audio option for an HLS video stream.
public struct AudioOption: Codable {
    /// URL to a m3u8 HLS media playlist file.
    public let url: URL
    /// Language for the audio
    public let language: String
    
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - url: URL to a m3u8 HLS media playlist file.
    ///   - language: Language of the audio
    public init(url: URL, language: String) {
        self.url = url
        self.language = language
    }
    
    /// A textual description of the Resolution Option.
    public var description: String {
        "\(languageString)"
    }
    
    /// A string value for the Language.
       public var languageString: String {
           switch language {
           case "en": return "English"
           case "es": return "Spanish"
           case "fr": return "French"
           case "de": return "German"
           case "it": return "Italian"
           case "pt": return "Portuguese"
           case "zh": return "Chinese"
           case "ja": return "Japanese"
           case "ko": return "Korean"
           case "ru": return "Russian"
           case "ar": return "Arabic"
           case "hi": return "Hindi"
           case "nl": return "Dutch"
           case "sv": return "Swedish"
           case "no": return "Norwegian"
           case "da": return "Danish"
           case "fi": return "Finnish"
           case "pl": return "Polish"
           case "tr": return "Turkish"
           case "he": return "Hebrew"
           case "id": return "Indonesian"
           case "th": return "Thai"
           case "vi": return "Vietnamese"
           case "cs": return "Czech"
           case "hu": return "Hungarian"
           case "el": return "Greek"
           case "ro": return "Romanian"
           case "bg": return "Bulgarian"
           case "uk": return "Ukrainian"
           case "ms": return "Malay"
           case "fa": return "Persian"
           case "sr": return "Serbian"
           case "hr": return "Croatian"
           case "sk": return "Slovak"
           case "sl": return "Slovenian"
           case "lt": return "Lithuanian"
           case "lv": return "Latvian"
           case "et": return "Estonian"
           default: return "Unknown"
           }
       }
}

extension AudioOption: Identifiable {
    public var id: String { url.absoluteString }
}

extension AudioOption: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(language)
        hasher.combine(url)
    }
}

extension AudioOption: Equatable {
    public static func == (lhs: AudioOption, rhs: AudioOption) -> Bool {
        return lhs.id == rhs.id &&
               lhs.language == rhs.language &&
               lhs.url == rhs.url
    }
}
