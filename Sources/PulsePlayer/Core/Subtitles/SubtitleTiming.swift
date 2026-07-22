import Foundation

enum SubtitleTiming {
    /// Parses `HH:MM:SS,mmm` / `HH:MM:SS.mmm` / `MM:SS.mmm`.
    static func parseTimestamp(_ raw: String) -> TimeInterval? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let parts = s.split(separator: ":").map(String.init)
        guard parts.count == 2 || parts.count == 3 else { return nil }

        let hours: Double
        let minutes: Double
        let seconds: Double
        if parts.count == 3 {
            guard let h = Double(parts[0]),
                  let m = Double(parts[1]),
                  let sec = Double(parts[2])
            else { return nil }
            hours = h
            minutes = m
            seconds = sec
        } else {
            guard let m = Double(parts[0]),
                  let sec = Double(parts[1])
            else { return nil }
            hours = 0
            minutes = m
            seconds = sec
        }
        return hours * 3600 + minutes * 60 + seconds
    }

    static func parseArrowLine(_ line: String) -> (TimeInterval, TimeInterval)? {
        // 00:00:01,000 --> 00:00:04,000
        // 00:00:01.000 --> 00:00:04.000 optional settings after
        let normalized = line.replacingOccurrences(of: "-->", with: " --> ")
        let tokens = normalized.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let arrow = tokens.firstIndex(of: "-->"),
              arrow > 0,
              arrow + 1 < tokens.count
        else { return nil }
        guard let start = parseTimestamp(tokens[arrow - 1]),
              let end = parseTimestamp(tokens[arrow + 1])
        else { return nil }
        return (start, end)
    }
}
