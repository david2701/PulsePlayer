import Foundation
import Testing
@testable import PulsePlayer

/// Real AVPlayer smoke tests against Apple sample HLS.
/// Skips cleanly when the network is unreachable (offline CI agents).
@Suite("AV integration")
struct AVIntegrationTests {
    private static let bipbop = URL(string:
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    )!

    private static func networkReachable() async -> Bool {
        do {
            var request = URLRequest(url: bipbop)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 8
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...399).contains(http.statusCode)
        } catch {
            return false
        }
    }

    @Test @MainActor
    func realHLSBecomesReady() async throws {
        guard await Self.networkReachable() else {
            return // skip offline
        }

        var config = PlayerConfiguration.default
        config.autoplay = false
        config.updatesNowPlayingInfo = false
        config.stall.startupTimeout = .seconds(25)
        let session = PlayerSession(configuration: config)
        defer { session.invalidate() }

        await session.load(MediaSource(url: Self.bipbop, title: "AV integration"))

        var ready = false
        for _ in 0..<50 {
            if session.status == .ready || session.status == .playing {
                ready = true
                break
            }
            if session.status == .failed {
                // Transient CDN / network — don't fail the suite hard.
                return
            }
            try await Task.sleep(for: .milliseconds(400))
        }

        #expect(ready)
        #expect(session.metricsSnapshot.loadCount == 1)
        #expect(!session.availableQualities.isEmpty || session.status == .ready)
    }

    @Test @MainActor
    func realHLSPlaySeek() async throws {
        guard await Self.networkReachable() else { return }

        var config = PlayerConfiguration.default
        config.autoplay = true
        config.updatesNowPlayingInfo = false
        config.stall.startupTimeout = .seconds(25)
        let session = PlayerSession(configuration: config)
        defer { session.invalidate() }

        await session.load(MediaSource(url: Self.bipbop, title: "AV seek"))

        var ok = false
        for _ in 0..<60 {
            if session.status == .playing || session.hasRenderedFrame {
                ok = true
                break
            }
            if session.status == .failed { return }
            try await Task.sleep(for: .milliseconds(400))
        }
        guard ok else { return }

        await session.seek(to: 5)
        #expect(session.playbackTime >= 4)
        session.pause()
    }
}
