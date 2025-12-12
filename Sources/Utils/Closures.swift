//
//  Closures.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 5/21/25.
//

import SwiftUI

public typealias VideoItemAction = ((VideoItem) -> Void)
public typealias CustomAction = (() -> Void)
public typealias CustomViewBuilder = ((Binding<VideoPlayer>) -> any View)

/// Describes a RealityView SwiftUI attachment to inject into the `ImmersiveSpace`.
public struct CustomAttachment: Identifiable {
    public var id: String
    public var body: CustomViewBuilder
    public var position: SIMD3<Float>
    public var orientation: simd_quatf
    public var relativeToControlPanel: Bool
    
    public init(id: String, body: @escaping CustomViewBuilder, position: SIMD3<Float>, orientation: simd_quatf, relativeToControlPanel: Bool) {
        self.id = id
        self.body = body
        self.position = position
        self.orientation = orientation
        self.relativeToControlPanel = relativeToControlPanel
    }
}
