import Foundation
import Testing
@testable import PulsePlayer

/// Real AVPlayer smoke tests against Apple sample HLS.
/// Opt in explicitly so a missing network can never be reported as a passing test.
@Suite(
    "AV integration",
    .enabled(
        if: ProcessInfo.processInfo.environment["PULSEPLAYER_RUN_NETWORK_TESTS"] == "1",
        "Set PULSEPLAYER_RUN_NETWORK_TESTS=1 to run network integration tests."
    )
)
struct AVIntegrationTests {
    private static let bipbop = URL(string:
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    )!

    @Test @MainActor
    func realHLSBecomesReady() async throws {
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
                Issue.record("HLS load failed: \(session.currentError?.userMessage ?? "unknown error")")
                break
            }
            try await Task.sleep(for: .milliseconds(400))
        }

        #expect(ready)
        #expect(session.metricsSnapshot.loadCount == 1)
        #expect(!session.availableQualities.isEmpty || session.status == .ready)
    }

    @Test @MainActor
    func realHLSPlaySeek() async throws {
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
            if session.status == .failed {
                Issue.record("HLS playback failed: \(session.currentError?.userMessage ?? "unknown error")")
                break
            }
            try await Task.sleep(for: .milliseconds(400))
        }
        #expect(ok)
        guard ok else { return }

        await session.seek(to: 5)
        #expect(session.playbackTime >= 4)
        session.pause()
    }
}
