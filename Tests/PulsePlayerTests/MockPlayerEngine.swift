import CoreGraphics
import Foundation
@testable import PulsePlayer

/// Test double: no AVPlayer, no network.
@MainActor
final class MockPlayerEngine: ManagedPlaybackControlling {
    var onSignal: ((PlayerEngineSignal) -> Void)?
    var onProductionSignal: ((ProductionEngineSignal) -> Void)?

    private(set) var configuration = PlayerConfiguration.default
    private(set) var source: MediaSource?
    private(set) var isPlaying = false
    private(set) var rate: Float = 1
    private(set) var muted = false
    private(set) var volume: Float = 1
    private var _currentTime: TimeInterval = 0
    private var _duration: TimeInterval? = 120
    private(set) var replaceCount = 0
    private(set) var clearCount = 0
    private(set) var cancelSeekCount = 0
    private(set) var cancelThumbnailCount = 0
    private(set) var tearDownCount = 0
    private(set) var skipInterstitialCount = 0
    var replaceError: Error?
    var replaceErrorByURL: [URL: Error] = [:]
    var autoReady = true
    var replaceDelayByURL: [URL: Duration] = [:]
    var seekDelayByTime: [TimeInterval: Duration] = [:]
    var peakBitRate: Double = 0
    var maxResolution: CGSize = .zero
    var mockAudio: [MediaTrackInfo] = []
    var mockText: [MediaTrackInfo] = []
    var seekable: ClosedRange<TimeInterval>? = 0...120
    private var replaceGeneration: UInt64 = 0
    private var seekGeneration: UInt64 = 0

    func applyConfiguration(_ config: PlayerConfiguration) {
        configuration = config
        muted = config.isMuted
    }

    func setLogHandler(_ handler: any PulsePlayerLogHandler) {
        _ = handler
    }

    func replaceCurrentItem(with source: MediaSource) async throws {
        replaceCount += 1
        replaceGeneration &+= 1
        let generation = replaceGeneration
        if let delay = replaceDelayByURL[source.url] {
            try await Task.sleep(for: delay)
        }
        try Task.checkCancellation()
        guard generation == replaceGeneration else {
            throw CancellationError()
        }
        if let replaceError = replaceErrorByURL[source.url] ?? replaceError {
            throw replaceError
        }
        self.source = source
        _currentTime = 0
        if autoReady {
            onSignal?(.itemStatusReady)
            onSignal?(.durationKnown(_duration))
            onSignal?(.bufferHealthy)
        }
    }

    func clearCurrentItem() {
        clearCount += 1
        replaceGeneration &+= 1
        seekGeneration &+= 1
        source = nil
        _currentTime = 0
        isPlaying = false
    }

    func play() {
        isPlaying = true
        onSignal?(.timeControlPlaying)
    }

    func pause() {
        isPlaying = false
        onSignal?(.timeControlPaused)
    }

    func cancelPendingSeeks() {
        cancelSeekCount += 1
        seekGeneration &+= 1
    }

    func seek(to time: TimeInterval) async throws {
        let generation = seekGeneration
        if let delay = seekDelayByTime[time] {
            try await Task.sleep(for: delay)
        }
        try Task.checkCancellation()
        guard generation == seekGeneration else {
            throw CancellationError()
        }
        _currentTime = time
    }

    func setRate(_ rate: Float) {
        self.rate = rate
        isPlaying = rate > 0
        if rate > 0 {
            onSignal?(.timeControlPlaying)
        }
    }
    func setMuted(_ muted: Bool) { self.muted = muted }
    func setVolume(_ volume: Float) { self.volume = volume }
    func currentTime() -> TimeInterval { _currentTime }
    func duration() -> TimeInterval? { _duration }

    func tearDown() {
        tearDownCount += 1
        replaceGeneration &+= 1
        seekGeneration &+= 1
        source = nil
        isPlaying = false
        onSignal = nil
    }

    func audioTracks() -> [MediaTrackInfo] { mockAudio }
    func textTracks() -> [MediaTrackInfo] { mockText }
    func selectAudioTrack(id: String?) {
        mockAudio = mockAudio.map {
            MediaTrackInfo(
                id: $0.id,
                kind: $0.kind,
                displayName: $0.displayName,
                languageCode: $0.languageCode,
                isExternal: $0.isExternal,
                isSelected: $0.id == id
            )
        }
    }

    func selectTextTrack(id: String?) {
        mockText = mockText.map {
            MediaTrackInfo(
                id: $0.id,
                kind: $0.kind,
                displayName: $0.displayName,
                languageCode: $0.languageCode,
                isExternal: $0.isExternal,
                isSelected: $0.id == id
            )
        }
    }

    func setPreferredPeakBitRate(_ bps: Double) { peakBitRate = bps }
    func setPreferredMaximumResolution(_ size: CGSize) { maxResolution = size }
    func seekableTimeRange() -> ClosedRange<TimeInterval>? { seekable }
    func thumbnail(at time: TimeInterval) async -> CGImage? { nil }
    func prepareThumbnailGenerator() {}
    func cancelThumbnailGeneration() {
        cancelThumbnailCount += 1
    }
    func skipCurrentInterstitial() {
        skipInterstitialCount += 1
    }

    func emit(_ signal: PlayerEngineSignal) { onSignal?(signal) }
    func emitProduction(_ signal: ProductionEngineSignal) {
        onProductionSignal?(signal)
    }
    func setDuration(_ value: TimeInterval?) { _duration = value }
    func advanceTime(to value: TimeInterval) {
        _currentTime = value
        onSignal?(.timeObserved(value))
    }
}
