import SwiftUI

/// Adaptive video surface for a long-lived `PlayerSession`.
public struct PulsePlayerView: View {
    private let session: PlayerSession
    private let videoGravity: PlayerVideoGravity
    private let showsSubtitles: Bool
    private let chrome: PlayerChromeMode
    private let accent: Color
    private let enableGestures: Bool

    @State private var isFullscreen = false

    public init(
        session: PlayerSession,
        videoGravity: PlayerVideoGravity = .resizeAspect,
        showsSubtitles: Bool = true,
        chrome: PlayerChromeMode = .none,
        accent: Color = .white,
        enableGestures: Bool = true
    ) {
        self.session = session
        self.videoGravity = videoGravity
        self.showsSubtitles = showsSubtitles
        self.chrome = chrome
        self.accent = accent
        self.enableGestures = enableGestures
    }

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
        self.enableGestures = true
    }

    public var body: some View {
        #if os(iOS) || os(tvOS)
        GeometryReader { geo in
            playerStack(size: geo.size)
        }
        .background(Color.black)
        .contentShape(Rectangle())
        .gesture(enableGestures ? doubleTapSeek : nil)
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

            if chrome != .none {
                PulsePlayerControls(
                    session: session,
                    mode: chrome,
                    accent: accent,
                    onFullscreen: { isFullscreen = true }
                )
            }

            if shouldShowLoader {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }

            if session.status == .failed {
                failureOverlay
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var failureOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
            Text("Playback failed")
                .font(.subheadline.weight(.semibold))
            Text(session.currentError?.userMessage ?? "Unknown error")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 20)
            if session.currentError?.isRecoverable == true {
                Button("Retry") {
                    Task { await session.retry() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .foregroundStyle(.white)
        .padding()
    }

    private var shouldShowLoader: Bool {
        guard !session.hasRenderedFrame else { return false }
        switch session.status {
        case .loading, .buffering: return true
        default: return false
        }
    }

    private var doubleTapSeek: some Gesture {
        TapGesture(count: 2).onEnded {
            Task { await session.seek(relative: 10) }
        }
    }
    #endif
}
