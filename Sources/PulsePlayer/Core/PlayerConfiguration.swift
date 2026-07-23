import CoreGraphics
import Foundation

/// Session configuration. Hot-update rules: see `PlayerSession.updateConfiguration`.
public struct PlayerConfiguration: Sendable, Equatable {
    public var autoplay: Bool
    public var isMuted: Bool
    public var loop: Bool
    public var allowsExternalPlayback: Bool
    public var allowsPictureInPicture: Bool
    public var prefersBackgroundAudio: Bool
    /// When false, the host app owns `AVAudioSession` activation and category.
    public var managesAudioSession: Bool
    /// Pauses video when the app enters background unless background audio or PiP is active.
    public var pausesWhenBackgrounded: Bool
    /// Restores playback on foreground only when it was paused by lifecycle handling.
    public var resumesPlaybackAfterForeground: Bool
    public var updatesNowPlayingInfo: Bool

    public var preferredForwardBufferDuration: TimeInterval
    public var automaticallyWaitsToMinimizeStalling: Bool

    public var preferredPeakBitRate: Double
    public var preferredMaximumResolution: CGSize
    public var canUseNetworkResourcesForLiveStreamingWhilePaused: Bool
    /// Enables measured live-edge catch-up. `nil` leaves AVPlayer's standard policy.
    public var liveLatencyPolicy: LiveLatencyPolicy?
    /// When true, manual quality selection reloads the HLS **media playlist**
    /// for a hard lock. Defaults to false so alternate audio, subtitle, and
    /// timed-metadata groups from the master presentation remain available.
    public var preferHardQualityLock: Bool

    public var retry: RetryPolicy
    public var stall: StallPolicy
    public var performanceBudget: PlaybackPerformanceBudget

    public var positionUpdateInterval: TimeInterval
    public var pauseWhenDetached: Bool

    public init(
        autoplay: Bool = false,
        isMuted: Bool = false,
        loop: Bool = false,
        allowsExternalPlayback: Bool = true,
        allowsPictureInPicture: Bool = true,
        prefersBackgroundAudio: Bool = false,
        updatesNowPlayingInfo: Bool = true,
        preferredForwardBufferDuration: TimeInterval = 0,
        automaticallyWaitsToMinimizeStalling: Bool = true,
        preferredPeakBitRate: Double = 0,
        preferredMaximumResolution: CGSize = .zero,
        canUseNetworkResourcesForLiveStreamingWhilePaused: Bool = false,
        preferHardQualityLock: Bool = false,
        retry: RetryPolicy = .default,
        stall: StallPolicy = .default,
        positionUpdateInterval: TimeInterval = 0.1,
        pauseWhenDetached: Bool = true
    ) {
        self.autoplay = autoplay
        self.isMuted = isMuted
        self.loop = loop
        self.allowsExternalPlayback = allowsExternalPlayback
        self.allowsPictureInPicture = allowsPictureInPicture
        self.prefersBackgroundAudio = prefersBackgroundAudio
        self.managesAudioSession = true
        self.pausesWhenBackgrounded = true
        self.resumesPlaybackAfterForeground = false
        self.updatesNowPlayingInfo = updatesNowPlayingInfo
        self.preferredForwardBufferDuration = preferredForwardBufferDuration
        self.automaticallyWaitsToMinimizeStalling = automaticallyWaitsToMinimizeStalling
        self.preferredPeakBitRate = preferredPeakBitRate
        self.preferredMaximumResolution = preferredMaximumResolution
        self.canUseNetworkResourcesForLiveStreamingWhilePaused = canUseNetworkResourcesForLiveStreamingWhilePaused
        self.liveLatencyPolicy = nil
        self.preferHardQualityLock = preferHardQualityLock
        self.retry = retry
        self.stall = stall
        self.performanceBudget = .disabled
        self.positionUpdateInterval = positionUpdateInterval
        self.pauseWhenDetached = pauseWhenDetached
    }

    public static let `default` = PlayerConfiguration()
}
