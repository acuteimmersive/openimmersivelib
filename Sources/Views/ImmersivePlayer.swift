//
//  ImmersivePlayer.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 9/11/24.
//

import SwiftUI
import RealityKit
import AVFoundation

/// An immersive video player, complete with UI controls
public struct ImmersivePlayer: View {
    /// The singleton video player control interface.
    @State var videoPlayer: VideoPlayer = VideoPlayer()
    
    /// The object managing the sphere or half-sphere displaying the video.
    // This needs to be a @State otherwise the video doesn't load.
    @State private(set) var videoScreen = VideoScreen()
    
    /// The item for which the player was open.
    ///
    /// The current implementation assumes only one media per appearance of the ImmersivePlayer.
    let selectedItem: VideoItem
    
    /// The callback to execute when the user closes the immersive player.
    let closeAction: CustomAction?
    
    /// A list of custom attachments provided by the developer.
    let customAttachments: [CustomAttachment]
    
    /// A custom button provided by the developer.
    let customButtons: CustomViewBuilder?
    
    /// The pose tracker ensuring the position of the control panel attachment is fixed relatively to the viewer.
    private let headTracker = HeadTracker()
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - selectedItem: the video item for which the player will be open.
    ///   - closeAction: the optional callback to execute when the user closes the immersive player.
    ///   - playbackEndedAction: the optional callback to execute when playback reaches the end of the video.
    ///   - customButtons: an optional view builder for custom buttons to add to the control panel.
    ///   - customAttachments: an optional list of view builders for custom attachments to add to the immersive player.
    public init(selectedItem: VideoItem, closeAction: CustomAction? = nil, playbackEndedAction: CustomAction? = nil, customButtons: CustomViewBuilder? = nil, customAttachments: [CustomAttachment] = []) {
        self.selectedItem = selectedItem
        self.closeAction = closeAction
        self.customButtons = customButtons
        self.customAttachments = customAttachments
        self.videoPlayer.playbackEndedAction = playbackEndedAction
    }
    
    public var body: some View {
        RealityView { content, attachments in
            let config = Config.shared
            
            // Setup root entity that will remain static relatively to the head
            let root = makeRootEntity()
            content.add(root)
            headTracker.start(content: content) { _ in
                guard let headTransform = headTracker.transform else {
                    return
                }
                let headPosition = simd_make_float3(headTransform.columns.3)
                root.position = headPosition
            }
            
            // Setup video sphere/half sphere entity
            root.addChild(videoScreen.entity)
            
            // Setup ControlPanel as a floating window within the immersive scene
            if let controlPanel = attachments.entity(for: "ControlPanel") {
                controlPanel.name = "ControlPanel"
                controlPanel.position = [0, config.controlPanelVerticalOffset, -config.controlPanelHorizontalOffset]
                controlPanel.orientation = simd_quatf(angle: -config.controlPanelTilt * .pi/180, axis: [1, 0, 0])
                root.addChild(controlPanel)
                
                for attachment in customAttachments {
                    if let customView = attachments.entity(for: attachment.id) {
                        customView.name = attachment.id
                        customView.position = attachment.position
                        customView.orientation = attachment.orientation
                        if attachment.relativeToControlPanel {
                            customView.position += controlPanel.position
                            customView.orientation *= controlPanel.orientation
                        }
                        root.addChild(customView)
                    }
                }
            }
            
            // Show a an error message when playback fails
            if let errorView = attachments.entity(for: "ErrorView") {
                errorView.name = "ErrorView"
                errorView.position = [0, 0, -0.7]
                root.addChild(errorView)
            }
            
            // Show a spinny animation when the video is buffering
            if let progressView = attachments.entity(for: "ProgressView") {
                progressView.name = "ProgressView"
                progressView.position = [0, 0, -0.7]
                root.addChild(progressView)
            }
            
            // Setup an invisible object that will catch all taps behind the control panel
            let tapCatcher = makeTapCatcher()
            root.addChild(tapCatcher)
        } update: { content, attachments in
            if let progressView = attachments.entity(for: "ProgressView") {
                progressView.isEnabled = videoPlayer.buffering || videoPlayer.loading
            }
            
            if let errorView = attachments.entity(for: "ErrorView") {
                errorView.isEnabled = videoPlayer.error != nil
            }
        } placeholder: {
            ProgressView()
        } attachments: {
            Attachment(id: "ControlPanel") {
                ControlPanel(videoPlayer: $videoPlayer, closeAction: closeAction, customButtons: customButtons)
                    .animation(.easeInOut(duration: 0.3), value: videoPlayer.shouldShowControlPanel)
            }
            
            Attachment(id: "ProgressView") {
                ProgressView()
            }
            
            Attachment(id: "ErrorView") {
                VStack {
                    Image(systemName: "play.slash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 50)
                        .padding()
                    Text(videoPlayer.error?.localizedDescription ?? "Media failed to play due to an unknown error.")
                        .frame(maxWidth: 400)
                        .padding()
                }
                .padding()
                .glassBackgroundEffect()
            }
            
            ForEach(customAttachments) { attachment in
                Attachment(id: attachment.id) {
                    AnyView(attachment.body($videoPlayer))
                        .animation(.easeInOut(duration: 0.3))
                }
            }
        }
        .onAppear {
            videoPlayer.openItem(selectedItem)
            videoPlayer.showControlPanel()
            videoPlayer.play()
            videoScreen.update(source: videoPlayer)
        }
        .onDisappear {
            videoPlayer.stop()
            videoPlayer.hideControlPanel()
            headTracker.stop()
        }
        .gesture(TapGesture()
            .targetedToAnyEntity()
            .onEnded { event in
                videoPlayer.toggleControlPanel()
            }
        )
    }
    
    /// Programmatically generates the root entity for the RealityView scene, and positions it at `(0, 1.2, 0)`,
    /// which is a typical position for a viewer's head while sitting on a chair.
    /// - Returns: a new root entity.
    private func makeRootEntity() -> some Entity {
        let entity = Entity()
        entity.name = "Root"
        entity.position = [0.0, 1.2, 0.0] // Origin would be the floor.
        return entity
    }
    
    /// Programmatically generates a tap catching entity in the shape of a large invisible box in front of the viewer.
    /// Taps captured by this invisible shape will toggle the control panel on and off.
    /// - Returns: a new tap catcher entity.
    private func makeTapCatcher() -> some Entity {
        let collisionShape: ShapeResource =
            .generateBox(width: 100, height: 100, depth: 1)
            .offsetBy(translation: [0.0, 0.0, -5.0])
        
        let entity = Config.shared.tapCatcherShowDebug ?
        ModelEntity(
            mesh: MeshResource(shape: collisionShape),
            materials: [UnlitMaterial(color: .red)]
        ) : Entity()
        
        entity.name = "TapCatcher"
        entity.components.set(CollisionComponent(shapes: [collisionShape], mode: .trigger, filter: .default))
        entity.components.set(InputTargetComponent())
        
        return entity
    }
}
