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
    public var updatesNowPlayingInfo: Bool

    public var preferredForwardBufferDuration: TimeInterval
    public var automaticallyWaitsToMinimizeStalling: Bool

    public var preferredPeakBitRate: Double
    public var preferredMaximumResolution: CGSize
    public var canUseNetworkResourcesForLiveStreamingWhilePaused: Bool
    /// When true (default), manual quality selection reloads the HLS **media playlist**
    /// for a hard lock. Soft peak-bitrate caps still apply as a fallback.
    public var preferHardQualityLock: Bool

    public var retry: RetryPolicy
    public var stall: StallPolicy

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
        preferHardQualityLock: Bool = true,
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
        self.updatesNowPlayingInfo = updatesNowPlayingInfo
        self.preferredForwardBufferDuration = preferredForwardBufferDuration
        self.automaticallyWaitsToMinimizeStalling = automaticallyWaitsToMinimizeStalling
        self.preferredPeakBitRate = preferredPeakBitRate
        self.preferredMaximumResolution = preferredMaximumResolution
        self.canUseNetworkResourcesForLiveStreamingWhilePaused = canUseNetworkResourcesForLiveStreamingWhilePaused
        self.preferHardQualityLock = preferHardQualityLock
        self.retry = retry
        self.stall = stall
        self.positionUpdateInterval = positionUpdateInterval
        self.pauseWhenDetached = pauseWhenDetached
    }

    public static let `default` = PlayerConfiguration()
}
