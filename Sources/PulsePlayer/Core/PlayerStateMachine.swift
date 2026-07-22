/// Closed set of state-machine events (DESIGN §3.2).
public enum PlayerStateEvent: Sendable, Equatable {
    case load
    case loadCancelled
    case itemReady
    case play
    case pause
    case bufferEmpty
    case bufferHealthy
    case stallTimeout
    case fail
    case didPlayToEnd
    case retry
    case reset
    case invalidate
    case loopAdvance
    case autoplayGate
}

/// Result of applying an event to a status.
public enum PlayerTransition: Sendable, Equatable {
    case to(PlayerStatus)
    case stay
    case illegal
}

/// Pure, MainActor-free state machine. All public status changes go through here.
public enum PlayerStateMachine: Sendable {
    /// Applies `event` to `status`. `isLive` affects `didPlayToEnd` only.
    public static func transition(
        status: PlayerStatus,
        event: PlayerStateEvent,
        isLive: Bool = false
    ) -> PlayerTransition {
        if status == .invalidated {
            return event == .invalidate ? .stay : .illegal
        }

        switch event {
        case .load:
            return status == .invalidated ? .illegal : .to(.loading)

        case .loadCancelled:
            switch status {
            case .loading: return .to(.idle)
            case .idle: return .stay
            default: return .illegal
            }

        case .itemReady:
            switch status {
            case .loading: return .to(.ready)
            case .ready: return .stay
            case .stalled: return .to(.ready)
            default: return .illegal
            }

        case .play:
            switch status {
            case .ready: return .to(.playing)
            case .playing, .buffering, .loading, .stalled: return .stay
            case .ended: return .to(.playing)
            case .idle, .failed, .invalidated: return .illegal
            }

        case .pause:
            switch status {
            case .playing, .buffering, .stalled: return .to(.ready)
            case .ready, .idle, .loading, .failed: return .stay
            case .ended: return .to(.ready)
            case .invalidated: return .illegal
            }

        case .bufferEmpty:
            switch status {
            case .ready, .playing: return .to(.buffering)
            case .buffering, .stalled, .loading: return .stay
            default: return .illegal
            }

        case .bufferHealthy:
            switch status {
            case .buffering, .stalled: return .to(.playing)
            case .playing, .ready: return .stay
            default: return .illegal
            }

        case .stallTimeout:
            switch status {
            case .buffering: return .to(.stalled)
            case .stalled: return .stay
            case .loading: return .illegal
            default: return .illegal
            }

        case .fail:
            switch status {
            case .loading, .ready, .playing, .buffering, .stalled:
                return .to(.failed)
            case .failed: return .stay
            default: return .illegal
            }

        case .didPlayToEnd:
            if isLive { return .stay }
            switch status {
            case .playing, .buffering: return .to(.ended)
            case .ended: return .stay
            default: return .illegal
            }

        case .retry:
            switch status {
            case .stalled, .failed: return .to(.loading)
            default: return .illegal
            }

        case .reset:
            switch status {
            case .invalidated: return .illegal
            default: return .to(.idle)
            }

        case .invalidate:
            return .to(.invalidated)

        case .loopAdvance:
            switch status {
            case .ended: return .to(.playing)
            default: return .illegal
            }

        case .autoplayGate:
            switch status {
            case .ready: return .to(.playing)
            default: return .illegal
            }
        }
    }

    /// Convenience: next status if legal/stay, else `nil` for illegal.
    public static func nextStatus(
        status: PlayerStatus,
        event: PlayerStateEvent,
        isLive: Bool = false
    ) -> PlayerStatus? {
        switch transition(status: status, event: event, isLive: isLive) {
        case .to(let s): return s
        case .stay: return status
        case .illegal: return nil
        }
    }
}
