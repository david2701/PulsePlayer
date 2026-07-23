import Foundation
import Testing
@testable import PulsePlayer

@Suite("PlayerSession orchestration")
@MainActor
struct PlayerSessionOrchestrationTests {
    private func makeSession(
        autoplay: Bool = false,
        engine: MockPlayerEngine
    ) -> PlayerSession {
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.autoplay = autoplay
        config.retry = RetryPolicy(maxAttempts: 2, baseDelay: .milliseconds(1), maxDelay: .milliseconds(5), jitter: 0)
        config.stall = StallPolicy(
            stallThreshold: .milliseconds(50),
            startupTimeout: .seconds(5),
            recoverProbeInterval: .milliseconds(10)
        )
        return PlayerSession(configuration: config, dependencies: deps)
    }

    @Test func loadReadyPlayHappyPath() async {
        let engine = MockPlayerEngine()
        let session = makeSession(engine: engine)
        let url = URL(string: "https://example.com/v.mp4")!
        await session.load(MediaSource(id: "a", url: url))

        #expect(session.status == .ready)
        #expect(session.currentSource?.id == "a")
        #expect(engine.replaceCount == 1)

        session.play()
        #expect(session.status == .playing)
        #expect(engine.isPlaying)

        session.invalidate()
        #expect(session.status == .invalidated)
    }

    @Test func autoplayEntersPlaying() async {
        let engine = MockPlayerEngine()
        let session = makeSession(autoplay: true, engine: engine)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))
        #expect(session.status == .playing || session.status == .ready)
        // autoplayGate / play should have run
        #expect(engine.isPlaying)
        session.invalidate()
    }

    @Test func pauseDuringLoadCancelsAutoplayIntent() async {
        let engine = MockPlayerEngine()
        engine.autoReady = false
        let session = makeSession(autoplay: true, engine: engine)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))
        session.pause()
        engine.emit(.itemStatusReady)

        #expect(session.status == .ready)
        #expect(!engine.isPlaying)
        session.invalidate()
    }

    @Test func itemFailureSetsFailed() async {
        let engine = MockPlayerEngine()
        engine.autoReady = false
        let session = makeSession(engine: engine)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))
        #expect(session.status == .loading)
        engine.emit(.itemFailed(domain: "NSURLErrorDomain", code: -1009, message: "offline"))
        #expect(session.status == .failed)
        #expect(session.currentError?.isRecoverable == true)
        session.invalidate()
    }

    @Test func liveDoesNotEnd() async {
        let engine = MockPlayerEngine()
        let session = makeSession(autoplay: true, engine: engine)
        await session.load(
            MediaSource(url: URL(string: "https://example.com/live.mp4")!, isLive: true)
        )
        engine.emit(.didPlayToEnd)
        #expect(session.status != .ended)
        session.invalidate()
    }

    @Test func loopRestartsPlaybackWithoutIllegalTransition() async {
        let engine = MockPlayerEngine()
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.autoplay = true
        config.loop = true
        config.updatesNowPlayingInfo = false
        let session = PlayerSession(configuration: config, dependencies: deps)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))
        engine.advanceTime(to: 120)

        engine.emit(.didPlayToEnd)
        try? await Task.sleep(for: .milliseconds(20))

        #expect(session.status == .playing)
        #expect(engine.currentTime() == 0)
        #expect(engine.isPlaying)
        session.invalidate()
    }

    @Test func timeControlRecoveryClosesRebufferMetrics() async {
        let engine = MockPlayerEngine()
        let session = makeSession(autoplay: true, engine: engine)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))

        engine.emit(.timeControlWaiting)
        #expect(session.status == .buffering)
        try? await Task.sleep(for: .milliseconds(2))
        engine.emit(.timeControlPlaying)

        #expect(session.status == .playing)
        #expect(session.metricsSnapshot.rebufferCount == 1)
        #expect(session.rebufferStartedAt == nil)
        session.invalidate()
    }

    @Test func rateStartsReadyPlaybackAndZeroPausesWithoutLosingPreference() async {
        let engine = MockPlayerEngine()
        let session = makeSession(engine: engine)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))

        session.setRate(2)
        #expect(session.status == .playing)
        #expect(session.playbackRate == 2)
        #expect(engine.rate == 2)

        session.setRate(0)
        #expect(session.status == .ready)
        #expect(session.playbackRate == 2)
        session.play()
        #expect(session.status == .playing)
        #expect(engine.rate == 2)
        session.invalidate()
    }

    @Test func resumeOnlyRetryLeavesLoadingState() async {
        let engine = MockPlayerEngine()
        engine.autoReady = false
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        config.retry.maxAttempts = 0
        config.retry.reloadItemOnRetry = false
        let session = PlayerSession(configuration: config, dependencies: deps)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))
        engine.emit(
            .itemFailed(
                domain: NSURLErrorDomain,
                code: NSURLErrorTimedOut,
                message: "timeout"
            )
        )

        await session.retry()

        #expect(session.status == .playing)
        #expect(engine.isPlaying)
        session.invalidate()
    }

    @Test func seekCompletes() async {
        let engine = MockPlayerEngine()
        let session = makeSession(engine: engine)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))
        await session.seek(to: 12)
        #expect(engine.currentTime() == 12)
        session.invalidate()
    }

    @Test func latestSeekWinsAndCancelsOlderSeek() async {
        let engine = MockPlayerEngine()
        engine.seekDelayByTime[10] = .milliseconds(80)
        engine.seekDelayByTime[20] = .milliseconds(1)
        let session = makeSession(engine: engine)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))

        let first = Task { @MainActor in
            await session.seek(to: 10)
        }
        try? await Task.sleep(for: .milliseconds(10))
        await session.seek(to: 20)
        await first.value

        #expect(engine.currentTime() == 20)
        #expect(session.playbackTime == 20)
        #expect(!session.isSeeking)
        #expect(engine.cancelSeekCount >= 2)
        session.invalidate()
    }

    @Test func resetClearsEngineAndSessionCanBeReused() async {
        let engine = MockPlayerEngine()
        let session = makeSession(engine: engine)
        await session.load(MediaSource(id: "first", url: URL(string: "https://example.com/1.mp4")!))
        await session.reset()

        #expect(session.status == .idle)
        #expect(session.currentSource == nil)
        #expect(engine.source == nil)
        #expect(engine.clearCount == 1)
        #expect(session.playbackTime == 0)

        await session.load(MediaSource(id: "second", url: URL(string: "https://example.com/2.mp4")!))
        #expect(session.status == .ready)
        #expect(session.currentSource?.id == "second")
        #expect(engine.replaceCount == 2)
        session.invalidate()
    }

    @Test func invalidateIsIdempotent() async {
        let engine = MockPlayerEngine()
        let session = makeSession(engine: engine)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))
        session.invalidate()
        session.invalidate()

        #expect(session.status == .invalidated)
        #expect(session.currentError == .sessionInvalidated)
        #expect(engine.tearDownCount == 1)
    }

    @Test func invalidatePublishesTerminalStateThenFinishesEventStream() async {
        let engine = MockPlayerEngine()
        let session = makeSession(engine: engine)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))
        let stream = session.makeEventStream()
        let collector = Task { @MainActor in
            var events: [PlayerEvent] = []
            for await event in stream {
                events.append(event)
            }
            return events
        }

        session.invalidate()
        let events = await collector.value

        #expect(
            events.contains(
                .stateChanged(from: .ready, to: .invalidated)
            )
        )
    }

    @Test func startupTimeoutClearsThePendingItem() async {
        let engine = MockPlayerEngine()
        engine.autoReady = false
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        config.retry.maxAttempts = 0
        config.stall.startupTimeout = .milliseconds(20)
        let session = PlayerSession(configuration: config, dependencies: deps)

        await session.load(MediaSource(url: URL(string: "https://example.com/slow.mp4")!))
        try? await Task.sleep(for: .milliseconds(60))

        #expect(session.status == .failed)
        #expect(session.currentError == .startupTimedOut)
        #expect(engine.clearCount == 1)
        #expect(engine.source == nil)
        session.invalidate()
    }

    @Test func replacingAnInFlightLoadEmitsCancellationTransition() async {
        let engine = MockPlayerEngine()
        engine.autoReady = false
        let session = makeSession(engine: engine)
        await session.load(MediaSource(id: "a", url: URL(string: "https://example.com/a.mp4")!))
        let stream = session.makeEventStream()

        await session.load(MediaSource(id: "b", url: URL(string: "https://example.com/b.mp4")!))
        var iterator = stream.makeAsyncIterator()
        let cancelled = await iterator.next()
        let restarted = await iterator.next()

        #expect(cancelled == .stateChanged(from: .loading, to: .idle))
        #expect(restarted == .stateChanged(from: .idle, to: .loading))
        #expect(session.currentSource?.id == "b")
        session.invalidate()
    }

    @Test func positionEventsAreThrottledButObservedTimeStaysCurrent() async {
        let engine = MockPlayerEngine()
        let session = makeSession(engine: engine)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))
        let stream = session.makeEventStream()
        let collector = Task { @MainActor in
            var positions: [TimeInterval] = []
            for await event in stream {
                if case .position(let value) = event {
                    positions.append(value)
                }
                if event == .warning("test-finished") {
                    break
                }
            }
            return positions
        }

        engine.advanceTime(to: 0)
        engine.advanceTime(to: 0.1)
        engine.advanceTime(to: 0.49)
        engine.advanceTime(to: 0.5)
        engine.advanceTime(to: 0.75)
        session.emit(.warning("test-finished"))
        let positions = await collector.value

        #expect(positions == [0, 0.5])
        #expect(session.playbackTime == 0.75)
        session.invalidate()
    }

    @Test func nonRecoverableRetryIsNoOp() async {
        let engine = MockPlayerEngine()
        engine.autoReady = false
        let session = makeSession(engine: engine)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))
        engine.emit(
            .itemFailed(
                domain: "AVFoundationErrorDomain",
                code: -11828,
                message: "format"
            )
        )
        #expect(session.status == .failed)
        let replaces = engine.replaceCount
        await session.retry()
        #expect(engine.replaceCount == replaces)
        session.invalidate()
    }
}
