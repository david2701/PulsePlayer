import SwiftUI

/// Transport chrome rendered according to `PlayerChromeMode`.
public struct PulsePlayerControls: View {
    private let session: PlayerSession
    private let mode: PlayerChromeMode
    private let accent: Color
    private let showsAirPlay: Bool
    private let showsQuality: Bool
    private let onFullscreen: (() -> Void)?

    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var showTracks = false
    @State private var showQuality = false

    public init(
        session: PlayerSession,
        mode: PlayerChromeMode = .full,
        accent: Color = .white,
        showsAirPlay: Bool = true,
        showsQuality: Bool = true,
        onFullscreen: (() -> Void)? = nil
    ) {
        self.session = session
        self.mode = mode
        self.accent = accent
        self.showsAirPlay = showsAirPlay
        self.showsQuality = showsQuality
        self.onFullscreen = onFullscreen
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
        .sheet(isPresented: $showTracks) {
            TrackPickerSheet(session: session)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showQuality) {
            QualityPickerSheet(session: session)
                .presentationDetents([.medium])
        }
    }

    private var minimalChrome: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { handleDoubleTap() }
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
                    if session.currentSource?.isLive == true {
                        liveBadge
                        Spacer()
                    } else {
                        Spacer()
                    }
                    Button { session.toggleMute() } label: {
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

    private func interactiveChrome<Bar: View>(@ViewBuilder bar: @escaping () -> Bar) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { handleDoubleTap() }
                .onTapGesture { toggleChrome() }

            VStack(spacing: 0) {
                if let image = session.scrubPreviewImage, isScrubbing {
                    scrubPreview(image)
                        .padding(.bottom, 8)
                }
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
        VStack(spacing: 6) {
            bufferBar
            scrubber
            HStack(spacing: 14) {
                playButton
                Text(timePairLabel)
                    .font(.caption.monospacedDigit())
                Spacer()
                bitrateLabel
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
        VStack(spacing: 8) {
            bufferBar
            scrubber
            HStack(spacing: 12) {
                playButton
                skipButton(-10, system: "gobackward.10")
                skipButton(10, system: "goforward.10")
                Text(timePairLabel)
                    .font(.caption.monospacedDigit())
                Spacer(minLength: 4)
                bitrateLabel
                if session.currentSource?.isLive == true {
                    Button("LIVE") {
                        Task { await session.seekToLiveEdge() }
                        bumpChrome()
                    }
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(session.isAtLiveEdge ? Color.red : Color.white.opacity(0.2), in: Capsule())
                }
                Button { showTracks = true; bumpChrome() } label: {
                    Image(systemName: "text.bubble")
                }
                if showsQuality, !session.availableQualities.isEmpty {
                    Button { showQuality = true; bumpChrome() } label: {
                        Image(systemName: "rectangle.connected.to.line.below")
                    }
                }
                #if canImport(UIKit)
                if showsAirPlay {
                    AirPlayRoutePicker()
                        .frame(width: 28, height: 28)
                }
                #endif
                if let onFullscreen {
                    Button { onFullscreen(); bumpChrome() } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                }
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
                .frame(maxWidth: 90)
                .tint(accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(barBackground)
    }

    private var bufferBar: some View {
        GeometryReader { geo in
            let p = max(0, min(1, session.bufferProgressValue ?? 0))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: geo.size.width * p)
            }
        }
        .frame(height: 3)
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
        let duration: Double = {
            if session.currentSource?.isLive == true,
               let range = session.seekableTimeRange
            {
                return max(range.upperBound - range.lowerBound, 0.001)
            }
            return max(session.playbackDuration ?? 0, 0.001)
        }()
        let base: Double = {
            if session.currentSource?.isLive == true,
               let range = session.seekableTimeRange
            {
                return range.lowerBound
            }
            return 0
        }()
        let absolute = isScrubbing ? scrubTime : session.playbackTime
        let value = min(max(0, absolute - base), duration)

        return Slider(
            value: Binding(
                get: { value },
                set: { newRelative in
                    let absTime = base + newRelative
                    if !isScrubbing {
                        isScrubbing = true
                        session.beginScrub()
                    }
                    scrubTime = absTime
                    session.updateScrub(time: absTime)
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

    @ViewBuilder
    private func scrubPreview(_ image: CGImage) -> some View {
        #if canImport(UIKit)
        Image(decorative: image, scale: 1, orientation: .up)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 160, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.3)))
        #endif
    }

    private var liveBadge: some View {
        Text("LIVE")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red, in: Capsule())
            .padding(16)
    }

    private var bitrateLabel: some View {
        Group {
            if let bps = session.indicatedBitrate ?? session.observedBitrate, bps > 0 {
                Text(bps >= 1_000_000
                     ? String(format: "%.1fM", bps / 1_000_000)
                     : String(format: "%.0fk", bps / 1000))
                    .font(.caption2.monospacedDigit())
                    .opacity(0.75)
            }
        }
    }

    private var barBackground: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.85)],
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

    private func handleDoubleTap() {
        // Approximate: double-tap seeks +10s (host can place side zones later).
        Task { await session.seek(relative: 10) }
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
