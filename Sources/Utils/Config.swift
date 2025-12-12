//
//  Config.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 1/16/25.
//

import Foundation
import SwiftUI

/// Fetches custom values in the application's openimmersive.plist
public final class Config: Sendable {
    /// URL scheme to substitute to http/https for loading HLS playlists (String): this is needed for selecting bandwidth or audio.
    public let customHttpUrlScheme: String
    /// Vertical offset of the control panel in meters (Number): + is up, - is down.
    public let controlPanelVerticalOffset: Float
    /// Horizontal offset of the control panel in meters (Number): + is forward, - is backward.
    public let controlPanelHorizontalOffset: Float
    /// Tilt of the control panel in degrees (Number): + is tilted up, - is tilted down.
    public let controlPanelTilt: Float
    /// Maximum height of the control panel's media info box (Number): title and details text will be truncated.
    public let controlPanelMediaInfoMaxHeight: Float
    /// Show or hide the control panel's bitrate readout for HLS streams (Boolean).
    public let controlPanelShowBitrate: Bool
    /// Show or hide the control panel's resolution selector for HLS streams (Boolean).
    public let controlPanelShowBitrateOptions: Bool
    /// Show or hide the control panel's audio selector for HLS streams (Boolean).
    public let controlPanelShowAudioOptions: Bool
    /// Show or hide the control panel's volume control (Boolean).
    public let controlPanelShowVolume: Bool
    /// Tint for the scrubber (String): RGB or RGBA color in hexadecimal in the #RRGGBB or #RRGGBBAA format.
    public let controlPanelScrubberTint: Color
    /// Radius of the video screen's sphere in meters (Number): make sure it's large enough to fit the control panel.
    public let videoScreenSphereRadius: Float
    /// Whether to show or hide the Tap Catcher in red (Boolean).
    public let tapCatcherShowDebug: Bool
    
    /// Shared config object with values that can be overridden by the app.
    public static let shared: Config = Config()
    
    /// Private initializer, parses openimmersive.plist in the enclosing app bundle.
    private init() {
        var config: [String: Any] = [:]
        if let url = Bundle.main.url(forResource: "openimmersive", withExtension: "plist") {
            if let data = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let customConfig = plist as? [String: Any] {
                config = customConfig
                print("OpenImmersive loaded with custom configuration")
            } else {
                print("OpenImmersive could not parse the configuration file, loaded with default configuration")
            }
        } else {
            print("OpenImmersive loaded with default configuration")
        }
        
        customHttpUrlScheme = config["customHttpUrlScheme"] as? String ?? "openimmersive"
        controlPanelVerticalOffset = config["controlPanelVerticalOffset"] as? Float ?? -0.5
        controlPanelHorizontalOffset = config["controlPanelHorizontalOffset"] as? Float ?? 0.7
        controlPanelTilt = config["controlPanelTilt"] as? Float ?? 12.0
        controlPanelMediaInfoMaxHeight = config["controlPanelMediaInfoMaxHeight"] as? Float ?? 140
        controlPanelShowBitrate = config["controlPanelShowBitrate"] as? Bool ?? true
        controlPanelShowBitrateOptions = config["controlPanelShowBitrateOptions"] as? Bool ?? true
        controlPanelShowAudioOptions = config["controlPanelShowAudioOptions"] as? Bool ?? true
        controlPanelShowVolume = config["controlPanelShowVolume"] as? Bool ?? true
        if let controlPanelScrubberTintValue = config["controlPanelScrubberTint"] as? String,
           let color = Self.color(from: controlPanelScrubberTintValue) {
            controlPanelScrubberTint = color
        } else {
            controlPanelScrubberTint = .orange.opacity(0.7)
        }
        videoScreenSphereRadius = config["videoScreenSphereRadius"] as? Float ?? 1000.0
        tapCatcherShowDebug = config["tapCatcherShowDebug"] as? Bool ?? false
    }
    
    /// Parses a string hexadecimal representation and returns the corresponding Color.
    /// - Parameters:
    ///   - colorString: text to be parsed, expected to be a hex color literal in the #RRGGBB or #RRGGBBAA format.
    /// - Returns: the corresponding Color, if the string is well formatted, otherwise nil.
    private static func color(from colorString: String) -> Color? {
        let trimmedString = colorString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let colorSearch = /#(?<red>[0-9A-F]{2})(?<green>[0-9A-F]{2})(?<blue>[0-9A-F]{2})(?<alpha>[0-9A-F]{2})?/
        
        guard let color = try? colorSearch.firstMatch(in: trimmedString),
              let red256 = Int(color.red, radix: 16),
              let green256 = Int(color.green, radix: 16),
              let blue256 = Int(color.blue, radix: 16) else {
            print("OpenImmersive could not parse the color: \(colorString). Accepted formats: #RRGGBB or #RRGGBBAA")
            return nil
        }
        
        let red = Double(red256) / 255.0
        let green = Double(green256) / 255.0
        let blue = Double(blue256) / 255.0
        var alpha = 1.0
        if let alphaHex = color.alpha,
           let alpha256 = Int(alphaHex, radix: 16) {
            alpha = Double(alpha256) / 255.0
        }

        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
