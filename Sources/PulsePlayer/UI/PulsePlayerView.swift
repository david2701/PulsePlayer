import SwiftUI

/// Zero-chrome video surface bound to a long-lived `PlayerSession`.
public struct PulsePlayerView: View {
    private let session: PlayerSession
    private let videoGravity: PlayerVideoGravity

    public init(
        session: PlayerSession,
        videoGravity: PlayerVideoGravity = .resizeAspect
    ) {
        self.session = session
        self.videoGravity = videoGravity
    }

    public var body: some View {
        #if canImport(UIKit)
        PlayerLayerRepresentable(session: session, videoGravity: videoGravity)
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
