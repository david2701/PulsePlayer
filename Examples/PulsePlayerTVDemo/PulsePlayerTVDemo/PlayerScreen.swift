import PulsePlayer
import SwiftUI

/// Full-screen player with Siri Remote play/pause and focusable transport.
struct PlayerScreen: View {
    let item: CatalogItem

    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(
            autoplay: true,
            isMuted: false,
            allowsPictureInPicture: false,
            updatesNowPlayingInfo: true,
            preferHardQualityLock: true
        )
    )
    @State private var showChrome = true
    @FocusState private var transportFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PulsePlayerView(
                session: session,
                videoGravity: .resizeAspect,
                showsSubtitles: false,
                chrome: .none,
                theme: .cinema,
                enableGestures: false
            )
            .ignoresSafeArea()

            if showChrome {
                VStack {
                    topBar
                    Spacer()
                    bottomChrome
                }
                .transition(.opacity)
            }

            if session.status == .failed {
                failureBanner
            }
        }
        .onPlayPauseCommand {
            PulsePlayerTVCommands.handlePlayPause(session: session)
            flashChrome()
        }
        .onExitCommand {
            // Default navigation pop when chrome hidden feels natural.
        }
        .task {
            await session.load(DemoMedia.source(from: item))
        }
        .onDisappear {
            session.pause()
        }
        .onAppear {
            transportFocused = true
            scheduleHide()
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.title2.bold())
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if session.isQualityHardLocked {
                Text("LOCKED \(session.selectedQuality.label)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.35), in: Capsule())
            }
        }
        .padding(.horizontal, 56)
        .padding(.top, 40)
        .background(
            LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
        )
    }

    private var bottomChrome: some View {
        VStack(spacing: 28) {
            progressRow
            HStack(spacing: 40) {
                PulsePlayerTVControls(session: session)
                    .focused($transportFocused)

                Menu {
                    Button("Auto") {
                        Task { await session.setQualityAuto() }
                    }
                    ForEach(session.availableQualities) { q in
                        Button(q.label) {
                            Task { await session.setQuality(q) }
                        }
                    }
                } label: {
                    Label("Quality", systemImage: "rectangle.connected.to.line.below")
                        .font(.headline)
                }
                .buttonStyle(.card)
            }
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 48)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.75), .black.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        )
    }

    private var progressRow: some View {
        HStack(spacing: 16) {
            Text(timeLabel(session.playbackTime))
                .font(.caption.monospacedDigit())
                .frame(width: 72, alignment: .leading)
            ProgressView(value: progress)
                .tint(.cyan)
            Text(timeLabel(session.playbackDuration ?? 0))
                .font(.caption.monospacedDigit())
                .frame(width: 72, alignment: .trailing)
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 8)
    }

    private var failureBanner: some View {
        VStack(spacing: 16) {
            Text("Playback failed")
                .font(.title2.bold())
            Text(session.currentError?.userMessage ?? "Unknown error")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if session.currentError?.isRecoverable == true {
                Button("Retry") {
                    Task { await session.retry() }
                }
                .buttonStyle(.card)
            }
        }
        .padding(40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var statusLine: String {
        var parts = [session.status.rawValue]
        if let bps = session.indicatedBitrate, bps > 0 {
            parts.append(String(format: "%.1f Mbps", bps / 1_000_000))
        }
        if !session.availableQualities.isEmpty {
            parts.append("\(session.availableQualities.count) variants")
        }
        return parts.joined(separator: " · ")
    }

    private var progress: Double {
        let d = session.playbackDuration ?? 0
        guard d > 0 else { return 0 }
        return min(1, max(0, session.playbackTime / d))
    }

    private func timeLabel(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let total = Int(t.rounded(.down))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func flashChrome() {
        showChrome = true
        scheduleHide()
    }

    private func scheduleHide() {
        Task {
            try? await Task.sleep(for: .seconds(4))
            if session.isPlaying {
                withAnimation { showChrome = false }
            }
        }
    }
}
