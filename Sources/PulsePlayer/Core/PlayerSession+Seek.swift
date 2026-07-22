import Foundation

@MainActor
extension PlayerSession {
    public func seek(to time: TimeInterval) async {
        guard status != .invalidated, status != .idle, status != .loading else { return }
        let target = max(0, time)
        do {
            try await engine.seek(to: target)
            emit(.seekCompleted(time: engine.currentTime()))
            if status == .ended {
                _ = apply(.pause)
            }
        } catch is CancellationError {
            return
        } catch {
            emit(.warning(URLSanitizer.sanitizeMessage(error.localizedDescription)))
        }
    }

    public func seek(relative delta: TimeInterval) async {
        let next = engine.currentTime() + delta
        let clamped: TimeInterval
        if let d = engine.duration() {
            clamped = min(max(0, next), d)
        } else {
            clamped = max(0, next)
        }
        await seek(to: clamped)
    }
}
