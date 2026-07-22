import Foundation

/// Now Playing center abstraction (effective hooks in 0.2.0).
@MainActor
public protocol NowPlayingCentering: AnyObject {
    func update(title: String?, subtitle: String?, elapsed: TimeInterval, duration: TimeInterval?, rate: Float)
    func clear()
}

@MainActor
public final class NoOpNowPlayingCenter: NowPlayingCentering {
    public init() {}
    public func update(title: String?, subtitle: String?, elapsed: TimeInterval, duration: TimeInterval?, rate: Float) {}
    public func clear() {}
}
