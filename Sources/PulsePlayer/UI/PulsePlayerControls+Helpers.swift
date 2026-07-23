import SwiftUI

extension PulsePlayerControls {
    var scrubRow: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                let p = max(0, min(1, session.bufferProgressValue ?? 0))
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: max(0, geo.size.width * p))
            }
            .frame(height: 4)
            .padding(.horizontal, 2)
            scrubber
        }
        .frame(height: 28)
    }

    @ViewBuilder
    var scrubber: some View {
        let span = scrubSpan
        let base = scrubBase
        let absolute = isScrubbing ? scrubTime : session.playbackTime
        let value = min(max(0, absolute - base), span)

        #if os(tvOS)
        // SwiftUI `Slider` is unavailable on tvOS — show progress; seek via remote ±skip.
        ProgressView(value: span > 0 ? value / span : 0)
            .tint(accent)
            .frame(maxWidth: .infinity)
            .frame(height: 12)
            .focusable()
            .onMoveCommand { direction in
                switch direction {
                case .left:
                    flashSeek(-skipInterval)
                case .right:
                    flashSeek(skipInterval)
                default:
                    break
                }
            }
            .accessibilityLabel(PulsePlayerLocalization.string("Current time"))
            .accessibilityValue(timeLabel(absolute))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    flashSeek(skipInterval)
                case .decrement:
                    flashSeek(-skipInterval)
                @unknown default:
                    break
                }
            }
        #else
        Slider(
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
            in: 0...span,
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
        .accessibilityLabel(PulsePlayerLocalization.string("Current time"))
        .accessibilityValue(timeLabel(absolute))
        #endif
    }

    var scrubSpan: Double {
        if session.currentSource?.isLive == true, let range = session.seekableTimeRange {
            return max(range.upperBound - range.lowerBound, 0.001)
        }
        return max(session.playbackDuration ?? 0, 0.001)
    }

    var scrubBase: Double {
        if session.currentSource?.isLive == true, let range = session.seekableTimeRange {
            return range.lowerBound
        }
        return 0
    }

    var centerPlayBadge: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(.white)
            .padding(22)
            .background(
                reduceTransparency
                    ? AnyShapeStyle(Color.black.opacity(0.9))
                    : AnyShapeStyle(.ultraThinMaterial.opacity(0.55)),
                in: Circle()
            )
            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
    }

    var titleCaption: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.currentSource?.title ?? "")
                    .font(.headline)
                Text(
                    PulsePlayerLocalization.format(
                        "Tap to play or pause · double-tap to skip %d seconds",
                        Int(skipInterval)
                    )
                )
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
        }
    }

    var livePill: some View {
        Text(PulsePlayerLocalization.string("Live").uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red, in: Capsule())
    }

    var statusPill: some View {
        Text(localizedStatus.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.14), in: Capsule())
    }

    var bitrateChip: some View {
        Group {
            if let bps = session.indicatedBitrate ?? session.observedBitrate, bps > 0 {
                Text(bps >= 1_000_000
                     ? String(format: "%.1fM", bps / 1_000_000)
                     : String(format: "%.0fk", bps / 1000))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(theme.chipOpacity), in: Capsule())
            }
        }
    }

    @ViewBuilder
    var bottomChromeBackground: some View {
        if reduceTransparency {
            Color.black.opacity(increasedContrast ? 0.98 : 0.9)
                .ignoresSafeArea(edges: .bottom)
        } else {
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(theme.bottomScrimOpacity * 0.62),
                    .black.opacity(theme.bottomScrimOpacity),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    var seekFlashOverlay: some View {
        Group {
            if let seekFlash {
                Text(seekFlash)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        reduceTransparency
                            ? AnyShapeStyle(Color.black.opacity(0.92))
                            : AnyShapeStyle(.ultraThinMaterial),
                        in: Capsule()
                    )
                    .overlay(Capsule().stroke(Color.white.opacity(0.25)))
                    .transition(reduceMotion
                        ? .opacity
                        : .scale.combined(with: .opacity))
            }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8),
            value: seekFlash
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    func scrubPreview(_ image: CGImage) -> some View {
        #if canImport(UIKit)
        VStack(spacing: 6) {
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: theme.scrubPreviewWidth, height: theme.scrubPreviewHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(accent.opacity(0.55), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.45), radius: 12, y: 6)

            Text(timeLabel(displayTime))
                .font(.caption.monospacedDigit().weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    reduceTransparency
                        ? AnyShapeStyle(Color.black.opacity(0.92))
                        : AnyShapeStyle(.ultraThinMaterial.opacity(0.9)),
                    in: Capsule()
                )
        }
        #endif
    }

    func controlButton(
        _ system: String,
        size: CGFloat,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size, weight: .semibold))
                .frame(
                    width: max(44, theme.controlIconSize),
                    height: max(44, theme.controlIconSize)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PulsePlayerIconButtonStyle())
        .accessibilityLabel(label)
        .accessibilityInputLabels([label])
    }

    func glassIconButton(
        _ system: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.body.weight(.semibold))
                .padding(12)
                .frame(minWidth: 44, minHeight: 44)
                .background(
                    reduceTransparency
                        ? AnyShapeStyle(Color.black.opacity(0.9))
                        : AnyShapeStyle(.ultraThinMaterial.opacity(0.7)),
                    in: Circle()
                )
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(PulsePlayerIconButtonStyle())
        .accessibilityLabel(label)
        .accessibilityInputLabels([label])
    }

    var displayTime: TimeInterval { isScrubbing ? scrubTime : session.playbackTime }

    var muteIcon: String {
        if session.isMuted || session.volume < 0.01 { return "speaker.slash.fill" }
        if session.volume < 0.45 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }

    var playPauseLabel: String {
        session.isPlaying
            ? PulsePlayerLocalization.string("Pause")
            : PulsePlayerLocalization.string("Play")
    }

    var muteLabel: String {
        session.isMuted
            ? PulsePlayerLocalization.string("Unmute")
            : PulsePlayerLocalization.string("Mute")
    }

    func skipLabel(backward: Bool) -> String {
        if backward {
            return PulsePlayerLocalization.format(
                "Skip backward %d seconds",
                Int(skipInterval)
            )
        }
        return PulsePlayerLocalization.format(
            "Skip forward %d seconds",
            Int(skipInterval)
        )
    }

    var localizedStatus: String {
        switch session.status {
        case .idle: PulsePlayerLocalization.string("Idle")
        case .loading: PulsePlayerLocalization.string("Loading")
        case .ready: PulsePlayerLocalization.string("Ready")
        case .playing: PulsePlayerLocalization.string("Playing")
        case .buffering: PulsePlayerLocalization.string("Buffering")
        case .stalled: PulsePlayerLocalization.string("Stalled")
        case .ended: PulsePlayerLocalization.string("Ended")
        case .failed: PulsePlayerLocalization.string("Failed")
        case .invalidated: PulsePlayerLocalization.string("Closed")
        }
    }

    func flashSeek(_ delta: TimeInterval) {
        Task { await session.seek(relative: delta) }
        seekFlash = delta >= 0 ? "+\(Int(delta))s" : "\(Int(delta))s"
        bumpChrome()
        seekFlashTask?.cancel()
        seekFlashTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            seekFlash = nil
            seekFlashTask = nil
        }
    }

    func toggleChrome() {
        controlsVisible.toggle()
        if controlsVisible { scheduleAutoHide() }
    }

    func bumpChrome() {
        controlsVisible = true
        scheduleAutoHide()
    }

    func scheduleAutoHide() {
        hideTask?.cancel()
        guard session.isPlaying, mode != .minimal else { return }
        let delay = theme.autoHideDelay
        hideTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, !isScrubbing, session.isPlaying else { return }
            controlsVisible = false
        }
    }

    func timeLabel(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let total = Int(t.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(
                format: "%d:%02d:%02d",
                locale: Locale.current,
                h,
                m,
                s
            )
        }
        return String(format: "%d:%02d", locale: Locale.current, m, s)
    }
}

private struct PulsePlayerIconButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? 0.94 : 1
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}
