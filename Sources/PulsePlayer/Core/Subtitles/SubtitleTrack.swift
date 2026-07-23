import Foundation

/// External subtitle track attached to a session.
public struct SubtitleTrack: Sendable, Equatable, Identifiable, Hashable {
    public let id: String
    public var languageCode: String?
    public var label: String?
    public var format: SubtitleFormat
    public var sourceURL: URL?
    /// Applied when resolving active cues: `mediaTime + offset`.
    public var offset: TimeInterval
    private var storedCues: [SubtitleCue]
    public var cues: [SubtitleCue] {
        get { storedCues }
        set {
            storedCues = newValue.sorted { $0.start < $1.start }
            rebuildCueIndex()
        }
    }
    private var cueEndPrefixMaximums: [TimeInterval]

    public init(
        id: String = UUID().uuidString,
        languageCode: String? = nil,
        label: String? = nil,
        format: SubtitleFormat,
        sourceURL: URL? = nil,
        offset: TimeInterval = 0,
        cues: [SubtitleCue]
    ) {
        self.id = id
        self.languageCode = languageCode
        self.label = label
        self.format = format
        self.sourceURL = sourceURL
        self.offset = offset
        self.storedCues = cues.sorted { $0.start < $1.start }
        self.cueEndPrefixMaximums = []
        rebuildCueIndex()
    }

    package func activeCues(at adjustedTime: TimeInterval) -> [SubtitleCue] {
        var low = 0
        var high = storedCues.count
        while low < high {
            let mid = (low + high) / 2
            if storedCues[mid].start <= adjustedTime {
                low = mid + 1
            } else {
                high = mid
            }
        }

        var index = low - 1
        var active: [SubtitleCue] = []
        while index >= 0, cueEndPrefixMaximums[index] > adjustedTime {
            let cue = storedCues[index]
            if cue.contains(adjustedTime) {
                active.append(cue)
            }
            index -= 1
        }
        return active.reversed()
    }

    private mutating func rebuildCueIndex() {
        cueEndPrefixMaximums.removeAll(keepingCapacity: true)
        cueEndPrefixMaximums.reserveCapacity(storedCues.count)
        var maximum = -TimeInterval.infinity
        for cue in storedCues {
            maximum = max(maximum, cue.end)
            cueEndPrefixMaximums.append(maximum)
        }
    }
}
