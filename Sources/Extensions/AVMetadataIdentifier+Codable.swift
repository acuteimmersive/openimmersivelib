//
//  AVMetadataIdentifier+Codable.swift
//  OpenImmersive
//
//  Created by Anthony Maës on 12/11/25.
//

import AVFoundation

/// Codable extension of AVMetadataIdentifier so it can be used in VideoItem
extension AVMetadataIdentifier: Codable {
    public typealias RawValue = String

    public var rawValue: String {
        return self.rawValue
    }

    init?(value: String) {
        self.init(rawValue: value)
    }
}
