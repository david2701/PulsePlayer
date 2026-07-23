import AVFoundation
import Foundation

/// Activates `AVAudioSession` for video/audio playback (background capable).
@MainActor
public final class SystemAudioSession: AudioSessionConfiguring {
    public static let shared = SystemAudioSession()

    private var continuations: [UUID: AsyncStream<AudioSessionEvent>.Continuation] = [:]
    private let observerTokens = AudioSessionObserverTokens()

    public init() {
        installObservers()
    }

    deinit {
        for continuation in continuations.values {
            continuation.finish()
        }
    }

    public func makeEventStream() -> AsyncStream<AudioSessionEvent> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(32)) { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.continuations[id] = nil
                }
            }
        }
    }

    public func activateForPlayback(background: Bool) throws {
        #if os(iOS) || os(tvOS)
        let session = AVAudioSession.sharedInstance()
        // `.playback` allows silent-switch audio. Background playback additionally
        // depends on the host app's Background Audio capability; the category
        // itself is the same in foreground and background.
        _ = background
        try session.setCategory(.playback, mode: .moviePlayback, options: [])
        try session.setActive(true, options: [])
        #else
        _ = background
        #endif
    }

    public func deactivate() throws {
        #if os(iOS) || os(tvOS)
        try AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
        #endif
    }

    private func emit(_ event: AudioSessionEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func installObservers() {
        #if os(iOS) || os(tvOS)
        let center = NotificationCenter.default
        observerTokens.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] note in
            let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let rawOptions = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor in
                guard let self, let rawType,
                      let type = AVAudioSession.InterruptionType(rawValue: rawType)
                else { return }
                switch type {
                case .began:
                    self.emit(.interruptionBegan)
                case .ended:
                    let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                    self.emit(.interruptionEnded(shouldResume: options.contains(.shouldResume)))
                @unknown default:
                    break
                }
            }
        })

        observerTokens.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                guard let self else { return }
                self.emit(.routeChanged(reason: Self.routeReason(raw)))
            }
        })

        observerTokens.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereLostNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in self?.emit(.mediaServicesLost) }
        })

        observerTokens.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in self?.emit(.mediaServicesReset) }
        })
        #endif
    }

    private static func routeReason(_ raw: UInt?) -> AudioRouteChangeReason {
        #if os(iOS) || os(tvOS)
        guard let raw, let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else {
            return .unknown
        }
        switch reason {
        case .newDeviceAvailable: return .newDeviceAvailable
        case .oldDeviceUnavailable: return .oldDeviceUnavailable
        case .categoryChange: return .categoryChange
        case .override: return .override
        case .wakeFromSleep: return .wakeFromSleep
        case .noSuitableRouteForCategory: return .noSuitableRoute
        case .routeConfigurationChange: return .routeConfigurationChange
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
        #else
        _ = raw
        return .unknown
        #endif
    }
}

private final class AudioSessionObserverTokens: @unchecked Sendable {
    private var values: [NSObjectProtocol] = []

    func append(_ token: NSObjectProtocol) {
        values.append(token)
    }

    deinit {
        for token in values {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
