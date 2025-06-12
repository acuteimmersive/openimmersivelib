//
//  URLUtils.swift
//  OpenImmersive
//
//  Created by Anthony Maës on 6/11/25.
//

import Foundation

/// Assembles an absolute URL to a resource from a string that may be a relative or absolute URL.
/// - Parameters:
///   - string: the input string, which is assumed to be an absolute URL or a relative path.
///   - baseURL: the base URL to append the input string to if it's a relative path.
/// - Returns: a URL object to an absolute URL that's either the input string (if already absolute) or the path appended to the input base URL otherwise.
public func absoluteURL(from string: String, relativeTo baseURL: URL) -> URL {
    // testing for host() ensures that the URL is absolute
    if let url = URL(string: string), url.host() != nil {
        url
    } else {
        // the URL is a relative path
        URL(filePath: string, relativeTo: baseURL)
    }
}
