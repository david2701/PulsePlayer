import Foundation

/// Simple local resume positions (UserDefaults-backed).
public final class ContinueWatchingStore: @unchecked Sendable {
    public static let shared = ContinueWatchingStore()

    private let defaults: UserDefaults
    private let prefix = "pulseplayer.continue."
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func save(sourceId: String, position: TimeInterval, duration: TimeInterval?) {
        // Don't save near start or near end.
        guard position > 5 else {
            remove(sourceId: sourceId)
            return
        }
        if let duration, duration > 0, position > duration * 0.95 {
            remove(sourceId: sourceId)
            return
        }
        lock.lock()
        defaults.set(position, forKey: prefix + sourceId)
        lock.unlock()
    }

    public func position(for sourceId: String) -> TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        let key = prefix + sourceId
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.double(forKey: key)
    }

    public func remove(sourceId: String) {
        lock.lock()
        defaults.removeObject(forKey: prefix + sourceId)
        lock.unlock()
    }
}
