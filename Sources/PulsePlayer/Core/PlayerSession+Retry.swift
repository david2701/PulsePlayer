import Foundation

@MainActor
extension PlayerSession {
    public func retry() async {
        guard status == .failed || status == .stalled else { return }
        if status == .failed, let err = currentError, !err.isRecoverable {
            return
        }
        await performRetry(manual: true)
    }

    func scheduleAutoRetryIfNeeded() {
        guard let error = currentError else { return }
        let policy = frozenRetryPolicy ?? configuration.retry
        frozenRetryPolicy = policy
        guard StallRecovery.canAutoRetry(
            error: error,
            attemptsUsed: retryAttemptsUsed,
            policy: policy
        ) else {
            return
        }
        let attempt = StallRecovery.nextAttempt(attemptsUsed: retryAttemptsUsed)
        let delay = policy.delay(forAttempt: attempt)
        emit(.retryScheduled(attempt: attempt, delay: delay))

        autoRetryTask?.cancel()
        let gen = loadGeneration
        autoRetryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.dependencies.clock.sleep(for: delay)
            } catch {
                return
            }
            guard gen == self.loadGeneration, self.status == .failed else { return }
            await self.performRetry(manual: false)
        }
    }

    func scheduleStallRetry() {
        let policy = frozenRetryPolicy ?? configuration.retry
        frozenRetryPolicy = policy
        guard retryAttemptsUsed < policy.maxAttempts else {
            fail(with: .stalledExhausted(attempts: retryAttemptsUsed))
            return
        }
        let attempt = StallRecovery.nextAttempt(attemptsUsed: retryAttemptsUsed)
        let delay = policy.delay(forAttempt: attempt)
        emit(.retryScheduled(attempt: attempt, delay: delay))

        let gen = loadGeneration
        autoRetryTask?.cancel()
        autoRetryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.dependencies.clock.sleep(for: delay)
            } catch {
                return
            }
            guard gen == self.loadGeneration, self.status == .stalled else { return }
            await self.performRetry(manual: false)
        }
    }

    private func performRetry(manual: Bool) async {
        retryAttemptsUsed += 1
        let attempt = retryAttemptsUsed
        emit(.retryStarted(attempt: attempt))
        guard apply(.retry) != nil else { return }

        currentError = nil
        wantsPlaying = true
        didEmitFirstFrame = false
        loadStartedAt = dependencies.clock.now()

        let policy = frozenRetryPolicy ?? configuration.retry
        if policy.reloadItemOnRetry, let source = currentSource {
            startStartupWatchdog(generation: loadGeneration)
            do {
                try await engine.replaceCurrentItem(with: source)
            } catch is CancellationError {
                return
            } catch {
                let ns = error as NSError
                fail(with: .assetLoadFailed(
                    underlying: URLSanitizer.sanitizeMessage(ns.localizedDescription),
                    recoverable: true
                ))
                return
            }
        } else {
            engine.play()
        }
        _ = manual
    }
}
