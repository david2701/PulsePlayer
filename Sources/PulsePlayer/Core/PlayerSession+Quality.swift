import CoreGraphics
import Foundation

@MainActor
extension PlayerSession {
    public var selectedQuality: StreamQuality {
        if selectedQualityId == StreamQuality.auto.id { return .auto }
        return availableQualities.first { $0.id == selectedQualityId } ?? .auto
    }

    /// True when playback is forced to a single HLS media playlist (hard lock).
    public var isQualityHardLocked: Bool { qualityHardLocked }

    func refreshQualities(for source: MediaSource) async {
        availableQualities = []
        selectedQualityId = StreamQuality.auto.id
        qualityHardLocked = false
        qualityMasterURL = nil

        let path = source.url.path.lowercased()
        let isHLS = path.hasSuffix(".m3u8") || source.url.absoluteString.contains(".m3u8")
        guard isHLS else { return }

        qualityMasterURL = source.url
        do {
            let qualities = try await HLSMasterParser.fetchQualities(from: source.url)
            guard !Task.isCancelled else { return }
            availableQualities = qualities
            emit(.qualitiesUpdated(count: qualities.count))
        } catch {
            emit(.warning(URLSanitizer.sanitizeMessage(error.localizedDescription)))
        }
    }

    /// Select quality. Prefers **hard lock** (reload variant playlist) when `playlistURL` is known
    /// and `configuration.preferHardQualityLock` is true; always applies soft ABR caps.
    /// Concurrent calls are coalesced (latest wins).
    public func setQuality(_ quality: StreamQuality) async {
        selectedQualityId = quality.id
        applySoftConstraints(quality)
        emit(.qualityChanged(id: quality.id))

        qualityTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.applyHardLockIfNeeded(quality)
        }
        qualityTask = task
        await task.value
    }

    public func setQualityAuto() async {
        await setQuality(.auto)
    }

    // MARK: - Soft ABR caps

    func applySoftConstraints(_ quality: StreamQuality) {
        if quality.id == StreamQuality.auto.id {
            engine.setPreferredPeakBitRate(0)
            engine.setPreferredMaximumResolution(.zero)
            return
        }
        engine.setPreferredPeakBitRate(Double(quality.bandwidth))
        if let w = quality.width, let h = quality.height {
            engine.setPreferredMaximumResolution(CGSize(width: w, height: h))
        } else if let h = quality.height {
            engine.setPreferredMaximumResolution(CGSize(width: h * 16 / 9, height: h))
        }
    }

    // MARK: - Hard lock (variant playlist reload)

    func applyHardLockIfNeeded(_ quality: StreamQuality) async {
        guard status != .invalidated, currentSource != nil else { return }
        guard !Task.isCancelled else { return }

        if quality.id == StreamQuality.auto.id {
            guard qualityHardLocked, let master = qualityMasterURL else {
                qualityHardLocked = false
                return
            }
            await reloadForQuality(url: master, hardLocked: false)
            return
        }

        guard configuration.preferHardQualityLock,
              let variant = quality.playlistURL
        else { return }

        if currentSource?.url.absoluteString == variant.absoluteString {
            qualityHardLocked = true
            return
        }

        await reloadForQuality(url: variant, hardLocked: true)
    }

    func reloadForQuality(url: URL, hardLocked: Bool) async {
        guard let current = currentSource else { return }
        guard !Task.isCancelled else { return }

        let resumeTime = playbackTime
        let resumePlay = wantsPlaying || isPlaying
        let ladder = availableQualities
        let selected = selectedQualityId
        let master = qualityMasterURL ?? current.url
        let next = current.replacingURL(url)

        // Do not cancel qualityTask (we're inside it). Cancel other load work only.
        loadTask?.cancel()
        loadTask = nil
        startupTask?.cancel()
        startupTask = nil
        stallTask?.cancel()
        stallTask = nil
        autoRetryTask?.cancel()
        autoRetryTask = nil

        loadGeneration &+= 1
        let gen = loadGeneration
        isQualityReload = true
        currentError = nil
        scrubPreviewImage = nil
        wasAtLiveEdge = false
        // Keep didEmitFirstFrame / TTFF from the primary load cycle.
        currentSource = next
        qualityHardLocked = hardLocked
        qualityMasterURL = master
        availableQualities = ladder
        selectedQualityId = selected
        wantsPlaying = resumePlay
        metrics.qualitySwitchCount += 1

        _ = apply(.load, isLive: next.isLive)
        // Soft event — hosts can ignore when switching quality.
        emit(.warning("quality-reload:\(hardLocked ? "lock" : "unlock")"))
        startStartupWatchdog(generation: gen)

        do {
            try await engine.replaceCurrentItem(with: next)
            guard gen == loadGeneration, !Task.isCancelled else { return }
            if resumeTime > 0.25 {
                try await engine.seek(to: resumeTime)
                playbackTime = engine.currentTime()
            }
            applySoftConstraints(selectedQuality)
            isQualityReload = false
            emitMetricsSnapshot()
        } catch is CancellationError {
            isQualityReload = false
            return
        } catch {
            isQualityReload = false
            guard gen == loadGeneration else { return }
            let ns = error as NSError
            fail(with: .assetLoadFailed(
                underlying: URLSanitizer.sanitizeMessage(ns.localizedDescription),
                recoverable: true
            ))
        }
    }
}
