import Foundation
import Observation

/// Priority for pool residency. Higher raw value = keep longer.
/// Order: distant < next < visible.
public enum PoolPriority: Int, Sendable, Comparable {
    case distant = 0
    case next = 1
    case visible = 2

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Reuses a fixed number of `PlayerSession`s for feed-style UIs.
@MainActor
@Observable
public final class PlayerPool {
    public let size: Int
    public private(set) var configuration: PlayerConfiguration

    /// Bumps when membership changes so SwiftUI re-reads `session(for:)`.
    public private(set) var revision: UInt64 = 0

    private struct Entry {
        let session: PlayerSession
        var sourceID: String?
        var priority: PoolPriority
        var lastUsed: ContinuousClock.Instant
    }

    @ObservationIgnored private var entries: [Entry] = []
    @ObservationIgnored private let dependencies: PlayerDependencies
    @ObservationIgnored private var prewarmTask: Task<Void, Never>?
    @ObservationIgnored private var maxPrewarmConcurrent: Int

    public init(
        size: Int = 3,
        configuration: PlayerConfiguration = .default,
        dependencies: PlayerDependencies = .production,
        maxPrewarmConcurrent: Int = 1
    ) {
        self.size = max(1, size)
        self.configuration = configuration
        self.dependencies = dependencies
        self.maxPrewarmConcurrent = max(1, maxPrewarmConcurrent)
    }

    /// Active sessions currently held by the pool.
    public var sessions: [PlayerSession] {
        _ = revision
        return entries.map(\.session)
    }

    public func session(for sourceID: String) -> PlayerSession? {
        _ = revision
        return entries.first { $0.sourceID == sourceID }?.session
    }

    private func noteChange() {
        revision &+= 1
    }

    /// Acquire a session for `source`, loading content. May evict lower-priority entries.
    @discardableResult
    public func acquire(
        source: MediaSource,
        priority: PoolPriority = .visible
    ) async -> PlayerSession {
        if let existing = entries.first(where: { $0.sourceID == source.id }) {
            touch(sourceID: source.id, priority: priority)
            let session = existing.session
            if priority == .visible {
                applyVisiblePlayback(session)
            }
            return session
        }

        await ensureCapacity(for: priority)
        let session = makeSession()
        entries.append(
            Entry(
                session: session,
                sourceID: source.id,
                priority: priority,
                lastUsed: ContinuousClock.now
            )
        )
        noteChange()

        var loadConfig = configuration
        loadConfig.autoplay = (priority == .visible)
        _ = session.updateConfiguration { $0 = loadConfig }
        await session.load(source)
        if priority == .visible {
            session.play()
        }
        noteChange()
        return session
    }

    /// Preload sources at `.next` priority (max concurrent loads limited).
    public func prewarm(_ sources: [MediaSource]) async {
        prewarmTask?.cancel()
        prewarmTask = Task { @MainActor in
            var queue = sources
            while !queue.isEmpty {
                if Task.isCancelled { return }
                let batch = Array(queue.prefix(self.maxPrewarmConcurrent))
                queue.removeFirst(min(self.maxPrewarmConcurrent, queue.count))
                for source in batch {
                    if Task.isCancelled { return }
                    if self.session(for: source.id) != nil { continue }
                    await self.acquire(source: source, priority: .next)
                    // Prewarm should not autoplay.
                    if let s = self.session(for: source.id) {
                        s.pause()
                    }
                }
            }
        }
        await prewarmTask?.value
    }

    public func release(_ session: PlayerSession) {
        guard let idx = entries.firstIndex(where: { $0.session.id == session.id }) else {
            return
        }
        let entry = entries.remove(at: idx)
        noteChange()
        entry.session.pause()
        if configuration.pauseWhenDetached {
            Task { await entry.session.reset() }
        }
    }

    /// Reassign priorities: first id = visible, next ids = next, others → distant / eviction.
    public func rebalance(visibleIDs: [String]) async {
        let nextSet = Set(visibleIDs.dropFirst().prefix(max(0, size - 1)))
        let primary = visibleIDs.first

        for i in entries.indices {
            guard let sid = entries[i].sourceID else { continue }
            if sid == primary {
                entries[i].priority = .visible
                entries[i].lastUsed = ContinuousClock.now
            } else if nextSet.contains(sid) {
                entries[i].priority = .next
            } else {
                entries[i].priority = .distant
                entries[i].session.pause()
            }
        }

        // Play visible, pause others.
        for entry in entries {
            if entry.sourceID == primary {
                applyVisiblePlayback(entry.session)
            } else {
                entry.session.pause()
            }
        }

        await trimToSize()
        noteChange()
    }

    /// Shutdown: invalidate all sessions.
    public func shutdown() {
        prewarmTask?.cancel()
        prewarmTask = nil
        for entry in entries {
            entry.session.invalidate()
        }
        entries.removeAll()
        noteChange()
    }

    public func updateConfiguration(_ mutate: (inout PlayerConfiguration) -> Void) {
        mutate(&configuration)
        for entry in entries {
            _ = entry.session.updateConfiguration { $0 = configuration }
        }
    }

    // MARK: - Private

    private func makeSession() -> PlayerSession {
        var config = configuration
        config.autoplay = false
        return PlayerSession(configuration: config, dependencies: dependencies)
    }

    private func touch(sourceID: String, priority: PoolPriority) {
        guard let i = entries.firstIndex(where: { $0.sourceID == sourceID }) else { return }
        entries[i].priority = priority
        entries[i].lastUsed = ContinuousClock.now
    }

    private func applyVisiblePlayback(_ session: PlayerSession) {
        session.play()
    }

    private func ensureCapacity(for priority: PoolPriority) async {
        while entries.count >= size {
            guard let victimIndex = evictionIndex(preferringBelow: priority) else {
                break
            }
            await evict(at: victimIndex)
        }
    }

    private func trimToSize() async {
        while entries.count > size {
            guard let victimIndex = evictionIndex(preferringBelow: .visible) else {
                break
            }
            await evict(at: victimIndex)
        }
        // Also drop distant extras when over soft pressure
        let distant = entries.indices.filter { entries[$0].priority == .distant }
        if entries.count > size, let firstDistant = distant.first {
            await evict(at: firstDistant)
        }
    }

    /// Pick lowest priority; tie-break oldest `lastUsed`.
    private func evictionIndex(preferringBelow: PoolPriority) -> Int? {
        let candidates = entries.indices.filter { entries[$0].priority < preferringBelow }
        let pool = candidates.isEmpty ? Array(entries.indices) : candidates
        return pool.min { a, b in
            let ea = entries[a]
            let eb = entries[b]
            if ea.priority != eb.priority {
                return ea.priority < eb.priority
            }
            return ea.lastUsed < eb.lastUsed
        }
    }

    private func evict(at index: Int) async {
        guard entries.indices.contains(index) else { return }
        let entry = entries.remove(at: index)
        noteChange()
        entry.session.pause()
        if configuration.pauseWhenDetached {
            await entry.session.reset()
        }
    }
}
