import Foundation

public enum MediaTrackKind: String, Sendable, Equatable {
    case audio
    case text
}

/// Unified track descriptor (HLS embedded or external).
public struct MediaTrackInfo: Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public let kind: MediaTrackKind
    public let displayName: String
    public let languageCode: String?
    public let isExternal: Bool
    public let isSelected: Bool

    public init(
        id: String,
        kind: MediaTrackKind,
        displayName: String,
        languageCode: String? = nil,
        isExternal: Bool = false,
        isSelected: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.languageCode = languageCode
        self.isExternal = isExternal
        self.isSelected = isSelected
    }
}

public struct StreamQuality: Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public let bandwidth: Int
    public let width: Int?
    public let height: Int?
    /// Media playlist URL for hard quality lock (resolved absolute when possible).
    public let playlistURL: URL?

    public init(
        id: String,
        bandwidth: Int,
        width: Int? = nil,
        height: Int? = nil,
        playlistURL: URL? = nil
    ) {
        self.id = id
        self.bandwidth = bandwidth
        self.width = width
        self.height = height
        self.playlistURL = playlistURL
    }

    public var label: String {
        if let height { return "\(height)p" }
        if bandwidth >= 1_000_000 {
            return String(format: "%.1f Mbps", Double(bandwidth) / 1_000_000)
        }
        return "\(bandwidth / 1000) kbps"
    }

    public static let auto = StreamQuality(id: "auto", bandwidth: 0, playlistURL: nil)

    /// Soft ABR constraint only (no variant playlist reload).
    public var supportsHardLock: Bool { playlistURL != nil && id != StreamQuality.auto.id }
}

public struct AdCue: Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public let start: TimeInterval
    public let duration: TimeInterval?
    public let url: URL?

    public init(
        id: String = UUID().uuidString,
        start: TimeInterval,
        duration: TimeInterval? = nil,
        url: URL? = nil
    ) {
        self.id = id
        self.start = start
        self.duration = duration
        self.url = url
    }
}
