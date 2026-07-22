import PulsePlayer
import SwiftUI

struct BasicPlaybackDemoView: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(
            autoplay: true,
            isMuted: false,
            allowsPictureInPicture: true,
            updatesNowPlayingInfo: true
        )
    )
    @State private var chrome: PlayerChromeMode = .full
    @State private var themeName = "Default"

    private var theme: PlayerChromeTheme {
        switch themeName {
        case "Pulse": return .pulse
        case "Cinema": return .cinema
        default: return .default
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                // Keep room for transport chrome (~120pt) so controls never clip.
                let ideal = geo.size.width * 9 / 16
                let playerHeight = min(max(ideal, 240), geo.size.height * 0.48)

                VStack(spacing: 0) {
                    PulsePlayerView(
                        session: session,
                        videoGravity: .resizeAspect,
                        showsSubtitles: false,
                        chrome: chrome,
                        theme: theme
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: playerHeight)
                    .background(Color.black)
                    .clipped()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                statusChip
                                Spacer()
                                if session.isPictureInPicturePossible {
                                    Button {
                                        session.startPictureInPicture()
                                    } label: {
                                        Label("PiP", systemImage: "pip.enter")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            Text(session.currentSource?.title ?? "No source")
                                .font(.title3.bold())

                            Text("Chrome mode")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Picker("Chrome", selection: $chrome) {
                                Text("Full").tag(PlayerChromeMode.full)
                                Text("Lite").tag(PlayerChromeMode.lite)
                                Text("Minimal").tag(PlayerChromeMode.minimal)
                                Text("None").tag(PlayerChromeMode.none)
                            }
                            .pickerStyle(.segmented)

                            Text("Theme")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Picker("Theme", selection: $themeName) {
                                Text("Default").tag("Default")
                                Text("Pulse").tag("Pulse")
                                Text("Cinema").tag("Cinema")
                            }
                            .pickerStyle(.segmented)

                            Text(helpText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Playback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Source") {
                        Button("BipBop Advanced") {
                            Task { await load(DemoMedia.bipbopAdvanced, "BipBop Advanced") }
                        }
                        Button("BipBop 16:9") {
                            Task { await load(DemoMedia.bipbop16x9, "BipBop 16:9") }
                        }
                        Button("BipBop 4:3") {
                            Task { await load(DemoMedia.bipbop4x3, "BipBop 4:3") }
                        }
                        Button("BipBop Basic") {
                            Task { await load(DemoMedia.bipbopBasic, "BipBop Basic") }
                        }
                        Button("Advanced TS") {
                            Task { await load(DemoMedia.advancedTS, "Advanced TS") }
                        }
                    }
                }
            }
            .task { await load(DemoMedia.bipbopAdvanced, "BipBop Advanced") }
            .onDisappear { session.pause() }
        }
    }

    private var helpText: String {
        switch chrome {
        case .none: return "Surface only — host builds UI."
        case .minimal: return "Tap center play/pause · mute corner."
        case .lite: return "Scrubber + play + time + mute."
        case .full: return "Full transport: scrub, ±10s, volume."
        }
    }

    private var statusChip: some View {
        Text(session.status.rawValue.uppercased())
            .font(.caption2.weight(.bold).monospaced())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.15), in: Capsule())
    }

    private func load(_ url: URL, _ title: String) async {
        await session.load(DemoMedia.source(url: url, id: title, title: title))
        session.play()
    }
}
