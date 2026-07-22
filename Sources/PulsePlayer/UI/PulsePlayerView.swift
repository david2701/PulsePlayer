import SwiftUI

/// Adaptive video surface for a long-lived `PlayerSession`.
public struct PulsePlayerView: View {
    private let session: PlayerSession
    private let videoGravity: PlayerVideoGravity
    private let showsSubtitles: Bool
    private let chrome: PlayerChromeMode
    private let theme: PlayerChromeTheme
    private let enableGestures: Bool

    @State private var isFullscreen = false

    public init(
        session: PlayerSession,
        videoGravity: PlayerVideoGravity = .resizeAspect,
        showsSubtitles: Bool = true,
        chrome: PlayerChromeMode = .none,
        theme: PlayerChromeTheme = .default,
        accent: Color? = nil,
        enableGestures: Bool = true
    ) {
        self.session = session
        self.videoGravity = videoGravity
        self.showsSubtitles = showsSubtitles
        self.chrome = chrome
        var resolved = theme
        if let accent { resolved.accent = accent }
        self.theme = resolved
        self.enableGestures = enableGestures
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
            chrome: chrome == .none ? .full : chrome
        )
        .accessibilityLabel(session.currentSource?.title ?? "Video")
        #else
        Color.black
            .overlay {
                Text("PulsePlayer UI targets iOS/tvOS")
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
                    onFullscreen: { isFullscreen = true }
                )
            }

            if shouldShowLoader {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(theme.accent)
                    .scaleEffect(1.05)
            }

            if session.status == .failed {
                failureOverlay
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
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
    }

    private var failureOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
            Text("Playback failed")
                .font(.headline)
            Text(session.currentError?.userMessage ?? "Unknown error")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 24)
            if session.currentError?.isRecoverable == true {
                Button {
                    Task { await session.retry() }
                } label: {
                    Text("Retry")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(theme.accent.opacity(0.22), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(.ultraThinMaterial.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
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
