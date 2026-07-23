import SwiftUI

#if os(iOS) || os(tvOS)
/// Fullscreen presenter for `PlayerSession` (SwiftUI).
public struct PulseFullscreenContainer: View {
    @Binding var isPresented: Bool
    let session: PlayerSession
    var chrome: PlayerChromeMode
    var videoGravity: PlayerVideoGravity
    var showsSubtitles: Bool
    var theme: PlayerChromeTheme
    var enableGestures: Bool

    public init(
        isPresented: Binding<Bool>,
        session: PlayerSession,
        chrome: PlayerChromeMode = .full,
        videoGravity: PlayerVideoGravity = .resizeAspect,
        showsSubtitles: Bool = true,
        theme: PlayerChromeTheme = .default,
        enableGestures: Bool = true
    ) {
        self._isPresented = isPresented
        self.session = session
        self.chrome = chrome
        self.videoGravity = videoGravity
        self.showsSubtitles = showsSubtitles
        self.theme = theme
        self.enableGestures = enableGestures
    }

    /// Source-compatible 1.0 fullscreen initializer.
    public init(
        isPresented: Binding<Bool>,
        session: PlayerSession,
        chrome: PlayerChromeMode = .full
    ) {
        self.init(
            isPresented: isPresented,
            session: session,
            chrome: chrome,
            videoGravity: .resizeAspect,
            showsSubtitles: true,
            theme: .default,
            enableGestures: true
        )
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            PulsePlayerView(
                session: session,
                videoGravity: videoGravity,
                showsSubtitles: showsSubtitles,
                chrome: chrome,
                theme: theme,
                enableGestures: enableGestures,
                allowsFullscreen: false
            )
            .ignoresSafeArea()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .padding(16)
            }
            .padding(.top, 8)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(
                PulsePlayerLocalization.string("Close full screen")
            )
        }
        #if !os(tvOS)
        .statusBarHidden(true)
        #endif
    }
}

public extension View {
    /// Source-compatible 1.0 fullscreen modifier.
    func pulseFullscreen(
        isPresented: Binding<Bool>,
        session: PlayerSession,
        chrome: PlayerChromeMode = .full
    ) -> some View {
        pulseFullscreen(
            isPresented: isPresented,
            session: session,
            chrome: chrome,
            videoGravity: .resizeAspect,
            showsSubtitles: true,
            theme: .default,
            enableGestures: true
        )
    }

    func pulseFullscreen(
        isPresented: Binding<Bool>,
        session: PlayerSession,
        chrome: PlayerChromeMode = .full,
        videoGravity: PlayerVideoGravity = .resizeAspect,
        showsSubtitles: Bool = true,
        theme: PlayerChromeTheme = .default,
        enableGestures: Bool = true
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            PulseFullscreenContainer(
                isPresented: isPresented,
                session: session,
                chrome: chrome,
                videoGravity: videoGravity,
                showsSubtitles: showsSubtitles,
                theme: theme,
                enableGestures: enableGestures
            )
        }
    }
}
#else
public extension View {
    /// Source-compatible 1.0 fullscreen modifier.
    func pulseFullscreen(
        isPresented: Binding<Bool>,
        session: PlayerSession,
        chrome: PlayerChromeMode = .full
    ) -> some View {
        self
    }

    /// No-op fullscreen on platforms without `fullScreenCover`.
    func pulseFullscreen(
        isPresented: Binding<Bool>,
        session: PlayerSession,
        chrome: PlayerChromeMode = .full,
        videoGravity: PlayerVideoGravity = .resizeAspect,
        showsSubtitles: Bool = true,
        theme: PlayerChromeTheme = .default,
        enableGestures: Bool = true
    ) -> some View {
        self
    }
}
#endif
