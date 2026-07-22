import Foundation

public enum SubtitleFormat: String, Sendable, Equatable, CaseIterable {
    case srt
    case vtt

    public static func detect(from url: URL) -> SubtitleFormat? {
        switch url.pathExtension.lowercased() {
        case "srt": return .srt
        case "vtt", "webvtt": return .vtt
        default: return nil
        }
    }

    public static func detect(from content: String) -> SubtitleFormat {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("WEBVTT") { return .vtt }
        return .srt
    }
}
