//
//  StreamUrlInput.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 10/17/24.
//

import SwiftUI

/// A button revealing a sheet with a `TextField` and a clipboard paste button for manual input of stream URLs.
public struct StreamUrlInput: View {
    /// The visibility of the sheet.
    @State private var isSheetShowing: Bool = false
    /// The current value of the text field.
    @State private var textfieldRawVal: String = ""
    /// The cleaned up value of the text field.
    private var textfieldVal: String {
        get {
            textfieldRawVal.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// The URL validity of the current value of the text field. The "Play Stream" button is only active if this is `true`.
    ///
    /// The URL verification is very lenient and will mostly catch obvious accidental inputs.
    @State private var isUrlValid: Bool = false
    
    /// The callback to execute after a valid stream URL has been submitted.
    var loadStreamAction: StreamAction
    
    /// Public initializer for visibility.
    /// - Parameters:
    ///   - loadStreamAction: the callback to execute after a file has been picked.
    public init(loadStreamAction: @escaping StreamAction) {
        self.loadStreamAction = loadStreamAction
    }
    
    public var body: some View {
        Button("Enter Stream URL", systemImage: "link.circle.fill") {
            isSheetShowing.toggle()
        }
        .sheet(isPresented: $isSheetShowing) {
            VStack {
                HStack {
                    Button("", systemImage: "xmark", role: .cancel) {
                        textfieldRawVal = ""
                        isSheetShowing = false
                    }
                    
                    Text("Enter or paste a HLS stream URL (.m3u/.m3u8)")
                        .font(.headline)
                        .padding()
                    
                    Spacer()
                }
                .padding()
                
                HStack {
                    TextField("Stream URL", text: $textfieldRawVal)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            loadStream()
                        }
                    
                    Button("", systemImage: "list.clipboard") {
                        if let str = UIPasteboard.general.string {
                            textfieldRawVal = str
                        }
                    }
                }
                .padding()
                
                HStack {
                    Button("Load Stream", systemImage: "play.rectangle.fill") {
                        loadStream()
                        isSheetShowing = false
                    }
                    .disabled(!isUrlValid)
                }
                .padding()
            }
            .padding()
            .interactiveDismissDisabled()
            .presentationBackground(.clear)
            .onChange(of: textfieldVal) { _, _ in
                isUrlValid = validateUrl() != nil
            }
        }
    }
    
    /// Validate that the text field value is a valid URL
    /// - Returns: a `URL` object for the text field value if the URL is valid, `nil` otherwise.
    ///
    /// The URL verification is very lenient and will mostly catch obvious accidental inputs.
    ///
    /// It checks that a `URL` object can be built from the text field string value,
    /// then checks that the resulting object has a host, which implicitly checks for scheme, domain, and basic syntax.
    private func validateUrl() -> URL? {
        guard let url = URL(string: textfieldVal),
              url.host() != nil else {
            return nil
        }
        
        return url
    }
    
    /// Loads the inputted stream for playback.
    private func loadStream() {
        guard let url = validateUrl() else {
            return
        }
        
        let stream = StreamModel(
            title: "HLS Stream",
            details: url.absoluteString,
            url: url,
            isSecurityScoped: false
        )
        
        loadStreamAction(stream)
    }
}

#Preview {
    StreamUrlInput() { _ in
        //nothing
    }
}
