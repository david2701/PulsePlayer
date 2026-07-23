import SwiftUI

extension PulsePlayerControls {
    func prefersCenterTransport(for size: CGSize) -> Bool {
        #if os(tvOS)
        true
        #else
        size.height >= 330 && size.width >= 440
        #endif
    }

    var contextLine: String? {
        var parts: [String] = []
        if let subtitle = session.currentSource?.subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }
        if let marker = session.activeEditorialMarker {
            parts.append(marker.title)
        }
        if let latency = session.liveLatency {
            parts.append(
                PulsePlayerLocalization.format("Live delay %.1f seconds", latency)
            )
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var showsPlaybackStatus: Bool {
        switch session.status {
        case .loading, .buffering, .stalled, .failed:
            true
        default:
            false
        }
    }

    var qualityPill: some View {
        metadataPill(
            session.selectedQuality.id == StreamQuality.auto.id
                ? PulsePlayerLocalization.string("Auto")
                : session.selectedQuality.label,
            systemImage: session.isQualityHardLocked ? "lock.fill" : "waveform.path",
            tint: session.isQualityHardLocked ? .orange : accent
        )
        .accessibilityLabel(PulsePlayerLocalization.string("Quality"))
        .accessibilityValue(
            session.isQualityHardLocked
                ? PulsePlayerLocalization.format(
                    "Quality locked at %@",
                    session.selectedQuality.label
                )
                : session.selectedQuality.label
        )
    }

    func metadataPill(
        _ title: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(increasedContrast ? 0.55 : 0.28), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(increasedContrast ? 0.9 : 0.42), lineWidth: 1)
            }
    }

    func cinematicTransportButton(
        _ systemImage: String,
        label: String,
        emphasis: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(
                    size: emphasis ? primaryTransportIconSize : secondaryTransportIconSize,
                    weight: .bold
                ))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(
            PulsePlayerCinematicButtonStyle(
                accent: accent,
                diameter: emphasis ? primaryTransportDiameter : secondaryTransportDiameter,
                emphasis: emphasis
            )
        )
        .accessibilityLabel(label)
        .accessibilityInputLabels([label])
    }

    var primaryTransportDiameter: CGFloat {
        #if os(tvOS)
        104
        #else
        72
        #endif
    }

    var secondaryTransportDiameter: CGFloat {
        #if os(tvOS)
        78
        #else
        54
        #endif
    }

    var primaryTransportIconSize: CGFloat {
        #if os(tvOS)
        38
        #else
        28
        #endif
    }

    var secondaryTransportIconSize: CGFloat {
        #if os(tvOS)
        27
        #else
        20
        #endif
    }

    var leadingTimeText: String {
        guard session.currentSource?.isLive == true else {
            return timeLabel(displayTime)
        }
        if session.isAtLiveEdge {
            return PulsePlayerLocalization.string("Live").uppercased()
        }
        if let latency = session.liveLatency {
            return "−\(timeLabel(latency))"
        }
        return timeLabel(displayTime)
    }

    var trailingTimeText: String {
        session.currentSource?.isLive == true
            ? PulsePlayerLocalization.string("Live").uppercased()
            : timeLabel(session.playbackDuration ?? 0)
    }

    func speedLabel(_ rate: Double) -> String {
        rate == 1 ? PulsePlayerLocalization.string("Normal") : "\(rate.formatted())×"
    }

    var primaryTransport: some View {
        HStack(spacing: 22) {
            cinematicTransportButton(
                "gobackward.10",
                label: skipLabel(backward: true),
                emphasis: false
            ) {
                flashSeek(-skipInterval)
            }
            #if os(tvOS)
            .focused($focusedControl, equals: .skipBackward)
            #endif

            cinematicTransportButton(
                session.isPlaying ? "pause.fill" : "play.fill",
                label: playPauseLabel,
                emphasis: true
            ) {
                session.togglePlayPause()
                bumpChrome()
            }
            #if os(tvOS)
            .focused($focusedControl, equals: .playPause)
            .defaultFocus($focusedControl, .playPause)
            #endif

            cinematicTransportButton(
                "goforward.10",
                label: skipLabel(backward: false),
                emphasis: false
            ) {
                flashSeek(skipInterval)
            }
            #if os(tvOS)
            .focused($focusedControl, equals: .skipForward)
            #endif
        }
        .pulsePlayerFocusSection()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(PulsePlayerLocalization.string("Player controls"))
    }

    var playbackOptionsMenu: some View {
        Menu {
            Button {
                showTracks = true
                bumpChrome()
            } label: {
                Label(
                    PulsePlayerLocalization.string("Audio & subtitles"),
                    systemImage: "text.bubble"
                )
            }
            if showsQuality {
                Button {
                    showQuality = true
                    bumpChrome()
                } label: {
                    Label(
                        PulsePlayerLocalization.string("Quality"),
                        systemImage: "rectangle.connected.to.line.below"
                    )
                }
            }
            Divider()
            Menu(PulsePlayerLocalization.string("Playback speed")) {
                ForEach([0.5, 1, 1.25, 1.5, 2], id: \.self) { rate in
                    Button {
                        session.setRate(Float(rate))
                        bumpChrome()
                    } label: {
                        if abs(Double(session.playbackRate) - rate) < 0.01 {
                            Label(speedLabel(rate), systemImage: "checkmark")
                        } else {
                            Text(speedLabel(rate))
                        }
                    }
                }
            }
            Button {
                session.toggleMute()
                bumpChrome()
            } label: {
                Label(muteLabel, systemImage: muteIcon)
            }
            Section(PulsePlayerLocalization.string("Volume")) {
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
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(
            PulsePlayerLocalization.string("More playback options")
        )
    }
}

private extension View {
    @ViewBuilder
    func pulsePlayerFocusSection() -> some View {
        #if os(tvOS)
        focusSection()
        #else
        self
        #endif
    }
}

private struct PulsePlayerCinematicButtonStyle: ButtonStyle {
    let accent: Color
    let diameter: CGFloat
    let emphasis: Bool

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: diameter, height: diameter)
            .foregroundStyle(foregroundStyle)
            .background(backgroundStyle, in: Circle())
            .overlay {
                Circle().stroke(strokeColor, lineWidth: isFocused ? 3 : 1)
            }
            .shadow(
                color: .black.opacity(isFocused ? 0.52 : 0.34),
                radius: isFocused ? 18 : 10,
                y: 6
            )
            .scaleEffect(scale(configuration: configuration))
            .animation(
                reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.76),
                value: configuration.isPressed
            )
            .animation(
                reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.8),
                value: isFocused
            )
    }

    private var foregroundStyle: Color {
        isFocused || emphasis ? .black : .white
    }

    private var backgroundStyle: Color {
        if isFocused { return .white }
        if emphasis { return accent }
        return reduceTransparency ? .black.opacity(0.9) : .black.opacity(0.56)
    }

    private var strokeColor: Color {
        isFocused ? accent : .white.opacity(emphasis ? 0.62 : 0.26)
    }

    private func scale(configuration: Configuration) -> CGFloat {
        if configuration.isPressed { return 0.92 }
        if isFocused { return 1.1 }
        return 1
    }
}
