import SwiftUI

/// Simple bottom-centered subtitle renderer bound to `PlayerSession`.
public struct PulseSubtitleOverlay: View {
    private let session: PlayerSession
    private let font: Font
    private let textColor: Color
    private let background: Color

    public init(
        session: PlayerSession,
        font: Font = .subheadline.weight(.semibold),
        textColor: Color = .white,
        background: Color = Color.black.opacity(0.55)
    ) {
        self.session = session
        self.font = font
        self.textColor = textColor
        self.background = background
    }

    public var body: some View {
        VStack {
            Spacer()
            if let text = session.currentSubtitleText, !text.isEmpty {
                Text(text)
                    .font(font)
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(background, in: RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: session.currentSubtitleText)
        .allowsHitTesting(false)
    }
}
