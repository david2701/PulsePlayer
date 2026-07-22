import SwiftUI

/// Transport chrome rendered according to `PlayerChromeMode`.
public struct PulsePlayerControls: View {
    let session: PlayerSession
    let mode: PlayerChromeMode
    let accent: Color
    let showsAirPlay: Bool
    let showsQuality: Bool
    let skipInterval: TimeInterval
    let onFullscreen: (() -> Void)?

    @State var isScrubbing = false
    @State var scrubTime: TimeInterval = 0
    @State var controlsVisible = true
    @State var hideTask: Task<Void, Never>?
    @State var showTracks = false
    @State var showQuality = false
    @State var seekFlash: String?

    public init(
        session: PlayerSession,
        mode: PlayerChromeMode = .full,
        accent: Color = .white,
        showsAirPlay: Bool = true,
        showsQuality: Bool = true,
        skipInterval: TimeInterval = 10,
        onFullscreen: (() -> Void)? = nil
    ) {
        self.session = session
        self.mode = mode
        self.accent = accent
        self.showsAirPlay = showsAirPlay
        self.showsQuality = showsQuality
        self.skipInterval = skipInterval
        self.onFullscreen = onFullscreen
    }

    public var body: some View {
        Group {
            switch mode {
            case .none: EmptyView()
            case .minimal: minimalChrome
            case .lite: interactiveShell { liteBar }
            case .full: interactiveShell { fullBar }
            }
        }
        .foregroundStyle(accent)
        .overlay { seekFlashOverlay }
        .sheet(isPresented: $showTracks) {
            TrackPickerSheet(session: session).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showQuality) {
            QualityPickerSheet(session: session).presentationDetents([.medium])
        }
    }
}
