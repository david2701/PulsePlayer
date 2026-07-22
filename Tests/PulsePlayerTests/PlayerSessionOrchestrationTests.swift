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
            MediaSource(url: URL(string: "https://example.com/live.m3u8")!, isLive: true)
        )
        engine.emit(.didPlayToEnd)
        #expect(session.status != .ended)
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
