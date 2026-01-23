//
//  SpatialVideoPicker.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 10/11/24.
//

import SwiftUI
import PhotosUI

/// A button revealing a `PhotosPicker` configured to only show spatial videos.
public struct SpatialVideoPicker: View {
    /// The currently selected item, if any.
    @State private var selectedItem: PhotosPickerItem?
    
    /// Whether the picker should show spatial videos only.
    let spatialVideosOnly: Bool
    
    /// The callback to execute after a valid spatial video has been picked.
    let loadItemAction: VideoItemAction
    
    /// The Photos picker filter to use based on `spatialVideosOnly`.
    public var filter: PHPickerFilter {
        spatialVideosOnly ? .all(of: [.spatialMedia, .not(.images)]) : .videos
    }
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///  - spatialVideosOnly: true if the picker should only show spatial videos, false to show all videos.
    ///  - loadItemAction: the callback to execute after a file has been picked.
    public init(spatialVideosOnly: Bool = true, loadItemAction: @escaping VideoItemAction) {
        self.spatialVideosOnly = spatialVideosOnly
        self.loadItemAction = loadItemAction
    }
    
    public var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: filter,
            preferredItemEncoding: .current
        ) {
            Label("Open from Gallery", systemImage: "photo.on.rectangle.angled.fill")
        }
        .photosPickerDisabledCapabilities([.search, .collectionNavigation])
        .photosPickerStyle(.presentation)
        .onChange(of: selectedItem) { _, _ in
            Task {
                do {
                    if let video = try await selectedItem?.loadTransferable(type: SpatialVideo.self),
                       video.status == .ready {
                        let item = VideoItem(
                            metadata: [
                                .commonIdentifierTitle: video.url.lastPathComponent,
                                .commonIdentifierDescription: "From Local Gallery",
                            ],
                            url: video.url
                        )
                        loadItemAction(item)
                    }
                } catch {
                    print("Error: could not load SpatialVideo Transferable: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    SpatialVideoPicker() { _ in
        //nothing
    }
}
