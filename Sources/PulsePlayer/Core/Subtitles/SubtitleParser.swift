import Foundation

public enum SubtitleParser: Sendable {
    public static func parse(
        content: String,
        format: SubtitleFormat? = nil
    ) throws -> (format: SubtitleFormat, cues: [SubtitleCue]) {
        let resolved = format ?? SubtitleFormat.detect(from: content)
        switch resolved {
        case .srt:
            return (.srt, try SRTParser.parse(content))
        case .vtt:
            return (.vtt, try VTTParser.parse(content))
        }
    }

    public static func parse(
        data: Data,
        format: SubtitleFormat? = nil
    ) throws -> (format: SubtitleFormat, cues: [SubtitleCue]) {
        guard let content = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
        else {
            throw PlayerError.invalidSource("Subtitle data is not valid UTF-8/UTF-16 text")
        }
        return try parse(content: content, format: format)
    }
}

/// Resolves active cues at media time + track offset.
public enum SubtitlePresenter: Sendable {
    public static func activeCues(
        in track: SubtitleTrack,
        mediaTime: TimeInterval
    ) -> [SubtitleCue] {
        let t = mediaTime + track.offset
        // Linear scan is fine for typical subtitle counts; binary search possible later.
        return track.cues.filter { $0.contains(t) }
    }

    public static func activeText(
        in track: SubtitleTrack,
        mediaTime: TimeInterval
    ) -> String? {
        let cues = activeCues(in: track, mediaTime: mediaTime)
        guard !cues.isEmpty else { return nil }
        return cues.map(\.text).joined(separator: "\n")
    }
}
