import Foundation

/// Pure helpers for stall / retry budgeting.
public enum StallRecovery: Sendable {
    /// Whether another auto-retry is allowed.
    public static func canAutoRetry(
        error: PlayerError,
        attemptsUsed: Int,
        policy: RetryPolicy
    ) -> Bool {
        guard error.isRecoverable else { return false }
        return attemptsUsed < policy.maxAttempts
    }

    /// Next attempt number (1-based) after `attemptsUsed` completed failures.
    public static func nextAttempt(attemptsUsed: Int) -> Int {
        attemptsUsed + 1
    }
}
