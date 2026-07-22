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
    /// FairPlay content id (host-defined). Used with `ContentKeyProviding`.
    public var contentKeyAssetId: String?
    /// Optional mid-roll / custom ad markers (host-driven plugin).
    public var adCues: [AdCue]
    /// Optional DVR window hint in seconds (live). `nil` = use seekable range from engine.
    public var dvrWindow: TimeInterval?

    public init(
        id: String = UUID().uuidString,
        url: URL,
        headers: [String: String] = [:],
        cookies: [HTTPCookieValue] = [],
        isLive: Bool = false,
        preferredForwardBufferDuration: TimeInterval? = nil,
        posterURL: URL? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        contentKeyAssetId: String? = nil,
        adCues: [AdCue] = [],
        dvrWindow: TimeInterval? = nil
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
        self.contentKeyAssetId = contentKeyAssetId
        self.adCues = adCues
        self.dvrWindow = dvrWindow
    }

    /// Copy with a different stream URL (quality lock / unlock).
    public func replacingURL(_ url: URL) -> MediaSource {
        MediaSource(
            id: id,
            url: url,
            headers: headers,
            cookies: cookies,
            isLive: isLive,
            preferredForwardBufferDuration: preferredForwardBufferDuration,
            posterURL: posterURL,
            title: title,
            subtitle: subtitle,
            contentKeyAssetId: contentKeyAssetId,
            adCues: adCues,
            dvrWindow: dvrWindow
        )
    }
}
