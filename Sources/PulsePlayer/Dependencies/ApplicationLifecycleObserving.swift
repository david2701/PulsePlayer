import Foundation

public enum ApplicationLifecycleEvent: Sendable, Equatable {
    case willResignActive
    case didEnterBackground
    case willEnterForeground
    case didBecomeActive
    case memoryWarning
}
@MainActor
public protocol ApplicationLifecycleObserving: AnyObject {
    func makeEventStream() -> AsyncStream<ApplicationLifecycleEvent>
}

@MainActor
public final class NoOpApplicationLifecycle: ApplicationLifecycleObserving {
    public init() {}

    public func makeEventStream() -> AsyncStream<ApplicationLifecycleEvent> {
        AsyncStream { $0.finish() }
    }
}
