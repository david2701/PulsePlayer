import Foundation

/// Describes media to load into a session.
public struct MediaSource: Sendable, Equatable, Identifiable {
    public let id: String
    public let url: URL
    /// Ordered alternate origins used after retry exhaustion.
    public var fallbackURLs: [URL]
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
    /// Requests acquisition/reuse of an offline-capable FairPlay key.
    public var requestsPersistableContentKey: Bool
    /// Optional mid-roll / custom ad markers (host-driven plugin).
    public var adCues: [AdCue]
    /// Native AVFoundation interstitial schedule. Empty keeps server-side HLS handling.
    public var interstitials: [InterstitialDescriptor]
    /// Chapters and skippable intro/recap/credits ranges.
    public var editorialMarkers: [EditorialMarker]
    /// Optional DVR window hint in seconds (live). `nil` = use seekable range from engine.
    public var dvrWindow: TimeInterval?

    public init(
        id: String = UUID().uuidString,
        url: URL,
        fallbackURLs: [URL] = [],
        headers: [String: String] = [:],
        cookies: [HTTPCookieValue] = [],
        isLive: Bool = false,
        preferredForwardBufferDuration: TimeInterval? = nil,
        posterURL: URL? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        contentKeyAssetId: String? = nil,
        requestsPersistableContentKey: Bool = false,
        adCues: [AdCue] = [],
        interstitials: [InterstitialDescriptor] = [],
        editorialMarkers: [EditorialMarker] = [],
        dvrWindow: TimeInterval? = nil
    ) {
        self.id = id
        self.url = url
        self.fallbackURLs = fallbackURLs.filter { $0 != url }
        self.headers = headers
        self.cookies = cookies
        self.isLive = isLive
        self.preferredForwardBufferDuration = preferredForwardBufferDuration
        self.posterURL = posterURL
        self.title = title
        self.subtitle = subtitle
        self.contentKeyAssetId = contentKeyAssetId
        self.requestsPersistableContentKey = requestsPersistableContentKey
        self.adCues = adCues
        self.interstitials = interstitials
        self.editorialMarkers = editorialMarkers.sorted { $0.start < $1.start }
        self.dvrWindow = dvrWindow
    }

    /// Source-compatible 1.0 initializer.
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
        self.init(
            id: id,
            url: url,
            fallbackURLs: [],
            headers: headers,
            cookies: cookies,
            isLive: isLive,
            preferredForwardBufferDuration: preferredForwardBufferDuration,
            posterURL: posterURL,
            title: title,
            subtitle: subtitle,
            contentKeyAssetId: contentKeyAssetId,
            requestsPersistableContentKey: false,
            adCues: adCues,
            interstitials: [],
            editorialMarkers: [],
            dvrWindow: dvrWindow
        )
    }

    /// Copy with a different stream URL (quality lock / unlock).
    public func replacingURL(_ url: URL) -> MediaSource {
        MediaSource(
            id: id,
            url: url,
            fallbackURLs: fallbackURLs.filter { $0 != url },
            headers: headers,
            cookies: cookies,
            isLive: isLive,
            preferredForwardBufferDuration: preferredForwardBufferDuration,
            posterURL: posterURL,
            title: title,
            subtitle: subtitle,
            contentKeyAssetId: contentKeyAssetId,
            requestsPersistableContentKey: requestsPersistableContentKey,
            adCues: adCues,
            interstitials: interstitials,
            editorialMarkers: editorialMarkers,
            dvrWindow: dvrWindow
        )
    }

    /// Copy with replacement request credentials.
    public func replacingCredentials(_ credentials: PlaybackCredentials) -> MediaSource {
        var copy = self
        copy.headers = credentials.headers
        copy.cookies = credentials.cookies
        return copy
    }
}
