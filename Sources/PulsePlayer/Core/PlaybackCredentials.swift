import Foundation

/// Why PulsePlayer is asking the host for a fresh playback credential set.
public enum PlaybackCredentialRefreshReason: Sendable, Equatable {
    case initialLoad
    case expiring
    case unauthorized
    case manual
}

/// Headers and cookies returned by a ``PlaybackCredentialProviding`` implementation.
public struct PlaybackCredentials: Sendable, Equatable {
    public var headers: [String: String]
    public var cookies: [HTTPCookieValue]
    /// Optional proactive renewal delay. Values at or below zero renew immediately.
    public var refreshAfter: Duration?

    public init(
        headers: [String: String] = [:],
        cookies: [HTTPCookieValue] = [],
        refreshAfter: Duration? = nil
    ) {
        self.headers = headers
        self.cookies = cookies
        self.refreshAfter = refreshAfter
    }
}

/// Supplies short-lived playback credentials without putting token logic in the player UI.
public protocol PlaybackCredentialProviding: Sendable {
    func credentials(
        for source: MediaSource,
        reason: PlaybackCredentialRefreshReason
    ) async throws -> PlaybackCredentials
}
