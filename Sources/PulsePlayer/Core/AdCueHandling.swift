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
    private var lastTime: TimeInterval?
    private var generation: UInt64 = 0
    private var callbackTasks: [String: Task<Void, Never>] = [:]
    weak var handler: (any AdCueHandling)?
    weak var session: PlayerSession?

    func reset(cues: [AdCue]) {
        self.cues = cues.sorted { $0.start < $1.start }
        fired.removeAll()
        lastTime = nil
        generation &+= 1
        callbackTasks.values.forEach { $0.cancel() }
        callbackTasks.removeAll()
    }

    func clear() {
        cues = []
        fired.removeAll()
        lastTime = nil
        generation &+= 1
        callbackTasks.values.forEach { $0.cancel() }
        callbackTasks.removeAll()
    }

    func tick(time: TimeInterval) {
        guard let handler, let session else { return }
        let previous = lastTime
        lastTime = time
        let lowerBound = previous.map { min($0, time) } ?? -.infinity
        let movedForward = previous == nil || time >= (previous ?? time)
        guard movedForward else { return }
        for cue in cues where !fired.contains(cue.id) {
            if cue.start > lowerBound && cue.start <= time + 0.05 {
                fired.insert(cue.id)
                session.emit(.adCueReached(id: cue.id))
                let gen = generation
                callbackTasks[cue.id] = Task { @MainActor [weak self, weak session] in
                    guard let session, !Task.isCancelled else { return }
                    await handler.playerSession(session, didReach: cue)
                    guard let self, gen == self.generation else { return }
                    self.callbackTasks[cue.id] = nil
                }
            }
        }
    }
}
