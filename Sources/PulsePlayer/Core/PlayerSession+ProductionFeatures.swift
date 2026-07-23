import Foundation

@MainActor
extension PlayerSession {
    func updateLivePlayback(at time: TimeInterval) {
        guard currentSource?.isLive == true, let edge = liveEdgeTime else {
            endLiveCatchUpIfNeeded()
            liveLatency = nil
            lastLiveLatencyEvent = nil
            return
        }

        let latency = max(0, edge - time)
        liveLatency = latency
        if lastLiveLatencyEvent.map({ abs($0 - latency) >= 0.25 }) ?? true {
            lastLiveLatencyEvent = latency
            emitProduction(.liveLatencyChanged(seconds: latency))
        }

        guard let policy = configuration.liveLatencyPolicy,
              wantsPlaying,
              status == .playing || status == .buffering,
              playbackRate == 1,
              !isSeeking,
              activeInterstitialID == nil
        else {
            endLiveCatchUpIfNeeded()
            return
        }

        if !isCatchingUpToLive,
           latency > policy.targetLatency + policy.catchUpThreshold
        {
            isCatchingUpToLive = true
            engine.setRate(policy.catchUpRate)
            emitProduction(.liveCatchUpChanged(active: true))
        } else if isCatchingUpToLive, latency <= policy.targetLatency {
            endLiveCatchUpIfNeeded()
        }
    }

    func endLiveCatchUpIfNeeded() {
        guard isCatchingUpToLive else { return }
        isCatchingUpToLive = false
        if wantsPlaying, status == .playing || status == .buffering {
            engine.setRate(playbackRate)
        }
        emitProduction(.liveCatchUpChanged(active: false))
    }

    func updateEditorialTimeline(at time: TimeInterval) {
        let matches = currentSource?.editorialMarkers.filter { $0.contains(time) } ?? []
        let marker = matches.first(where: \.isSkippable) ?? matches.first
        guard marker?.id != activeEditorialMarker?.id else { return }
        activeEditorialMarker = marker
        emitProduction(.editorialMarkerChanged(id: marker?.id))

        if marker?.kind == .credits {
            presentUpNextIfAvailable()
        }
    }

    /// Seeks to the end of the active intro, recap, or credits range.
    public func skipActiveEditorialMarker() async {
        guard let marker = activeEditorialMarker, marker.isSkippable else { return }
        await seek(to: marker.end)
    }

    /// Presents the configured proposal, or derives one from the playback queue.
    public func presentUpNextIfAvailable() {
        guard !isUpNextPresented, let proposal = resolvedNextProposal else { return }
        nextContentProposal = proposal
        isUpNextPresented = true
        emitProduction(.upNextPresented(id: proposal.id))
        scheduleAutomaticUpNextAcceptance(for: proposal)
    }

    public func dismissUpNext() {
        guard isUpNextPresented, let proposal = nextContentProposal else { return }
        upNextTask?.cancel()
        upNextTask = nil
        isUpNextPresented = false
        emitProduction(.upNextDismissed(id: proposal.id))
    }

    public func acceptUpNext() async {
        guard isUpNextPresented, let proposal = nextContentProposal else { return }
        upNextTask?.cancel()
        upNextTask = nil
        isUpNextPresented = false
        emitProduction(.upNextAccepted(id: proposal.id))

        if playbackQueue?.nextItem?.id == proposal.id {
            await playbackQueue?.next()
        } else {
            await load(proposal.mediaSource)
            play()
        }
    }

    /// Requests native AVFoundation interstitial skip when currently eligible.
    public func skipActiveInterstitial() {
        guard canSkipInterstitial else { return }
        (engine as? any ManagedPlaybackControlling)?.skipCurrentInterstitial()
    }

    func evaluatePerformanceBudget() {
        let budget = configuration.performanceBudget
        if let actual = metrics.ttffMilliseconds,
           let maximum = budget.maximumTTFFMilliseconds,
           actual > maximum,
           emittedPerformanceViolations.insert("ttff").inserted
        {
            emitProduction(.performanceBudgetExceeded(
                .timeToFirstFrame(
                    actualMilliseconds: actual,
                    maximumMilliseconds: maximum
                )
            ))
        }
        if let maximum = budget.maximumRebufferCount,
           metrics.rebufferCount > maximum,
           emittedPerformanceViolations.insert("rebuffer-count").inserted
        {
            emitProduction(.performanceBudgetExceeded(
                .rebufferCount(actual: metrics.rebufferCount, maximum: maximum)
            ))
        }
        if let maximum = budget.maximumTotalRebufferMilliseconds,
           metrics.totalRebufferMilliseconds > maximum,
           emittedPerformanceViolations.insert("rebuffer-duration").inserted
        {
            emitProduction(.performanceBudgetExceeded(
                .totalRebuffer(
                    actualMilliseconds: metrics.totalRebufferMilliseconds,
                    maximumMilliseconds: maximum
                )
            ))
        }
    }

    func clearProductionFeatureState() {
        endLiveCatchUpIfNeeded()
        liveLatency = nil
        lastLiveLatencyEvent = nil
        activeEditorialMarker = nil
        activeInterstitialID = nil
        canSkipInterstitial = false
        isUpNextPresented = false
        upNextTask?.cancel()
        upNextTask = nil
    }

    private var resolvedNextProposal: NextContentProposal? {
        if let nextContentProposal {
            return nextContentProposal
        }
        guard let source = playbackQueue?.nextItem else { return nil }
        return NextContentProposal(
            id: source.id,
            sourceURL: source.url,
            title: source.title ?? PulsePlayerLocalization.string("up_next"),
            subtitle: source.subtitle,
            previewImageURL: source.posterURL,
            headers: source.headers,
            cookies: source.cookies
        )
    }

    private func scheduleAutomaticUpNextAcceptance(for proposal: NextContentProposal) {
        upNextTask?.cancel()
        guard let interval = proposal.automaticAcceptanceInterval, interval > 0 else {
            upNextTask = nil
            return
        }
        upNextTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return
            }
            guard let self,
                  self.isUpNextPresented,
                  self.nextContentProposal?.id == proposal.id
            else { return }
            await self.acceptUpNext()
        }
    }
}
