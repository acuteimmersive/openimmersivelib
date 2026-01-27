//
//  VideoItem.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 9/25/24.
//

import AVFoundation

/// Simple structure describing a video.
public struct VideoItem: Codable {
    nonisolated
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
    
    nonisolated
    public enum FramePacking: Codable {
        /// The video doesn't use frame packing. Use this for mono and MV-HEVC stereo videos (Spatial, AIV, some APMP).
        case none
        /// Left eye and right eye are packed side-by-side in each video frame. Common with legacy stereo VR180.
        case sideBySide
        /// Left eye and right eye are packed on top of one another in each video frame. Common with legacy stereo VR360.
        case overUnder
    }
    
    /// Dictionary of metadata values for the video. `commonIdentifierTitle` and `commonIdentifierDescription` are expected.
    public var metadata: [AVMetadataIdentifier: String]
    /// URL to a media, whether local or streamed from a HLS server (m3u8).
    public var url: URL
    /// The projection type of the media (will default to 180.0 degree equirectangular if nil).
    public var projection: Projection?
    /// The frame packing type of the media (default to .none).
    public var framePacking: FramePacking
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - metadata: dictionary of metadata values for the video. `commonIdentifierTitle` and `commonIdentifierDescription` are expected.
    ///   - url: URL to a media, whether local or streamed from a HLS server (m3u8).
    ///   - projection: the projection type of the media (default nil).
    ///   - framePacking: the frame packing type of the media (default .none)
    public init(metadata: [AVMetadataIdentifier: String], url: URL, projection: Projection? = nil, framePacking: FramePacking = .none) {
        self.metadata = metadata
        self.url = url
        self.projection = projection
        self.framePacking = framePacking
    }
}

extension VideoItem: Identifiable {
    public var id: String { url.absoluteString }
}

extension VideoItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension VideoItem: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
