import SwiftUI

/// Adaptive video surface for a long-lived `PlayerSession`.
public struct PulsePlayerView: View {
    private let session: PlayerSession
    private let videoGravity: PlayerVideoGravity
    private let showsSubtitles: Bool
    private let chrome: PlayerChromeMode
    private let theme: PlayerChromeTheme
    private let enableGestures: Bool
    private let allowsFullscreen: Bool
    private let showsEditorialOverlays: Bool

    @State private var isFullscreen = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        session: PlayerSession,
        videoGravity: PlayerVideoGravity = .resizeAspect,
        showsSubtitles: Bool = true,
        chrome: PlayerChromeMode = .none,
        theme: PlayerChromeTheme = .default,
        accent: Color? = nil,
        enableGestures: Bool = true,
        allowsFullscreen: Bool = true,
        showsEditorialOverlays: Bool = true
    ) {
        self.session = session
        self.videoGravity = videoGravity
        self.showsSubtitles = showsSubtitles
        self.chrome = chrome
        var resolved = theme
        if let accent { resolved.accent = accent }
        self.theme = resolved
        self.enableGestures = enableGestures
        self.allowsFullscreen = allowsFullscreen
        self.showsEditorialOverlays = showsEditorialOverlays
    }

    /// Source-compatible 1.0 player-view initializer.
    public init(
        session: PlayerSession,
        videoGravity: PlayerVideoGravity = .resizeAspect,
        showsSubtitles: Bool = true,
        chrome: PlayerChromeMode = .none,
        theme: PlayerChromeTheme = .default,
        accent: Color? = nil,
        enableGestures: Bool = true
    ) {
        self.init(
            session: session,
            videoGravity: videoGravity,
            showsSubtitles: showsSubtitles,
            chrome: chrome,
            theme: theme,
            accent: accent,
            enableGestures: enableGestures,
            allowsFullscreen: true,
            showsEditorialOverlays: true
        )
    }

    public init(
        session: PlayerSession,
        videoGravity: PlayerVideoGravity = .resizeAspect,
        showsSubtitles: Bool = true,
        showsControls: Bool
    ) {
        self.init(
            session: session,
            videoGravity: videoGravity,
            showsSubtitles: showsSubtitles,
            chrome: showsControls ? .full : .none
        )
    }

    public var body: some View {
        #if os(iOS) || os(tvOS)
        GeometryReader { geo in
            playerStack(size: geo.size)
        }
        .background(Color.black)
        .pulseFullscreen(
            isPresented: $isFullscreen,
            session: session,
            chrome: chrome == .none ? .full : chrome,
            videoGravity: videoGravity,
            showsSubtitles: showsSubtitles,
            theme: theme,
            enableGestures: enableGestures
        )
        .accessibilityLabel(
            session.currentSource?.title
                ?? PulsePlayerLocalization.string("Video")
        )
        #else
        Color.black
            .overlay {
                Text(PulsePlayerLocalization.string("PulsePlayer UI targets iOS/tvOS"))
                    .foregroundStyle(.secondary)
            }
        #endif
    }

    #if os(iOS) || os(tvOS)
    @ViewBuilder
    private func playerStack(size: CGSize) -> some View {
        ZStack {
            Color.black
            PlayerLayerRepresentable(session: session, videoGravity: videoGravity)
                .frame(width: size.width, height: size.height)

            if showsSubtitles {
                PulseSubtitleOverlay(session: session)
            }

            if chrome == .none, enableGestures {
                gestureOnlyOverlay
            }

            if chrome != .none {
                PulsePlayerControls(
                    session: session,
                    mode: chrome,
                    theme: theme,
                    onFullscreen: allowsFullscreen
                        ? { isFullscreen = true }
                        : nil
                )
            }

            if showsEditorialOverlays {
                PulseEditorialOverlay(session: session, accent: theme.accent)
            }

            if shouldShowLoader {
                ProgressView(PulsePlayerLocalization.string("Loading"))
                    .labelStyle(.iconOnly)
                    .progressViewStyle(.circular)
                    .tint(theme.accent)
                    .scaleEffect(1.05)
                    .accessibilityLabel(
                        PulsePlayerLocalization.string("Loading")
                    )
            }

            if session.status == .failed {
                failureOverlay
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        #if os(tvOS)
        .onPlayPauseCommand {
            if chrome == .none {
                session.togglePlayPause()
            }
        }
        #endif
    }

    private var gestureOnlyOverlay: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    Task { await session.seek(relative: -10) }
                }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    Task { await session.seek(relative: 10) }
                }
        }
        .accessibilityElement()
        .accessibilityLabel(
            session.currentSource?.title
                ?? PulsePlayerLocalization.string("Video")
        )
        .accessibilityAction(
            named: session.isPlaying
                ? PulsePlayerLocalization.string("Pause")
                : PulsePlayerLocalization.string("Play")
        ) {
            session.togglePlayPause()
        }
        .accessibilityAction(
            named: PulsePlayerLocalization.format(
                "Skip backward %d seconds",
                10
            )
        ) {
            Task { await session.seek(relative: -10) }
        }
        .accessibilityAction(
            named: PulsePlayerLocalization.format(
                "Skip forward %d seconds",
                10
            )
        ) {
            Task { await session.seek(relative: 10) }
        }
    }

    private var failureOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
            Text(PulsePlayerLocalization.string("Playback failed"))
                .font(.headline)
            Text(
                session.currentError?.userMessage
                    ?? PulsePlayerLocalization.string("Unknown error")
            )
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 24)
            if session.currentError?.isRecoverable == true {
                Button {
                    Task { await session.retry() }
                } label: {
                    Text(PulsePlayerLocalization.string("Retry"))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(theme.accent.opacity(0.22), in: Capsule())
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .controlSize(.large)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            reduceTransparency
                ? AnyShapeStyle(Color.black.opacity(0.95))
                : AnyShapeStyle(.ultraThinMaterial.opacity(0.35)),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var shouldShowLoader: Bool {
        guard !session.hasRenderedFrame else { return false }
        switch session.status {
        case .loading, .buffering: return true
        default: return false
        }
    }
    #endif
}
