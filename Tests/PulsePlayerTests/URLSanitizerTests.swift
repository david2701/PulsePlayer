import Foundation
import Testing
@testable import PulsePlayer

@Suite("URLSanitizer")
struct URLSanitizerTests {
    @Test func redactsQueryToken() throws {
        let url = try #require(URL(string: "https://cdn.example/v.m3u8?token=abc&x=1"))
        let s = URLSanitizer.sanitizeURL(url)
        // URLComponents may percent-encode angle brackets.
        #expect(s.contains("token=<redacted>") || s.contains("token=%3Credacted%3E"))
        #expect(s.contains("x=1"))
        #expect(!s.contains("token=abc"))
    }

    @Test func redactsAuthorizationHeader() {
        let out = URLSanitizer.sanitizeHeaders([
            "Authorization": "Bearer secret",
            "Accept": "application/json",
        ])
        #expect(out["Authorization"] == "<redacted>")
        #expect(out["Accept"] == "application/json")
    }

    @Test func redactsBearerInMessage() {
        let s = URLSanitizer.sanitizeMessage("error Bearer eyJhbGciOiJIUzI1NiJ9.xx")
        #expect(s.contains("<redacted>"))
        #expect(!s.contains("eyJhbGciOiJIUzI1NiJ9"))
    }
}
