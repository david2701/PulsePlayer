import Foundation
import MediaPlayer

/// Updates `MPNowPlayingInfoCenter` and installs remote command handlers.
/// Handlers are removed by stored tokens (does not wipe other app targets).
@MainActor
public final class SystemNowPlayingCenter: NowPlayingCentering {
    public static let shared = SystemNowPlayingCenter()

    public struct CommandHandlers: Sendable {
        public var play: @MainActor @Sendable () -> Void
        public var pause: @MainActor @Sendable () -> Void
        public var togglePlayPause: @MainActor @Sendable () -> Void
        public var seek: (@MainActor @Sendable (TimeInterval) -> Void)?
        public var skipForward: (@MainActor @Sendable (TimeInterval) -> Void)?
        public var skipBackward: (@MainActor @Sendable (TimeInterval) -> Void)?

        public init(
            play: @escaping @MainActor @Sendable () -> Void,
            pause: @escaping @MainActor @Sendable () -> Void,
            togglePlayPause: @escaping @MainActor @Sendable () -> Void,
            seek: (@MainActor @Sendable (TimeInterval) -> Void)? = nil,
            skipForward: (@MainActor @Sendable (TimeInterval) -> Void)? = nil,
            skipBackward: (@MainActor @Sendable (TimeInterval) -> Void)? = nil
        ) {
            self.play = play
            self.pause = pause
            self.togglePlayPause = togglePlayPause
            self.seek = seek
            self.skipForward = skipForward
            self.skipBackward = skipBackward
        }
    }

    private var handlers: CommandHandlers?
    private var tokens: [Any] = []
    private var activeOwner: UUID?
    private var ownerHandlers: [UUID: CommandHandlers] = [:]

    public init() {}

    public func setCommandHandlers(_ handlers: CommandHandlers?) {
        removeCommands()
        self.handlers = handlers
        if handlers != nil {
            installCommands()
        }
    }

    package func register(owner: UUID, handlers: CommandHandlers) {
        ownerHandlers[owner] = handlers
        if activeOwner == owner {
            setCommandHandlers(handlers)
        }
    }

    package func activate(owner: UUID) {
        guard activeOwner != owner else { return }
        activeOwner = owner
        setCommandHandlers(ownerHandlers[owner])
    }

    package func deactivate(owner: UUID, clear: Bool) {
        guard activeOwner == owner else { return }
        activeOwner = nil
        setCommandHandlers(nil)
        if clear {
            self.clear()
        }
    }

    package func unregister(owner: UUID, clear: Bool) {
        ownerHandlers[owner] = nil
        deactivate(owner: owner, clear: clear)
    }

    package func update(
        owner: UUID,
        title: String?,
        subtitle: String?,
        elapsed: TimeInterval,
        duration: TimeInterval?,
        rate: Float
    ) {
        guard activeOwner == owner else { return }
        update(
            title: title,
            subtitle: subtitle,
            elapsed: elapsed,
            duration: duration,
            rate: rate
        )
    }

    public func update(
        title: String?,
        subtitle: String?,
        elapsed: TimeInterval,
        duration: TimeInterval?,
        rate: Float
    ) {
        var info: [String: Any] = [:]
        if let title { info[MPMediaItemPropertyTitle] = title }
        if let subtitle { info[MPMediaItemPropertyArtist] = subtitle }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        if let duration, duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    public func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func installCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        tokens.append(center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.handlers?.play() }
            return .success
        })

        center.pauseCommand.isEnabled = true
        tokens.append(center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.handlers?.pause() }
            return .success
        })

        center.togglePlayPauseCommand.isEnabled = true
        tokens.append(center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.handlers?.togglePlayPause() }
            return .success
        })

        center.changePlaybackPositionCommand.isEnabled = true
        tokens.append(center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let position = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            let time = position.positionTime
            Task { @MainActor in self.handlers?.seek?(time) }
            return .success
        })

        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [15]
        tokens.append(center.skipForwardCommand.addTarget { [weak self] event in
            guard let self else { return .commandFailed }
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in self.handlers?.skipForward?(interval) }
            return .success
        })

        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [15]
        tokens.append(center.skipBackwardCommand.addTarget { [weak self] event in
            guard let self else { return .commandFailed }
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in self.handlers?.skipBackward?(interval) }
            return .success
        })
    }

    private func removeCommands() {
        let center = MPRemoteCommandCenter.shared()
        for token in tokens {
            center.playCommand.removeTarget(token)
            center.pauseCommand.removeTarget(token)
            center.togglePlayPauseCommand.removeTarget(token)
            center.changePlaybackPositionCommand.removeTarget(token)
            center.skipForwardCommand.removeTarget(token)
            center.skipBackwardCommand.removeTarget(token)
        }
        tokens.removeAll()
    }
}
