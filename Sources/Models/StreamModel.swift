//
//  StreamModel.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 9/25/24.
//

import Foundation

/// Simple structure describing a video stream.
public struct StreamModel: Codable {
    public enum Projection: Codable {
        /// Spherical projection of an equirectangular (or half equirectangular) frame. Use this for mono or MV-HEVC stereo VR180 & VR360 video.
        /// - Parameters:
        ///   - fieldOfView: the horizontal field of view of the video, in degrees.
        ///   - force: if false, use the field of view encoded in the media (only for local MV-HEVC). If true, use the provided `fieldOfView` no matter what (default false).
        case equirectangular(fieldOfView: Float, force: Bool = false)
        /// Rectangular video. Use this for 2D video and Spatial Video.
        case rectangular
        /// Native rendering for Apple Immersive Video (AIVU).
        case appleImmersive
    }
    
    /// The title of the video stream.
    public var title: String
    /// A short description of the video stream.
    public var details: String
    /// URL to a media, whether local or streamed from a HLS server (m3u8).
    public var url: URL
    /// The projection type of the media (will default to 180.0 degree equirectangular if nil).
    public var projection: Projection?
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - title: the title of the video stream.
    ///   - details: a short description of the video stream.
    ///   - url: URL to a media, whether local or streamed from a server (m3u8).
    ///   - projection: the projection type of the media (default nil).
    public init(title: String, details: String, url: URL, projection: Projection? = nil) {
        self.title = title
        self.details = details
        self.url = url
        self.projection = projection
    }
}

extension StreamModel: Identifiable {
    public var id: String { url.absoluteString }
}

extension StreamModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension StreamModel: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
