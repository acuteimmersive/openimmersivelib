//
//  PlaylistLoaderDelegate.swift
//  OpenImmersive
//
//  Created by Anthony Maës on 6/12/25.
//

import AVFoundation

/// A delegate that intercepts the loading of AVURLAsset objects whose URL point to a remote HLS root playlist (.m3u8).
/// This delegate pulls the playlist file and rewrites it as desired in order to only keep the desired resolution and audio options.
public class PlaylistLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    /// The URL of the HLS root playlist (.m3u8).
    public var url: URL
    /// The URL of the HLS root playlist (see `url`), with http:// or https:// swapped with the app's custom url scheme as defined in `Config.customHttpUrlScheme`.
    public var customSchemeURL: URL {
        guard var components = URLComponents(url: self.url, resolvingAgainstBaseURL: false),
              ["http", "https"].contains(components.scheme)
        else {
            return url
        }
        components.scheme = Config.shared.customHttpUrlScheme
        return components.url!
    }
    /// The selected bitrate/resolution rung, if any.
    public var bitrateRung: BitrateRung?
    /// The selected audio language/format option, if any.
    public var audioOption: AudioOption?
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///    - url: the URL of the HLS root playlist (.m3u8).
    ///    - bitrateRung: the desired bitrate/resolution rung, as parsed from `PlaylistReader`.
    ///    - audioOption: the desired audio option, as parsed from `PlaylistReader`.
    public init(_ url: URL, bitrateRung: BitrateRung? = nil, audioOption: AudioOption? = nil) {
        self.url = url
        self.bitrateRung = bitrateRung
        self.audioOption = audioOption
    }
    
    /// Invoked when assistance is required of the application to load a resource.
    /// - Parameters:
    ///    - resourceLoader: The instance of AVAssetResourceLoader for which the loading request is being made.
    ///    - loadingRequest: An instance of AVAssetResourceLoadingRequest that provides information about the requested resource.
    /// - Returns: true if the delegate can load the resource indicated by the AVAssetResourceLoadingRequest; otherwise false.
    ///
    /// See `AVAssetResourceLoaderDelegate` for more details.
    ///
    /// This implementation intercepts HLS playlist requests and filters the response according to the configuration of the delegate,
    /// in order to only keep the desired resolution/bitrate and/or audio language/format.
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                               shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let requestURL = loadingRequest.request.url,
              let scheme = requestURL.scheme,
              scheme == Config.shared.customHttpUrlScheme else {
            return false
        }
        let url = self.url
        let resolution = self.bitrateRung
        let audio = self.audioOption

        Task {
            do {
                if let contentInformationRequest = loadingRequest.contentInformationRequest {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    
                    contentInformationRequest.contentType = response.mimeType
                    contentInformationRequest.contentLength = Int64(data.count)
                    contentInformationRequest.isByteRangeAccessSupported = false
                    contentInformationRequest.isEntireLengthAvailableOnDemand = true
                    contentInformationRequest.renewalDate = nil
                }
                
                if let dataRequest = loadingRequest.dataRequest {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    
                    let writer = try PlaylistWriter(from: data, baseURL: url)
                    let filteredData = try await writer.makeVariant(
                        withBitrateRung: resolution,
                        withAudio: audio,
                        absoluteURLs: true
                    )
                    dataRequest.respond(with: filteredData)
                }
                
                loadingRequest.finishLoading()
            } catch {
                print("Error while processing the asset loading request: \(error.localizedDescription)")
                loadingRequest.finishLoading(with: error)
            }
        }
        return true
    }
}
