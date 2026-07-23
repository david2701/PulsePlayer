import Foundation
import Testing
@testable import PulsePlayer

@Suite("Authenticated HTTP requests")
struct HTTPRequestBuilderTests {
    @Test func cookieScopeHonorsDomainPathExpiryAndSecureFlag() {
        let now = Date(timeIntervalSince1970: 1_000)
        let cookies = [
            HTTPCookieValue(
                name: "valid",
                value: "1",
                domain: ".example.com",
                path: "/video",
                isSecure: true,
                expiresDate: now.addingTimeInterval(60)
            ),
            HTTPCookieValue(
                name: "expired",
                value: "1",
                domain: "example.com",
                isSecure: false,
                expiresDate: now.addingTimeInterval(-1)
            ),
            HTTPCookieValue(
                name: "wrongPath",
                value: "1",
                domain: "example.com",
                path: "/account",
                isSecure: false
            ),
            HTTPCookieValue(
                name: "wrongDomain",
                value: "1",
                domain: "other.example",
                isSecure: false
            ),
        ]
        let url = URL(string: "https://cdn.example.com/video/segment.ts")!

        let header = HTTPRequestBuilder.cookieHeader(
            cookies: cookies,
            for: url,
            now: now
        )

        #expect(header?.contains("valid=1") == true)
        #expect(header?.contains("expired=1") == false)
        #expect(header?.contains("wrongPath=1") == false)
        #expect(header?.contains("wrongDomain=1") == false)
    }

    @Test func cookiePathRequiresAnRFCBoundary() {
        let cookie = HTTPCookieValue(
            name: "session",
            value: "abc",
            domain: "example.com",
            path: "/video",
            isSecure: false
        )

        #expect(
            HTTPRequestBuilder.cookieHeader(
                cookies: [cookie],
                for: URL(string: "https://example.com/video/1.ts")!
            ) != nil
        )
        #expect(
            HTTPRequestBuilder.cookieHeader(
                cookies: [cookie],
                for: URL(string: "https://example.com/videography/1.ts")!
            ) == nil
        )
    }

    @Test func secureCookiesAreNotSentOverHTTPAndExplicitHeaderWins() {
        let cookie = HTTPCookieValue(
            name: "session",
            value: "secret",
            domain: "example.com",
            isSecure: true
        )
        let insecure = URL(string: "http://example.com/video.m3u8")!
        #expect(
            HTTPRequestBuilder.cookieHeader(cookies: [cookie], for: insecure) == nil
        )

        let request = HTTPRequestBuilder.request(
            url: URL(string: "https://example.com/video.m3u8")!,
            headers: ["Cookie": "host=value"],
            cookies: [cookie]
        )
        #expect(request.value(forHTTPHeaderField: "Cookie") == "host=value")
    }
}
