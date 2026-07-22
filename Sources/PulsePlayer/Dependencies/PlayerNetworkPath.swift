import Foundation
import Network

/// Coarse network availability for recovery decisions.
public protocol PlayerNetworkPath: Sendable {
    var isSatisfied: Bool { get }
}

/// Default path monitor snapshot (best-effort).
public final class SystemPlayerNetworkPath: PlayerNetworkPath, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.pulseplayer.network")
    private let lock = NSLock()
    private var _satisfied = true

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            self._satisfied = path.status == .satisfied
            self.lock.unlock()
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    public var isSatisfied: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _satisfied
    }
}
