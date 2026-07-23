import AVFoundation
import CoreGraphics
import Foundation
import Observation

/// Long-lived playback session. Own with `@State`; never construct inside `body` without storage.
@MainActor
@Observable
public final class PlayerSession: Identifiable {
    public let id: UUID
    /// Changes for every primary load and groups exported telemetry.
    public internal(set) var playbackID: UUID = UUID()

    // internal(set): extensions in this module orchestrate lifecycle.
    public internal(set) var status: PlayerStatus = .idle
    public internal(set) var currentSource: MediaSource?
    public internal(set) var currentError: PlayerError?
    public internal(set) var configuration: PlayerConfiguration

    /// Observed playback clock (drives UI scrubber / labels). Prefer this over `currentTime` in SwiftUI.
    public internal(set) var playbackTime: TimeInterval = 0
    public internal(set) var playbackDuration: TimeInterval?
    public internal(set) var volume: Float = 1
    public internal(set) var playbackRate: Float = 1
    public internal(set) var isSeeking: Bool = false
    public internal(set) var isExternalPlaybackActive: Bool = false

    /// Live engine time (not Observation-tracked by itself).
    public var currentTime: TimeInterval { engine.currentTime() }
    public var duration: TimeInterval? { engine.duration() ?? playbackDuration }

    public var isPlaying: Bool {
        status == .playing || status == .buffering
    }

    public var isMuted: Bool { configuration.isMuted }

    /// Supplies initial and refreshed request credentials when configured.
    public var credentialProvider: (any PlaybackCredentialProviding)?

    /// True after first displayable frame (or headless time advance).
    public var hasRenderedFrame: Bool { didEmitFirstFrame }

    /// External subtitle tracks (SRT/VTT).
    public internal(set) var subtitleTracks: [SubtitleTrack] = []
    public internal(set) var activeSubtitleTrackID: String?
    /// Current on-screen subtitle text.
    public internal(set) var currentSubtitleText: String?
    /// Visual style for `PulseSubtitleOverlay`.
    public var subtitleStyle: SubtitleStyle = .default
    /// Master switch for external subtitles.
    public var subtitlesEnabled: Bool = true

    /// QoE snapshots (updated from access log / buffer signals).
    public internal(set) var indicatedBitrate: Double?
    public internal(set) var observedBitrate: Double?
    public internal(set) var bufferProgressValue: Double?
    /// Scrub preview frame (optional).
    public internal(set) var scrubPreviewImage: CGImage?
    /// HLS quality ladder (empty if unknown / progressive).
    public internal(set) var availableQualities: [StreamQuality] = []
    /// Selected quality id (`auto` or variant id).
    public internal(set) var selectedQualityId: String = StreamQuality.auto.id
    /// Master playlist URL used to rebuild the quality ladder / unlock hard lock.
    public internal(set) var qualityMasterURL: URL?
    /// Whether the engine is currently on a single locked media playlist.
    var qualityHardLocked = false
    /// In-flight quality hard-lock task (coalesced).
    var qualityTask: Task<Void, Never>?
    /// Pending seek after load/item ready (continue watching / startAt).
    var pendingStartAt: TimeInterval?
    /// Rolling QoE counters (reset per primary `load`, not per quality switch).
    public internal(set) var metrics: PlaybackMetrics = .empty

    /// Distance from the current time to the live edge.
    public internal(set) var liveLatency: TimeInterval?
    public internal(set) var isCatchingUpToLive: Bool = false

    /// Native AVFoundation interstitial state.
    public internal(set) var activeInterstitialID: String?
    public internal(set) var canSkipInterstitial: Bool = false

    /// Current chapter or skippable editorial segment.
    public internal(set) var activeEditorialMarker: EditorialMarker?
    public var nextContentProposal: NextContentProposal?
    public internal(set) var isUpNextPresented: Bool = false

    /// Snapshot of QoE counters (value copy).
    public var metricsSnapshot: PlaybackMetrics { metrics }

    /// Optional queue for playlist autoplay-next.
    public weak var playbackQueue: PlaybackQueue?
    /// Optional ad cue handler.
    public weak var adCueHandler: (any AdCueHandling)?
    /// Persist position on pause/end.
    public var continueWatchingEnabled: Bool = true
    public var continueStore: ContinueWatchingStore = .shared

    let engine: any PlaybackControlling
    let dependencies: PlayerDependencies
    let lifetimeCleanup: PlayerSessionLifetimeCleanup
    let eventBus = PlayerEventBus()
    let productionEventBus = ProductionPlayerEventBus()
    let telemetryDispatcher: PlaybackTelemetryDispatcher
    let pipController = PictureInPictureController()
    let adCueTracker = AdCueTracker()

    var loadGeneration: UInt64 = 0
    var seekGeneration: UInt64 = 0
    var thumbnailGeneration: UInt64 = 0
    var wantsPlaying = false
    var retryAttemptsUsed = 0
    var frozenRetryPolicy: RetryPolicy?
    var loadStartedAt: ContinuousClock.Instant?
    var didEmitFirstFrame = false
    var rebufferStartedAt: ContinuousClock.Instant?
    var stallTask: Task<Void, Never>?
    var startupTask: Task<Void, Never>?
    var autoRetryTask: Task<Void, Never>?
    var loadTask: Task<Void, Never>?
    var audioSessionActivated = false
    var audioEventTask: Task<Void, Never>?
    var resumeAfterAudioInterruption = false
    var lifecycleEventTask: Task<Void, Never>?
    var resumeAfterForeground = false
    var _contentKeyProvider: (any ContentKeyProviding)?
    var _persistableContentKeyStore: (any PersistableContentKeyStoring)?
    var credentialRefreshTask: Task<Void, Never>?
    var credentialGeneration: UInt64 = 0
    var sourceFallbackIndex = 0
    var recoveryOriginalSource: MediaSource?
    var upNextTask: Task<Void, Never>?
    var lastLiveLatencyEvent: TimeInterval?
    var emittedPerformanceViolations: Set<String> = []
    var thumbnailTask: Task<Void, Never>?
    var restartTask: Task<Void, Never>?
    var lastPositionEventTime: TimeInterval = -.infinity
    /// Avoid spamming `.liveEdgeReached` every position tick.
    var wasAtLiveEdge = false

    public init(
        configuration: PlayerConfiguration = .default,
        dependencies: PlayerDependencies = .production
    ) {
        let sessionID = UUID()
        let playbackEngine = dependencies.engineFactory()
        self.id = sessionID
        self.configuration = configuration
        self.dependencies = dependencies
        self.engine = playbackEngine
        self.telemetryDispatcher = PlaybackTelemetryDispatcher(sink: dependencies.telemetry)
        self.lifetimeCleanup = PlayerSessionLifetimeCleanup(
            sessionID: sessionID,
            engine: playbackEngine,
            nowPlaying: dependencies.nowPlaying,
            audioSession: dependencies.audioSession,
            log: dependencies.log
        )
        self.engine.applyConfiguration(configuration)
        if let managed = self.engine as? any ManagedPlaybackControlling {
            managed.setLogHandler(dependencies.log)
            managed.onProductionSignal = { [weak self] signal in
                self?.handleProductionEngineSignal(signal)
            }
        }
        self.engine.setMuted(configuration.isMuted)
        self.volume = 1
        self.engine.setVolume(1)
        self.engine.onSignal = { [weak self] signal in
            self?.handleEngineSignal(signal)
        }
        self.adCueTracker.session = self
        // Platform hooks (PiP events, remote commands) after `self` is ready.
        self.configurePlatformHooks()
        self.startAudioSessionObservation()
        self.startApplicationLifecycleObservation()
    }

    public func makeEventStream() -> AsyncStream<PlayerEvent> {
        eventBus.makeStream()
    }

    /// Production-only signals added after the SemVer-frozen 1.0 event surface.
    public func makeProductionEventStream() -> AsyncStream<ProductionPlayerEvent> {
        productionEventBus.makeStream()
    }

    // MARK: - State machine apply

    @discardableResult
    func apply(
        _ event: PlayerStateEvent,
        isLive: Bool? = nil
    ) -> PlayerStatus? {
        let live = isLive ?? currentSource?.isLive ?? false
        let from = status
        switch PlayerStateMachine.transition(status: from, event: event, isLive: live) {
        case .to(let next):
            status = next
            if from != next {
                emit(.stateChanged(from: from, to: next))
            }
            return next
        case .stay:
            return status
        case .illegal:
            #if DEBUG
            assertionFailure("Illegal transition \(from) + \(event)")
            #endif
            eventBus.yield(.warning("Illegal transition \(from) + \(event)"))
            return nil
        }
    }

    func emit(_ event: PlayerEvent) {
        switch event {
        case .warning(let message):
            dependencies.log.log(level: .info, message: message)
        case .failed(let error):
            dependencies.log.log(level: .error, message: error.userMessage)
        default:
            break
        }
        eventBus.yield(event)
        telemetryDispatcher.submit(
            PlaybackTelemetryRecord(
                sessionID: id,
                playbackID: playbackID,
                sourceID: currentSource?.id,
                event: event
            )
        )
    }

    func emitProduction(_ event: ProductionPlayerEvent) {
        productionEventBus.yield(event)
        telemetryDispatcher.submit(
            ProductionPlaybackTelemetryRecord(
                sessionID: id,
                playbackID: playbackID,
                sourceID: currentSource?.id,
                event: event
            )
        )
    }

    func cancelLoadWork() {
        loadTask?.cancel()
        loadTask = nil
        startupTask?.cancel()
        startupTask = nil
        stallTask?.cancel()
        stallTask = nil
        autoRetryTask?.cancel()
        autoRetryTask = nil
        credentialRefreshTask?.cancel()
        credentialRefreshTask = nil
        credentialGeneration &+= 1
    }

    func cancelInteractiveWork() {
        seekGeneration &+= 1
        thumbnailGeneration &+= 1
        (engine as? any ManagedPlaybackControlling)?.cancelPendingSeeks()
        (engine as? any ManagedPlaybackControlling)?.cancelThumbnailGeneration()
        thumbnailTask?.cancel()
        thumbnailTask = nil
        restartTask?.cancel()
        restartTask = nil
        upNextTask?.cancel()
        upNextTask = nil
        isSeeking = false
    }

    func fail(with error: PlayerError) {
        if status == .failed, currentError == error {
            return
        }
        currentError = error
        metrics.errorCount += 1
        metrics.lastError = error
        guard apply(.fail) != nil else { return }
        emit(.failed(error))
        scheduleAutoRetryIfNeeded()
    }

    func resetLoadCycleMetrics(sourceID: String?) {
        emittedPerformanceViolations = []
        metrics.loadCount += 1
        metrics.ttff = nil
        metrics.ttffMilliseconds = nil
        metrics.rebufferCount = 0
        metrics.totalRebuffer = .zero
        metrics.totalRebufferMilliseconds = 0
        metrics.qualitySwitchCount = 0
        metrics.sourceID = sourceID
        metrics.loadStartedAt = dependencies.clock.now()
        // Keep errorCount / lastError across loads for session lifetime diagnostics.
    }

    func recordRebuffer(duration: Duration) {
        metrics.rebufferCount += 1
        metrics.totalRebuffer += duration
        metrics.totalRebufferMilliseconds = PlaybackMetrics.milliseconds(from: metrics.totalRebuffer)
    }
}

final class PlayerSessionLifetimeCleanup: @unchecked Sendable {
    private let payload: PlayerSessionCleanupPayload

    @MainActor
    init(
        sessionID: UUID,
        engine: any PlaybackControlling,
        nowPlaying: any NowPlayingCentering,
        audioSession: any AudioSessionConfiguring,
        log: any PulsePlayerLogHandler
    ) {
        payload = PlayerSessionCleanupPayload(
            sessionID: sessionID,
            engine: engine,
            nowPlaying: nowPlaying,
            audioSession: audioSession,
            log: log
        )
    }

    @MainActor
    func setAudioSessionActive(_ active: Bool) {
        payload.audioSessionActive = active
    }

    deinit {
        let payload = payload
        Task { @MainActor in
            payload.run()
        }
    }
}

private final class PlayerSessionCleanupPayload: @unchecked Sendable {
    private let sessionID: UUID
    private let engine: any PlaybackControlling
    private let nowPlaying: any NowPlayingCentering
    private let audioSession: any AudioSessionConfiguring
    private let log: any PulsePlayerLogHandler
    var audioSessionActive = false

    @MainActor
    init(
        sessionID: UUID,
        engine: any PlaybackControlling,
        nowPlaying: any NowPlayingCentering,
        audioSession: any AudioSessionConfiguring,
        log: any PulsePlayerLogHandler
    ) {
        self.sessionID = sessionID
        self.engine = engine
        self.nowPlaying = nowPlaying
        self.audioSession = audioSession
        self.log = log
    }

    @MainActor
    func run() {
        if let center = nowPlaying as? SystemNowPlayingCenter {
            center.unregister(owner: sessionID, clear: true)
        }
        if audioSessionActive {
            do {
                try audioSession.deactivate()
            } catch {
                log.log(
                    level: .error,
                    message: "Audio session cleanup failed: \(error.localizedDescription)"
                )
            }
            audioSessionActive = false
        }
        engine.tearDown()
    }
}
