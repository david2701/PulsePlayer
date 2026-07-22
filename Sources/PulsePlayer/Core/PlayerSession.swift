import AVFoundation
import Foundation
import Observation

/// Long-lived playback session. Own with `@State`; never construct inside `body` without storage.
@MainActor
@Observable
public final class PlayerSession: Identifiable {
    public let id: UUID

    // internal(set): extensions in this module orchestrate lifecycle.
    public internal(set) var status: PlayerStatus = .idle
    public internal(set) var currentSource: MediaSource?
    public internal(set) var currentError: PlayerError?
    public internal(set) var configuration: PlayerConfiguration

    public var currentTime: TimeInterval { engine.currentTime() }
    public var duration: TimeInterval? { engine.duration() }
    public internal(set) var isExternalPlaybackActive: Bool = false

    /// External subtitle tracks (SRT/VTT).
    public internal(set) var subtitleTracks: [SubtitleTrack] = []
    public internal(set) var activeSubtitleTrackID: String?
    /// Current on-screen subtitle text.
    public internal(set) var currentSubtitleText: String?

    let engine: any PlaybackControlling
    let dependencies: PlayerDependencies
    let eventBus = PlayerEventBus()
    let pipController = PictureInPictureController()

    var loadGeneration: UInt64 = 0
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
    var platformConfigured = false

    public init(
        configuration: PlayerConfiguration = .default,
        dependencies: PlayerDependencies = .production
    ) {
        self.id = UUID()
        self.configuration = configuration
        self.dependencies = dependencies
        self.engine = dependencies.engineFactory()
        self.engine.applyConfiguration(configuration)
        self.engine.onSignal = { [weak self] signal in
            self?.handleEngineSignal(signal)
        }
        // Platform hooks (PiP events, remote commands) after `self` is ready.
        self.configurePlatformHooks()
        self.platformConfigured = true
    }

    deinit {
        // Best-effort; MainActor deinit is constrained — tearDown via invalidate preferred.
    }

    public func makeEventStream() -> AsyncStream<PlayerEvent> {
        eventBus.makeStream()
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
                eventBus.yield(.stateChanged(from: from, to: next))
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
        eventBus.yield(event)
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
    }

    func fail(with error: PlayerError) {
        currentError = error
        guard apply(.fail) != nil else { return }
        emit(.failed(error))
        scheduleAutoRetryIfNeeded()
    }
}
