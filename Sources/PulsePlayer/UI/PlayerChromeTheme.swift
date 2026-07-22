import SwiftUI

/// Visual tokens for built-in transport chrome.
public struct PlayerChromeTheme: Equatable {
    public var accent: Color
    /// Top scrim strength (0…1).
    public var topScrimOpacity: Double
    /// Bottom scrim peak opacity (0…1).
    public var bottomScrimOpacity: Double
    public var showsScrubPreview: Bool
    public var scrubPreviewWidth: CGFloat
    public var scrubPreviewHeight: CGFloat
    public var showsBitrateChip: Bool
    public var autoHideDelay: TimeInterval
    public var controlIconSize: CGFloat
    /// Pill / chip fill opacity.
    public var chipOpacity: Double

    public init(
        accent: Color = .white,
        topScrimOpacity: Double = 0.65,
        bottomScrimOpacity: Double = 0.88,
        showsScrubPreview: Bool = true,
        scrubPreviewWidth: CGFloat = 168,
        scrubPreviewHeight: CGFloat = 94,
        showsBitrateChip: Bool = true,
        autoHideDelay: TimeInterval = 3.2,
        controlIconSize: CGFloat = 34,
        chipOpacity: Double = 0.12
    ) {
        self.accent = accent
        self.topScrimOpacity = topScrimOpacity
        self.bottomScrimOpacity = bottomScrimOpacity
        self.showsScrubPreview = showsScrubPreview
        self.scrubPreviewWidth = scrubPreviewWidth
        self.scrubPreviewHeight = scrubPreviewHeight
        self.showsBitrateChip = showsBitrateChip
        self.autoHideDelay = autoHideDelay
        self.controlIconSize = controlIconSize
        self.chipOpacity = chipOpacity
    }

    /// Computed presets avoid non-Sendable static stored `Color` issues under Swift 6.
    public static var `default`: PlayerChromeTheme { PlayerChromeTheme() }

    /// Cyan accent, slightly softer scrims.
    public static var pulse: PlayerChromeTheme {
        PlayerChromeTheme(
            accent: Color(red: 0.35, green: 0.78, blue: 1.0),
            topScrimOpacity: 0.55,
            bottomScrimOpacity: 0.82,
            chipOpacity: 0.16
        )
    }

    /// Minimal dark chrome, no bitrate chip.
    public static var cinema: PlayerChromeTheme {
        PlayerChromeTheme(
            accent: .white,
            topScrimOpacity: 0.45,
            bottomScrimOpacity: 0.92,
            showsBitrateChip: false,
            autoHideDelay: 2.4
        )
    }
}
