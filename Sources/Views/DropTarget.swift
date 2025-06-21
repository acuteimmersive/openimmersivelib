//
//  DropTarget.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 6/20/25.
//

import SwiftUI

/// A view capable of receiving of showing videos dragged from other apps.
public struct DropTarget<Content: View>: View {
    /// Whether a dragged video is hovering the view at the moment.
    @State var isTargeted: Bool = false
    
    /// The nested view.
    let content: () -> Content
    
    /// The callback to execute after a valid video has been dropped.
    var loadStreamAction: StreamAction
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - content: the view builder for the view to nest.
    ///   - loadStreamAction: the callback to execute after a file has been picked.
    public init(@ViewBuilder content: @escaping () -> Content, loadStreamAction: @escaping StreamAction) {
        self.content = content
        self.loadStreamAction = loadStreamAction
    }
    
    public var body: some View {
        Group {
            if isTargeted {
                ZStack {
                    Color.clear
                    VStack(spacing: 20) {
                        Image(systemName: "photo.badge.arrow.down")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                        Text("Drop your video here")
                    }
                }
                .background(
                    // Espouse the boundaries of the app window
                    RoundedRectangle(cornerRadius: 50)
                        .fill(.clear)
                        .strokeBorder(style: StrokeStyle(lineWidth: 4, dash: [10]))
                )
            } else {
                content()
            }
        }
        .contentShape(.rect)
        .dropDestination(for: SpatialVideo.self) { videos, _ in
            guard let video = videos.first else {
                return false
            }
            
            let stream = StreamModel(
                title: video.url.lastPathComponent,
                details: "From dropped video",
                url: video.url
            )
            loadStreamAction(stream)
            return true
        } isTargeted: { val in withAnimation { isTargeted = val } }
    }
}

#Preview(windowStyle: .automatic) {
    DropTarget() {
        Color.clear
    } loadStreamAction: { _ in
        
    }
}
