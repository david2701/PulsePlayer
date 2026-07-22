import SwiftUI

/// Subtitle renderer driven by `session.currentSubtitleText` + `session.subtitleStyle`.
public struct PulseSubtitleOverlay: View {
    private let session: PlayerSession

    public init(session: PlayerSession) {
        self.session = session
    }

    public var body: some View {
        let style = session.subtitleStyle
        Group {
            if session.subtitlesEnabled,
               let text = session.currentSubtitleText,
               !text.isEmpty
            {
                positioned {
                    Text(text)
                        .font(.system(
                            size: style.fontSize,
                            weight: style.fontWeightBold ? .semibold : .regular
                        ))
                        .foregroundStyle(textColor(style))
                        .multilineTextAlignment(.center)
                        .lineLimit(style.maxLines)
                        .padding(.horizontal, style.horizontalPadding)
                        .padding(.vertical, style.verticalPadding)
                        .background(
                            backgroundColor(style),
                            in: RoundedRectangle(cornerRadius: style.cornerRadius)
                        )
                        .padding(.horizontal, 20)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: session.currentSubtitleText)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func positioned<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let inset = session.subtitleStyle.edgeInset
        switch session.subtitleStyle.position {
        case .top:
            VStack {
                content().padding(.top, inset)
                Spacer()
            }
        case .center:
            VStack {
                Spacer()
                content()
                Spacer()
            }
        case .bottom:
            VStack {
                Spacer()
                content().padding(.bottom, inset)
            }
        }
    }

    private func textColor(_ style: SubtitleStyle) -> Color {
        Color(
            red: style.textRed,
            green: style.textGreen,
            blue: style.textBlue,
            opacity: style.textOpacity
        )
    }

    private func backgroundColor(_ style: SubtitleStyle) -> Color {
        Color(
            red: style.backgroundRed,
            green: style.backgroundGreen,
            blue: style.backgroundBlue,
            opacity: style.backgroundOpacity
        )
    }
}
