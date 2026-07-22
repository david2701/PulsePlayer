import Foundation

@MainActor
extension PlayerSession {
    /// Seek to absolute media time (seconds). Updates `playbackTime` immediately for UI.
    public func seek(to time: TimeInterval) async {
        guard status != .invalidated, status != .idle else { return }
        // Allow scrub while loading finishes; clamp when duration known.
        let upper = playbackDuration ?? engine.duration() ?? .greatestFiniteMagnitude
        let target = min(max(0, time), max(0, upper))
        isSeeking = true
        playbackTime = target
        defer { isSeeking = false }

        do {
            try await engine.seek(to: target)
            let actual = engine.currentTime()
            playbackTime = actual
            emit(.seekCompleted(time: actual))
            refreshSubtitles(at: actual)
            if status == .ended {
                _ = apply(.pause)
            }
            refreshNowPlaying()
        } catch is CancellationError {
            return
        } catch {
            emit(.warning(URLSanitizer.sanitizeMessage(error.localizedDescription)))
        }
    }

    public func seek(relative delta: TimeInterval) async {
        let base = isSeeking ? playbackTime : engine.currentTime()
        await seek(to: base + delta)
    }

    /// Begin interactive scrub (UI holds value; call `seek(to:)` / `endScrub` to commit).
    public func beginScrub() {
        isSeeking = true
    }

    public func updateScrub(time: TimeInterval) {
        isSeeking = true
        playbackTime = max(0, time)
        refreshSubtitles(at: playbackTime)
    }

    public func endScrub(commit time: TimeInterval) async {
        await seek(to: time)
    }
}
