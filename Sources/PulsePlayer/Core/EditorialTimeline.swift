import Foundation

public enum EditorialMarkerKind: String, Sendable, Equatable, Codable {
    case chapter
    case intro
    case recap
    case credits
}

/// A chapter or skippable editorial range in the primary media timeline.
public struct EditorialMarker: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public var kind: EditorialMarkerKind
    public var title: String
    public var start: TimeInterval
    public var end: TimeInterval

    public init(
        id: String = UUID().uuidString,
        kind: EditorialMarkerKind,
        title: String,
        start: TimeInterval,
        end: TimeInterval
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.start = max(0, start)
        self.end = max(self.start, end)
    }

    public var isSkippable: Bool {
        kind == .intro || kind == .recap || kind == .credits
    }

    public func contains(_ time: TimeInterval) -> Bool {
        time >= start && time < end
    }
}

/// Metadata and source for an in-player “Up Next” proposal.
public struct NextContentProposal: Sendable, Equatable, Identifiable {
    public let id: String
    public var sourceURL: URL
    public var title: String
    public var subtitle: String?
    public var previewImageURL: URL?
    public var headers: [String: String]
    public var cookies: [HTTPCookieValue]
    public var automaticAcceptanceInterval: TimeInterval?

    public init(
        id: String = UUID().uuidString,
        sourceURL: URL,
        title: String,
        subtitle: String? = nil,
        previewImageURL: URL? = nil,
        headers: [String: String] = [:],
        cookies: [HTTPCookieValue] = [],
        automaticAcceptanceInterval: TimeInterval? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.title = title
        self.subtitle = subtitle
        self.previewImageURL = previewImageURL
        self.headers = headers
        self.cookies = cookies
        self.automaticAcceptanceInterval = automaticAcceptanceInterval
    }

    public var mediaSource: MediaSource {
        MediaSource(
            id: id,
            url: sourceURL,
            headers: headers,
            cookies: cookies,
            posterURL: previewImageURL,
            title: title,
            subtitle: subtitle
        )
    }
}
