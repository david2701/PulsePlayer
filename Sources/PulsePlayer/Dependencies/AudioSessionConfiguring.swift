import Foundation

public enum AudioRouteChangeReason: Sendable, Equatable {
    case newDeviceAvailable
    case oldDeviceUnavailable
    case categoryChange
    case override
    case wakeFromSleep
    case noSuitableRoute
    case routeConfigurationChange
    case unknown
}

public enum AudioSessionEvent: Sendable, Equatable {
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case routeChanged(reason: AudioRouteChangeReason)
    case mediaServicesLost
    case mediaServicesReset
}

/// Audio session configuration (effective in 0.2.0).
@MainActor
public protocol AudioSessionConfiguring: AnyObject {
    func activateForPlayback(background: Bool) throws
    func deactivate() throws
    func makeEventStream() -> AsyncStream<AudioSessionEvent>
}

public extension AudioSessionConfiguring {
    func makeEventStream() -> AsyncStream<AudioSessionEvent> {
        AsyncStream { $0.finish() }
    }
}

@MainActor
public final class NoOpAudioSession: AudioSessionConfiguring {
    public init() {}
    public func activateForPlayback(background: Bool) throws {}
    public func deactivate() throws {}
}
