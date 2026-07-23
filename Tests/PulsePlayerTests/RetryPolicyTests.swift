import Testing
@testable import PulsePlayer

@Suite("RetryPolicy")
struct RetryPolicyTests {
    @Test func delayGrowsWithAttempt() {
        let policy = RetryPolicy(
            maxAttempts: 5,
            baseDelay: .milliseconds(100),
            maxDelay: .seconds(10),
            jitter: 0
        )
        let d1 = policy.delay(forAttempt: 1).timeInterval
        let d2 = policy.delay(forAttempt: 2).timeInterval
        let d3 = policy.delay(forAttempt: 3).timeInterval
        #expect(d2 > d1)
        #expect(d3 > d2)
    }

    @Test func delayCappedByMax() {
        let policy = RetryPolicy(
            baseDelay: .seconds(1),
            maxDelay: .seconds(2),
            jitter: 0
        )
        let d = policy.delay(forAttempt: 10).timeInterval
        #expect(d <= 2.1)
    }

    @Test func jitterIsSymmetricDeterministicAndBounded() {
        let policy = RetryPolicy(
            baseDelay: .seconds(1),
            maxDelay: .seconds(10),
            jitter: 0.2
        )
        #expect(
            policy.delay(forAttempt: 1, randomUnit: 0).timeInterval == 0.8
        )
        #expect(
            policy.delay(forAttempt: 1, randomUnit: 0.5).timeInterval == 1
        )
        #expect(
            policy.delay(forAttempt: 1, randomUnit: 1).timeInterval == 1.2
        )
        #expect(
            policy.delay(forAttempt: 1, randomUnit: -100).timeInterval == 0.8
        )
        #expect(
            policy.delay(forAttempt: 1, randomUnit: 100).timeInterval == 1.2
        )
    }

    @Test func stallRecoveryBudget() {
        let policy = RetryPolicy(maxAttempts: 2)
        #expect(
            StallRecovery.canAutoRetry(
                error: .startupTimedOut,
                attemptsUsed: 0,
                policy: policy
            )
        )
        #expect(
            !StallRecovery.canAutoRetry(
                error: .startupTimedOut,
                attemptsUsed: 2,
                policy: policy
            )
        )
        #expect(
            !StallRecovery.canAutoRetry(
                error: .invalidSource("x"),
                attemptsUsed: 0,
                policy: policy
            )
        )
    }
}
