import SwiftUI

extension PulsePlayerControls {
    var minimalChrome: some View {
        GeometryReader { _ in
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
                        glassIconButton(
                            muteIcon,
                            label: session.isMuted
                                ? PulsePlayerLocalization.string("Unmute")
                                : PulsePlayerLocalization.string("Mute")
                        ) {
                            session.toggleMute()
                        }
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
            .accessibilityElement(children: .contain)
            .accessibilityLabel(PulsePlayerLocalization.string("Player controls"))
            .accessibilityAction(
                named: playPauseLabel
            ) {
                session.togglePlayPause()
            }
            .accessibilityAction(
                named: skipLabel(backward: true)
            ) {
                flashSeek(-skipInterval)
            }
            .accessibilityAction(
                named: skipLabel(backward: false)
            ) {
                flashSeek(skipInterval)
            }
        }
    }

    func interactiveShell<Bar: View>(
        @ViewBuilder bar: @escaping (_ usesCenterTransport: Bool) -> Bar
    ) -> some View {
        GeometryReader { geo in
            let usesCenterTransport = mode == .full && prefersCenterTransport(for: geo.size)

            ZStack {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 0) {
                    if controlsVisible {
                        topBar(compact: !usesCenterTransport)
                            .transition(reduceMotion
                                ? .opacity
                                : .move(edge: .top).combined(with: .opacity))
                    }
                    Spacer(minLength: 0)

                    if controlsVisible, usesCenterTransport {
                        primaryTransport
                            .transition(reduceMotion
                                ? .opacity
                                : .scale(scale: 0.94).combined(with: .opacity))
                    }

                    Spacer(minLength: 0)
                    if theme.showsScrubPreview,
                       let image = session.scrubPreviewImage,
                       isScrubbing
                    {
                        scrubPreview(image).padding(.bottom, 8)
                    }
                    if controlsVisible {
                        bar(usesCenterTransport)
                            .transition(reduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86),
            value: controlsVisible
        )
        .onAppear { scheduleAutoHide() }
        .onChange(of: session.isPlaying) { _, playing in
            if playing { scheduleAutoHide() } else { controlsVisible = true }
        }
    }

    func topBar(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: compact ? 2 : 5) {
                Text(session.currentSource?.title ?? " ")
                    .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
                    .lineLimit(1)

                if !compact, let contextLine {
                    Text(contextLine)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                if session.activeInterstitialID != nil {
                    metadataPill(
                        PulsePlayerLocalization.string("Ad").uppercased(),
                        systemImage: "megaphone.fill",
                        tint: .yellow
                    )
                }
                if session.currentSource?.isLive == true {
                    livePill.fixedSize()
                }
                if !session.availableQualities.isEmpty {
                    qualityPill
                }
                if showsPlaybackStatus {
                    statusPill.fixedSize()
                }
            }
        }
        .foregroundStyle(.white)
        #if os(tvOS)
        .padding(.horizontal, 56)
        .padding(.top, 38)
        .padding(.bottom, 28)
        #else
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 18)
        #endif
        .background(
            Group {
                if reduceTransparency {
                    Color.black.opacity(increasedContrast ? 0.98 : 0.9)
                } else {
                    LinearGradient(
                        colors: [.black.opacity(theme.topScrimOpacity), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        )
    }

    /// Times live on the scrubber row (never truncated by icon HStack).
    var liteBar: some View {
        VStack(spacing: 10) {
            timedScrubber
            HStack(spacing: 14) {
                controlButton(
                    session.isPlaying ? "pause.fill" : "play.fill",
                    size: 20,
                    label: playPauseLabel
                ) {
                    session.togglePlayPause(); bumpChrome()
                }
                Spacer(minLength: 0)
                if theme.showsBitrateChip { bitrateChip }
                controlButton(
                    muteIcon,
                    size: 15,
                    label: muteLabel
                ) {
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
    func fullBar(usesCenterTransport: Bool) -> some View {
        VStack(spacing: 10) {
            timedScrubber

            ViewThatFits(in: .horizontal) {
                fullTransportRow(
                    showsPrimaryControls: !usesCenterTransport,
                    showsSecondaryControls: true
                )
                fullTransportRow(
                    showsPrimaryControls: !usesCenterTransport,
                    showsSecondaryControls: false
                )
            }
        }
        #if os(tvOS)
        .padding(.horizontal, 56)
        .padding(.top, 18)
        .padding(.bottom, 42)
        #else
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        #endif
        .background(bottomChromeBackground)
    }

    func fullTransportRow(
        showsPrimaryControls: Bool,
        showsSecondaryControls: Bool
    ) -> some View {
        HStack(spacing: 4) {
            if showsPrimaryControls {
                controlButton(
                    session.isPlaying ? "pause.fill" : "play.fill",
                    size: 20,
                    label: playPauseLabel
                ) {
                    session.togglePlayPause(); bumpChrome()
                }
                controlButton(
                    "gobackward.10",
                    size: 16,
                    label: skipLabel(backward: true)
                ) { flashSeek(-skipInterval) }
                controlButton(
                    "goforward.10",
                    size: 16,
                    label: skipLabel(backward: false)
                ) { flashSeek(skipInterval) }
            } else if let marker = session.activeEditorialMarker {
                Label(marker.title, systemImage: marker.kind == .chapter ? "list.bullet" : "forward.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
            }

            Spacer(minLength: showsSecondaryControls ? 8 : 0)

            if session.currentSource?.isLive == true {
                liveEdgeButton
            }
            if showsSecondaryControls, theme.showsBitrateChip {
                bitrateChip
            }

            playbackOptionsMenu

            if showsSecondaryControls {
                #if canImport(UIKit) && !os(tvOS)
                if showsAirPlay {
                    AirPlayRoutePicker()
                        .frame(width: 44, height: 44)
                }
                #endif

                controlButton(
                    muteIcon,
                    size: 15,
                    label: muteLabel
                ) {
                    session.toggleMute(); bumpChrome()
                }
            }

            if let onFullscreen {
                controlButton(
                    "arrow.up.left.and.arrow.down.right",
                    size: 14,
                    label: PulsePlayerLocalization.string("Enter full screen")
                ) {
                    onFullscreen(); bumpChrome()
                }
            }
        }
    }

    /// Industry layout: `0:06 ———●——— 10:00`
    var timedScrubber: some View {
        HStack(spacing: 8) {
            Text(leadingTimeText)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
                .frame(minWidth: 42, alignment: .leading)
                .accessibilityLabel(PulsePlayerLocalization.string("Current time"))
                .accessibilityValue(leadingTimeText)

            scrubRow
                .frame(maxWidth: .infinity)

            Text(trailingTimeText)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(minWidth: 42, alignment: .trailing)
                .accessibilityLabel(PulsePlayerLocalization.string("Duration"))
                .accessibilityValue(trailingTimeText)
        }
    }

    private var liveEdgeButton: some View {
        Button {
            Task { await session.seekToLiveEdge() }
            bumpChrome()
        } label: {
            Text(PulsePlayerLocalization.string("Live").uppercased())
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    (session.isAtLiveEdge ? Color.red : Color.white.opacity(0.18)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(PulsePlayerLocalization.string("Go to live"))
        .accessibilityValue(
            session.isAtLiveEdge
                ? PulsePlayerLocalization.string("Live")
                : PulsePlayerLocalization.string("Go to live")
        )
    }
}
