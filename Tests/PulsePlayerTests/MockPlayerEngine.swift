import CoreGraphics
import Foundation
@testable import PulsePlayer

/// Test double: no AVPlayer, no network.
@MainActor
final class MockPlayerEngine: PlaybackControlling {
    var onSignal: ((PlayerEngineSignal) -> Void)?

    private(set) var configuration = PlayerConfiguration.default
    private(set) var source: MediaSource?
    private(set) var isPlaying = false
    private(set) var rate: Float = 1
    private(set) var muted = false
    private(set) var volume: Float = 1
    private var _currentTime: TimeInterval = 0
    private var _duration: TimeInterval? = 120
    private(set) var replaceCount = 0
    var replaceError: Error?
    var autoReady = true
    var peakBitRate: Double = 0
    var maxResolution: CGSize = .zero
    var mockAudio: [MediaTrackInfo] = []
    var mockText: [MediaTrackInfo] = []
    var seekable: ClosedRange<TimeInterval>? = 0...120

    func applyConfiguration(_ config: PlayerConfiguration) {
        configuration = config
        muted = config.isMuted
    }

    func replaceCurrentItem(with source: MediaSource) async throws {
        replaceCount += 1
        if let replaceError {
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

    func play() {
        isPlaying = true
        onSignal?(.timeControlPlaying)
    }

    func pause() {
        isPlaying = false
        onSignal?(.timeControlPaused)
    }

    func seek(to time: TimeInterval) async throws {
        _currentTime = time
    }

    func setRate(_ rate: Float) { self.rate = rate }
    func setMuted(_ muted: Bool) { self.muted = muted }
    func setVolume(_ volume: Float) { self.volume = volume }
    func currentTime() -> TimeInterval { _currentTime }
    func duration() -> TimeInterval? { _duration }

    func tearDown() {
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
    func prepareThumbnailGenerator() {}
    func thumbnail(at time: TimeInterval) async -> CGImage? { nil }

    func emit(_ signal: PlayerEngineSignal) { onSignal?(signal) }
    func setDuration(_ value: TimeInterval?) { _duration = value }
    func advanceTime(to value: TimeInterval) {
        _currentTime = value
        onSignal?(.timeObserved(value))
    }
}
