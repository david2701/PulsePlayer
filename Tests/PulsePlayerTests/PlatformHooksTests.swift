import Foundation
import Testing
@testable import PulsePlayer

@Suite("Platform hooks 0.2")
@MainActor
struct PlatformHooksTests {
    @Test func pipInactiveWithoutLayer() {
        let pip = PictureInPictureController()
        #expect(!pip.isPossible)
        #expect(!pip.isActive)
        pip.start() // no-op
        #expect(!pip.isActive)
    }

    @Test func sessionExposesPiPAPI() async {
        let engine = MockPlayerEngine()
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.allowsPictureInPicture = true
        config.updatesNowPlayingInfo = false
        let session = PlayerSession(configuration: config, dependencies: deps)
        #expect(!session.isPictureInPictureActive)
        session.startPictureInPicture() // no layer → no-op
        #expect(!session.isPictureInPictureActive)
        session.invalidate()
    }

    @Test func productionDependenciesUseSystemHooks() {
        let deps = PlayerDependencies.production
        #expect(deps.nowPlaying is SystemNowPlayingCenter)
        #expect(deps.audioSession is SystemAudioSession)
    }

    @Test func versionIs100() {
        #expect(PulsePlayerInfo.version == "1.0.0")
    }

    @Test func attributionCreditsAuthor() {
        #expect(PulsePlayerInfo.author == "David Villegas")
        #expect(PulsePlayerInfo.attribution.contains("David Villegas"))
    }

    @Test func audioOwnershipCanMoveBackToTheHost() async {
        let engine = MockPlayerEngine()
        let audio = MockAudioSession()
        let deps = PlayerDependencies(
            clock: SystemPlayerClock(),
            network: AlwaysSatisfiedNetwork(),
            nowPlaying: NoOpNowPlayingCenter(),
            audioSession: audio,
            log: DefaultPulsePlayerLogHandler(),
            engineFactory: { engine }
        )
        var config = PlayerConfiguration.default
        config.autoplay = true
        config.updatesNowPlayingInfo = false
        let session = PlayerSession(configuration: config, dependencies: deps)
        await session.load(MediaSource(url: URL(string: "https://example.com/a.mp4")!))
        #expect(audio.activationCount == 1)

        session.updateConfiguration { $0.managesAudioSession = false }
        #expect(audio.deactivationCount == 1)

        session.updateConfiguration { $0.managesAudioSession = true }
        #expect(audio.activationCount == 2)
        session.invalidate()
        #expect(audio.deactivationCount == 2)
    }

    @Test func lifetimeFallbackTearsDownForgottenSession() async {
        let engine = MockPlayerEngine()
        let audio = MockAudioSession()
        let deps = PlayerDependencies(
            clock: SystemPlayerClock(),
            network: AlwaysSatisfiedNetwork(),
            nowPlaying: NoOpNowPlayingCenter(),
            audioSession: audio,
            log: DefaultPulsePlayerLogHandler(),
            engineFactory: { engine }
        )
        var config = PlayerConfiguration.default
        config.autoplay = true
        config.updatesNowPlayingInfo = false
        var session: PlayerSession? = PlayerSession(
            configuration: config,
            dependencies: deps
        )
        weak let weakSession = session
        await session?.load(
            MediaSource(url: URL(string: "https://example.com/a.mp4")!)
        )
        #expect(audio.activationCount == 1)

        session = nil
        await Task.yield()
        await Task.yield()

        #expect(weakSession == nil)
        #expect(audio.deactivationCount == 1)
        #expect(engine.tearDownCount == 1)
    }
}

@MainActor
private final class MockAudioSession: AudioSessionConfiguring {
    private(set) var activationCount = 0
    private(set) var deactivationCount = 0

    func activateForPlayback(background: Bool) throws {
        _ = background
        activationCount += 1
    }

    func deactivate() throws {
        deactivationCount += 1
    }
}
