// Example snippet for an iOS app target that depends on PulsePlayer via SPM.
// Copy into your app or open this folder as a reference when building the demo target.
//
// Requires: iOS 17+, import PulsePlayer

import PulsePlayer
import SwiftUI

struct BasicPlaybackView: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(autoplay: true, isMuted: true)
    )

    var body: some View {
        VStack(spacing: 12) {
            PulsePlayerView(session: session)
                .frame(maxWidth: .infinity)
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(Color.black)

            HStack {
                Button("Play") { session.play() }
                Button("Pause") { session.pause() }
                Button("Seek +10s") {
                    Task { await session.seek(relative: 10) }
                }
            }
            .buttonStyle(.bordered)

            Text(session.status.rawValue)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            // Public Apple sample stream (network required).
            let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")!
            await session.load(MediaSource(url: url, title: "BipBop"))
        }
    }
}
