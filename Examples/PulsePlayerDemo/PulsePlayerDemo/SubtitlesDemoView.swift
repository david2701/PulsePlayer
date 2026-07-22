import PulsePlayer
import SwiftUI

struct SubtitlesDemoView: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(autoplay: true, isMuted: true)
    )
    @State private var offset: Double = 0
    @State private var fontSize: Double = 17
    @State private var bgOpacity: Double = 0.55
    @State private var position: SubtitleVerticalPosition = .bottom
    @State private var message = ""

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let playerHeight = min(geo.size.width * 9 / 16, geo.size.height * 0.38)
                VStack(spacing: 0) {
                    PulsePlayerView(
                        session: session,
                        videoGravity: .resizeAspect,
                        showsSubtitles: true,
                        chrome: .full
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: playerHeight)
                    .background(Color.black)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            GroupBox("Active cue") {
                                Text(session.currentSubtitleText ?? "—")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            GroupBox("Track") {
                                Toggle("Enabled", isOn: Binding(
                                    get: { session.subtitlesEnabled },
                                    set: { session.setSubtitlesEnabled($0) }
                                ))
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            GroupBox("Timing & style") {
                                sliderRow("Offset s", value: $offset, range: -5...5) {
                                    session.setSubtitleOffset($0, trackID: "en")
                                }
                                sliderRow("Font", value: $fontSize, range: 12...28) { _ in
                                    applyStyle()
                                }
                                sliderRow("Background", value: $bgOpacity, range: 0...0.9) { _ in
                                    applyStyle()
                                }
                                Picker("Position", selection: $position) {
                                    Text("Top").tag(SubtitleVerticalPosition.top)
                                    Text("Center").tag(SubtitleVerticalPosition.center)
                                    Text("Bottom").tag(SubtitleVerticalPosition.bottom)
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: position) { _, _ in applyStyle() }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Subtitles")
            .navigationBarTitleDisplayMode(.inline)
            .task { await bootstrap() }
            .onDisappear { session.pause() }
        }
    }

    private func bootstrap() async {
        await session.load(
            DemoMedia.source(url: DemoMedia.bipbopAdvanced, id: "subs", title: "BipBop + SRT")
        )
        do {
            let track = try session.addSubtitle(
                content: DemoMedia.sampleSRT,
                id: "en",
                languageCode: "en",
                label: "English",
                format: .srt,
                select: true
            )
            message = "\(track.cues.count) cues — scrub to verify sync"
            applyStyle()
            session.play()
        } catch {
            message = error.localizedDescription
        }
    }

    private func applyStyle() {
        session.applySubtitleStyle(
            SubtitleStyle(
                fontSize: fontSize,
                backgroundOpacity: bgOpacity,
                edgeInset: 72,
                position: position
            )
        )
    }

    private func sliderRow(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title): \(String(format: "%.1f", value.wrappedValue))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { value.wrappedValue },
                    set: { value.wrappedValue = $0; onChange($0) }
                ),
                in: range
            )
        }
    }
}
