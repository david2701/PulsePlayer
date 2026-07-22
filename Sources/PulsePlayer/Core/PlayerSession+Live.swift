import Foundation

@MainActor
extension PlayerSession {
    /// Seekable window from the engine (live DVR or VOD).
    public var seekableTimeRange: ClosedRange<TimeInterval>? {
        engine.seekableTimeRange()
    }

    /// True when playing near the live edge (within 8s).
    public var isAtLiveEdge: Bool {
        guard currentSource?.isLive == true,
              let range = seekableTimeRange
        else { return false }
        return playbackTime >= range.upperBound - 8
    }

    /// Live edge timestamp (end of seekable range).
    public var liveEdgeTime: TimeInterval? {
        seekableTimeRange?.upperBound
    }

    public func seekToLiveEdge() async {
        guard let edge = liveEdgeTime else { return }
        await seek(to: max(0, edge - 1))
    }

    /// Clamp seek into DVR window when live.
    func clampLiveSeek(_ time: TimeInterval) -> TimeInterval {
        guard currentSource?.isLive == true else { return time }
        if let range = seekableTimeRange {
            return min(max(time, range.lowerBound), range.upperBound)
        }
        if let window = currentSource?.dvrWindow, let edge = liveEdgeTime {
            return min(max(time, edge - window), edge)
        }
        return time
    }
}
