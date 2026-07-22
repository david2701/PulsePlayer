import Foundation

/// Parses SubRip (`.srt`) text.
public enum SRTParser: Sendable {
    public static func parse(_ content: String) throws -> [SubtitleCue] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var cues: [SubtitleCue] = []
        cues.reserveCapacity(blocks.count)

        for block in blocks {
            let lines = block
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard lines.count >= 2 else { continue }

            var idx = 0
            // Optional numeric index line
            if lines[0].allSatisfy(\.isNumber) {
                idx = 1
            }
            guard idx < lines.count else { continue }
            guard let range = SubtitleTiming.parseArrowLine(lines[idx]) else { continue }
            let textLines = Array(lines[(idx + 1)...])
            guard !textLines.isEmpty else { continue }
            let text = textLines.joined(separator: "\n")
            cues.append(
                SubtitleCue(
                    start: range.0,
                    end: range.1,
                    text: stripTags(text)
                )
            )
        }

        if cues.isEmpty, !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PlayerError.invalidSource("SRT parse produced no cues")
        }
        return cues.sorted { $0.start < $1.start }
    }

    private static func stripTags(_ text: String) -> String {
        // Minimal HTML-like tag strip for common SRT tags.
        guard text.contains("<") else { return text }
        var result = ""
        result.reserveCapacity(text.count)
        var inside = false
        for ch in text {
            if ch == "<" { inside = true; continue }
            if ch == ">" { inside = false; continue }
            if !inside { result.append(ch) }
        }
        return result
    }
}
