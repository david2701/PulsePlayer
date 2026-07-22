import SwiftUI

/// Zero-chrome video surface bound to a long-lived `PlayerSession`.
public struct PulsePlayerView: View {
    private let session: PlayerSession
    private let videoGravity: PlayerVideoGravity
    private let showsSubtitles: Bool

    public init(
        session: PlayerSession,
        videoGravity: PlayerVideoGravity = .resizeAspect,
        showsSubtitles: Bool = true
    ) {
        self.session = session
        self.videoGravity = videoGravity
        self.showsSubtitles = showsSubtitles
    }

    public var body: some View {
        #if canImport(UIKit)
        ZStack {
            PlayerLayerRepresentable(session: session, videoGravity: videoGravity)
            if showsSubtitles {
                PulseSubtitleOverlay(session: session)
            }
        }
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
