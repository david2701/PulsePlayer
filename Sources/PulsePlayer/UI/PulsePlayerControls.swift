import Observation
import SwiftUI

/// Transport chrome rendered according to `PlayerChromeMode`.
public struct PulsePlayerControls: View {
    let session: PlayerSession
    let mode: PlayerChromeMode
    let theme: PlayerChromeTheme
    let showsAirPlay: Bool
    let showsQuality: Bool
    let skipInterval: TimeInterval
    let onFullscreen: (() -> Void)?

    @State private var interaction = PulsePlayerControlsInteraction()
    #if os(tvOS)
    @FocusState var focusedControl: PulsePlayerControlFocus?
    #endif
    @Environment(\.accessibilityReduceMotion) private var environmentReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var environmentReduceTransparency
    @Environment(\.colorSchemeContrast) private var environmentContrast

    var isScrubbing: Bool {
        get { interaction.isScrubbing }
        nonmutating set { interaction.isScrubbing = newValue }
    }
    var scrubTime: TimeInterval {
        get { interaction.scrubTime }
        nonmutating set { interaction.scrubTime = newValue }
    }
    var controlsVisible: Bool {
        get { interaction.controlsVisible }
        nonmutating set { interaction.controlsVisible = newValue }
    }
    var hideTask: Task<Void, Never>? {
        get { interaction.hideTask }
        nonmutating set { interaction.hideTask = newValue }
    }
    var showTracks: Bool {
        get { interaction.showTracks }
        nonmutating set { interaction.showTracks = newValue }
    }
    var showQuality: Bool {
        get { interaction.showQuality }
        nonmutating set { interaction.showQuality = newValue }
    }
    var seekFlash: String? {
        get { interaction.seekFlash }
        nonmutating set { interaction.seekFlash = newValue }
    }
    var seekFlashTask: Task<Void, Never>? {
        get { interaction.seekFlashTask }
        nonmutating set { interaction.seekFlashTask = newValue }
    }
    var reduceMotion: Bool { environmentReduceMotion }
    var reduceTransparency: Bool { environmentReduceTransparency }
    var increasedContrast: Bool { environmentContrast == .increased }

    public init(
        session: PlayerSession,
        mode: PlayerChromeMode = .full,
        theme: PlayerChromeTheme = .default,
        accent: Color? = nil,
        showsAirPlay: Bool = true,
        showsQuality: Bool = true,
        skipInterval: TimeInterval = 10,
        onFullscreen: (() -> Void)? = nil
    ) {
        self.session = session
        self.mode = mode
        var resolved = theme
        if let accent { resolved.accent = accent }
        self.theme = resolved
        self.showsAirPlay = showsAirPlay
        self.showsQuality = showsQuality
        self.skipInterval = skipInterval
        self.onFullscreen = onFullscreen
    }

    var accent: Color { theme.accent }

    public var body: some View {
        Group {
            switch mode {
            case .none: EmptyView()
            case .minimal: minimalChrome
            case .lite: interactiveShell { _ in liteBar }
            case .full:
                interactiveShell { usesCenterTransport in
                    fullBar(usesCenterTransport: usesCenterTransport)
                }
            }
        }
        .foregroundStyle(accent)
        .overlay { seekFlashOverlay }
        .sheet(isPresented: Binding(
            get: { showTracks },
            set: { showTracks = $0 }
        )) {
            TrackPickerSheet(session: session).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: Binding(
            get: { showQuality },
            set: { showQuality = $0 }
        )) {
            QualityPickerSheet(session: session).presentationDetents([.medium])
        }
        .onDisappear {
            hideTask?.cancel()
            hideTask = nil
            seekFlashTask?.cancel()
            seekFlashTask = nil
        }
        #if os(tvOS)
        .onPlayPauseCommand {
            session.togglePlayPause()
            bumpChrome()
        }
        #endif
    }
}

@MainActor
@Observable
private final class PulsePlayerControlsInteraction {
    var isScrubbing = false
    var scrubTime: TimeInterval = 0
    var controlsVisible = true
    @ObservationIgnored var hideTask: Task<Void, Never>?
    var showTracks = false
    var showQuality = false
    var seekFlash: String?
    @ObservationIgnored var seekFlashTask: Task<Void, Never>?
}

#if os(tvOS)
enum PulsePlayerControlFocus: Hashable {
    case skipBackward
    case playPause
    case skipForward
}
#endif
