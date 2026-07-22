import AVFoundation
import Foundation

/// Builds `AVURLAsset` with headers/cookies per DESIGN §7.
@MainActor
enum AssetFactory {
    static func makeURLAsset(from source: MediaSource) -> AVURLAsset {
        var options: [String: Any] = [:]
        var headers = source.headers

        if !source.cookies.isEmpty {
            let cookieHeader = source.cookies
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
            if headers["Cookie"] == nil && headers["cookie"] == nil {
                headers["Cookie"] = cookieHeader
            }
        }

        if !headers.isEmpty {
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }

        return AVURLAsset(url: source.url, options: options)
    }
}
