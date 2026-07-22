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
            availableQualities = qualities
            emit(.qualitiesUpdated(count: qualities.count))
        } catch {
            emit(.warning(URLSanitizer.sanitizeMessage(error.localizedDescription)))
        }
    }

    /// Select quality. Prefers **hard lock** (reload variant playlist) when `playlistURL` is known
    /// and `configuration.preferHardQualityLock` is true; always applies soft ABR caps.
    public func setQuality(_ quality: StreamQuality) async {
        selectedQualityId = quality.id
        applySoftConstraints(quality)
        emit(.qualityChanged(id: quality.id))
        await applyHardLockIfNeeded(quality)
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

        let resumeTime = playbackTime
        let resumePlay = wantsPlaying || isPlaying
        let ladder = availableQualities
        let selected = selectedQualityId
        let master = qualityMasterURL ?? current.url
        let next = current.replacingURL(url)

        cancelLoadWork()
        loadGeneration &+= 1
        let gen = loadGeneration
        currentError = nil
        scrubPreviewImage = nil
        wasAtLiveEdge = false
        currentSource = next
        qualityHardLocked = hardLocked
        qualityMasterURL = master
        availableQualities = ladder
        selectedQualityId = selected
        wantsPlaying = resumePlay

        _ = apply(.load, isLive: next.isLive)
        emit(.loadStarted(sourceID: next.id))
        startStartupWatchdog(generation: gen)

        do {
            try await engine.replaceCurrentItem(with: next)
            guard gen == loadGeneration else { return }
            if resumeTime > 0.25 {
                try await engine.seek(to: resumeTime)
                playbackTime = engine.currentTime()
            }
            applySoftConstraints(selectedQuality)
        } catch is CancellationError {
            return
        } catch {
            guard gen == loadGeneration else { return }
            let ns = error as NSError
            fail(with: .assetLoadFailed(
                underlying: URLSanitizer.sanitizeMessage(ns.localizedDescription),
                recoverable: true
            ))
        }
    }
}
