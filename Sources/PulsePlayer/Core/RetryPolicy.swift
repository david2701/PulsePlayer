import Foundation

/// Exponential backoff parameters for recoverable failures.
public struct RetryPolicy: Sendable, Equatable {
    public var maxAttempts: Int
    public var baseDelay: Duration
    public var maxDelay: Duration
    public var jitter: Double
    public var reloadItemOnRetry: Bool

    public init(
        maxAttempts: Int = 3,
        baseDelay: Duration = .milliseconds(400),
        maxDelay: Duration = .seconds(8),
        jitter: Double = 0.2,
        reloadItemOnRetry: Bool = true
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitter = jitter
        self.reloadItemOnRetry = reloadItemOnRetry
    }

    public static let `default` = RetryPolicy()

    /// Jittered delay before attempt `attempt` (1-based).
    public func delay(forAttempt attempt: Int) -> Duration {
        delay(forAttempt: attempt, randomUnit: Double.random(in: 0...1))
    }

    /// Deterministic variant used by package tests. `randomUnit` is clamped to `0...1`.
    package func delay(forAttempt attempt: Int, randomUnit: Double) -> Duration {
        let clamped = max(1, attempt)
        let baseNs = Double(baseDelay.components.seconds) * 1_000_000_000
            + Double(baseDelay.components.attoseconds) / 1_000_000_000
        let maxNs = Double(maxDelay.components.seconds) * 1_000_000_000
            + Double(maxDelay.components.attoseconds) / 1_000_000_000
        let exp = min(maxNs, baseNs * pow(2.0, Double(clamped - 1)))
        let j = max(0, min(1, jitter))
        let sample = max(0, min(1, randomUnit))
        let factor = 1.0 + ((sample * 2 - 1) * j)
        let ns = min(maxNs, max(0, exp * factor))
        return .nanoseconds(Int64(ns))
    }
}

/// Stall / startup watchdog policy.
public struct StallPolicy: Sendable, Equatable {
    public var stallThreshold: Duration
    public var startupTimeout: Duration
    public var recoverProbeInterval: Duration

    public init(
        stallThreshold: Duration = .seconds(2),
        startupTimeout: Duration = .seconds(30),
        recoverProbeInterval: Duration = .milliseconds(250)
    ) {
        self.stallThreshold = stallThreshold
        self.startupTimeout = startupTimeout
        self.recoverProbeInterval = recoverProbeInterval
    }

    public static let `default` = StallPolicy()
}

extension Duration {
    var timeInterval: TimeInterval {
        let c = components
        return TimeInterval(c.seconds) + TimeInterval(c.attoseconds) / 1e18
    }
}
