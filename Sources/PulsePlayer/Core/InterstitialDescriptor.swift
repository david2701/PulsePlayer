import Foundation

public struct InterstitialRestrictions: OptionSet, Sendable, Equatable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let constrainsSeekingForward = Self(rawValue: 1 << 0)
    public static let requiresPreferredRate = Self(rawValue: 1 << 1)
}

/// Client-scheduled native AVFoundation interstitial.
public struct InterstitialDescriptor: Sendable, Equatable, Identifiable {
    public let id: String
    public var time: TimeInterval
    public var assetURLs: [URL]
    public var restrictions: InterstitialRestrictions
    public var resumptionOffset: TimeInterval
    public var playoutLimit: TimeInterval?
    public var willPlayOnce: Bool
    public var alignsToSegmentBoundaries: Bool
    public var skipAfter: TimeInterval?

    public init(
        id: String = UUID().uuidString,
        time: TimeInterval,
        assetURLs: [URL],
        restrictions: InterstitialRestrictions = [],
        resumptionOffset: TimeInterval = 0,
        playoutLimit: TimeInterval? = nil,
        willPlayOnce: Bool = true,
        alignsToSegmentBoundaries: Bool = true,
        skipAfter: TimeInterval? = nil
    ) {
        self.id = id
        self.time = max(0, time)
        self.assetURLs = assetURLs
        self.restrictions = restrictions
        self.resumptionOffset = max(0, resumptionOffset)
        self.playoutLimit = playoutLimit
        self.willPlayOnce = willPlayOnce
        self.alignsToSegmentBoundaries = alignsToSegmentBoundaries
        self.skipAfter = skipAfter
    }
}
