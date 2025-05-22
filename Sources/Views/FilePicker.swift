//
//  FilePicker.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 10/17/24.
//

import SwiftUI
import UniformTypeIdentifiers

/// A button revealing a file importer configured to only allow the selection of videos.
public struct FilePicker: View {
    /// The visibility of the file importer.
    @State private var isFileImporterShowing = false
    
    /// The callback to execute after a file has been picked.
    var loadStreamAction: StreamAction
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - loadStreamAction: the callback to execute after a file has been picked.
    public init(loadStreamAction: @escaping StreamAction) {
        self.loadStreamAction = loadStreamAction
    }
    
    public var body: some View {
        Button("Open from Files", systemImage: "folder.fill") {
            isFileImporterShowing.toggle()
        }
        .fileImporter(
            isPresented: $isFileImporterShowing,
            allowedContentTypes: [.audiovisualContent, UTType(filenameExtension: "aivu")!]
        ) { result in
            switch result {
            case .success(let url):
                // Hack: this should be mirrored by url.stopAccessingSecurityScopedResource(),
                // but it would prevent playing the same file twice.
                url.startAccessingSecurityScopedResource()
                
                let stream = StreamModel(
                    title: url.lastPathComponent,
                    details: "From Local Files",
                    url: url
                )
                loadStreamAction(stream)
                break
                
            case .failure(let error):
                print("Error: failed to load file: \(error)")
                break
            }
        }
    }
}

#Preview {
    FilePicker() { _ in
        // nothing
    }
}
