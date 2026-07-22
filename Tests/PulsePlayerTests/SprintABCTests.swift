import Foundation
import Testing
@testable import PulsePlayer

@Suite("Sprint A/B/C foundations")
struct SprintABCTests {
    @Test func hlsMasterParserExtractsQualities() {
        let master = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
        low.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720
        mid.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
        hi.m3u8
        """
        let q = HLSMasterParser.parseQualities(from: master)
        #expect(q.count == 3)
        #expect(q.first?.height == 1080)
        #expect(q.contains(where: { $0.height == 720 }))
    }

    @Test func continueWatchingSaveAndClearNearEnd() {
        let store = ContinueWatchingStore(
            defaults: UserDefaults(suiteName: "pulse.test.\(UUID().uuidString)")!
        )
        store.save(sourceId: "ep1", position: 30, duration: 100)
        #expect(store.position(for: "ep1") == 30)
        store.save(sourceId: "ep1", position: 98, duration: 100)
        #expect(store.position(for: "ep1") == nil)
        store.save(sourceId: "ep1", position: 2, duration: 100)
        #expect(store.position(for: "ep1") == nil)
    }

    @Test @MainActor
    func playbackQueueAdvances() async {
        let engine = MockPlayerEngine()
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        config.autoplay = false
        let session = PlayerSession(configuration: config, dependencies: deps)
        let queue = PlaybackQueue(
            items: [
                MediaSource(id: "a", url: URL(string: "https://example.com/a.m3u8")!),
                MediaSource(id: "b", url: URL(string: "https://example.com/b.m3u8")!),
            ],
            autoplayNext: true
        )
        queue.session = session
        session.playbackQueue = queue
        await queue.play(at: 0)
        #expect(queue.currentIndex == 0)
        #expect(engine.replaceCount == 1)
        await queue.next()
        #expect(queue.currentIndex == 1)
        #expect(engine.replaceCount == 2)
        session.invalidate()
    }

    @Test @MainActor
    func qualitySelectionSetsPeakBitrate() async {
        let engine = MockPlayerEngine()
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        let session = PlayerSession(configuration: config, dependencies: deps)
        session.availableQualities = [
            StreamQuality(id: "720", bandwidth: 2_500_000, width: 1280, height: 720)
        ]
        session.setQuality(session.availableQualities[0])
        #expect(engine.peakBitRate == 2_500_000)
        session.setQualityAuto()
        #expect(engine.peakBitRate == 0)
        session.invalidate()
    }

    @Test @MainActor
    func liveClampUsesSeekable() async {
        let engine = MockPlayerEngine()
        engine.seekable = 100...200
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        let session = PlayerSession(configuration: config, dependencies: deps)
        await session.load(
            MediaSource(id: "live", url: URL(string: "https://example.com/live.m3u8")!, isLive: true)
        )
        #expect(session.clampLiveSeek(50) == 100)
        #expect(session.clampLiveSeek(250) == 200)
        session.invalidate()
    }
}
