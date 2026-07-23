import Foundation
import Testing
@testable import PulsePlayer

@Suite("Sprint A/B/C foundations")
struct SprintABCTests {
    @Test func hlsMasterParserExtractsQualities() {
        let base = URL(string: "https://cdn.example.com/hls/master.m3u8")!
        let master = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
        low.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720
        mid.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
        hi.m3u8
        """
        let q = HLSMasterParser.parseQualities(from: master, baseURL: base)
        #expect(q.count == 3)
        #expect(q.first?.height == 1080)
        #expect(q.contains(where: { $0.height == 720 }))
        #expect(q.first?.playlistURL?.absoluteString == "https://cdn.example.com/hls/hi.m3u8")
        #expect(q.first?.supportsHardLock == true)
    }

    @Test func hlsMasterParserIgnoresVariantWithoutURI() {
        let master = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=100000
        # a comment, but no URI
        #EXT-X-STREAM-INF:BANDWIDTH=200000
        valid.m3u8
        """
        let qualities = HLSMasterParser.parseQualities(
            from: master,
            baseURL: URL(string: "https://example.com/master.m3u8")!
        )
        #expect(qualities.count == 1)
        #expect(qualities[0].bandwidth == 200_000)
        #expect(
            qualities[0].playlistURL?.absoluteString
                == "https://example.com/valid.m3u8"
        )
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
                MediaSource(id: "a", url: URL(string: "https://example.com/a.mp4")!),
                MediaSource(id: "b", url: URL(string: "https://example.com/b.mp4")!),
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
        config.preferHardQualityLock = false
        let session = PlayerSession(configuration: config, dependencies: deps)
        session.availableQualities = [
            StreamQuality(id: "720", bandwidth: 2_500_000, width: 1280, height: 720)
        ]
        await session.setQuality(session.availableQualities[0])
        #expect(engine.peakBitRate == 2_500_000)
        await session.setQualityAuto()
        #expect(engine.peakBitRate == 0)
        session.invalidate()
    }

    @Test @MainActor
    func qualityHardLockReloadsVariantPlaylist() async {
        let engine = MockPlayerEngine()
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        config.preferHardQualityLock = true
        config.autoplay = false
        let session = PlayerSession(configuration: config, dependencies: deps)
        let master = URL(string: "https://cdn.example.com/master.mp4")!
        let variant = URL(string: "https://cdn.example.com/720.m3u8")!
        await session.load(MediaSource(id: "ep", url: master, title: "Q"))
        let locked = StreamQuality(
            id: "720",
            bandwidth: 2_500_000,
            width: 1280,
            height: 720,
            playlistURL: variant
        )
        session.availableQualities = [locked]
        session.qualityMasterURL = master
        await session.setQuality(locked)
        #expect(engine.source?.url == variant)
        #expect(session.isQualityHardLocked)
        #expect(engine.peakBitRate == 2_500_000)
        await session.setQualityAuto()
        #expect(engine.source?.url == master)
        #expect(!session.isQualityHardLocked)
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
            MediaSource(id: "live", url: URL(string: "https://example.com/live.mp4")!, isLive: true)
        )
        #expect(session.clampLiveSeek(50) == 100)
        #expect(session.clampLiveSeek(250) == 200)
        session.invalidate()
    }
}
