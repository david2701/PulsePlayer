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

    @Test func versionIs072() {
        #expect(PulsePlayerInfo.version == "0.7.2")
    }

    @Test func attributionCreditsAuthor() {
        #expect(PulsePlayerInfo.author == "David Villegas")
        #expect(PulsePlayerInfo.attribution.contains("David Villegas"))
    }
}
