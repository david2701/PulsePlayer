/// Public playback lifecycle status.
public enum PlayerStatus: String, Sendable, Equatable, CaseIterable {
    case idle
    case loading
    case ready
    case playing
    case buffering
    case stalled
    case failed
    case ended
    case invalidated
}
