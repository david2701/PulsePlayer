import SwiftUI

extension PulsePlayerControls {
    var minimalChrome: some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { flashSeek(-skipInterval) }
                        .onTapGesture { session.togglePlayPause() }
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { flashSeek(skipInterval) }
                        .onTapGesture { session.togglePlayPause() }
                }

                if !session.isPlaying {
                    centerPlayBadge.allowsHitTesting(false)
                }

                VStack {
                    HStack(spacing: 10) {
                        if session.currentSource?.isLive == true { livePill }
                        Spacer(minLength: 0)
                        glassIconButton(muteIcon) { session.toggleMute() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    Spacer()
                    titleCaption
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func interactiveShell<Bar: View>(@ViewBuilder bar: @escaping () -> Bar) -> some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { flashSeek(-skipInterval) }
                            .onTapGesture { toggleChrome() }
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { flashSeek(skipInterval) }
                            .onTapGesture { toggleChrome() }
                    }
                    .frame(height: max(0, geo.size.height - 120))
                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    if controlsVisible {
                        topBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                    if theme.showsScrubPreview,
                       let image = session.scrubPreviewImage,
                       isScrubbing
                    {
                        scrubPreview(image).padding(.bottom, 8)
                    }
                    if controlsVisible {
                        bar()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: controlsVisible)
        .onAppear { scheduleAutoHide() }
        .onChange(of: session.isPlaying) { _, playing in
            if playing { scheduleAutoHide() } else { controlsVisible = true }
        }
    }

    var topBar: some View {
        HStack(spacing: 10) {
            Text(session.currentSource?.title ?? " ")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if session.currentSource?.isLive == true {
                livePill.fixedSize()
            }
            statusPill.fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [.black.opacity(theme.topScrimOpacity), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// Times live on the scrubber row (never truncated by icon HStack).
    var liteBar: some View {
        VStack(spacing: 10) {
            timedScrubber
            HStack(spacing: 14) {
                controlButton(session.isPlaying ? "pause.fill" : "play.fill", size: 20) {
                    session.togglePlayPause(); bumpChrome()
                }
                Spacer(minLength: 0)
                if theme.showsBitrateChip { bitrateChip }
                controlButton(muteIcon, size: 15) {
                    session.toggleMute(); bumpChrome()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(bottomChromeBackground)
    }

    /// Primary icons only — times are on the scrubber line above.
    var fullBar: some View {
        VStack(spacing: 10) {
            timedScrubber

            HStack(spacing: 4) {
                controlButton(session.isPlaying ? "pause.fill" : "play.fill", size: 20) {
                    session.togglePlayPause(); bumpChrome()
                }
                controlButton("gobackward.10", size: 16) { flashSeek(-skipInterval) }
                controlButton("goforward.10", size: 16) { flashSeek(skipInterval) }

                Spacer(minLength: 8)

                if session.currentSource?.isLive == true {
                    liveEdgeButton
                }

                if theme.showsBitrateChip { bitrateChip }

                Menu {
                    Button {
                        showTracks = true; bumpChrome()
                    } label: {
                        Label("Audio & subtitles", systemImage: "text.bubble")
                    }
                    if showsQuality {
                        Button {
                            showQuality = true; bumpChrome()
                        } label: {
                            Label("Quality", systemImage: "rectangle.connected.to.line.below")
                        }
                    }
                    Divider()
                    Button {
                        session.toggleMute(); bumpChrome()
                    } label: {
                        Label(session.isMuted ? "Unmute" : "Mute", systemImage: muteIcon)
                    }
                    Section("Volume") {
                        Button("25%") { session.setVolume(0.25); bumpChrome() }
                        Button("50%") { session.setVolume(0.5); bumpChrome() }
                        Button("75%") { session.setVolume(0.75); bumpChrome() }
                        Button("100%") { session.setVolume(1); bumpChrome() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                #if canImport(UIKit) && !os(tvOS)
                if showsAirPlay {
                    AirPlayRoutePicker()
                        .frame(width: 32, height: 32)
                }
                #endif

                controlButton(muteIcon, size: 15) {
                    session.toggleMute(); bumpChrome()
                }

                if let onFullscreen {
                    controlButton("arrow.up.left.and.arrow.down.right", size: 14) {
                        onFullscreen(); bumpChrome()
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(bottomChromeBackground)
    }

    /// Industry layout: `0:06 ———●——— 10:00`
    var timedScrubber: some View {
        HStack(spacing: 8) {
            Text(timeLabel(displayTime))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: 42, alignment: .leading)
                .accessibilityLabel("Current time")

            scrubRow
                .frame(maxWidth: .infinity)

            Text(timeLabel(session.playbackDuration ?? 0))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 42, alignment: .trailing)
                .accessibilityLabel("Duration")
        }
    }

    private var liveEdgeButton: some View {
        Button {
            Task { await session.seekToLiveEdge() }
            bumpChrome()
        } label: {
            Text("LIVE")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    (session.isAtLiveEdge ? Color.red : Color.white.opacity(0.18)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}
