//
//  AIVUtils.swift
//  OpenImmersive
//
//  Created by Zachary Grant Handshoe on 5/25/25.
//
import Foundation

/// A helper function which parses a playlist and determins if it is AIV or not
public func detectAIVStream(url: URL) async -> Bool {
    await withCheckedContinuation { continuation in
        let playlistReader = PlaylistReader(url: url) { reader in
            Task { @MainActor in
                if case .success = reader.state {
                    continuation.resume(returning: await reader.isAiv)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
