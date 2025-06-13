//
//  PlaylistLoaderDelegate.swift
//  OpenImmersive
//
//  Created by Anthony Maës on 6/12/25.
//

import AVFoundation

public class PlaylistLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    public let resolutionOption: ResolutionOption?
    public let audioOption: AudioOption?
    
    public init(resolutionOption: ResolutionOption? = nil, audioOption: AudioOption? = nil) {
        self.resolutionOption = resolutionOption
        self.audioOption = audioOption
    }
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                               shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        print("resource loader should wait for loading of requested resource: \(loadingRequest.request.url?.absoluteString ?? "???")")
        
        let customSchemes = [Config.shared.customHttpUrlScheme, Config.shared.customHttpsUrlScheme]
        guard let requestURL = loadingRequest.request.url,
              let scheme = requestURL.scheme,
              customSchemes.contains(scheme) else {
            print("skipping non-m3u8 resource: \(loadingRequest.request.url?.absoluteString ?? "???")")
            return false
        }
        
        guard resolutionOption != nil || audioOption != nil else {
            print("skipping no resolution option and no audio option")
            return false
        }
        
        let url = httpURL(from: requestURL)
        let resolution = self.resolutionOption
        let audio = self.audioOption

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                let writer = try PlaylistWriter(from: data, baseURL: url)
                let filteredData = try await writer.makeVariant(
                    withResolution: resolution,
                    withAudio: audio
                )
                
                loadingRequest.dataRequest?.respond(with: filteredData)
                loadingRequest.finishLoading()
            } catch {
                print("Error while processing the filtered playlist: \(error)")
                loadingRequest.finishLoading(with: error)
            }
        }
        return true
    }
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                               shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest
    ) -> Bool {
        print("resource loader should wait for renewal of requested resource: \(renewalRequest.request.url?.absoluteString ?? "???")")
        return false
    }
}
