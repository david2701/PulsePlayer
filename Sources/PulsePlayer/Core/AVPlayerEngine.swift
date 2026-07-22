import AVFoundation
import Foundation

/// Production engine: AVPlayer wrapper. Split via extensions for ≤400 lines.
@MainActor
final class AVPlayerEngine: PlaybackControlling, AVPlayerEngineUIBridging {
    let avPlayer: AVPlayer
    var onSignal: ((PlayerEngineSignal) -> Void)?

    private(set) var currentItem: AVPlayerItem?
    private(set) var configuration: PlayerConfiguration = .default
    var playerLayer: AVPlayerLayer?
    private var generation: UInt64 = 0

    // Shared with observation extensions (same module; not file-private).
    var itemStatusObs: NSKeyValueObservation?
    var bufferEmptyObs: NSKeyValueObservation?
    var keepUpObs: NSKeyValueObservation?
    var timeControlObs: NSKeyValueObservation?
    var externalPlaybackObs: NSKeyValueObservation?
    var readyForDisplayObs: NSKeyValueObservation?
    var endObserver: NSObjectProtocol?
    var failedObserver: NSObjectProtocol?
    var accessLogObserver: NSObjectProtocol?
    var timeObserver: Any?

    var lastIndicatedBps: Double?
    var lastObservedBps: Double?
    var lastEmittedTime: TimeInterval = -1

    init(player: AVPlayer = AVPlayer()) {
        self.avPlayer = player
        avPlayer.actionAtItemEnd = .pause
        installPlayerObservations()
    }

    func applyConfiguration(_ config: PlayerConfiguration) {
        configuration = config
        avPlayer.isMuted = config.isMuted
        avPlayer.allowsExternalPlayback = config.allowsExternalPlayback
        avPlayer.automaticallyWaitsToMinimizeStalling = config.automaticallyWaitsToMinimizeStalling
        applyItemConfiguration()
        reinstallTimeObserver()
    }

    func replaceCurrentItem(with source: MediaSource) async throws {
        generation &+= 1
        let gen = generation
        tearDownItemObservers()

        let asset = AssetFactory.makeURLAsset(from: source)
        let item = AVPlayerItem(asset: asset)
        currentItem = item
        applyItemConfiguration(to: item)

        if let preferred = source.preferredForwardBufferDuration {
            item.preferredForwardBufferDuration = preferred
        } else if configuration.preferredForwardBufferDuration > 0 {
            item.preferredForwardBufferDuration = configuration.preferredForwardBufferDuration
        }

        installItemObservers(item: item, generation: gen)
        avPlayer.replaceCurrentItem(with: item)

        // Kick asset readiness; KVO may also fire.
        do {
            let status = try await asset.load(.isPlayable)
            guard gen == generation else { return }
            if !status {
                emit(.itemFailed(
                    domain: "PulsePlayer",
                    code: -1,
                    message: "Asset not playable"
                ))
            }
        } catch {
            guard gen == generation else { return }
            let ns = error as NSError
            emit(.itemFailed(
                domain: ns.domain,
                code: ns.code,
                message: URLSanitizer.sanitizeMessage(ns.localizedDescription)
            ))
        }
    }

    func play() {
        avPlayer.play()
    }

    func pause() {
        avPlayer.pause()
    }

    func seek(to time: TimeInterval) async throws {
        let cm = CMTime(seconds: time, preferredTimescale: 600)
        await avPlayer.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setRate(_ rate: Float) {
        avPlayer.rate = rate
    }

    func setMuted(_ muted: Bool) {
        avPlayer.isMuted = muted
    }

    func setVolume(_ volume: Float) {
        avPlayer.volume = max(0, min(1, volume))
    }

    func currentTime() -> TimeInterval {
        let t = avPlayer.currentTime()
        return t.seconds.isFinite ? t.seconds : 0
    }

    func duration() -> TimeInterval? {
        guard let item = currentItem else { return nil }
        let d = item.duration
        guard d.isNumeric, d.seconds.isFinite, d.seconds > 0 else { return nil }
        return d.seconds
    }

    func tearDown() {
        generation &+= 1
        tearDownItemObservers()
        tearDownPlayerObservations()
        removeTimeObserver()
        avPlayer.replaceCurrentItem(with: nil)
        currentItem = nil
        playerLayer?.player = nil
        playerLayer = nil
        onSignal = nil
    }

    func attachPlayerLayer(_ layer: AVPlayerLayer?) {
        readyForDisplayObs?.invalidate()
        readyForDisplayObs = nil
        playerLayer = layer
        layer?.player = avPlayer
        guard let layer else { return }
        readyForDisplayObs = layer.observe(\.isReadyForDisplay, options: [.new, .initial]) {
            [weak self] layer, _ in
            let ready = layer.isReadyForDisplay
            Task { @MainActor in
                guard let self, ready else { return }
                self.emit(.readyForDisplay)
            }
        }
    }

    // MARK: - Internal helpers used by extensions

    func emit(_ signal: PlayerEngineSignal) {
        onSignal?(signal)
    }

    var currentGeneration: UInt64 { generation }

    func applyItemConfiguration(to item: AVPlayerItem? = nil) {
        let target = item ?? currentItem
        guard let target else { return }
        if configuration.preferredPeakBitRate > 0 {
            target.preferredPeakBitRate = configuration.preferredPeakBitRate
        } else {
            target.preferredPeakBitRate = 0
        }
        target.preferredMaximumResolution = configuration.preferredMaximumResolution
        target.canUseNetworkResourcesForLiveStreamingWhilePaused =
            configuration.canUseNetworkResourcesForLiveStreamingWhilePaused
        if configuration.preferredForwardBufferDuration > 0 {
            target.preferredForwardBufferDuration = configuration.preferredForwardBufferDuration
        }
    }
}
