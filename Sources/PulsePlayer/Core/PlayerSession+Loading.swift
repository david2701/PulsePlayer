import Foundation

@MainActor
extension PlayerSession {
    public func load(_ source: MediaSource) async {
        guard status != .invalidated else { return }

        cancelLoadWork()
        loadGeneration &+= 1
        let gen = loadGeneration

        wantsPlaying = configuration.autoplay
        didEmitFirstFrame = false
        loadStartedAt = dependencies.clock.now()
        currentError = nil
        retryAttemptsUsed = 0
        frozenRetryPolicy = nil
        rebufferStartedAt = nil

        _ = apply(.load, isLive: source.isLive)
        currentSource = source
        emit(.loadStarted(sourceID: source.id))
        adCueTracker.handler = adCueHandler
        adCueTracker.reset(cues: source.adCues)
        scrubPreviewImage = nil
        indicatedBitrate = nil
        observedBitrate = nil
        bufferProgressValue = nil
        wasAtLiveEdge = false

        startStartupWatchdog(generation: gen)

        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.engine.replaceCurrentItem(with: source)
                guard gen == self.loadGeneration, !Task.isCancelled else { return }
                await self.refreshQualities(for: source)
            } catch is CancellationError {
                return
            } catch {
                guard gen == self.loadGeneration else { return }
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
        cancelLoadWork()
        loadGeneration &+= 1
        wantsPlaying = false
        currentError = nil
        currentSource = nil
        didEmitFirstFrame = false
        retryAttemptsUsed = 0
        clearSubtitles()
        engine.pause()
        // Replace with empty by tearing item via a dummy cancel — engine keeps player.
        // Full clear: tearDown not called so session reusable; load next source.
        _ = apply(.reset)
        emit(.warning("reset"))
    }

    public func invalidate() {
        cancelLoadWork()
        loadGeneration &+= 1
        pipController.tearDown()
        clearNowPlaying()
        clearSubtitles()
        if let np = dependencies.nowPlaying as? SystemNowPlayingCenter {
            np.setCommandHandlers(nil)
        }
        engine.tearDown()
        eventBus.finish()
        currentSource = nil
        currentError = .sessionInvalidated
        _ = apply(.invalidate)
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

        let shouldPlay = wantsPlaying || configuration.autoplay
        if shouldPlay {
            activateAudioIfNeeded()
            if status == .ready {
                _ = apply(.autoplayGate)
            }
            // If play from ready with empty buffer, engine signals will move to buffering.
            if status == .playing || status == .ready {
                if status == .ready {
                    _ = apply(.play)
                }
                engine.play()
                emit(.playbackStarted)
                refreshNowPlaying(rate: 1)
            }
        } else {
            refreshNowPlaying(rate: 0)
        }
    }
}
