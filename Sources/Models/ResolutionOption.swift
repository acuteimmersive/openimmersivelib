//
//  ResolutionOption.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 11/16/24.
//

import Foundation

/// Simple structure describing a resolution option for an HLS video stream.
public struct ResolutionOption: Codable {
    /// Pixel resolution of the video stream.
    public let size: CGSize
    /// Peak bitrate of the video stream.
    public let bitrate: Int
    /// URL to a m3u8 HLS media playlist file.
    public let url: URL
    
    /// The line used to declare the resolution option in the HLS playlist
    public let declarationLine: String
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - size: the pixel resolution of the video stream.
    ///   - bitrate: the peak bitrate of the video stream.
    ///   - url: URL to a m3u8 HLS media playlist file.
    public init(size: CGSize, bitrate: Int, url: URL, declarationLine: String) {
        self.size = size
        self.bitrate = bitrate
        self.url = url
        self.declarationLine = declarationLine
    }
    
    /// A textual description of the Resolution Option.
    public var description: String {
        "\(resolutionString) (\(bitrateString))"
    }
    
    /// A string value for the Resolution Option's peak bitrate.
    public var bitrateString: String {
        switch bitrate {
        case 0..<1_000_000:
            return "\(bitrate/1000) Kbps"
        default:
            return "\(bitrate/1_000_000) Mbps"
        }
    }
    
    /// A string value for the Resolution Option's pixel resolution.
    public var resolutionString: String {
        switch size.height {
        case 0..<500:
            return "Low"
        case 720:
            return "720p"
        case 1080:
            return "1080p"
        case 1750...:
            return "\(Int(Float(size.height)/1000.0 + 0.4) * 2)K" // 4K, 6K, 8K etc.
        default:
            return "\(Int(Float(size.height)/500.0 + 0.2))K" // 1K, 2K, 3K
        }
    }
}

extension ResolutionOption: Identifiable {
    public var id: String { url.absoluteString }
}

extension ResolutionOption: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(size.width)
        hasher.combine(size.height)
        hasher.combine(bitrate)
        hasher.combine(url)
    }
}

extension ResolutionOption: Equatable {
    public static func == (lhs: ResolutionOption, rhs: ResolutionOption) -> Bool {
        return lhs.id == rhs.id &&
               lhs.size == rhs.size &&
               lhs.bitrate == rhs.bitrate &&
               lhs.url == rhs.url
    }
}
