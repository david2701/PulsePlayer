import SwiftUI

/// Transport chrome rendered according to `PlayerChromeMode`.
public struct PulsePlayerControls: View {
    private let session: PlayerSession
    private let mode: PlayerChromeMode
    private let accent: Color

    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    public init(
        session: PlayerSession,
        mode: PlayerChromeMode = .full,
        accent: Color = .white
    ) {
        self.session = session
        self.mode = mode
        self.accent = accent
    }

    public var body: some View {
        Group {
            switch mode {
            case .none:
                EmptyView()
            case .minimal:
                minimalChrome
            case .lite:
                interactiveChrome { liteBar }
            case .full:
                interactiveChrome { fullBar }
            }
        }
        .foregroundStyle(accent)
    }

    // MARK: - Minimal (feed)

    private var minimalChrome: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { session.togglePlayPause() }

            if !session.isPlaying {
                Image(systemName: "play.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
                    .allowsHitTesting(false)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        session.toggleMute()
                    } label: {
                        Image(systemName: muteIcon)
                            .font(.body.weight(.semibold))
                            .padding(12)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - Interactive shells

    private func interactiveChrome<Bar: View>(@ViewBuilder bar: @escaping () -> Bar) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { toggleChrome() }

            VStack(spacing: 0) {
                Spacer()
                if controlsVisible {
                    bar()
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

    private var liteBar: some View {
        VStack(spacing: 8) {
            scrubber
            HStack(spacing: 14) {
                playButton
                Text(timePairLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button { session.toggleMute(); bumpChrome() } label: {
                    Image(systemName: muteIcon)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(barBackground)
    }

    private var fullBar: some View {
        VStack(spacing: 10) {
            scrubber
            HStack(spacing: 14) {
                playButton
                skipButton(-10, system: "gobackward.10")
                skipButton(10, system: "goforward.10")
                Text(timePairLabel)
                    .font(.caption.monospacedDigit())
                Spacer(minLength: 4)
                Button { session.toggleMute(); bumpChrome() } label: {
                    Image(systemName: muteIcon)
                }
                Slider(
                    value: Binding(
                        get: { Double(session.volume) },
                        set: { session.setVolume(Float($0)); bumpChrome() }
                    ),
                    in: 0...1
                )
                .frame(maxWidth: 100)
                .tint(accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(barBackground)
    }

    private var playButton: some View {
        Button {
            session.togglePlayPause()
            bumpChrome()
        } label: {
            Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                .font(.title3)
                .frame(width: 32, height: 32)
        }
    }

    private func skipButton(_ delta: TimeInterval, system: String) -> some View {
        Button {
            Task { await session.seek(relative: delta) }
            bumpChrome()
        } label: {
            Image(systemName: system)
                .font(.body.weight(.semibold))
        }
    }

    private var scrubber: some View {
        let duration = max(session.playbackDuration ?? 0, 0.001)
        let value = isScrubbing ? scrubTime : session.playbackTime
        return Slider(
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

    private var barBackground: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.82)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var timePairLabel: String {
        "\(timeLabel(displayTime)) / \(timeLabel(session.playbackDuration ?? 0))"
    }

    private var displayTime: TimeInterval {
        isScrubbing ? scrubTime : session.playbackTime
    }

    private var muteIcon: String {
        if session.isMuted || session.volume < 0.01 { return "speaker.slash.fill" }
        if session.volume < 0.45 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
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
        guard session.isPlaying, mode != .minimal else { return }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !isScrubbing, session.isPlaying else { return }
            controlsVisible = false
        }
    }

    private func timeLabel(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let total = Int(t.rounded(.down))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
