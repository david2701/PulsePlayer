import Foundation

/// Host plugin for ad markers. Core only detects cues and notifies.
@MainActor
public protocol AdCueHandling: AnyObject {
    func playerSession(_ session: PlayerSession, didReach cue: AdCue) async
}

/// Tracks fired ad cues for a single item load.
@MainActor
final class AdCueTracker {
    private var fired: Set<String> = []
    private var cues: [AdCue] = []
    weak var handler: (any AdCueHandling)?
    weak var session: PlayerSession?

    func reset(cues: [AdCue]) {
        self.cues = cues.sorted { $0.start < $1.start }
        fired.removeAll()
    }

    func clear() {
        cues = []
        fired.removeAll()
    }

    func tick(time: TimeInterval) {
        guard let handler, let session else { return }
        for cue in cues where !fired.contains(cue.id) {
            // Fire when playback crosses start (within 0.35s window for discrete ticks).
            if time + 0.05 >= cue.start && time <= cue.start + 1.0 {
                fired.insert(cue.id)
                session.emit(.adCueReached(id: cue.id))
                Task { await handler.playerSession(session, didReach: cue) }
            }
        }
    }
}
