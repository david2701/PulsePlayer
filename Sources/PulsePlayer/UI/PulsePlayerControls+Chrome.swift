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
                // Tap / double-tap zones (leave bottom band free for scrubber hits).
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
                    .frame(height: max(0, geo.size.height - 110))
                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    if controlsVisible {
                        topBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                    if let image = session.scrubPreviewImage, isScrubbing {
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
        HStack(alignment: .center, spacing: 10) {
            Text(session.currentSource?.title ?? " ")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            if session.currentSource?.isLive == true {
                livePill
                    .fixedSize()
            }
            statusPill
                .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.65), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// Compact transport — fits iPhone width without clipping.
    var liteBar: some View {
        VStack(spacing: 8) {
            scrubRow
            HStack(spacing: 12) {
                controlButton(session.isPlaying ? "pause.fill" : "play.fill", size: 20) {
                    session.togglePlayPause(); bumpChrome()
                }
                .fixedSize()

                Text(timePairLabel)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .fixedSize()

                Spacer(minLength: 4)
                bitrateChip
                controlButton(muteIcon, size: 15) {
                    session.toggleMute(); bumpChrome()
                }
                .fixedSize()
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(bottomChromeBackground)
    }

    /// Full chrome: primary row + overflow menu (never packs a volume Slider into a tight HStack).
    var fullBar: some View {
        VStack(spacing: 8) {
            scrubRow

            HStack(spacing: 10) {
                // Primary cluster — always visible, never compresses away.
                HStack(spacing: 8) {
                    controlButton(session.isPlaying ? "pause.fill" : "play.fill", size: 20) {
                        session.togglePlayPause(); bumpChrome()
                    }
                    controlButton("gobackward.10", size: 16) { flashSeek(-skipInterval) }
                    controlButton("goforward.10", size: 16) { flashSeek(skipInterval) }
                }
                .fixedSize()

                Text(timePairLabel)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)

                Spacer(minLength: 6)

                if session.currentSource?.isLive == true {
                    liveEdgeButton
                        .fixedSize()
                }

                bitrateChip

                // Overflow: tracks, quality, volume, AirPlay — prevents edge clipping.
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
                        // Menu can't host live Slider well; stepped volume.
                        Button("Volume 25%") { session.setVolume(0.25); bumpChrome() }
                        Button("Volume 50%") { session.setVolume(0.5); bumpChrome() }
                        Button("Volume 75%") { session.setVolume(0.75); bumpChrome() }
                        Button("Volume 100%") { session.setVolume(1); bumpChrome() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .fixedSize()

                #if canImport(UIKit) && !os(tvOS)
                if showsAirPlay {
                    AirPlayRoutePicker()
                        .frame(width: 30, height: 30)
                        .fixedSize()
                }
                #endif

                controlButton(muteIcon, size: 15) {
                    session.toggleMute(); bumpChrome()
                }
                .fixedSize()

                if let onFullscreen {
                    controlButton("arrow.up.left.and.arrow.down.right", size: 14) {
                        onFullscreen(); bumpChrome()
                    }
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(bottomChromeBackground)
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
