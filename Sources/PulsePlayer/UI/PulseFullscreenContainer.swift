import SwiftUI

#if os(iOS) || os(tvOS)
/// Fullscreen presenter for `PlayerSession` (SwiftUI).
public struct PulseFullscreenContainer: View {
    @Binding var isPresented: Bool
    let session: PlayerSession
    var chrome: PlayerChromeMode

    public init(
        isPresented: Binding<Bool>,
        session: PlayerSession,
        chrome: PlayerChromeMode = .full
    ) {
        self._isPresented = isPresented
        self.session = session
        self.chrome = chrome
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            PulsePlayerView(
                session: session,
                videoGravity: .resizeAspect,
                showsSubtitles: true,
                chrome: chrome,
                enableGestures: true
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
        }
        #if !os(tvOS)
        .statusBarHidden(true)
        #endif
    }
}

public extension View {
    func pulseFullscreen(
        isPresented: Binding<Bool>,
        session: PlayerSession,
        chrome: PlayerChromeMode = .full
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            PulseFullscreenContainer(
                isPresented: isPresented,
                session: session,
                chrome: chrome
            )
        }
    }
}
#else
public extension View {
    /// No-op fullscreen on platforms without `fullScreenCover`.
    func pulseFullscreen(
        isPresented: Binding<Bool>,
        session: PlayerSession,
        chrome: PlayerChromeMode = .full
    ) -> some View {
        self
    }
}
#endif
