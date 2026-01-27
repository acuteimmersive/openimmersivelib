//
//  VideoScreen.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 1/17/25.
//

import RealityKit
import Observation

/// Manages `Entity` with the sphere/half-sphere or native player onto which the video is projected.
public class VideoScreen {
    /// The `Entity` containing the sphere or flat plane onto which the video is projected.
    public let entity: Entity = Entity()
    
    /// Public initializer for visibility.
    public init() {}
    
    /// The transform to apply to the native VideoPlayerComponent when the projection is a simple rectangle.
    private static let rectangularScreenTransform = Transform(
        scale: .init(x: 100, y: 100, z: -100),
        rotation: .init(),
        translation: .init(x: 0, y: 0, z: -200))
    
    /// Updates the video screen mesh with values from a VideoPlayer instance to resize it and start displaying its video media.
    /// - Parameters:
    ///   - videoPlayer: the VideoPlayer instance
    public func update(source videoPlayer: VideoPlayer) {
        let projection = videoPlayer.projection
        switch projection {
        case .equirectangular(fieldOfView: _, force: _):
            // updateSphere() must be called only once to prevent creating multiple VideoMaterial instances
            withObservationTracking {
                _ = videoPlayer.aspectRatio
            } onChange: {
                Task { @MainActor in
                    self.updateSphere(videoPlayer)
                }
            }
        
        case .rectangular:
            self.updateNativePlayer(videoPlayer, transform: Self.rectangularScreenTransform)
            
        case .appleImmersive:
            // the Apple Immersive Video entity should always use the identity transform
            self.updateNativePlayer(videoPlayer)
        }
    }
    
    /// Programmatically generates the sphere or half-sphere entity with a VideoMaterial onto which the video is projected.
    /// - Parameters:
    ///   - videoPlayer:the VideoPlayer instance
    private func updateSphere(_ videoPlayer: VideoPlayer) {
        let (mesh, transform) = VideoTools.makeVideoMesh(
            hFov: videoPlayer.horizontalFieldOfView,
            vFov: videoPlayer.verticalFieldOfView
        )
        
        entity.name = "VideoScreen (Sphere)"
        entity.components[VideoPlayerComponent.self] = nil
        entity.components[ModelComponent.self] = ModelComponent(
            mesh: mesh,
            materials: [videoPlayer.material]
        )
        entity.transform = transform
    }
    
    /// Sets up the entity with a VideoPlayerComponent that renders the video natively.
    /// - Parameters:
    ///   - videoPlayer:the VideoPlayer instance
    ///   - transform: the position of the entity (default identity)
    private func updateNativePlayer(_ videoPlayer: VideoPlayer, transform: Transform = .identity) {
        entity.name = "VideoScreen (Native Player)"
        entity.components[ModelComponent.self] = nil
        entity.components[VideoPlayerComponent.self] = videoPlayer.component
        entity.transform = transform
    }
}

public extension VideoPlayer {
    /// A RealityKit video material created from the underlying AVPlayer or AVSampleBufferVideoRenderer,
    /// depending on whether the media has frame packing or not.
    var material: VideoMaterial {
        if let renderer {
            VideoMaterial(videoRenderer: renderer)
        } else {
            VideoMaterial(avPlayer: player)
        }
    }
    
    /// A RealityKit video player component created from the underlying AVPlayer or AVSampleBufferVideoRenderer,
    /// depending on whether the media has frame packing or not.
    var component: VideoPlayerComponent {
        var component: VideoPlayerComponent
        if let renderer {
            component = VideoPlayerComponent(videoRenderer: renderer)
        } else {
            component = VideoPlayerComponent(avPlayer: player)
        }
        component.desiredViewingMode = .stereo
        component.desiredImmersiveViewingMode = .full
        return component
    }
}
