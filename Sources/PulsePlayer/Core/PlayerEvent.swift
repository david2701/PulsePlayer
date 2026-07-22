import Foundation

/// QoE / lifecycle events emitted via `PlayerSession.makeEventStream()`.
public enum PlayerEvent: Sendable, Equatable {
    case stateChanged(from: PlayerStatus, to: PlayerStatus)
    case loadStarted(sourceID: String)
    case readyToPlay(sourceID: String)
    case firstFrame(elapsed: Duration)
    case playbackStarted
    case playbackPaused
    case rebufferStarted
    case rebufferEnded(duration: Duration)
    case stallDetected
    case retryScheduled(attempt: Int, delay: Duration)
    case retryStarted(attempt: Int)
    case failed(PlayerError)
    case ended
    case position(TimeInterval)
    case duration(TimeInterval?)
    case buffer(progress: Double?)
    case bitrateChanged(indicatedBps: Double?, observedBps: Double?)
    case externalPlaybackActive(Bool)
    case pictureInPicture(PiPEvent)
    case seekCompleted(time: TimeInterval)
    case subtitleTrackChanged(id: String?)
    case warning(String)
}

public enum PiPEvent: Sendable, Equatable {
    case willStart
    case didStart
    case willStop
    case didStop
    case restoreUI
}
