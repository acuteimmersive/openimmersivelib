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
        /// Base CMFormatDescription could not be extracted from a pixel buffer.
        case CreateBaseFormatDescriptionError(status: Int)
        /// APMP CMFormatDescription could not be created.
        case CreateAPMPFormatDescriptionError(status: Int)
        /// APMP CMSampleBuffer could not be created.
        case CreateAPMPSampleBufferError(status: Int)
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
        var baseFormatDescription: CMFormatDescription?
        var status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &baseFormatDescription
        )
        
        guard status == noErr, let baseFormatDescription else {
            throw APMPInjectorError.CreateBaseFormatDescriptionError(status: Int(status))
        }
        
        // Get existing extensions and add our APMP extensions
        var extensions: [String: Any] = [:]
        if let existingExtensions = CMFormatDescriptionGetExtensions(baseFormatDescription) as? [String: Any] {
            extensions = existingExtensions
        }
        
        let packingValue: CFString = switch packing {
        case .none: "" as CFString // unreachable
        case .sideBySide: kCMFormatDescriptionViewPackingKind_SideBySide
        case .overUnder: kCMFormatDescriptionViewPackingKind_OverUnder
        }
        extensions[kCMFormatDescriptionExtension_ViewPackingKind as String] = packingValue
        
        let projectionValue: CFString = switch projection {
        case .equirectangular(let fieldOfView, let _):
            if fieldOfView > 180 { kCMFormatDescriptionProjectionKind_Equirectangular }
            else { kCMFormatDescriptionProjectionKind_HalfEquirectangular }
        case .rectangular: kCMFormatDescriptionProjectionKind_Rectilinear
        case .appleImmersive: kCMFormatDescriptionProjectionKind_AppleImmersiveVideo
        }
        extensions[kCMFormatDescriptionExtension_ProjectionKind as String] = projectionValue
        
        let fieldOfView: CFNumber = switch projection {
        case .equirectangular(let fieldOfView, let _): fieldOfView as CFNumber
        case .rectangular: 70 as CFNumber
        case .appleImmersive: 180 as CFNumber
        }
        extensions[kCMFormatDescriptionExtension_HorizontalFieldOfView as String] = fieldOfView as CFNumber
        
        let dimensions = CMVideoFormatDescriptionGetDimensions(baseFormatDescription)
        let codecType = CMFormatDescriptionGetMediaSubType(baseFormatDescription)
        
        var apmpFormatDescription: CMFormatDescription?
        status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: codecType,
            width: dimensions.width,
            height: dimensions.height,
            extensions: extensions as CFDictionary,
            formatDescriptionOut: &apmpFormatDescription
        )
        
        guard status == noErr, let apmpFormatDescription else {
            throw APMPInjectorError.CreateAPMPFormatDescriptionError(status: Int(status))
        }
        
        return apmpFormatDescription
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
        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: time,
            decodeTimeStamp: .invalid
        )
        
        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        
        guard status == noErr, let sampleBuffer else {
            throw APMPInjectorError.CreateAPMPSampleBufferError(status: Int(status))
        }
        
        return sampleBuffer
    }
}
