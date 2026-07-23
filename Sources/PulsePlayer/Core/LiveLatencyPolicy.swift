import Foundation

/// Live-edge behavior for HLS live playback.
public struct LiveLatencyPolicy: Sendable, Equatable {
    public var targetLatency: TimeInterval
    public var catchUpThreshold: TimeInterval
    public var catchUpRate: Float

    public init(
        targetLatency: TimeInterval = 3,
        catchUpThreshold: TimeInterval = 2,
        catchUpRate: Float = 1.03
    ) {
        self.targetLatency = max(0.5, targetLatency)
        self.catchUpThreshold = max(0.25, catchUpThreshold)
        self.catchUpRate = min(1.10, max(1.0, catchUpRate))
    }

    public static let lowLatency = LiveLatencyPolicy()
}
