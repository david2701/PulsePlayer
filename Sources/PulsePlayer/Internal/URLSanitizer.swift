import Foundation

/// Redacts secrets from URLs, headers, and free-form messages before logs/events.
public enum URLSanitizer: Sendable {
    /// Query keys stripped from URLs (case-insensitive).
    public static let queryDenylist: Set<String> = [
        "token", "access_token", "auth", "authorization", "sig", "signature",
        "jwt", "key", "apikey", "api_key", "expires", "expiry", "session",
        "password", "secret", "code", "id_token", "refresh_token",
    ]

    /// Header names redacted (case-insensitive substring match).
    public static let headerDenylistSubstrings: [String] = [
        "authorization", "cookie", "set-cookie", "x-api-key", "x-auth",
        "token", "secret", "password",
    ]

    public static func sanitizeURL(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "<invalid-url>"
        }
        if let items = components.queryItems {
            components.queryItems = items.map { item in
                let name = item.name.lowercased()
                if queryDenylist.contains(name) {
                    return URLQueryItem(name: item.name, value: "<redacted>")
                }
                return item
            }
        }
        return components.string ?? url.absoluteString
    }

    public static func sanitizeHeaders(_ headers: [String: String]) -> [String: String] {
        var out: [String: String] = [:]
        out.reserveCapacity(headers.count)
        for (key, value) in headers {
            if shouldRedactHeader(key) {
                out[key] = "<redacted>"
            } else {
                out[key] = value
            }
        }
        return out
    }

    public static func sanitizeMessage(_ message: String) -> String {
        // Strip query-like secrets and common bearer tokens.
        var result = message
        if let regex = try? NSRegularExpression(
            pattern: #"(?i)(token|sig|jwt|auth|key|password|secret)=([^\s&"']+)"#,
            options: []
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1=<redacted>"
            )
        }
        if let regex = try? NSRegularExpression(
            pattern: #"(?i)(Bearer\s+)[A-Za-z0-9\-\._~\+\/]+=*"#,
            options: []
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1<redacted>"
            )
        }
        return result
    }

    public static func shouldRedactHeader(_ name: String) -> Bool {
        let lower = name.lowercased()
        return headerDenylistSubstrings.contains { lower.contains($0) }
    }
}
