import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Bridges UIKit process lifecycle notifications into an async event stream.
@MainActor
public final class SystemApplicationLifecycle: ApplicationLifecycleObserving {
    public static let shared = SystemApplicationLifecycle()

    public init() {}

    public func makeEventStream() -> AsyncStream<ApplicationLifecycleEvent> {
        #if canImport(UIKit)
        let center = NotificationCenter.default
        let names: [(Notification.Name, ApplicationLifecycleEvent)] = [
            (UIApplication.willResignActiveNotification, .willResignActive),
            (UIApplication.didEnterBackgroundNotification, .didEnterBackground),
            (UIApplication.willEnterForegroundNotification, .willEnterForeground),
            (UIApplication.didBecomeActiveNotification, .didBecomeActive),
            (UIApplication.didReceiveMemoryWarningNotification, .memoryWarning),
        ]
        return AsyncStream(bufferingPolicy: .bufferingNewest(16)) { continuation in
            let tokenBox = LifecycleObserverTokens(center: center)
            tokenBox.set(names.map { name, event in
                center.addObserver(forName: name, object: nil, queue: nil) { _ in
                    continuation.yield(event)
                }
            })
            continuation.onTermination = { _ in
                tokenBox.removeAll()
            }
        }
        #else
        return AsyncStream { $0.finish() }
        #endif
    }
}

#if canImport(UIKit)
private final class LifecycleObserverTokens: @unchecked Sendable {
    let center: NotificationCenter
    private let lock = NSLock()
    private var tokens: [NSObjectProtocol] = []

    init(center: NotificationCenter) {
        self.center = center
    }

    func set(_ tokens: [NSObjectProtocol]) {
        lock.lock()
        self.tokens = tokens
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        let snapshot = tokens
        tokens = []
        lock.unlock()
        for token in snapshot {
            center.removeObserver(token)
        }
    }
}
#endif
