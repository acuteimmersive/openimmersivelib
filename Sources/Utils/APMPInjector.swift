//
//  APMPInjector.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 1/26/26.
//

import AVFoundation
import CoreMedia
import CoreVideo

/// Injects APMP metadata into frames to render stereo frame-packed media efficiently.
public class APMPInjector {
    /// Errors specific to APMP Injector.
    public enum APMPInjectorError: Error {
        /// The APMPInjector could not be created with framePacking = .none
        case InvalidFramePacking
    }
    
    /// The renderer to use for enqueueing. Expose this so callers can
    /// associate it with a display layer or RealityKit component.
    public let renderer = AVSampleBufferVideoRenderer()
    /// The source media's frame packing type, must be .sideBySide or .overUnder.
    private let packing: VideoItem.FramePacking
    /// The source media's projection type.
    private let projection: VideoItem.Projection
    /// The CoreMedia Format Description to inject to frames so they're treated as APMP.
    private var cachedFormatDescription: CMFormatDescription?
    /// The dimensions of the last pixel buffer, used to invalidate `cachedFormatDescription`.
    private var cachedDimensions: CMVideoDimensions?
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - packing: the source media's frame packing type, must be .sideBySide or .overUnder.
    ///   - projection: the source media's projection type.
    public init(
        packing: VideoItem.FramePacking,
        projection: VideoItem.Projection
    ) throws {
        guard packing != .none else {
            throw APMPInjectorError.InvalidFramePacking
        }
        self.packing = packing
        self.projection = projection
    }
    
    /// Full pipeline from video output to enqueue.
    /// Returns false if no new frame was available.
    /// - Parameters:
    ///   - videoOutput: The video output to extract the frame data from.
    ///   - at: The time at which sample will be presented. Must be valid numeric time.
    ///   - duration: How long the frame should be displayed before the next one, defaults to .invalid (unknown).
    /// - Returns: True is the frame was successfully enqueued.
    @discardableResult
    public func processFrame(
        videoOutput output: AVPlayerItemVideoOutput,
        at itemTime: CMTime,
        duration: CMTime = .invalid
    ) throws -> Bool {
        var presentationTime = CMTime.zero
        guard output.hasNewPixelBuffer(forItemTime: itemTime),
              renderer.isReadyForMoreMediaData,
              let pixelBuffer = output.copyPixelBuffer(
                forItemTime: itemTime,
                itemTimeForDisplay: &presentationTime
              ) else {
            return false
        }
        
        let formatDescription = try getAPMPFormatDescription(for: pixelBuffer)
        let sampleBuffer = try createSampleBuffer(
            pixelBuffer: pixelBuffer,
            formatDescription: formatDescription,
            time: presentationTime,
            duration: duration
        )
        
        renderer.enqueue(sampleBuffer)
        return true
    }
    
    /// Provides the CoreMedia video format description with APMP tags for the provided pixel buffer.
    /// - Parameters:
    ///   - pixelBuffer: The video pixel buffer of the current video frame.
    /// - Returns: The CoreMedia format description object with APMP tags.
    private func getAPMPFormatDescription(
        for pixelBuffer: CVPixelBuffer
    ) throws -> CMFormatDescription {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let dimensions = CMVideoDimensions(width: Int32(width), height: Int32(height))
        
        if let cachedFormatDescription,
           let cachedDimensions,
           cachedDimensions.width == dimensions.width,
           cachedDimensions.height == dimensions.height {
            return cachedFormatDescription
        }
        
        let formatDescription = try createAPMPFormatDescription(for: pixelBuffer)
        
        cachedFormatDescription = formatDescription
        cachedDimensions = dimensions
        
        return formatDescription
    }
    
    /// Creates a CoreMedia video format description with APMP tags for the provided pixel buffer.
    /// - Parameters:
    ///   - pixelBuffer: The video pixel buffer of the current frame.
    /// - Returns: The CoreMedia format description object with APMP tags.
    private func createAPMPFormatDescription(
        for pixelBuffer: CVPixelBuffer
    ) throws -> CMFormatDescription {
        let baseFormat = try CMVideoFormatDescription(imageBuffer: pixelBuffer)
        var extensions = baseFormat.extensions
        
        let (packingKind, baseline, disparity): (CMFormatDescription.Extensions.Value.ViewPackingKind, Float?, Float?)
        (packingKind, baseline, disparity) = switch packing {
        case .none: (.sideBySide, nil, nil) // unreachable
        case .sideBySide(let baseline, let horizontalDisparity): (.sideBySide, baseline, horizontalDisparity)
        case .overUnder(let baseline, let horizontalDisparity): (.overUnder, baseline, horizontalDisparity)
        }
        
        extensions[.viewPackingKind] = .viewPackingKind(packingKind)
        if let baseline {
            // multiply by 1000 to go from mm to µm
            extensions[.stereoCameraBaseline] = .number(UInt32(baseline * 1000))
        }
        if let disparity {
            // clamp from [-1.0, 1.0] and multiply by 10,000 to go in tenths of thousandth of the uniform range
            extensions[.horizontalDisparityAdjustment] = .number(Int32(min(max(disparity, -1.0), 1.0) * 10000))
        }
        
        let (projectionKind, fieldOfView): (CMFormatDescription.Extensions.Value.ProjectionKind, Float)
        (projectionKind, fieldOfView) = switch projection {
        case .equirectangular(let fieldOfView, let _): (fieldOfView > 180 ? .equirectangular : .halfEquirectangular, fieldOfView)
        case .rectangular: (.rectilinear, 65.0) // hard-coded typical spatial video field of view
        case .appleImmersive: (.appleImmersiveVideo, 180.0)
        }
        
        extensions[.projectionKind] = .projectionKind(projectionKind)
        // multiply by 1000 to go from degrees to thousandth of degrees
        extensions[.horizontalFieldOfView] = .number(UInt32(fieldOfView * 1000))
        
        return try CMVideoFormatDescription(
            videoCodecType: baseFormat.mediaSubType,
            width: Int(baseFormat.dimensions.width),
            height: Int(baseFormat.dimensions.height),
            extensions: extensions
        )
    }
    
    /// Creates the CoreMedia sample buffer associating a pixel buffer and a video format description.
    /// - Parameters:
    ///   - pixelBuffer: The video pixel buffer for the current frame.
    ///   - formatDescription: The video format description containing the APMP tags.
    ///   - time: The presentation media time for the current frame.
    ///   - duration: How long the frame should be displayed before the next one.
    /// - Returns: The CoreMedia format description object with APMP tags.
    private func createSampleBuffer(
        pixelBuffer: CVPixelBuffer,
        formatDescription: CMFormatDescription,
        time: CMTime,
        duration: CMTime
    ) throws -> CMSampleBuffer {
        let timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: time,
            decodeTimeStamp: .invalid
        )
        
        return try CMSampleBuffer(
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: timing
        )
    }
}
