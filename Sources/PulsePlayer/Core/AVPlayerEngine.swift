import AVFoundation
import Foundation

/// Production engine: AVPlayer wrapper. Split via extensions for ≤400 lines.
@MainActor
final class AVPlayerEngine: ManagedPlaybackControlling, AVPlayerEngineUIBridging {
    let avPlayer: AVPlayer
    var onSignal: ((PlayerEngineSignal) -> Void)?
    var onProductionSignal: ((ProductionEngineSignal) -> Void)?

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
    var errorLogObserver: NSObjectProtocol?
    var timeObserver: Any?
    var interstitialMonitor: AVPlayerInterstitialEventMonitor?
    var interstitialController: AVPlayerInterstitialEventController?
    var interstitialObservers: [NSObjectProtocol] = []
    var interstitialTimeObserver: Any?
    var interstitialDescriptorByID: [String: InterstitialDescriptor] = [:]

    var lastIndicatedBps: Double?
    var lastObservedBps: Double?
    var lastEmittedTime: TimeInterval = -1
    var lastBufferProgress: Double?
    var hasEmittedBufferProgress = false

    /// id → AVMediaSelectionOption for current item
    var audioOptionById: [String: AVMediaSelectionOption] = [:]
    var textOptionById: [String: AVMediaSelectionOption] = [:]
    var audioSelectionGroup: AVMediaSelectionGroup?
    var textSelectionGroup: AVMediaSelectionGroup?
    var fairPlayLoader: FairPlayContentKeyLoader?
    var thumbnailGenerator = ThumbnailGenerator()
    var contentKeyProvider: (any ContentKeyProviding)?
    var persistableContentKeyStore: (any PersistableContentKeyStoring)?
    var logHandler: any PulsePlayerLogHandler = DefaultPulsePlayerLogHandler()

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

    func setLogHandler(_ handler: any PulsePlayerLogHandler) {
        logHandler = handler
    }

    func replaceCurrentItem(with source: MediaSource) async throws {
        generation &+= 1
        let gen = generation
        clearCurrentItemResources(replacingPlayerItem: false)

        let asset = AssetFactory.makeURLAsset(from: source)

        if let provider = contentKeyProvider {
            let assetId = source.contentKeyAssetId ?? source.id
            let loader = FairPlayContentKeyLoader(
                provider: provider,
                assetId: assetId,
                persistableStore: source.requestsPersistableContentKey
                    ? persistableContentKeyStore
                    : nil,
                logHandler: logHandler
            )
            loader.onPersistableKeyStored = { [weak self] assetID in
                self?.emitProduction(.persistableContentKeyStored(assetID: assetID))
            }
            loader.attach(to: asset)
            fairPlayLoader = loader
        }

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
        configureInterstitials(for: source, primaryItem: item, generation: gen)
        thumbnailGenerator.prepare(asset: asset)

        do {
            let playable = try await asset.load(.isPlayable)
            try Task.checkCancellation()
            guard gen == generation else {
                throw CancellationError()
            }
            guard playable else {
                throw PlayerError.invalidSource("Asset is not playable")
            }
            await refreshTrackMaps(asset: asset, item: item)
        } catch {
            guard gen == generation else { throw CancellationError() }
            clearCurrentItem()
            throw error
        }
    }

    func clearCurrentItem() {
        generation &+= 1
        clearCurrentItemResources(replacingPlayerItem: true)
    }

    private func clearCurrentItemResources(replacingPlayerItem: Bool) {
        tearDownItemObservers()
        fairPlayLoader?.tearDown()
        fairPlayLoader = nil
        audioOptionById = [:]
        textOptionById = [:]
        audioSelectionGroup = nil
        textSelectionGroup = nil
        thumbnailGenerator.clear()
        tearDownInterstitials()
        lastIndicatedBps = nil
        lastObservedBps = nil
        lastBufferProgress = nil
        hasEmittedBufferProgress = false
        if replacingPlayerItem {
            avPlayer.replaceCurrentItem(with: nil)
            currentItem = nil
        }
    }

    func play() {
        avPlayer.play()
    }

    func pause() {
        avPlayer.pause()
    }

    func cancelPendingSeeks() {
        currentItem?.cancelPendingSeeks()
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
        clearCurrentItemResources(replacingPlayerItem: true)
        tearDownPlayerObservations()
        removeTimeObserver()
        playerLayer?.player = nil
        playerLayer = nil
        onSignal = nil
        onProductionSignal = nil
    }

    func audioTracks() -> [MediaTrackInfo] {
        buildTrackInfos(kind: .audio, map: audioOptionById)
    }

    func textTracks() -> [MediaTrackInfo] {
        buildTrackInfos(kind: .text, map: textOptionById)
    }

    func selectAudioTrack(id: String?) {
        select(optionId: id, map: audioOptionById, characteristic: .audible)
    }

    func selectTextTrack(id: String?) {
        select(optionId: id, map: textOptionById, characteristic: .legible)
    }

    func setPreferredPeakBitRate(_ bps: Double) {
        configuration.preferredPeakBitRate = bps
        currentItem?.preferredPeakBitRate = bps
    }

    func setPreferredMaximumResolution(_ size: CGSize) {
        configuration.preferredMaximumResolution = size
        currentItem?.preferredMaximumResolution = size
    }

    func seekableTimeRange() -> ClosedRange<TimeInterval>? {
        guard let range = currentItem?.seekableTimeRanges
            .compactMap({ $0.timeRangeValue })
            .max(by: { $0.duration.seconds < $1.duration.seconds })
        else { return nil }
        let start = range.start.seconds
        let end = start + range.duration.seconds
        guard start.isFinite, end.isFinite, end > start else { return nil }
        return start...end
    }

    func thumbnail(at time: TimeInterval) async -> CGImage? {
        await thumbnailGenerator.image(at: time)
    }

    func prepareThumbnailGenerator() {
        guard let asset = currentItem?.asset as? AVURLAsset else { return }
        thumbnailGenerator.prepare(asset: asset)
    }

    func cancelThumbnailGeneration() {
        thumbnailGenerator.cancelPending()
    }

    func skipCurrentInterstitial() {
        guard let controller = interstitialController, controller.currentEvent != nil else { return }
        if #available(iOS 26, tvOS 26, macOS 26, *) {
            controller.skipCurrentEvent()
        } else {
            controller.cancelCurrentEvent(withResumptionOffset: .invalid)
        }
    }

    private func buildTrackInfos(
        kind: MediaTrackKind,
        map: [String: AVMediaSelectionOption]
    ) -> [MediaTrackInfo] {
        guard let item = currentItem else { return [] }
        let group = kind == .audio ? audioSelectionGroup : textSelectionGroup
        guard let group else { return [] }
        let selected = item.currentMediaSelection.selectedMediaOption(in: group)
        return map.map { id, option in
            MediaTrackInfo(
                id: id,
                kind: kind,
                displayName: option.displayName,
                languageCode: option.extendedLanguageTag,
                isExternal: false,
                isSelected: option == selected
            )
        }
        .sorted { $0.displayName < $1.displayName }
    }

    private func select(
        optionId: String?,
        map: [String: AVMediaSelectionOption],
        characteristic: AVMediaCharacteristic
    ) {
        guard let item = currentItem else { return }
        let group = characteristic == .audible ? audioSelectionGroup : textSelectionGroup
        guard let group else { return }
        if let optionId, let option = map[optionId] {
            item.select(option, in: group)
        } else {
            item.select(nil, in: group)
        }
    }

    private func refreshTrackMaps(asset: AVURLAsset, item: AVPlayerItem) async {
        audioOptionById = [:]
        textOptionById = [:]
        do {
            audioSelectionGroup = try await asset.loadMediaSelectionGroup(for: .audible)
        } catch is CancellationError {
            return
        } catch {
            logHandler.log(
                level: .debug,
                message: "Audio-track discovery unavailable: \(error.localizedDescription)"
            )
        }
        do {
            textSelectionGroup = try await asset.loadMediaSelectionGroup(for: .legible)
        } catch is CancellationError {
            return
        } catch {
            logHandler.log(
                level: .debug,
                message: "Text-track discovery unavailable: \(error.localizedDescription)"
            )
        }
        if let audioGroup = audioSelectionGroup {
            for (idx, option) in audioGroup.options.enumerated() {
                let id = "audio-\(option.extendedLanguageTag ?? option.displayName)-\(idx)"
                audioOptionById[id] = option
            }
        }
        if let textGroup = textSelectionGroup {
            for (idx, option) in textGroup.options.enumerated() {
                let id = "text-\(option.extendedLanguageTag ?? option.displayName)-\(idx)"
                textOptionById[id] = option
            }
        }
        _ = item
    }

    func attachPlayerLayer(_ layer: AVPlayerLayer?) {
        guard playerLayer !== layer else {
            if layer?.player !== avPlayer {
                layer?.player = avPlayer
            }
            return
        }
        readyForDisplayObs?.invalidate()
        readyForDisplayObs = nil
        playerLayer?.player = nil
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

    func emitProduction(_ signal: ProductionEngineSignal) {
        onProductionSignal?(signal)
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
        if let livePolicy = configuration.liveLatencyPolicy {
            target.configuredTimeOffsetFromLive = CMTime(
                seconds: livePolicy.targetLatency,
                preferredTimescale: 600
            )
            target.automaticallyPreservesTimeOffsetFromLive = true
        } else {
            target.configuredTimeOffsetFromLive = .invalid
            target.automaticallyPreservesTimeOffsetFromLive = false
        }
        if configuration.preferredForwardBufferDuration > 0 {
            target.preferredForwardBufferDuration = configuration.preferredForwardBufferDuration
        }
    }
}
