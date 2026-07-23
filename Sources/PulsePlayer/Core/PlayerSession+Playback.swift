import Foundation

@MainActor
extension PlayerSession {
    public func play() {
        guard status != .invalidated else { return }
        wantsPlaying = true

        switch status {
        case .loading:
            return
        case .ended:
            activateAudioIfNeeded()
            restartTask?.cancel()
            restartTask = Task { @MainActor [weak self] in
                guard let self else { return }
                await self.seek(to: 0)
                guard !Task.isCancelled, self.status != .invalidated else { return }
                _ = self.apply(.play)
                self.claimNowPlayingOwnership()
                self.engine.play()
                self.emit(.playbackStarted)
                self.refreshNowPlaying(rate: self.playbackRate)
            }
        case .ready, .buffering, .stalled, .playing:
            activateAudioIfNeeded()
            if status == .ready {
                _ = apply(.play)
            }
            claimNowPlayingOwnership()
            if playbackRate <= 0 || playbackRate == 1 {
                playbackRate = 1
                engine.play()
            } else {
                engine.setRate(playbackRate)
            }
            if status == .playing {
                emit(.playbackStarted)
            }
            refreshNowPlaying(rate: playbackRate)
        case .idle, .failed:
            break
        case .invalidated:
            break
        }
    }

    public func pause() {
        guard status != .invalidated else { return }
        let wasActivelyPlaying = status == .playing
            || status == .buffering
            || status == .stalled
            || status == .ended
        wantsPlaying = false
        engine.pause()
        _ = apply(.pause)
        if wasActivelyPlaying {
            emit(.playbackPaused)
            refreshNowPlaying(rate: 0)
            saveContinueWatchingIfNeeded()
        }
    }

    public func togglePlayPause() {
        if status == .playing || status == .buffering {
            pause()
        } else {
            play()
        }
    }

    public func setRate(_ rate: Float) {
        let value = max(0, rate)
        guard value > 0 else {
            pause()
            return
        }
        playbackRate = value
        wantsPlaying = true
        switch status {
        case .ready, .ended:
            play()
        case .playing, .buffering, .stalled:
            claimNowPlayingOwnership()
            engine.setRate(value)
            refreshNowPlaying(rate: value)
        case .loading, .idle, .failed, .invalidated:
            break
        }
    }

    public func setMuted(_ muted: Bool) {
        _ = updateConfiguration { $0.isMuted = muted }
        engine.setMuted(muted)
    }

    public func setVolume(_ volume: Float) {
        let v = max(0, min(1, volume))
        self.volume = v
        engine.setVolume(v)
        if v > 0, configuration.isMuted {
            setMuted(false)
        }
    }

    public func toggleMute() {
        setMuted(!isMuted)
    }

    func handleEngineSignal(_ signal: PlayerEngineSignal) {
        guard status != .invalidated else { return }

        switch signal {
        case .itemStatusReady:
            handleItemReady()

        case .itemFailed(let domain, let code, let message):
            let error = CoreMediaErrorMap.makeItemFailed(
                domain: domain,
                code: code,
                message: message
            )
            fail(with: error)

        case .bufferEmpty:
            if status == .playing || status == .ready {
                if apply(.bufferEmpty) != nil {
                    rebufferStartedAt = dependencies.clock.now()
                    emit(.rebufferStarted)
                    startStallWatchdog()
                }
            }

        case .bufferHealthy:
            recoverFromBuffering(resumeEngine: wantsPlaying)

        case .didPlayToEnd:
            let live = currentSource?.isLive ?? false
            if live { return }
            if configuration.loop {
                guard apply(.didPlayToEnd) != nil else { return }
                wantsPlaying = true
                _ = apply(.loopAdvance)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await seek(to: 0)
                    guard self.status == .playing,
                          !Task.isCancelled
                    else { return }
                    if self.playbackRate == 1 {
                        self.engine.play()
                    } else {
                        self.engine.setRate(self.playbackRate)
                    }
                    self.emit(.playbackStarted)
                    self.refreshNowPlaying(rate: self.playbackRate)
                }
            } else if apply(.didPlayToEnd) != nil {
                wantsPlaying = false
                emit(.ended)
                refreshNowPlaying(rate: 0)
                saveContinueWatchingIfNeeded()
                if let queue = playbackQueue {
                    Task { await queue.handleSessionEnded() }
                }
            }

        case .timeControlPlaying:
            if status == .buffering || status == .stalled {
                recoverFromBuffering(resumeEngine: false)
            } else if status == .ready {
                _ = apply(.bufferHealthy)
            }

        case .timeControlWaiting:
            if status == .playing {
                _ = apply(.bufferEmpty)
                rebufferStartedAt = dependencies.clock.now()
                emit(.rebufferStarted)
                startStallWatchdog()
            }

        case .timeControlPaused:
            break

        case .readyForDisplay:
            emitFirstFrameIfNeeded()

        case .accessLog(let indicated, let observed):
            indicatedBitrate = indicated
            observedBitrate = observed
            metrics.lastIndicatedBitrate = indicated
            metrics.lastObservedBitrate = observed
            emit(.bitrateChanged(indicatedBps: indicated, observedBps: observed))

        case .externalPlayback(let active):
            isExternalPlaybackActive = active
            emit(.externalPlaybackActive(active))

        case .timeObserved(let t):
            if !isSeeking {
                playbackTime = t
            }
            if abs(t - lastPositionEventTime) >= 0.5 {
                lastPositionEventTime = t
                emit(.position(t))
            }
            let mediaTime = isSeeking ? playbackTime : t
            refreshSubtitles(at: mediaTime)
            adCueTracker.tick(time: mediaTime)
            updateEditorialTimeline(at: mediaTime)
            updateLivePlayback(at: mediaTime)
            if currentSource?.isLive == true {
                let atEdge = isAtLiveEdge
                if atEdge, !wasAtLiveEdge {
                    emit(.liveEdgeReached)
                }
                wasAtLiveEdge = atEdge
            } else {
                wasAtLiveEdge = false
            }
            // Headless first-frame fallback: time advanced while intending to play.
            if !didEmitFirstFrame, wantsPlaying, t > 0.05 {
                emitFirstFrameIfNeeded()
            }

        case .durationKnown(let d):
            playbackDuration = d
            emit(.duration(d))

        case .bufferProgress(let p):
            bufferProgressValue = p
            emit(.buffer(progress: p))
        }
    }

    func emitFirstFrameIfNeeded() {
        guard !didEmitFirstFrame else { return }
        didEmitFirstFrame = true
        let start = loadStartedAt ?? dependencies.clock.now()
        let elapsed = start.duration(to: dependencies.clock.now())
        metrics.ttff = elapsed
        metrics.ttffMilliseconds = PlaybackMetrics.milliseconds(from: elapsed)
        emit(.firstFrame(elapsed: elapsed))
        evaluatePerformanceBudget()
        emitMetricsSnapshot()
    }

    private func recoverFromBuffering(resumeEngine: Bool) {
        guard status == .buffering || status == .stalled else { return }
        let started = rebufferStartedAt
        guard apply(.bufferHealthy) != nil else { return }
        if let started {
            let elapsed = started.duration(to: dependencies.clock.now())
            recordRebuffer(duration: elapsed)
            emit(.rebufferEnded(duration: elapsed))
            evaluatePerformanceBudget()
            emitMetricsSnapshot()
        }
        rebufferStartedAt = nil
        stallTask?.cancel()
        stallTask = nil
        if resumeEngine {
            if playbackRate == 1 {
                engine.play()
            } else {
                engine.setRate(playbackRate)
            }
        }
    }

    func emitMetricsSnapshot() {
        emit(.metrics(
            ttffMs: metrics.ttffMilliseconds,
            rebufferCount: metrics.rebufferCount,
            indicatedBps: metrics.lastIndicatedBitrate ?? indicatedBitrate,
            observedBps: metrics.lastObservedBitrate ?? observedBitrate
        ))
    }

    func saveContinueWatchingIfNeeded() {
        guard continueWatchingEnabled,
              let source = currentSource,
              !source.isLive
        else { return }
        continueStore.save(
            sourceId: source.id,
            position: playbackTime,
            duration: playbackDuration
        )
    }

    func startStallWatchdog() {
        stallTask?.cancel()
        let threshold = configuration.stall.stallThreshold
        let gen = loadGeneration
        stallTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.dependencies.clock.sleep(for: threshold)
            } catch {
                return
            }
            guard gen == self.loadGeneration, self.status == .buffering else { return }
            if self.apply(.stallTimeout) != nil {
                self.emit(.stallDetected)
                self.scheduleStallRetry()
            }
        }
    }
}
