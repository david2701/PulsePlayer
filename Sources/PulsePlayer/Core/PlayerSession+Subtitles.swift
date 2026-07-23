import Foundation

@MainActor
extension PlayerSession {
    /// Source-compatible 1.0 subtitle loader.
    @discardableResult
    public func addSubtitle(
        from url: URL,
        id: String = UUID().uuidString,
        languageCode: String? = nil,
        label: String? = nil,
        format: SubtitleFormat? = nil,
        offset: TimeInterval = 0,
        select: Bool = true
    ) async throws -> SubtitleTrack {
        try await addSubtitle(
            from: url,
            id: id,
            languageCode: languageCode,
            label: label,
            format: format,
            offset: offset,
            select: select,
            headers: [:],
            cookies: []
        )
    }

    /// Load and parse a remote or local subtitle file, then optionally select it.
    @discardableResult
    public func addSubtitle(
        from url: URL,
        id: String = UUID().uuidString,
        languageCode: String? = nil,
        label: String? = nil,
        format: SubtitleFormat? = nil,
        offset: TimeInterval = 0,
        select: Bool = true,
        headers: [String: String] = [:],
        cookies: [HTTPCookieValue] = []
    ) async throws -> SubtitleTrack {
        let detected = format ?? SubtitleFormat.detect(from: url)
        let parsed = try await SubtitleResourceLoader.loadAndParse(
            url: url,
            format: detected,
            headers: headers,
            cookies: cookies
        )
        let track = SubtitleTrack(
            id: id,
            languageCode: languageCode,
            label: label ?? languageCode ?? url.lastPathComponent,
            format: parsed.format,
            sourceURL: url,
            offset: offset,
            cues: parsed.cues
        )
        upsertTrack(track)
        if select {
            selectSubtitle(id: track.id)
        }
        return track
    }

    /// Parse from in-memory text.
    @discardableResult
    public func addSubtitle(
        content: String,
        id: String = UUID().uuidString,
        languageCode: String? = nil,
        label: String? = nil,
        format: SubtitleFormat? = nil,
        offset: TimeInterval = 0,
        select: Bool = true
    ) throws -> SubtitleTrack {
        let parsed = try SubtitleParser.parse(content: content, format: format)
        let track = SubtitleTrack(
            id: id,
            languageCode: languageCode,
            label: label ?? languageCode,
            format: parsed.format,
            sourceURL: nil,
            offset: offset,
            cues: parsed.cues
        )
        upsertTrack(track)
        if select {
            selectSubtitle(id: track.id)
        }
        return track
    }

    public func selectSubtitle(id: String?) {
        if let id, !subtitleTracks.contains(where: { $0.id == id }) {
            emit(.warning("Unknown subtitle track \(id)"))
            return
        }
        activeSubtitleTrackID = id
        emit(.subtitleTrackChanged(id: id))
        refreshSubtitles(at: engine.currentTime())
    }

    public func setSubtitleOffset(_ offset: TimeInterval, trackID: String? = nil) {
        let targetID = trackID ?? activeSubtitleTrackID
        guard let targetID,
              let idx = subtitleTracks.firstIndex(where: { $0.id == targetID })
        else { return }
        subtitleTracks[idx].offset = offset
        refreshSubtitles(at: engine.currentTime())
    }

    public func removeSubtitle(id: String) {
        subtitleTracks.removeAll { $0.id == id }
        if activeSubtitleTrackID == id {
            activeSubtitleTrackID = nil
            currentSubtitleText = nil
            emit(.subtitleTrackChanged(id: nil))
        }
    }

    public func clearSubtitles() {
        subtitleTracks = []
        activeSubtitleTrackID = nil
        currentSubtitleText = nil
    }

    public func setSubtitlesEnabled(_ enabled: Bool) {
        subtitlesEnabled = enabled
        if !enabled {
            currentSubtitleText = nil
        } else {
            refreshSubtitles(at: playbackTime)
        }
    }

    public func applySubtitleStyle(_ style: SubtitleStyle) {
        subtitleStyle = style
    }

    func refreshSubtitles(at mediaTime: TimeInterval) {
        guard subtitlesEnabled,
              let id = activeSubtitleTrackID,
              let track = subtitleTracks.first(where: { $0.id == id })
        else {
            if currentSubtitleText != nil {
                currentSubtitleText = nil
            }
            return
        }
        let text = SubtitlePresenter.activeText(in: track, mediaTime: mediaTime)
        if text != currentSubtitleText {
            currentSubtitleText = text
        }
    }

    private func upsertTrack(_ track: SubtitleTrack) {
        if let idx = subtitleTracks.firstIndex(where: { $0.id == track.id }) {
            subtitleTracks[idx] = track
        } else {
            subtitleTracks.append(track)
        }
    }
}

private enum SubtitleResourceLoader {
    private static let maximumBytes = 10 * 1_024 * 1_024

    @concurrent
    static func loadAndParse(
        url: URL,
        format: SubtitleFormat?,
        headers: [String: String],
        cookies: [HTTPCookieValue]
    ) async throws -> (format: SubtitleFormat, cues: [SubtitleCue]) {
        let data: Data
        if url.isFileURL {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = values.fileSize, size > maximumBytes {
                throw PlayerError.invalidSource("Subtitle file exceeds 10 MB")
            }
            data = try Data(contentsOf: url, options: [.mappedIfSafe])
        } else {
            var request = HTTPRequestBuilder.request(
                url: url,
                headers: headers,
                cookies: cookies
            )
            request.timeoutInterval = 30
            let (bytes, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                guard (200...299).contains(http.statusCode) else {
                    throw PlayerError.itemFailed(
                        domain: "HTTP",
                        code: http.statusCode,
                        message: "Subtitle HTTP \(http.statusCode)",
                        recoverable: http.statusCode == 408
                            || http.statusCode == 429
                            || http.statusCode >= 500
                    )
                }
                if let length = http.value(forHTTPHeaderField: "Content-Length"),
                   let size = Int(length),
                   size > maximumBytes
                {
                    throw PlayerError.invalidSource("Subtitle response exceeds 10 MB")
                }
            }
            data = bytes
        }
        guard data.count <= maximumBytes else {
            throw PlayerError.invalidSource("Subtitle data exceeds 10 MB")
        }
        try Task.checkCancellation()
        return try SubtitleParser.parse(data: data, format: format)
    }
}
