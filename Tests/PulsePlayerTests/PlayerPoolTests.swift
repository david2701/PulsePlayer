import Foundation
import Testing
@testable import PulsePlayer

@Suite("PlayerPool")
@MainActor
struct PlayerPoolTests {
    private func mockDeps() -> (PlayerDependencies, [MockPlayerEngine]) {
        // Each session gets its own engine instance via factory.
        var engines: [MockPlayerEngine] = []
        let deps = PlayerDependencies.testing {
            let e = MockPlayerEngine()
            engines.append(e)
            return e
        }
        return (deps, engines)
    }

    private func source(_ id: String) -> MediaSource {
        MediaSource(id: id, url: URL(string: "https://example.com/\(id).mp4")!)
    }

    @Test func acquireLoadsAndReusesBySourceID() async {
        let (deps, _) = mockDeps()
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        let pool = PlayerPool(size: 3, configuration: config, dependencies: deps)

        let s1 = await pool.acquire(source: source("a"), priority: .visible)
        let s2 = await pool.acquire(source: source("a"), priority: .visible)
        #expect(s1.id == s2.id)
        #expect(pool.session(for: "a")?.id == s1.id)

        pool.shutdown()
    }

    @Test func poolRespectsSizeWithEviction() async {
        let (deps, _) = mockDeps()
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        let pool = PlayerPool(size: 2, configuration: config, dependencies: deps)

        _ = await pool.acquire(source: source("a"), priority: .visible)
        _ = await pool.acquire(source: source("b"), priority: .next)
        #expect(pool.sessions.count == 2)

        _ = await pool.acquire(source: source("c"), priority: .visible)
        #expect(pool.sessions.count == 2)
        #expect(pool.session(for: "c") != nil)

        pool.shutdown()
    }

    @Test func rebalanceSetsVisibleAndPausesOthers() async {
        let (deps, _) = mockDeps()
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        let pool = PlayerPool(size: 3, configuration: config, dependencies: deps)

        let a = await pool.acquire(source: source("a"), priority: .visible)
        let b = await pool.acquire(source: source("b"), priority: .next)
        #expect(a.status == .playing || a.status == .ready || a.status == .buffering)

        await pool.rebalance(visibleIDs: ["b", "a"])
        #expect(pool.session(for: "b") != nil)
        // b should be playing intent; a paused
        #expect(b.status == .playing || b.status == .ready || b.status == .buffering)
        #expect(a.status == .ready || a.status == .idle || a.status == .ended)

        pool.shutdown()
    }

    @Test func prewarmCreatesNextPrioritySessions() async {
        let (deps, _) = mockDeps()
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        let pool = PlayerPool(size: 3, configuration: config, dependencies: deps)

        await pool.prewarm([source("x"), source("y")])
        #expect(pool.session(for: "x") != nil)
        #expect(pool.session(for: "y") != nil)
        // Prewarm pauses after load
        #expect(pool.session(for: "x")?.status != .playing)

        pool.shutdown()
    }

    @Test func poolPriorityOrder() {
        #expect(PoolPriority.distant < PoolPriority.next)
        #expect(PoolPriority.next < PoolPriority.visible)
    }

    @Test func releaseRemovesSession() async {
        let (deps, _) = mockDeps()
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        let pool = PlayerPool(size: 3, configuration: config, dependencies: deps)
        let s = await pool.acquire(source: source("z"), priority: .visible)
        pool.release(s)
        #expect(pool.session(for: "z") == nil)
        pool.shutdown()
    }
}
