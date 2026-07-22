import CoreGraphics
import Foundation

public enum SubtitleVerticalPosition: String, Sendable, Equatable, CaseIterable {
    case top
    case center
    case bottom
}

/// Presentation style for external subtitles (overlay).
public struct SubtitleStyle: Sendable, Equatable {
    public var fontSize: CGFloat
    public var fontWeightBold: Bool
    public var textRed: Double
    public var textGreen: Double
    public var textBlue: Double
    public var textOpacity: Double
    public var backgroundRed: Double
    public var backgroundGreen: Double
    public var backgroundBlue: Double
    public var backgroundOpacity: Double
    public var cornerRadius: CGFloat
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat
    public var edgeInset: CGFloat
    public var position: SubtitleVerticalPosition
    public var maxLines: Int

    public init(
        fontSize: CGFloat = 17,
        fontWeightBold: Bool = true,
        textRed: Double = 1,
        textGreen: Double = 1,
        textBlue: Double = 1,
        textOpacity: Double = 1,
        backgroundRed: Double = 0,
        backgroundGreen: Double = 0,
        backgroundBlue: Double = 0,
        backgroundOpacity: Double = 0.55,
        cornerRadius: CGFloat = 8,
        horizontalPadding: CGFloat = 14,
        verticalPadding: CGFloat = 8,
        edgeInset: CGFloat = 56,
        position: SubtitleVerticalPosition = .bottom,
        maxLines: Int = 3
    ) {
        self.fontSize = fontSize
        self.fontWeightBold = fontWeightBold
        self.textRed = textRed
        self.textGreen = textGreen
        self.textBlue = textBlue
        self.textOpacity = textOpacity
        self.backgroundRed = backgroundRed
        self.backgroundGreen = backgroundGreen
        self.backgroundBlue = backgroundBlue
        self.backgroundOpacity = backgroundOpacity
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.edgeInset = edgeInset
        self.position = position
        self.maxLines = maxLines
    }

    public static let `default` = SubtitleStyle()

    public static let large = SubtitleStyle(fontSize: 22, edgeInset: 72)

    public static let highContrast = SubtitleStyle(
        fontSize: 18,
        backgroundOpacity: 0.8
    )
}
