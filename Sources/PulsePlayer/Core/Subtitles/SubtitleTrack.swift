import Foundation

/// External subtitle track attached to a session.
public struct SubtitleTrack: Sendable, Equatable, Identifiable, Hashable {
    public let id: String
    public var languageCode: String?
    public var label: String?
    public var format: SubtitleFormat
    public var sourceURL: URL?
    /// Applied when resolving active cues: `mediaTime + offset`.
    public var offset: TimeInterval
    public var cues: [SubtitleCue]

    public init(
        id: String = UUID().uuidString,
        languageCode: String? = nil,
        label: String? = nil,
        format: SubtitleFormat,
        sourceURL: URL? = nil,
        offset: TimeInterval = 0,
        cues: [SubtitleCue]
    ) {
        self.id = id
        self.languageCode = languageCode
        self.label = label
        self.format = format
        self.sourceURL = sourceURL
        self.offset = offset
        self.cues = cues
    }
}
