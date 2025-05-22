//
//  VideoTools.swift
//  SpatialPlayer
//
//  Created by Michael Swanson on 2/6/24.
//

import RealityKit
@preconcurrency import AVFoundation

@MainActor
public struct VideoTools {
    /// Generates a sphere mesh suitable for mapping an equirectangular video source.
    /// - Parameters:
    ///   - radius: The radius of the sphere.
    ///   - sourceHorizontalFov: Horizontal field of view of the source material.
    ///   - sourceVerticalFov: Vertical field of view of the source material.
    ///   - clipHorizontalFov: Horizontal field of view to clip.
    ///   - clipVerticalFov: Vertical field of view to clip.
    ///   - verticalSlices: The number of divisions around the sphere.
    ///   - horizontalSlices: The number of divisions from top to bottom.
    /// - Returns: A MeshResource representing the sphere.
    public static func generateVideoSphere(
        radius: Float,
        sourceHorizontalFov: Float,
        sourceVerticalFov: Float,
        clipHorizontalFov: Float,
        clipVerticalFov: Float,
        verticalSlices: Int,
        horizontalSlices: Int
    ) -> MeshResource? {
        
        // Vertices
        var vertices: [simd_float3] = Array(
            repeating: simd_float3(), count: (verticalSlices + 1) * (horizontalSlices + 1))
        
        let verticalScale: Float = clipVerticalFov / 180.0
        let verticalOffset: Float = (1.0 - verticalScale) / 2.0
        
        let horizontalScale: Float = clipHorizontalFov / 360.0
        let horizontalOffset: Float = (1.0 - horizontalScale) / 2.0
        
        for y: Int in 0...horizontalSlices {
            let angle1 =
            ((Float.pi * (Float(y) / Float(horizontalSlices))) * verticalScale) + (verticalOffset * Float.pi)
            let sin1 = sin(angle1)
            let cos1 = cos(angle1)
            
            for x: Int in 0...verticalSlices {
                let angle2 =
                ((Float.pi * 2 * (Float(x) / Float(verticalSlices))) * horizontalScale)
                + (horizontalOffset * Float.pi * 2)
                let sin2 = sin(angle2)
                let cos2 = cos(angle2)
                
                vertices[x + (y * (verticalSlices + 1))] = SIMD3<Float>(
                    sin1 * cos2 * radius, cos1 * radius, sin1 * sin2 * radius)
            }
        }
        
        // Normals
        var normals: [SIMD3<Float>] = []
        for vertex in vertices {
            normals.append(-normalize(vertex))  // Invert to show on inside of sphere
        }
        
        // UVs
        var uvCoordinates: [simd_float2] = Array(repeating: simd_float2(), count: vertices.count)
        
        let uvHorizontalScale = clipHorizontalFov / sourceHorizontalFov
        let uvHorizontalOffset = (1.0 - uvHorizontalScale) / 2.0
        let uvVerticalScale = clipVerticalFov / sourceVerticalFov
        let uvVerticalOffset = (1.0 - uvVerticalScale) / 2.0
        
        for y in 0...horizontalSlices {
            for x in 0...verticalSlices {
                var uv: simd_float2 = [
                    (Float(x) / Float(verticalSlices)), 1.0 - (Float(y) / Float(horizontalSlices)),
                ]
                uv.x = (uv.x * uvHorizontalScale) + uvHorizontalOffset
                uv.y = (uv.y * uvVerticalScale) + uvVerticalOffset
                uvCoordinates[x + (y * (verticalSlices + 1))] = uv
            }
        }
        
        // Indices / triangles
        var indices: [UInt32] = []
        for y in 0..<horizontalSlices {
            for x in 0..<verticalSlices {
                let current: UInt32 = UInt32(x) + (UInt32(y) * UInt32(verticalSlices + 1))
                let next: UInt32 = current + UInt32(verticalSlices + 1)
                
                indices.append(current + 1)
                indices.append(current)
                indices.append(next + 1)
                
                indices.append(next + 1)
                indices.append(current)
                indices.append(next)
            }
        }
        
        var meshDescriptor = MeshDescriptor(name: "proceduralMesh")
        meshDescriptor.positions = MeshBuffer(vertices)
        meshDescriptor.normals = MeshBuffer(normals)
        meshDescriptor.primitives = .triangles(indices)
        meshDescriptor.textureCoordinates = MeshBuffer(uvCoordinates)
        
        let mesh = try? MeshResource.generate(from: [meshDescriptor])
        
        return mesh
    }
    
    /// Makes a spherical projection `MeshResource` for an immersive video.
    /// - Parameters:
    ///     - hFov: the horizontal field of view in degrees (default 180.0).
    ///     - vFov: the vertical field of view in degrees (default 180.0).
    /// - Returns: A tuple containing the `MeshResource` and `Transform` for the video.
    public static func makeVideoMesh(hFov: Float = 180.0, vFov: Float = 180.0) -> (mesh: MeshResource, transform: Transform) {
        let config = Config.shared
        let horizontalFov = min(360.0, max(0.0, hFov))
        let verticalFov = min(180.0, max(0.0, vFov))
        let horizontalSlices = max(1, Int(horizontalFov / 3))
        let verticalSlices = max(1, Int(verticalFov / 3))
        
        let mesh = VideoTools.generateVideoSphere(
            radius: config.videoScreenSphereRadius,
            sourceHorizontalFov: horizontalFov,
            sourceVerticalFov: verticalFov,
            clipHorizontalFov: horizontalFov,
            clipVerticalFov: verticalFov,
            verticalSlices: verticalSlices,
            horizontalSlices: horizontalSlices)
        
        let transform = Transform(
            scale: .init(x: 1, y: 1, z: 1),
            rotation: .init(angle: -Float.pi / 2, axis: .init(x: 0, y: 1, z: 0)),
            translation: .init(x: 0, y: 0, z: 0))
        
        return (mesh: mesh!, transform: transform)
    }
    
    /// Retrieves video resolution & field of view information from an `AVAsset`.
    /// - Parameters:
    ///   - asset: The `AVAsset` instance to extract video information from.
    /// - Returns: An optional tuple with the the video resolution, and, if the video is MV-HEVC, the horizontal field of view; nil if the video lacks the information.
    public static func getVideoDimensions(asset: AVAsset) async -> (CGSize, Float?)? {
        guard let tracks = try? await asset.load(.tracks),
              let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
            print("Could not extract video dimensions: No video track found")
            return nil
        }
        
        guard let (naturalSize, formatDescriptions) = try? await videoTrack.load(.naturalSize, .formatDescriptions)
        else {
            print("Could not extract video dimensions: Failed to load video properties")
            return nil
        }
        
        guard let formatDescription = formatDescriptions.first else {
            print("Could extract video resolution but not format description")
            return (naturalSize, nil)
        }
        
        guard let extensions = CMFormatDescriptionGetExtensions(formatDescription) as Dictionary?,
              let rawHorizontalFieldOfView = extensions[kCMFormatDescriptionExtension_HorizontalFieldOfView] as? UInt32 else {
            print("Could extract video resolution but not field of view: No extensions found in format description.")
            return (naturalSize, nil)
        }
        
        let horizontalFieldOfView = Float(rawHorizontalFieldOfView) / 1000.0
        return (naturalSize, horizontalFieldOfView)
    }
}
