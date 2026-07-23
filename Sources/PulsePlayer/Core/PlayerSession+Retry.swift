import Foundation

@MainActor
extension PlayerSession {
    public func retry() async {
        guard status == .failed || status == .stalled else { return }
        if status == .failed, let err = currentError, !err.isRecoverable {
            return
        }
        if retryAttemptsUsed >= (frozenRetryPolicy ?? configuration.retry).maxAttempts,
           await performSourceFallbackIfAvailable()
        {
            return
        }
        await performRetry()
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
            if error.isRecoverable {
                autoRetryTask?.cancel()
                autoRetryTask = Task { @MainActor [weak self] in
                    _ = await self?.performSourceFallbackIfAvailable()
                }
            }
            return
        }
        let attempt = StallRecovery.nextAttempt(attemptsUsed: retryAttemptsUsed)
        let delay = policy.delay(forAttempt: attempt)
        emit(.retryScheduled(attempt: attempt, delay: delay))

        autoRetryTask?.cancel()
        let gen = loadGeneration
        autoRetryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await self.waitForNetwork(
                generation: gen,
                expectedStatus: .failed
            ) else { return }
            do {
                try await self.dependencies.clock.sleep(for: delay)
            } catch {
                return
            }
            guard gen == self.loadGeneration, self.status == .failed else { return }
            await self.performRetry()
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
            guard await self.waitForNetwork(
                generation: gen,
                expectedStatus: .stalled
            ) else { return }
            do {
                try await self.dependencies.clock.sleep(for: delay)
            } catch {
                return
            }
            guard gen == self.loadGeneration, self.status == .stalled else { return }
            await self.performRetry()
        }
    }

    private func performRetry() async {
        guard dependencies.network.isSatisfied else {
            fail(with: .networkUnavailable)
            return
        }
        let retryError = currentError
        var retrySource = currentSource
        var refreshedCredentials: PlaybackCredentials?
        if retryError?.suggestedAction == .reauthenticate,
           let source = currentSource,
           credentialProvider != nil
        {
            do {
                let refreshed = try await sourceWithFreshCredentials(
                    source,
                    reason: .unauthorized
                )
                retrySource = refreshed.0
                refreshedCredentials = refreshed.1
                currentSource = refreshed.0
            } catch {
                _ = await performSourceFallbackIfAvailable()
                return
            }
        }
        retryAttemptsUsed += 1
        let attempt = retryAttemptsUsed
        emit(.retryStarted(attempt: attempt))
        guard apply(.retry) != nil else { return }

        currentError = nil
        wantsPlaying = true
        didEmitFirstFrame = false
        loadStartedAt = dependencies.clock.now()

        let policy = frozenRetryPolicy ?? configuration.retry
        if policy.reloadItemOnRetry, let source = retrySource {
            startStartupWatchdog(generation: loadGeneration)
            do {
                try await engine.replaceCurrentItem(with: source)
                scheduleCredentialRefresh(
                    credentials: refreshedCredentials,
                    source: source
                )
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
            _ = apply(.itemReady)
            _ = apply(.play)
            activateAudioIfNeeded()
            claimNowPlayingOwnership()
            if playbackRate == 1 {
                engine.play()
            } else {
                engine.setRate(playbackRate)
            }
            emit(.playbackStarted)
            refreshNowPlaying(rate: playbackRate)
        }
    }

    @discardableResult
    func performSourceFallbackIfAvailable() async -> Bool {
        guard status == .failed || status == .stalled,
              let original = recoveryOriginalSource,
              let current = currentSource
        else { return false }
        let urls = [original.url] + original.fallbackURLs
        let nextIndex = sourceFallbackIndex + 1
        guard urls.indices.contains(nextIndex) else { return false }

        let previousIndex = sourceFallbackIndex
        sourceFallbackIndex = nextIndex
        retryAttemptsUsed = 0
        metrics.sourceFallbackCount += 1
        emitProduction(.sourceFallback(fromIndex: previousIndex, toIndex: nextIndex))

        var fallback = current.replacingURL(urls[nextIndex])
        fallback.fallbackURLs = original.fallbackURLs
        if credentialProvider != nil {
            do {
                let refreshed = try await sourceWithFreshCredentials(
                    fallback,
                    reason: .unauthorized
                )
                fallback = refreshed.0
                scheduleCredentialRefresh(
                    credentials: refreshed.1,
                    source: fallback
                )
            } catch {
                return await performSourceFallbackIfAvailable()
            }
        }

        guard apply(.retry) != nil else { return false }
        currentError = nil
        currentSource = fallback
        wantsPlaying = true
        loadStartedAt = dependencies.clock.now()
        startStartupWatchdog(generation: loadGeneration)
        do {
            try await engine.replaceCurrentItem(with: fallback)
            return true
        } catch {
            let ns = error as NSError
            fail(with: .assetLoadFailed(
                underlying: URLSanitizer.sanitizeMessage(ns.localizedDescription),
                recoverable: true
            ))
            return true
        }
    }

    private func waitForNetwork(
        generation: UInt64,
        expectedStatus: PlayerStatus
    ) async -> Bool {
        var reportedUnavailable = false
        while !dependencies.network.isSatisfied {
            guard generation == loadGeneration,
                  status == expectedStatus,
                  !Task.isCancelled
            else { return false }
            if !reportedUnavailable {
                reportedUnavailable = true
                emit(.warning(PlayerError.networkUnavailable.userMessage))
            }
            do {
                try await dependencies.clock.sleep(
                    for: configuration.stall.recoverProbeInterval
                )
            } catch {
                return false
            }
        }
        return generation == loadGeneration && status == expectedStatus && !Task.isCancelled
    }
}
