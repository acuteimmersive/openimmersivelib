//
//  PlaylistWriter.swift
//  OpenImmersive
//
//  Created by Zachary Handshoe on 2/24/25.
//

import Foundation

class PlaylistWriter {
    /// Writes an HLS playlist with the given video stream and audio option to a temporary file
    /// - Parameters:
    ///   - videoStreamInfo: The EXT-X-STREAM-INF line and URL for the video
    ///   - audioMediaInfo: The EXT-X-MEDIA line for the audio option
    /// - Returns: Text of a temporary file containing the playlist
    /// - Throws: Error if writing fails
    public func writeTemporaryPlaylist(videoStreamInfo: String, videoStreamUrl: String, audioMediaInfo: String) throws -> String {
        // Build the playlist content
        var playlistContent = "#EXTM3U\n"
        playlistContent += "#EXT-X-VERSION:12\n"
        
        // Add the video information line
        playlistContent += videoStreamInfo + "\n"
        
        // Add the video URL line
        playlistContent += videoStreamUrl + "\n"
        
        // Add the audio media line
//        playlistContent += audioMediaInfo + "\n"
        
        // Write the content to the temporary file
        do {
            print("Temporary Playlist Created")
            return playlistContent
        } catch {
            print("Failed to write playlist: \(error.localizedDescription)")
            throw error
        }
    }
}
