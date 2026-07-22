import Foundation

@MainActor
extension PlayerSession {
    /// Embedded + external audio tracks.
    public var availableAudioTracks: [MediaTrackInfo] {
        engine.audioTracks()
    }

    /// Embedded text tracks + external subtitle tracks (unified).
    public var availableTextTracks: [MediaTrackInfo] {
        let embedded = engine.textTracks()
        let external = subtitleTracks.map { track in
            MediaTrackInfo(
                id: "ext-\(track.id)",
                kind: .text,
                displayName: track.label ?? track.languageCode ?? track.id,
                languageCode: track.languageCode,
                isExternal: true,
                isSelected: activeSubtitleTrackID == track.id
            )
        }
        return embedded + external
    }

    public func selectAudioTrack(id: String?) {
        engine.selectAudioTrack(id: id)
        emit(.audioTrackChanged(id: id))
    }

    public func selectTextTrack(id: String?) {
        if let id, id.hasPrefix("ext-") {
            let externalId = String(id.dropFirst(4))
            engine.selectTextTrack(id: nil)
            selectSubtitle(id: externalId)
            return
        }
        // Embedded legible track — clear external overlay selection.
        selectSubtitle(id: nil)
        engine.selectTextTrack(id: id)
        emit(.textTrackChanged(id: id))
    }
}
