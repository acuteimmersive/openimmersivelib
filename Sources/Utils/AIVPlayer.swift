//
//  AIVPlayer.swift
//  OpenImmersive
//
//  Created by Zachary Grant Handshoe on 5/25/25.
//

import AVKit
import SwiftUI

/// A view that presents the video content of an player object.
///
/// This class is a view controller representable type that adapts the interface
/// of AVPlayerViewController. It disables the view controller's default controls
/// so it can draw custom controls over the video content.
///
// This view is a SwiftUI wrapper over `AVPlayerViewController`.

public struct AIVPlayer: UIViewControllerRepresentable {
    let url: URL

    public init(url: URL) {
        self.url = url
    }

    
    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        // 1) Create the URL asset
        let asset = AVURLAsset(url: url)
        
        // 2) Hook it into the player
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        let controller = AVPlayerViewController()
        controller.player = player
        
        // 3) Start playback
        player.play()
        
        return controller
    }

    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // no dynamic updates in this example
    }
}
