import Foundation

/// Built-in control density for `PulsePlayerView`.
public enum PlayerChromeMode: String, Sendable, Equatable, CaseIterable {
    /// Video surface only (host draws chrome).
    case none
    /// Center play/pause + optional mute. Feed / inline cards.
    case minimal
    /// Slim scrubber + play + time. Short-form / feed detail.
    case lite
    /// Full transport: scrub, skip, mute, volume, times.
    case full
}
