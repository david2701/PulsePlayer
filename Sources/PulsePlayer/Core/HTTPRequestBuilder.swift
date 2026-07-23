import Foundation

enum HTTPRequestBuilder {
    static func request(
        url: URL,
        headers: [String: String] = [:],
        cookies: [HTTPCookieValue] = []
    ) -> URLRequest {
        var request = URLRequest(url: url)
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if request.value(forHTTPHeaderField: "Cookie") == nil {
            let valid = validCookies(cookies, for: url)
            if !valid.isEmpty {
                let fields = HTTPCookie.requestHeaderFields(with: valid)
                request.setValue(fields["Cookie"], forHTTPHeaderField: "Cookie")
            }
        }
        return request
    }

    static func cookieHeader(
        cookies: [HTTPCookieValue],
        for url: URL,
        now: Date = Date()
    ) -> String? {
        let valid = validCookies(cookies, for: url, now: now)
        guard !valid.isEmpty else { return nil }
        return HTTPCookie.requestHeaderFields(with: valid)["Cookie"]
    }

    private static func validCookies(
        _ values: [HTTPCookieValue],
        for url: URL,
        now: Date = Date()
    ) -> [HTTPCookie] {
        guard let host = url.host?.lowercased() else { return [] }
        let requestPath = url.path.isEmpty ? "/" : url.path
        let isHTTPS = url.scheme?.lowercased() == "https"

        return values.compactMap { value in
            let domain = value.domain
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .lowercased()
            let cookiePath = value.path.isEmpty ? "/" : value.path
            let pathMatches = requestPath == cookiePath
                || (cookiePath.hasSuffix("/") && requestPath.hasPrefix(cookiePath))
                || requestPath.hasPrefix("\(cookiePath)/")
            guard !domain.isEmpty,
                  host == domain || host.hasSuffix(".\(domain)"),
                  pathMatches,
                  value.expiresDate.map({ $0 > now }) ?? true,
                  !value.isSecure || isHTTPS
            else { return nil }

            var properties: [HTTPCookiePropertyKey: Any] = [
                .name: value.name,
                .value: value.value,
                .domain: value.domain,
                .path: cookiePath,
                .secure: value.isSecure ? "TRUE" : "FALSE",
            ]
            if let expiresDate = value.expiresDate {
                properties[.expires] = expiresDate
            }
            return HTTPCookie(properties: properties)
        }
    }
}
