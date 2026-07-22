import SwiftUI

/// Transport chrome: play/pause, interactive scrubber, time, mute, volume, ±skip.
public struct PulsePlayerControls: View {
    public struct Style {
        public var showsVolumeSlider: Bool
        public var skipInterval: TimeInterval

        public init(
            showsVolumeSlider: Bool = true,
            skipInterval: TimeInterval = 10
        ) {
            self.showsVolumeSlider = showsVolumeSlider
            self.skipInterval = skipInterval
        }
    }

    private let session: PlayerSession
    private let style: Style
    private let accent: Color

    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    public init(
        session: PlayerSession,
        style: Style = Style(),
        accent: Color = .white
    ) {
        self.session = session
        self.style = style
        self.accent = accent
    }

    public var body: some View {
        ZStack {
            // Tap surface to toggle chrome.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { toggleChrome() }

            VStack(spacing: 0) {
                Spacer()
                if controlsVisible {
                    chrome
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeOut(duration: 0.18), value: controlsVisible)
        .onAppear { scheduleAutoHide() }
        .onChange(of: session.isPlaying) { _, playing in
            if playing { scheduleAutoHide() } else { controlsVisible = true }
        }
    }

    private var chrome: some View {
        VStack(spacing: 10) {
            scrubber
            HStack(spacing: 16) {
                Button {
                    session.togglePlayPause()
                    bumpChrome()
                } label: {
                    Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 36, height: 36)
                }

                Button {
                    Task { await session.seek(relative: -style.skipInterval) }
                    bumpChrome()
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.body.weight(.semibold))
                }

                Button {
                    Task { await session.seek(relative: style.skipInterval) }
                    bumpChrome()
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.body.weight(.semibold))
                }

                Text(timeLabel(displayTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))

                Text(timeLabel(session.playbackDuration ?? 0))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))

                Spacer(minLength: 8)

                Button {
                    session.toggleMute()
                    bumpChrome()
                } label: {
                    Image(systemName: muteIcon)
                        .font(.body.weight(.semibold))
                }

                if style.showsVolumeSlider {
                    Slider(
                        value: Binding(
                            get: { Double(session.volume) },
                            set: { session.setVolume(Float($0)); bumpChrome() }
                        ),
                        in: 0...1
                    )
                    .frame(width: 88)
                    .tint(accent)
                }
            }
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var scrubber: some View {
        let duration = max(session.playbackDuration ?? 0, 0.001)
        let value = isScrubbing ? scrubTime : session.playbackTime
        return VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { min(max(0, value), duration) },
                    set: { newValue in
                        if !isScrubbing {
                            isScrubbing = true
                            session.beginScrub()
                        }
                        scrubTime = newValue
                        session.updateScrub(time: newValue)
                        bumpChrome()
                    }
                ),
                in: 0...duration,
                onEditingChanged: { editing in
                    if editing {
                        isScrubbing = true
                        scrubTime = session.playbackTime
                        session.beginScrub()
                    } else {
                        let t = scrubTime
                        isScrubbing = false
                        Task { await session.endScrub(commit: t) }
                    }
                    bumpChrome()
                }
            )
            .tint(accent)
        }
    }

    private var displayTime: TimeInterval {
        isScrubbing ? scrubTime : session.playbackTime
    }

    private var muteIcon: String {
        if session.isMuted || session.volume < 0.01 { return "speaker.slash.fill" }
        if session.volume < 0.4 { return "speaker.wave.1.fill" }
        if session.volume < 0.75 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func toggleChrome() {
        controlsVisible.toggle()
        if controlsVisible { scheduleAutoHide() }
    }

    private func bumpChrome() {
        controlsVisible = true
        scheduleAutoHide()
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        guard session.isPlaying else { return }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !isScrubbing, session.isPlaying else { return }
            controlsVisible = false
        }
    }

    private func timeLabel(_ t: TimeInterval) -> String {
        guard t.isFinite else { return "0:00" }
        let total = max(0, Int(t.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
