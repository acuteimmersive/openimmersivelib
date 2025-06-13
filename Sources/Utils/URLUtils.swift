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

public func hlsURL(from url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
        return url
    }
    
    if components.scheme == "http" {
        components.scheme = Config.shared.customHttpUrlScheme
    } else if components.scheme == "https" {
        components.scheme = Config.shared.customHttpsUrlScheme
    } else {
        return url
    }
    
    return components.url!
}

public func httpURL(from url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
        return url
    }
    
    if components.scheme == Config.shared.customHttpUrlScheme {
        components.scheme = "http"
    } else if components.scheme == Config.shared.customHttpsUrlScheme {
        components.scheme = "https"
    } else {
        return url
    }
    
    return components.url!
}
