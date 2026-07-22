import Foundation

/// Clock abstraction for tests (startup/stall timers, backoff).
public protocol PlayerClock: Sendable {
    func now() -> ContinuousClock.Instant
    func sleep(for duration: Duration) async throws
}

public struct SystemPlayerClock: PlayerClock {
    public init() {}

    public func now() -> ContinuousClock.Instant {
        ContinuousClock.now
    }

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
