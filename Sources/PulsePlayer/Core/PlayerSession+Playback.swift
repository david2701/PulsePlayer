import Foundation

@MainActor
extension PlayerSession {
    public func play() {
        guard status != .invalidated else { return }
        wantsPlaying = true
        activateAudioIfNeeded()

        switch status {
        case .loading:
            return
        case .ended:
            Task { await seek(to: 0) }
            _ = apply(.play)
            engine.play()
            emit(.playbackStarted)
            refreshNowPlaying(rate: 1)
        case .ready, .buffering, .stalled, .playing:
            if status == .ready {
                _ = apply(.play)
            }
            engine.play()
            if status == .playing {
                emit(.playbackStarted)
            }
            refreshNowPlaying(rate: 1)
        case .idle, .failed:
            break
        case .invalidated:
            break
        }
    }

    public func pause() {
        guard status != .invalidated else { return }
        wantsPlaying = false
        engine.pause()
        if apply(.pause) != nil {
            emit(.playbackPaused)
            refreshNowPlaying(rate: 0)
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
        engine.setRate(rate)
    }

    public func setMuted(_ muted: Bool) {
        _ = updateConfiguration { $0.isMuted = muted }
    }

    public func setVolume(_ volume: Float) {
        engine.setVolume(volume)
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
            if status == .buffering || status == .stalled {
                let started = rebufferStartedAt
                if apply(.bufferHealthy) != nil {
                    if let started {
                        let elapsed = started.duration(to: dependencies.clock.now())
                        emit(.rebufferEnded(duration: elapsed))
                    }
                    rebufferStartedAt = nil
                    stallTask?.cancel()
                    if wantsPlaying {
                        engine.play()
                    }
                }
            }

        case .didPlayToEnd:
            let live = currentSource?.isLive ?? false
            if live { return }
            if configuration.loop {
                Task {
                    await seek(to: 0)
                    if apply(.loopAdvance) != nil {
                        engine.play()
                        emit(.playbackStarted)
                    }
                }
            } else if apply(.didPlayToEnd) != nil {
                wantsPlaying = false
                emit(.ended)
            }

        case .timeControlPlaying:
            if status == .buffering || status == .ready {
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
            emit(.bitrateChanged(indicatedBps: indicated, observedBps: observed))

        case .externalPlayback(let active):
            isExternalPlaybackActive = active
            emit(.externalPlaybackActive(active))

        case .timeObserved(let t):
            emit(.position(t))
            refreshNowPlaying()
            refreshSubtitles(at: t)
            // Headless first-frame fallback: time advanced while intending to play.
            if !didEmitFirstFrame, wantsPlaying, t > 0.05 {
                emitFirstFrameIfNeeded()
            }

        case .durationKnown(let d):
            emit(.duration(d))

        case .bufferProgress(let p):
            emit(.buffer(progress: p))
        }
    }

    func emitFirstFrameIfNeeded() {
        guard !didEmitFirstFrame else { return }
        didEmitFirstFrame = true
        let start = loadStartedAt ?? dependencies.clock.now()
        let elapsed = start.duration(to: dependencies.clock.now())
        emit(.firstFrame(elapsed: elapsed))
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
