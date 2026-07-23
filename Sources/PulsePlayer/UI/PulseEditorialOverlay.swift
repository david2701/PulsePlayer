#if os(iOS) || os(tvOS)
import SwiftUI

struct PulseEditorialOverlay: View {
    let session: PlayerSession
    let accent: Color

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            playbackInfo
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, contextualTopInset)

            skipButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, contextualTopInset)

            if session.isUpNextPresented, let proposal = session.nextContentProposal {
                UpNextCard(session: session, proposal: proposal, accent: accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    #if os(tvOS)
                    .padding(64)
                    #else
                    .padding(20)
                    .padding(.bottom, 82)
                    #endif
            }
        }
        #if os(tvOS)
        .padding(40)
        #else
        .padding(12)
        #endif
    }

    @ViewBuilder
    private var playbackInfo: some View {
        if session.activeEditorialMarker != nil
            || session.liveLatency != nil
            || session.activeInterstitialID != nil
        {
            VStack(alignment: .leading, spacing: 5) {
                if session.activeInterstitialID != nil {
                    Label(
                        PulsePlayerLocalization.string("Advertisement"),
                        systemImage: "megaphone.fill"
                    )
                    .foregroundStyle(.yellow)
                }
            if let marker = session.activeEditorialMarker, marker.kind == .chapter {
                Label(marker.title, systemImage: "list.bullet")
                    .accessibilityLabel(
                        PulsePlayerLocalization.format("Chapter: %@", marker.title)
                    )
            }
            if let latency = session.liveLatency {
                Label(
                    PulsePlayerLocalization.format("Live delay %.1f seconds", latency),
                    systemImage: session.isCatchingUpToLive
                        ? "speedometer"
                        : "dot.radiowaves.left.and.right"
                )
            }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(overlayBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var skipButton: some View {
        if session.canSkipInterstitial {
            Button(PulsePlayerLocalization.string("Skip ad")) {
                session.skipActiveInterstitial()
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .accessibilityHint(PulsePlayerLocalization.string("Returns to the main video"))
        } else if let marker = session.activeEditorialMarker, marker.isSkippable {
            Button(skipLabel(for: marker.kind)) {
                Task { await session.skipActiveEditorialMarker() }
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .accessibilityHint(
                PulsePlayerLocalization.format("Skips to %.0f seconds", marker.end)
            )
        }
    }

    private var overlayBackground: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color.black.opacity(0.92))
            : AnyShapeStyle(.ultraThinMaterial)
    }

    private var contextualTopInset: CGFloat {
        #if os(tvOS)
        92
        #else
        48
        #endif
    }

    private func skipLabel(for kind: EditorialMarkerKind) -> String {
        switch kind {
        case .intro: PulsePlayerLocalization.string("Skip intro")
        case .recap: PulsePlayerLocalization.string("Skip recap")
        case .credits: PulsePlayerLocalization.string("Skip credits")
        case .chapter: PulsePlayerLocalization.string("Skip")
        }
    }
}

private struct UpNextCard: View {
    enum Action: Hashable {
        case play
        case dismiss
    }

    let session: PlayerSession
    let proposal: NextContentProposal
    let accent: Color

    #if os(tvOS)
    @FocusState private var focusedAction: Action?
    #endif
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 16) {
            if let imageURL = proposal.previewImageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.white.opacity(0.08)
                        .overlay { ProgressView().tint(.white) }
                }
                #if os(tvOS)
                .frame(width: 240, height: 135)
                #else
                .frame(width: 112, height: 72)
                #endif
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(PulsePlayerLocalization.string("Up Next").uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                Text(proposal.title)
                    .font(.headline)
                    .lineLimit(2)
                if let subtitle = proposal.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack {
                    Button(PulsePlayerLocalization.string("Play now")) {
                        Task { await session.acceptUpNext() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    #if os(tvOS)
                    .focused($focusedAction, equals: .play)
                    #endif

                    Button(PulsePlayerLocalization.string("Dismiss")) {
                        session.dismissUpNext()
                    }
                    .buttonStyle(.bordered)
                    #if os(tvOS)
                    .focused($focusedAction, equals: .dismiss)
                    #endif
                }
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(
            reduceTransparency
                ? AnyShapeStyle(Color.black.opacity(0.96))
                : AnyShapeStyle(.ultraThinMaterial),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        #if os(tvOS)
        .frame(maxWidth: 680)
        .focusSection()
        .defaultFocus($focusedAction, .play)
        #else
        .frame(maxWidth: 430)
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            PulsePlayerLocalization.format("Up Next: %@", proposal.title)
        )
    }
}
#endif
