import AVFoundation
import Foundation

/// Builds `AVURLAsset` with headers/cookies per DESIGN §7.
@MainActor
enum AssetFactory {
    static func makeURLAsset(from source: MediaSource) -> AVURLAsset {
        var options: [String: Any] = [:]
        var headers = source.headers

        if !headers.keys.contains(where: { $0.caseInsensitiveCompare("Cookie") == .orderedSame }),
           let cookieHeader = HTTPRequestBuilder.cookieHeader(
               cookies: source.cookies,
               for: source.url
           )
        {
            headers["Cookie"] = cookieHeader
        }

        if !headers.isEmpty {
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }

        return AVURLAsset(url: source.url, options: options)
    }
}
