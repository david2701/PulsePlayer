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
            ScrollView {
                VStack(spacing: 16) {
                    PulsePlayerView(
                        session: session,
                        showsSubtitles: true,
                        showsControls: true
                    )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)

                    GroupBox("Active cue") {
                        Text(session.currentSubtitleText ?? "—")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.body.weight(.medium))
                    }
                    .padding(.horizontal, 16)

                    GroupBox("Track") {
                        Toggle("Subtitles enabled", isOn: Binding(
                            get: { session.subtitlesEnabled },
                            set: { session.setSubtitlesEnabled($0) }
                        ))
                        if !session.subtitleTracks.isEmpty {
                            Picker("Track", selection: Binding(
                                get: { session.activeSubtitleTrackID ?? "" },
                                set: { session.selectSubtitle(id: $0.isEmpty ? nil : $0) }
                            )) {
                                Text("Off").tag("")
                                ForEach(session.subtitleTracks) { track in
                                    Text(track.label ?? track.id).tag(track.id)
                                }
                            }
                        }
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)

                    GroupBox("Timing & style") {
                        labeledSlider("Offset s", value: $offset, range: -5...5) { value in
                            session.setSubtitleOffset(value, trackID: "en")
                        }
                        labeledSlider("Font size", value: $fontSize, range: 12...28) { _ in
                            applyStyle()
                        }
                        labeledSlider("Background", value: $bgOpacity, range: 0...0.9) { _ in
                            applyStyle()
                        }
                        Picker("Position", selection: $position) {
                            Text("Top").tag(SubtitleVerticalPosition.top)
                            Text("Center").tag(SubtitleVerticalPosition.center)
                            Text("Bottom").tag(SubtitleVerticalPosition.bottom)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: position) { _, _ in applyStyle() }

                        HStack {
                            Button("Default style") {
                                fontSize = 17
                                bgOpacity = 0.55
                                position = .bottom
                                applyStyle()
                            }
                            Button("Large") {
                                fontSize = 22
                                bgOpacity = 0.7
                                applyStyle()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Subtitles")
            .navigationBarTitleDisplayMode(.inline)
            .task { await bootstrap() }
            .onDisappear { session.pause() }
        }
    }

    private func bootstrap() async {
        await session.load(
            DemoMedia.source(url: DemoMedia.bigBuckBunnyMP4, id: "bbb-subs", title: "BBB + SRT")
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
            message = "\(track.cues.count) cues · scrub to verify sync"
            applyStyle()
            session.play()
        } catch {
            message = "Error: \(error.localizedDescription)"
        }
    }

    private func applyStyle() {
        session.applySubtitleStyle(
            SubtitleStyle(
                fontSize: fontSize,
                backgroundOpacity: bgOpacity,
                position: position
            )
        )
    }

    private func labeledSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title): \(String(format: "%.1f", value.wrappedValue))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: Binding(
                get: { value.wrappedValue },
                set: { value.wrappedValue = $0; onChange($0) }
            ), in: range)
        }
    }
}
