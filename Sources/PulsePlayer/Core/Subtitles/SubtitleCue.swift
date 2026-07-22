import Foundation

/// Timed subtitle line.
public struct SubtitleCue: Sendable, Equatable, Identifiable, Hashable {
    public var id: String
    public var start: TimeInterval
    public var end: TimeInterval
    public var text: String

    public init(
        id: String = UUID().uuidString,
        start: TimeInterval,
        end: TimeInterval,
        text: String
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }

    public func contains(_ time: TimeInterval) -> Bool {
        time >= start && time < end
    }
}
