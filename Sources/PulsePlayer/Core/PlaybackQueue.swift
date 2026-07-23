import Foundation
import Observation

/// Ordered playlist with next/previous and optional autoplay-next.
@MainActor
@Observable
public final class PlaybackQueue {
    public private(set) var items: [MediaSource]
    public private(set) var currentIndex: Int = 0
    public var autoplayNext: Bool = true
    public var resumeFromContinueWatching: Bool = true

    public weak var session: PlayerSession?
    public var continueStore: ContinueWatchingStore = .shared

    public init(items: [MediaSource] = [], autoplayNext: Bool = true) {
        self.items = items
        self.autoplayNext = autoplayNext
    }

    public var current: MediaSource? {
        items.indices.contains(currentIndex) ? items[currentIndex] : nil
    }

    public var nextItem: MediaSource? {
        let index = currentIndex + 1
        return items.indices.contains(index) ? items[index] : nil
    }

    public var hasNext: Bool { currentIndex + 1 < items.count }
    public var hasPrevious: Bool { currentIndex > 0 }

    public func setItems(_ items: [MediaSource], startAt index: Int = 0) {
        self.items = items
        currentIndex = items.isEmpty ? 0 : min(max(0, index), items.count - 1)
    }

    public func playCurrent() async {
        guard let session, let item = current else { return }
        await session.load(item)
        if resumeFromContinueWatching,
           let pos = continueStore.position(for: item.id),
           !item.isLive
        {
            await session.seek(to: pos)
        }
        session.play()
    }

    public func play(at index: Int) async {
        guard items.indices.contains(index) else { return }
        saveProgress()
        currentIndex = index
        await playCurrent()
    }

    public func next() async {
        guard hasNext else { return }
        await play(at: currentIndex + 1)
    }

    public func previous() async {
        guard hasPrevious else { return }
        await play(at: currentIndex - 1)
    }

    public func saveProgress() {
        guard let session, let item = current, !item.isLive else { return }
        continueStore.save(
            sourceId: item.id,
            position: session.playbackTime,
            duration: session.playbackDuration
        )
    }

    /// Call when session ends to auto-advance.
    public func handleSessionEnded() async {
        saveProgress()
        if autoplayNext, hasNext {
            await next()
        }
    }
}
