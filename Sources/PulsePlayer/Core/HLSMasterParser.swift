import Foundation

/// Lightweight HLS master playlist parser for quality variants.
public enum HLSMasterParser: Sendable {
    public static func parseQualities(from masterPlaylist: String) -> [StreamQuality] {
        var qualities: [StreamQuality] = []
        let lines = masterPlaylist
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#EXT-X-STREAM-INF:") {
                let attrs = parseAttributes(String(line.dropFirst("#EXT-X-STREAM-INF:".count)))
                let bandwidth = Int(attrs["BANDWIDTH"] ?? attrs["AVERAGE-BANDWIDTH"] ?? "0") ?? 0
                var width: Int?
                var height: Int?
                if let res = attrs["RESOLUTION"] {
                    let parts = res.split(separator: "x")
                    if parts.count == 2 {
                        width = Int(parts[0])
                        height = Int(parts[1])
                    }
                }
                // Next non-empty non-tag line is URI (used as id seed).
                var uri = "variant-\(qualities.count)"
                var j = i + 1
                while j < lines.count {
                    let u = lines[j].trimmingCharacters(in: .whitespaces)
                    if u.isEmpty { j += 1; continue }
                    if u.hasPrefix("#") { break }
                    uri = u
                    break
                }
                qualities.append(
                    StreamQuality(
                        id: "\(bandwidth)-\(height ?? 0)-\(uri.hashValue)",
                        bandwidth: bandwidth,
                        width: width,
                        height: height
                    )
                )
            }
            i += 1
        }

        // Unique by height then bandwidth descending.
        var seen = Set<Int>()
        let sorted = qualities.sorted { $0.bandwidth > $1.bandwidth }
        var unique: [StreamQuality] = []
        for q in sorted {
            let key = q.height ?? q.bandwidth
            if seen.insert(key).inserted {
                unique.append(q)
            }
        }
        return unique
    }

    public static func fetchQualities(from masterURL: URL) async throws -> [StreamQuality] {
        let (data, response) = try await URLSession.shared.data(from: masterURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw PlayerError.assetLoadFailed(
                underlying: "HLS master HTTP \(http.statusCode)",
                recoverable: true
            )
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw PlayerError.invalidSource("Invalid HLS master playlist encoding")
        }
        return parseQualities(from: text)
    }

    private static func parseAttributes(_ raw: String) -> [String: String] {
        var result: [String: String] = [:]
        // Simple split respecting quoted values.
        var current = ""
        var key = ""
        var inQuotes = false
        var readingValue = false
        for ch in raw {
            if ch == "\"" {
                inQuotes.toggle()
                continue
            }
            if !inQuotes && ch == "=" {
                key = current.trimmingCharacters(in: .whitespaces)
                current = ""
                readingValue = true
                continue
            }
            if !inQuotes && ch == "," {
                if readingValue {
                    result[key] = current.trimmingCharacters(in: .whitespaces)
                }
                current = ""
                key = ""
                readingValue = false
                continue
            }
            current.append(ch)
        }
        if readingValue, !key.isEmpty {
            result[key] = current.trimmingCharacters(in: .whitespaces)
        }
        return result
    }
}
