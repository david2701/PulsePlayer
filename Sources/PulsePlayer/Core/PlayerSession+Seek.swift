import Foundation

@MainActor
extension PlayerSession {
    /// Seek to absolute media time (seconds). Updates `playbackTime` immediately for UI.
    public func seek(to time: TimeInterval) async {
        guard status != .invalidated, status != .idle else { return }
        seekGeneration &+= 1
        let generation = seekGeneration
        (engine as? any ManagedPlaybackControlling)?.cancelPendingSeeks()
        let upper = playbackDuration ?? engine.duration() ?? .greatestFiniteMagnitude
        var target = min(max(0, time), max(0, upper))
        target = clampLiveSeek(target)
        isSeeking = true
        playbackTime = target
        defer {
            if generation == seekGeneration {
                isSeeking = false
            }
        }

        do {
            try await engine.seek(to: target)
            guard generation == seekGeneration, !Task.isCancelled else { return }
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
        playbackTime = clampLiveSeek(max(0, time))
        refreshSubtitles(at: playbackTime)
        thumbnailTask?.cancel()
        (engine as? any ManagedPlaybackControlling)?.cancelThumbnailGeneration()
        thumbnailGeneration &+= 1
        let generation = thumbnailGeneration
        let t = playbackTime
        thumbnailTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            let image = await self.engine.thumbnail(at: t)
            guard !Task.isCancelled, generation == self.thumbnailGeneration else { return }
            self.scrubPreviewImage = image
        }
    }

    public func endScrub(commit time: TimeInterval) async {
        thumbnailTask?.cancel()
        thumbnailTask = nil
        (engine as? any ManagedPlaybackControlling)?.cancelThumbnailGeneration()
        thumbnailGeneration &+= 1
        scrubPreviewImage = nil
        await seek(to: time)
    }
}
