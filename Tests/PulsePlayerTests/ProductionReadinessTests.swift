import AVFoundation
import Foundation
import Testing
@testable import PulsePlayer

@Suite("Production readiness")
@MainActor
struct ProductionReadinessTests {
    @Test func credentialsRefreshAndPreservePlayback() async {
        let engine = MockPlayerEngine()
        let provider = CredentialProvider()
        let session = makeSession(engine: engine)
        session.credentialProvider = provider

        await session.load(source("credentials"))
        #expect(engine.source?.headers["Authorization"] == "Bearer token-1")

        session.play()
        engine.advanceTime(to: 34)
        await session.refreshPlaybackCredentials()
        try? await Task.sleep(for: .milliseconds(10))

        #expect(engine.replaceCount == 2)
        #expect(engine.source?.headers["Authorization"] == "Bearer token-2")
        #expect(engine.currentTime() == 34)
        #expect(session.metricsSnapshot.credentialRefreshCount == 2)
        session.invalidate()
    }

    @Test func expiringCredentialsRefreshProactively() async {
        let engine = MockPlayerEngine()
        let session = makeSession(engine: engine)
        session.credentialProvider = ExpiringCredentialProvider()

        await session.load(source("proactive-credentials"))
        await waitUntil { engine.replaceCount >= 2 }

        #expect(engine.replaceCount >= 2)
        #expect(session.metricsSnapshot.credentialRefreshCount >= 2)
        session.invalidate()
    }

    @Test func exhaustedOriginFallsBackToAlternateURL() async {
        let engine = MockPlayerEngine()
        let primary = URL(string: "https://origin.example/video.mp4")!
        let alternate = URL(string: "https://backup.example/video.mp4")!
        engine.replaceErrorByURL[primary] = URLError(.timedOut)
        let session = makeSession(engine: engine) {
            $0.retry.maxAttempts = 0
        }

        await session.load(MediaSource(
            id: "fallback",
            url: primary,
            fallbackURLs: [alternate]
        ))
        try? await Task.sleep(for: .milliseconds(30))

        #expect(engine.source?.url == alternate)
        #expect(session.currentSource?.url == alternate)
        #expect(session.metricsSnapshot.sourceFallbackCount == 1)
        session.invalidate()
    }

    @Test func audioInterruptionAndRouteLossAreHandled() async {
        let engine = MockPlayerEngine()
        let audio = EventAudioSession()
        let session = makeSession(engine: engine, audio: audio) {
            $0.autoplay = true
        }
        await session.load(source("audio"))
        #expect(engine.isPlaying)

        audio.emit(.interruptionBegan)
        await waitUntil { !engine.isPlaying }
        #expect(!engine.isPlaying)

        audio.emit(.interruptionEnded(shouldResume: true))
        await waitUntil { engine.isPlaying }
        #expect(engine.isPlaying)

        audio.emit(.routeChanged(reason: .oldDeviceUnavailable))
        await waitUntil { !engine.isPlaying }
        #expect(!engine.isPlaying)

        session.play()
        audio.emit(.mediaServicesLost)
        await waitUntil { !engine.isPlaying }
        audio.emit(.mediaServicesReset)
        await waitUntil { engine.isPlaying }
        #expect(engine.isPlaying)
        session.invalidate()
    }

    @Test func backgroundLifecycleUsesExplicitResumePolicy() async {
        let engine = MockPlayerEngine()
        let lifecycle = EventApplicationLifecycle()
        let session = makeSession(engine: engine, lifecycle: lifecycle) {
            $0.autoplay = true
            $0.resumesPlaybackAfterForeground = true
        }
        await session.load(source("lifecycle"))

        lifecycle.emit(.didEnterBackground)
        await waitUntil { !engine.isPlaying }
        #expect(!engine.isPlaying)

        lifecycle.emit(.didBecomeActive)
        await waitUntil { engine.isPlaying }
        #expect(engine.isPlaying)

        engine.emit(.readyForDisplay)
        lifecycle.emit(.memoryWarning)
        await Task.yield()
        #expect(session.scrubPreviewImage == nil)
        #expect(engine.cancelThumbnailCount > 0)
        session.invalidate()
    }

    @Test func telemetryKeepsSessionAndPlaybackCorrelation() async {
        let engine = MockPlayerEngine()
        let sink = TelemetrySink()
        let session = makeSession(engine: engine, telemetry: sink)
        let expectedSessionID = session.id

        await session.load(source("telemetry"))
        let expectedPlaybackID = session.playbackID
        session.play()
        session.invalidate()

        for _ in 0..<20 {
            if await sink.records().contains(where: {
                if case .stateChanged(_, .invalidated) = $0.event { true } else { false }
            }) {
                break
            }
            try? await Task.sleep(for: .milliseconds(2))
        }
        let records = await sink.records()
        #expect(!records.isEmpty)
        #expect(records.allSatisfy { $0.sessionID == expectedSessionID })
        #expect(records.contains { $0.playbackID == expectedPlaybackID })
    }

    @Test func liveLatencyCatchUpStartsAndStops() async {
        let engine = MockPlayerEngine()
        engine.seekable = 0...120
        let session = makeSession(engine: engine) {
            $0.autoplay = true
            $0.liveLatencyPolicy = LiveLatencyPolicy(
                targetLatency: 3,
                catchUpThreshold: 2,
                catchUpRate: 1.05
            )
        }
        await session.load(MediaSource(
            id: "live",
            url: URL(string: "https://example.com/live.mp4")!,
            isLive: true
        ))

        engine.advanceTime(to: 100)
        #expect(session.liveLatency == 20)
        #expect(session.isCatchingUpToLive)
        #expect(engine.rate == 1.05)

        engine.advanceTime(to: 118)
        #expect(!session.isCatchingUpToLive)
        #expect(engine.rate == 1)
        session.invalidate()
    }

    @Test func nativeLiveOffsetUsesTheConfiguredLatencyPolicy() {
        let engine = AVPlayerEngine()
        var configuration = PlayerConfiguration.default
        configuration.liveLatencyPolicy = LiveLatencyPolicy(
            targetLatency: 2.5,
            catchUpThreshold: 1,
            catchUpRate: 1.04
        )
        engine.applyConfiguration(configuration)
        let item = AVPlayerItem(
            url: URL(string: "https://example.com/live.m3u8")!
        )

        engine.applyItemConfiguration(to: item)

        #expect(item.configuredTimeOffsetFromLive.seconds == 2.5)
        #expect(item.automaticallyPreservesTimeOffsetFromLive)
        engine.tearDown()
    }

    @Test func nativeInterstitialControllerCoversServerAndClientSchedules() {
        let engine = AVPlayerEngine()
        let item = AVPlayerItem(
            url: URL(string: "https://example.com/main.m3u8")!
        )
        engine.avPlayer.replaceCurrentItem(with: item)
        engine.configureInterstitials(
            for: MediaSource(
                id: "server",
                url: URL(string: "https://example.com/server.m3u8")!
            ),
            primaryItem: item,
            generation: engine.currentGeneration
        )
        #expect(engine.interstitialController != nil)
        #expect(engine.interstitialController?.events.isEmpty == true)

        let clientSource = MediaSource(
            id: "client",
            url: URL(string: "https://example.com/client.m3u8")!,
            interstitials: [
                InterstitialDescriptor(
                    id: "ad-1",
                    time: 12,
                    assetURLs: [URL(string: "https://example.com/ad.m3u8")!],
                    skipAfter: 5
                ),
            ]
        )
        engine.configureInterstitials(
            for: clientSource,
            primaryItem: item,
            generation: engine.currentGeneration
        )

        #expect(engine.interstitialDescriptorByID["ad-1"] == clientSource.interstitials[0])
        #expect(engine.interstitialController != nil)
        engine.tearDown()
    }

    @Test func editorialSkipAndUpNextFlow() async {
        let engine = MockPlayerEngine()
        let session = makeSession(engine: engine)
        session.nextContentProposal = NextContentProposal(
            id: "episode-2",
            sourceURL: URL(string: "https://example.com/2.mp4")!,
            title: "Episode 2"
        )
        await session.load(MediaSource(
            id: "episode-1",
            url: URL(string: "https://example.com/1.mp4")!,
            editorialMarkers: [
                EditorialMarker(
                    id: "intro",
                    kind: .intro,
                    title: "Intro",
                    start: 5,
                    end: 15
                ),
                EditorialMarker(
                    id: "credits",
                    kind: .credits,
                    title: "Credits",
                    start: 100,
                    end: 120
                ),
            ]
        ))

        engine.advanceTime(to: 7)
        #expect(session.activeEditorialMarker?.id == "intro")
        await session.skipActiveEditorialMarker()
        #expect(engine.currentTime() == 15)

        engine.advanceTime(to: 105)
        #expect(session.isUpNextPresented)
        session.dismissUpNext()
        #expect(!session.isUpNextPresented)
        session.invalidate()
    }

    @Test func interstitialSignalsAndSkipAreMapped() async {
        let engine = MockPlayerEngine()
        let session = makeSession(engine: engine)
        await session.load(source("interstitial"))

        engine.emitProduction(.interstitialChanged(id: "ad-1"))
        engine.emitProduction(.interstitialSkippable(id: "ad-1", canSkip: true))
        #expect(session.activeInterstitialID == "ad-1")
        #expect(session.canSkipInterstitial)

        session.skipActiveInterstitial()
        #expect(engine.skipInterstitialCount == 1)
        engine.emitProduction(.interstitialChanged(id: nil))
        #expect(session.activeInterstitialID == nil)
        session.invalidate()
    }

    @Test func performanceBudgetEmitsViolationOnce() async {
        let engine = MockPlayerEngine()
        let session = makeSession(engine: engine) {
            $0.performanceBudget.maximumTTFFMilliseconds = 0
        }
        await session.load(source("budget"))
        let stream = session.makeProductionEventStream()
        engine.emit(.readyForDisplay)

        var iterator = stream.makeAsyncIterator()
        var violation: PerformanceBudgetViolation?
        for _ in 0..<3 {
            guard let event = await iterator.next() else { break }
            if case .performanceBudgetExceeded(let value) = event {
                violation = value
                break
            }
        }
        guard case .timeToFirstFrame = violation else {
            Issue.record("Expected a TTFF performance-budget violation")
            session.invalidate()
            return
        }
        session.invalidate()
    }

    @Test func persistableKeyFileStoreRoundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PulsePlayerKeys-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try PersistableContentKeyFileStore(directory: directory)
        let key = Data([0x01, 0x02, 0x03])

        try await store.storeContentKey(key, for: "asset/with unsafe:path")
        #expect(try await store.contentKey(for: "asset/with unsafe:path") == key)
        try await store.removeContentKey(for: "asset/with unsafe:path")
        #expect(try await store.contentKey(for: "asset/with unsafe:path") == nil)
    }

    @Test func httpErrorDiagnosticTriggersReauthenticationPath() async {
        let engine = MockPlayerEngine()
        engine.autoReady = false
        let session = makeSession(engine: engine) {
            $0.retry.maxAttempts = 0
        }
        await session.load(source("auth"))
        engine.emitProduction(.diagnostic(.errorLog(
            domain: "HTTP",
            statusCode: 401,
            comment: "Unauthorized"
        )))

        #expect(session.status == .failed)
        #expect(session.currentError?.suggestedAction == .reauthenticate)
        session.invalidate()
    }

    private func source(_ id: String) -> MediaSource {
        MediaSource(id: id, url: URL(string: "https://example.com/\(id).mp4")!)
    }

    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<20 where !predicate() {
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    private func makeSession(
        engine: MockPlayerEngine,
        audio: (any AudioSessionConfiguring)? = nil,
        lifecycle: (any ApplicationLifecycleObserving)? = nil,
        telemetry: any PlaybackTelemetrySink = NoOpPlaybackTelemetrySink(),
        configure: (inout PlayerConfiguration) -> Void = { _ in }
    ) -> PlayerSession {
        var configuration = PlayerConfiguration.default
        configuration.updatesNowPlayingInfo = false
        configuration.retry = RetryPolicy(
            maxAttempts: 1,
            baseDelay: .milliseconds(1),
            maxDelay: .milliseconds(2),
            jitter: 0
        )
        configure(&configuration)
        let dependencies = PlayerDependencies(
            telemetry: telemetry,
            applicationLifecycle: lifecycle ?? NoOpApplicationLifecycle(),
            clock: SystemPlayerClock(),
            network: AlwaysSatisfiedNetwork(),
            nowPlaying: NoOpNowPlayingCenter(),
            audioSession: audio ?? NoOpAudioSession(),
            log: DefaultPulsePlayerLogHandler(),
            engineFactory: { engine }
        )
        return PlayerSession(configuration: configuration, dependencies: dependencies)
    }
}
