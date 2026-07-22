import SwiftUI

/// Video surface bound to a long-lived `PlayerSession`.
///
/// - Zero chrome by default for custom UIs.
/// - Pass `showsControls: true` for built-in transport (seek, play, volume).
public struct PulsePlayerView: View {
    private let session: PlayerSession
    private let videoGravity: PlayerVideoGravity
    private let showsSubtitles: Bool
    private let showsControls: Bool
    private let controlsStyle: PulsePlayerControls.Style

    public init(
        session: PlayerSession,
        videoGravity: PlayerVideoGravity = .resizeAspect,
        showsSubtitles: Bool = true,
        showsControls: Bool = false,
        controlsStyle: PulsePlayerControls.Style = PulsePlayerControls.Style()
    ) {
        self.session = session
        self.videoGravity = videoGravity
        self.showsSubtitles = showsSubtitles
        self.showsControls = showsControls
        self.controlsStyle = controlsStyle
    }

    public var body: some View {
        #if canImport(UIKit)
        ZStack {
            PlayerLayerRepresentable(session: session, videoGravity: videoGravity)
            if showsSubtitles {
                PulseSubtitleOverlay(session: session)
            }
            if showsControls {
                PulsePlayerControls(session: session, style: controlsStyle)
            }
            if session.status == .loading || session.status == .buffering {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.15)
            }
        }
        .background(Color.black)
        .accessibilityLabel(session.currentSource?.title ?? "Video")
        #else
        Color.black
            .overlay {
                Text("PulsePlayer requires UIKit")
                    .foregroundStyle(.secondary)
            }
        #endif
    }
}
