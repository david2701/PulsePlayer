import SwiftUI

/// Adaptive video surface for a long-lived `PlayerSession`.
///
/// Use `chrome:` to pick control density:
/// - `.none` — surface only
/// - `.minimal` — feed / inline (tap play, mute)
/// - `.lite` — slim scrubber
/// - `.full` — production transport bar
public struct PulsePlayerView: View {
    private let session: PlayerSession
    private let videoGravity: PlayerVideoGravity
    private let showsSubtitles: Bool
    private let chrome: PlayerChromeMode
    private let accent: Color

    public init(
        session: PlayerSession,
        videoGravity: PlayerVideoGravity = .resizeAspect,
        showsSubtitles: Bool = true,
        chrome: PlayerChromeMode = .none,
        accent: Color = .white
    ) {
        self.session = session
        self.videoGravity = videoGravity
        self.showsSubtitles = showsSubtitles
        self.chrome = chrome
        self.accent = accent
    }

    /// Compatibility initializer (`showsControls` → `.full` / `.none`).
    public init(
        session: PlayerSession,
        videoGravity: PlayerVideoGravity = .resizeAspect,
        showsSubtitles: Bool = true,
        showsControls: Bool
    ) {
        self.session = session
        self.videoGravity = videoGravity
        self.showsSubtitles = showsSubtitles
        self.chrome = showsControls ? .full : .none
        self.accent = .white
    }

    public var body: some View {
        #if canImport(UIKit)
        GeometryReader { geo in
            ZStack {
                Color.black

                PlayerLayerRepresentable(session: session, videoGravity: videoGravity)
                    .frame(width: geo.size.width, height: geo.size.height)

                if showsSubtitles {
                    PulseSubtitleOverlay(session: session)
                }

                if chrome != .none {
                    PulsePlayerControls(session: session, mode: chrome, accent: accent)
                }

                if shouldShowLoader {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.1)
                }

                if session.status == .failed {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                        Text("Playback failed")
                            .font(.subheadline.weight(.semibold))
                        if let err = session.currentError {
                            Text(String(describing: err))
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .opacity(0.7)
                        }
                        Button("Retry") {
                            Task { await session.retry() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .foregroundStyle(.white)
                    .padding()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .background(Color.black)
        .accessibilityLabel(session.currentSource?.title ?? "Video")
        #else
        Color.black
        #endif
    }

    /// Spinner only until first frame — never stuck covering a playing surface.
    private var shouldShowLoader: Bool {
        guard !session.hasRenderedFrame else { return false }
        switch session.status {
        case .loading, .buffering:
            return true
        default:
            return false
        }
    }
}
