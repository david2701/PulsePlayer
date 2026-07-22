import Foundation

/// Describes media to load into a session.
public struct MediaSource: Sendable, Equatable, Identifiable {
    public let id: String
    public let url: URL
    /// Applied to the *initial* AVURLAsset request only (see README / DESIGN §7).
    public var headers: [String: String]
    public var cookies: [HTTPCookieValue]
    /// When true, play-to-end does not enter `.ended`; duration may be nil.
    public var isLive: Bool
    public var preferredForwardBufferDuration: TimeInterval?
    public var posterURL: URL?
    public var title: String?
    public var subtitle: String?

    public init(
        id: String = UUID().uuidString,
        url: URL,
        headers: [String: String] = [:],
        cookies: [HTTPCookieValue] = [],
        isLive: Bool = false,
        preferredForwardBufferDuration: TimeInterval? = nil,
        posterURL: URL? = nil,
        title: String? = nil,
        subtitle: String? = nil
    ) {
        self.id = id
        self.url = url
        self.headers = headers
        self.cookies = cookies
        self.isLive = isLive
        self.preferredForwardBufferDuration = preferredForwardBufferDuration
        self.posterURL = posterURL
        self.title = title
        self.subtitle = subtitle
    }
}
