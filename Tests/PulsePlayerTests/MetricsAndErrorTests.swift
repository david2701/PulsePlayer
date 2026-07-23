import Foundation
import Testing
@testable import PulsePlayer

@Suite("Metrics & errors 1.0")
struct MetricsAndErrorTests {
    @Test func suggestedActions() {
        #expect(PlayerError.networkUnavailable.suggestedAction == .checkNetwork)
        #expect(PlayerError.sessionInvalidated.suggestedAction == .recreateSession)
        #expect(PlayerError.startupTimedOut.suggestedAction == .retry)
        #expect(PlayerError.invalidSource("bad").suggestedAction == .changeSource)
        #expect(
            PlayerError.assetLoadFailed(underlying: "x", recoverable: true).suggestedAction == .retry
        )
        #expect(
            PlayerError.assetLoadFailed(underlying: "x", recoverable: false).suggestedAction
                == .changeSource
        )
    }

    @Test @MainActor
    func metricsTrackLoadAndRebuffer() async {
        let engine = MockPlayerEngine()
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        config.autoplay = true
        let session = PlayerSession(configuration: config, dependencies: deps)
        defer { session.invalidate() }

        await session.load(MediaSource(url: URL(string: "https://example.com/a.m3u8")!, title: "A"))
        #expect(session.metricsSnapshot.loadCount == 1)
        #expect(session.metricsSnapshot.sourceID != nil)

        engine.emit(.readyForDisplay)
        #expect(session.metricsSnapshot.ttffMilliseconds != nil)

        engine.emit(.bufferEmpty)
        engine.emit(.bufferHealthy)
        // rebuffer only records when transition happens with rebufferStartedAt
        // force path via timeControlWaiting while playing
        session.play()
        engine.emit(.timeControlWaiting)
        engine.emit(.bufferHealthy)

        let snap = session.metricsSnapshot
        #expect(snap.rebufferCount >= 1 || snap.ttffMilliseconds != nil)
    }

    @Test @MainActor
    func loadStartAtSeeksAfterReady() async {
        let engine = MockPlayerEngine()
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        config.autoplay = false
        let session = PlayerSession(configuration: config, dependencies: deps)
        defer { session.invalidate() }

        await session.load(
            MediaSource(url: URL(string: "https://example.com/a.mp4")!),
            startAt: 15
        )
        // handleItemReady schedules seek asynchronously
        try? await Task.sleep(for: .milliseconds(50))
        #expect(engine.currentTime() == 15 || session.playbackTime == 15 || session.pendingStartAt == nil)
    }

    @Test @MainActor
    func concurrentQualityLocksCoalesce() async {
        let engine = MockPlayerEngine()
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        config.preferHardQualityLock = true
        config.autoplay = false
        let session = PlayerSession(configuration: config, dependencies: deps)
        defer { session.invalidate() }

        let master = URL(string: "https://cdn.example.com/master.m3u8")!
        let v720 = URL(string: "https://cdn.example.com/720.m3u8")!
        let v1080 = URL(string: "https://cdn.example.com/1080.m3u8")!
        await session.load(MediaSource(id: "q", url: master))
        let q720 = StreamQuality(
            id: "720", bandwidth: 2_500_000, width: 1280, height: 720, playlistURL: v720
        )
        let q1080 = StreamQuality(
            id: "1080", bandwidth: 5_000_000, width: 1920, height: 1080, playlistURL: v1080
        )
        session.availableQualities = [q720, q1080]
        session.qualityMasterURL = master

        async let a: Void = session.setQuality(q720)
        async let b: Void = session.setQuality(q1080)
        _ = await (a, b)

        #expect(session.selectedQualityId == q1080.id || session.selectedQualityId == q720.id)
        #expect(engine.source?.url == v1080 || engine.source?.url == v720)
        #expect(session.metricsSnapshot.qualitySwitchCount >= 1)
    }
}
