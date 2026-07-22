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
                    HStack {
                        if session.currentSource?.isLive == true { livePill }
                        Spacer()
                        glassIconButton(muteIcon) { session.toggleMute() }
                    }
                    .padding(16)
                    Spacer()
                    titleCaption
                        .padding(.horizontal, 18)
                        .padding(.bottom, 28)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
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
                    .frame(height: geo.size.height * 0.72)
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { toggleChrome() }
                }

                VStack(spacing: 0) {
                    if controlsVisible {
                        topBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                    if let image = session.scrubPreviewImage, isScrubbing {
                        scrubPreview(image).padding(.bottom, 10)
                    }
                    if controlsVisible {
                        bar()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: controlsVisible)
        .onAppear { scheduleAutoHide() }
        .onChange(of: session.isPlaying) { _, playing in
            if playing { scheduleAutoHide() } else { controlsVisible = true }
        }
    }

    var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.currentSource?.title ?? " ")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let sub = session.currentSource?.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer()
            if session.currentSource?.isLive == true { livePill }
            statusPill
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.55), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    var liteBar: some View {
        VStack(spacing: 10) {
            scrubRow
            HStack(spacing: 18) {
                controlButton(session.isPlaying ? "pause.fill" : "play.fill", size: 22) {
                    session.togglePlayPause(); bumpChrome()
                }
                Text(timePairLabel)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                bitrateChip
                controlButton(muteIcon, size: 16) {
                    session.toggleMute(); bumpChrome()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(bottomChromeBackground)
    }

    var fullBar: some View {
        VStack(spacing: 12) {
            scrubRow
            HStack(spacing: 14) {
                controlButton(session.isPlaying ? "pause.fill" : "play.fill", size: 22) {
                    session.togglePlayPause(); bumpChrome()
                }
                controlButton("gobackward.10", size: 17) { flashSeek(-skipInterval) }
                controlButton("goforward.10", size: 17) { flashSeek(skipInterval) }

                Text(timePairLabel)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(minWidth: 88, alignment: .leading)

                Spacer(minLength: 6)
                bitrateChip

                if session.currentSource?.isLive == true {
                    Button {
                        Task { await session.seekToLiveEdge() }
                        bumpChrome()
                    } label: {
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                (session.isAtLiveEdge ? Color.red : Color.white.opacity(0.18)),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }

                controlButton("text.bubble", size: 15) {
                    showTracks = true; bumpChrome()
                }

                if showsQuality, !session.availableQualities.isEmpty {
                    controlButton("rectangle.connected.to.line.below", size: 15) {
                        showQuality = true; bumpChrome()
                    }
                }

                #if canImport(UIKit) && !os(tvOS)
                if showsAirPlay {
                    AirPlayRoutePicker().frame(width: 28, height: 28)
                }
                #endif

                if let onFullscreen {
                    controlButton("arrow.up.left.and.arrow.down.right", size: 14) {
                        onFullscreen(); bumpChrome()
                    }
                }

                controlButton(muteIcon, size: 15) {
                    session.toggleMute(); bumpChrome()
                }

                Slider(
                    value: Binding(
                        get: { Double(session.volume) },
                        set: { session.setVolume(Float($0)); bumpChrome() }
                    ),
                    in: 0...1
                )
                .frame(maxWidth: 84)
                .tint(accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(bottomChromeBackground)
    }
}
