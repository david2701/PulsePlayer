import Foundation

/// Audio session configuration (effective in 0.2.0).
@MainActor
public protocol AudioSessionConfiguring: AnyObject {
    func activateForPlayback(background: Bool) throws
    func deactivate() throws
}

@MainActor
public final class NoOpAudioSession: AudioSessionConfiguring {
    public init() {}
    public func activateForPlayback(background: Bool) throws {}
    public func deactivate() throws {}
}
