import Foundation

/// Aggregate QoE counters for the current (or last) session load cycle.
public struct PlaybackMetrics: Sendable, Equatable {
    /// How many primary `load` calls were invoked on this session.
    public var loadCount: Int
    /// Hard quality switches (variant playlist reloads).
    public var qualitySwitchCount: Int
    public var credentialRefreshCount: Int
    public var sourceFallbackCount: Int
    /// Time to first frame for the latest successful playback start.
    public var ttff: Duration?
    public var ttffMilliseconds: Double?
    /// Completed rebuffer events this load cycle.
    public var rebufferCount: Int
    public var totalRebuffer: Duration
    public var totalRebufferMilliseconds: Double
    public var lastIndicatedBitrate: Double?
    public var lastObservedBitrate: Double?
    public var errorCount: Int
    public var lastError: PlayerError?
    public var sourceID: String?
    /// Wall-clock when the latest load started (session clock).
    public var loadStartedAt: ContinuousClock.Instant?

    public init(
        loadCount: Int = 0,
        qualitySwitchCount: Int = 0,
        ttff: Duration? = nil,
        ttffMilliseconds: Double? = nil,
        rebufferCount: Int = 0,
        totalRebuffer: Duration = .zero,
        totalRebufferMilliseconds: Double = 0,
        lastIndicatedBitrate: Double? = nil,
        lastObservedBitrate: Double? = nil,
        errorCount: Int = 0,
        lastError: PlayerError? = nil,
        sourceID: String? = nil,
        loadStartedAt: ContinuousClock.Instant? = nil
    ) {
        self.loadCount = loadCount
        self.qualitySwitchCount = qualitySwitchCount
        self.credentialRefreshCount = 0
        self.sourceFallbackCount = 0
        self.ttff = ttff
        self.ttffMilliseconds = ttffMilliseconds
        self.rebufferCount = rebufferCount
        self.totalRebuffer = totalRebuffer
        self.totalRebufferMilliseconds = totalRebufferMilliseconds
        self.lastIndicatedBitrate = lastIndicatedBitrate
        self.lastObservedBitrate = lastObservedBitrate
        self.errorCount = errorCount
        self.lastError = lastError
        self.sourceID = sourceID
        self.loadStartedAt = loadStartedAt
    }

    public static let empty = PlaybackMetrics()

    static func milliseconds(from duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000
            + Double(duration.components.attoseconds) / 1e15
    }
}

/// Suggested host response to a ``PlayerError``.
public enum PlayerErrorAction: String, Sendable, Equatable {
    /// Call `retry()` or reload the same source.
    case retry
    /// Replace credentials / headers and call `load` again.
    case reauthenticate
    /// Wait for connectivity, then retry.
    case checkNetwork
    /// User or host should pick another asset.
    case changeSource
    /// Session is dead — create a new `PlayerSession`.
    case recreateSession
    /// No automatic recovery.
    case none
}
