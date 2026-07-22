import Foundation

/// Parses WebVTT (`.vtt`) text.
public enum VTTParser: Sendable {
    public static func parse(_ content: String) throws -> [SubtitleCue] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        // Drop WEBVTT header and optional metadata until first blank after header.
        if let first = lines.first, first.uppercased().hasPrefix("WEBVTT") {
            lines.removeFirst()
            while let head = lines.first, !head.trimmingCharacters(in: .whitespaces).isEmpty {
                // Skip NOTE / Style / Region headers at top.
                if head.uppercased().hasPrefix("NOTE")
                    || head.uppercased().hasPrefix("STYLE")
                    || head.uppercased().hasPrefix("REGION")
                {
                    lines.removeFirst()
                    while let more = lines.first, !more.isEmpty {
                        lines.removeFirst()
                    }
                    if lines.first?.isEmpty == true { lines.removeFirst() }
                    continue
                }
                // Other header metadata lines
                if SubtitleTiming.parseArrowLine(head) == nil {
                    lines.removeFirst()
                    continue
                }
                break
            }
        }

        let body = lines.joined(separator: "\n")
        let blocks = body.components(separatedBy: "\n\n")
        var cues: [SubtitleCue] = []

        for block in blocks {
            let rawLines = block
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { String($0) }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard !rawLines.isEmpty else { continue }
            if rawLines[0].uppercased().hasPrefix("NOTE") { continue }
            if rawLines[0].uppercased().hasPrefix("STYLE") { continue }
            if rawLines[0].uppercased().hasPrefix("REGION") { continue }

            var idx = 0
            // Optional cue identifier
            if SubtitleTiming.parseArrowLine(rawLines[0]) == nil {
                idx = 1
            }
            guard idx < rawLines.count,
                  let range = SubtitleTiming.parseArrowLine(rawLines[idx])
            else { continue }
            let textLines = Array(rawLines[(idx + 1)...])
            guard !textLines.isEmpty else { continue }
            let text = textLines
                .map(stripCueSettings)
                .joined(separator: "\n")
            cues.append(
                SubtitleCue(
                    start: range.0,
                    end: range.1,
                    text: stripTags(text)
                )
            )
        }

        if cues.isEmpty, content.uppercased().contains("WEBVTT") {
            // Empty VTT is valid.
            return []
        }
        if cues.isEmpty, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PlayerError.invalidSource("VTT parse produced no cues")
        }
        return cues.sorted { $0.start < $1.start }
    }

    private static func stripCueSettings(_ line: String) -> String {
        line
    }

    private static func stripTags(_ text: String) -> String {
        guard text.contains("<") else { return text }
        var result = ""
        var inside = false
        for ch in text {
            if ch == "<" { inside = true; continue }
            if ch == ">" { inside = false; continue }
            if !inside { result.append(ch) }
        }
        return result
    }
}
