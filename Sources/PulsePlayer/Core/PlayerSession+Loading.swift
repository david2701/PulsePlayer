import Foundation

@MainActor
extension PlayerSession {
    /// Load media. Optional `startAt` seeks after the item is ready.
    /// When `resumeContinueWatching` is true and a saved position exists, it wins over `startAt`.
    public func load(
        _ source: MediaSource,
        startAt: TimeInterval? = nil,
        resumeContinueWatching: Bool = false
    ) async {
        guard status != .invalidated else { return }

        qualityTask?.cancel()
        qualityTask = nil
        let wasLoading = status == .loading
        cancelLoadWork()
        cancelInteractiveWork()
        if wasLoading {
            _ = apply(.loadCancelled)
        }
        loadGeneration &+= 1
        let gen = loadGeneration
        qualityHardLocked = false
        playbackID = UUID()
        sourceFallbackIndex = 0
        recoveryOriginalSource = source

        wantsPlaying = configuration.autoplay
        didEmitFirstFrame = false
        loadStartedAt = dependencies.clock.now()
        currentError = nil
        retryAttemptsUsed = 0
        frozenRetryPolicy = nil
        rebufferStartedAt = nil

        if resumeContinueWatching, let saved = continueStore.position(for: source.id) {
            pendingStartAt = saved
        } else {
            pendingStartAt = startAt
        }

        resetLoadCycleMetrics(sourceID: source.id)
        metrics.loadStartedAt = loadStartedAt

        _ = apply(.load, isLive: source.isLive)
        currentSource = source
        emit(.loadStarted(sourceID: source.id))
        adCueTracker.handler = adCueHandler
        adCueTracker.reset(cues: source.adCues)
        scrubPreviewImage = nil
        indicatedBitrate = nil
        observedBitrate = nil
        bufferProgressValue = nil
        clearProductionFeatureState()
        wasAtLiveEdge = false
        availableQualities = []
        selectedQualityId = StreamQuality.auto.id
        qualityMasterURL = nil

        startStartupWatchdog(generation: gen)

        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let (resolvedSource, credentials) = try await self.sourceWithFreshCredentials(
                    source,
                    reason: .initialLoad
                )
                guard gen == self.loadGeneration, !Task.isCancelled else { return }
                self.currentSource = resolvedSource
                try await self.engine.replaceCurrentItem(with: resolvedSource)
                guard gen == self.loadGeneration, !Task.isCancelled else { return }
                await self.refreshQualities(for: resolvedSource)
                self.scheduleCredentialRefresh(
                    credentials: credentials,
                    source: resolvedSource
                )
            } catch is CancellationError {
                return
            } catch {
                guard gen == self.loadGeneration else { return }
                if let playerError = error as? PlayerError {
                    self.fail(with: playerError)
                    return
                }
                let ns = error as NSError
                if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled {
                    return
                }
                let pe = CoreMediaErrorMap.makeItemFailed(
                    domain: ns.domain,
                    code: ns.code,
                    message: ns.localizedDescription
                )
                let mapped: PlayerError = .assetLoadFailed(
                    underlying: URLSanitizer.sanitizeMessage(ns.localizedDescription),
                    recoverable: pe.isRecoverable
                )
                self.fail(with: mapped)
            }
        }

        await loadTask?.value
    }

    public func reset() async {
        guard status != .invalidated else { return }
        qualityTask?.cancel()
        qualityTask = nil
        cancelLoadWork()
        cancelInteractiveWork()
        loadGeneration &+= 1
        wantsPlaying = false
        currentError = nil
        currentSource = nil
        recoveryOriginalSource = nil
        didEmitFirstFrame = false
        retryAttemptsUsed = 0
        frozenRetryPolicy = nil
        pendingStartAt = nil
        playbackTime = 0
        playbackDuration = nil
        indicatedBitrate = nil
        observedBitrate = nil
        bufferProgressValue = nil
        availableQualities = []
        selectedQualityId = StreamQuality.auto.id
        qualityMasterURL = nil
        qualityHardLocked = false
        scrubPreviewImage = nil
        rebufferStartedAt = nil
        clearProductionFeatureState()
        didEmitFirstFrame = false
        wasAtLiveEdge = false
        lastPositionEventTime = -.infinity
        clearSubtitles()
        engine.pause()
        (engine as? any ManagedPlaybackControlling)?.clearCurrentItem()
        adCueTracker.clear()
        releaseNowPlayingOwnership(clear: true)
        deactivateAudioIfNeeded()
        _ = apply(.reset)
    }

    public func invalidate() {
        guard status != .invalidated else { return }
        qualityTask?.cancel()
        qualityTask = nil
        cancelLoadWork()
        cancelInteractiveWork()
        loadGeneration &+= 1
        pipController.tearDown()
        unregisterNowPlayingOwnership(clear: true)
        clearSubtitles()
        adCueTracker.clear()
        clearProductionFeatureState()
        deactivateAudioIfNeeded()
        engine.tearDown()
        audioEventTask?.cancel()
        audioEventTask = nil
        lifecycleEventTask?.cancel()
        lifecycleEventTask = nil
        currentSource = nil
        currentError = .sessionInvalidated
        _ = apply(.invalidate)
        eventBus.finish()
        productionEventBus.finish()
        telemetryDispatcher.finish()
    }

    func startStartupWatchdog(generation gen: UInt64) {
        let timeout = configuration.stall.startupTimeout
        startupTask?.cancel()
        startupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.dependencies.clock.sleep(for: timeout)
            } catch {
                return
            }
            guard gen == self.loadGeneration, self.status == .loading else { return }
            self.loadTask?.cancel()
            self.loadTask = nil
            self.loadGeneration &+= 1
            (self.engine as? any ManagedPlaybackControlling)?.clearCurrentItem()
            self.fail(with: .startupTimedOut)
        }
    }

    func handleItemReady() {
        startupTask?.cancel()
        startupTask = nil
        guard status == .loading || status == .stalled else { return }

        if status == .stalled {
            _ = apply(.itemReady)
        } else {
            _ = apply(.itemReady)
        }

        if let id = currentSource?.id {
            emit(.readyToPlay(sourceID: id))
        }
        if let d = engine.duration() {
            playbackDuration = d
            emit(.duration(d))
        }
        playbackTime = engine.currentTime()

        if let start = pendingStartAt, start > 0.25 {
            pendingStartAt = nil
            Task { @MainActor [weak self] in
                await self?.seek(to: start)
            }
        } else {
            pendingStartAt = nil
        }

        let shouldPlay = wantsPlaying
        if shouldPlay {
            activateAudioIfNeeded()
            claimNowPlayingOwnership()
            if status == .ready {
                _ = apply(.autoplayGate)
            }
            // If play from ready with empty buffer, engine signals will move to buffering.
            if status == .playing || status == .ready {
                if status == .ready {
                    _ = apply(.play)
                }
                if playbackRate == 1 {
                    engine.play()
                } else {
                    engine.setRate(playbackRate)
                }
                emit(.playbackStarted)
                refreshNowPlaying(rate: playbackRate)
            }
        } else {
            refreshNowPlaying(rate: 0)
        }
    }
}
