import Foundation

/// Injectable dependencies for sessions and tests.
@MainActor
public struct PlayerDependencies {
    public var clock: any PlayerClock
    public var network: any PlayerNetworkPath
    public var nowPlaying: any NowPlayingCentering
    public var audioSession: any AudioSessionConfiguring
    public var log: any PulsePlayerLogHandler
    /// Factory for the playback engine (package; tests / internal).
    package var engineFactory: @MainActor () -> any PlaybackControlling

    /// Public production-oriented initializer (default AVPlayer engine + platform hooks).
    public init(
        clock: any PlayerClock = SystemPlayerClock(),
        network: any PlayerNetworkPath = SystemPlayerNetworkPath(),
        nowPlaying: (any NowPlayingCentering)? = nil,
        audioSession: (any AudioSessionConfiguring)? = nil,
        log: any PulsePlayerLogHandler = DefaultPulsePlayerLogHandler()
    ) {
        self.clock = clock
        self.network = network
        self.nowPlaying = nowPlaying ?? SystemNowPlayingCenter()
        self.audioSession = audioSession ?? SystemAudioSession()
        self.log = log
        self.engineFactory = { AVPlayerEngine() }
    }

    /// Package initializer for custom engines (tests).
    package init(
        clock: any PlayerClock,
        network: any PlayerNetworkPath,
        nowPlaying: any NowPlayingCentering,
        audioSession: any AudioSessionConfiguring,
        log: any PulsePlayerLogHandler,
        engineFactory: @escaping @MainActor () -> any PlaybackControlling
    ) {
        self.clock = clock
        self.network = network
        self.nowPlaying = nowPlaying
        self.audioSession = audioSession
        self.log = log
        self.engineFactory = engineFactory
    }

    public static var production: PlayerDependencies {
        PlayerDependencies()
    }

    package static func testing(
        engine: @escaping @MainActor () -> any PlaybackControlling,
        clock: any PlayerClock = SystemPlayerClock(),
        network: any PlayerNetworkPath = AlwaysSatisfiedNetwork()
    ) -> PlayerDependencies {
        PlayerDependencies(
            clock: clock,
            network: network,
            nowPlaying: NoOpNowPlayingCenter(),
            audioSession: NoOpAudioSession(),
            log: DefaultPulsePlayerLogHandler(),
            engineFactory: engine
        )
    }
}

public struct AlwaysSatisfiedNetwork: PlayerNetworkPath {
    public init() {}
    public var isSatisfied: Bool { true }
}
