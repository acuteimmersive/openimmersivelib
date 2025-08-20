//
//  SpatialVideoTransferable.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 10/16/24.
//

import CoreTransferable
import UniformTypeIdentifiers

/// A representation for a spatial or immersive video selected from the Photos API or dragged and dropped onto the app
public struct SpatialVideo: Transferable {
    public enum Status: Sendable {
        case failed, ready
    }
    public let status: Status
    public let url: URL

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .audiovisualContent) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            let (status, url): (Status, URL) = copyFile(received.file)
            return Self.init(status: status, url: url)
        }
        
        FileRepresentation(contentType: UTType(filenameExtension: "aivu")!) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            let (status, url): (Status, URL) = copyFile(received.file)
            return Self.init(status: status, url: url)
        }
    }
    
    private static func copyFile(_ file: URL) -> (Status, URL) {
        let fileManager = FileManager.default
        
        let videosFolder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Videos")
        let newUrl = videosFolder.appendingPathComponent(file.lastPathComponent)
        
        if !fileManager.fileExists(atPath: newUrl.path) {
            try? fileManager
                .createDirectory(at: videosFolder, withIntermediateDirectories: true)
            
            // clean up the folder to keep the memory footprint of the app low
            try? fileManager
                .contentsOfDirectory(at: videosFolder, includingPropertiesForKeys: nil)
                .forEach { file in
                    try? fileManager.removeItem(atPath: file.path)
                }
            
            do {
                try fileManager.copyItem(at: file, to: newUrl)
            } catch {
                print("Error: could not create a temporary copy of the selected video file: \(error.localizedDescription)")
                return (.failed, newUrl)
            }
        }
        
        return (.ready, newUrl)
    }
}
