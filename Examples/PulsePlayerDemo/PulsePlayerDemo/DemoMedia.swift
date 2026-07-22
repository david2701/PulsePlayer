import Foundation
import PulsePlayer

/// Demo sources — **Apple-hosted HLS only**.
/// Google sample MP4s often fail on simulator with NSURLError -1102
/// ("no permission to access the requested resource").
enum DemoMedia {
    /// Advanced fMP4 HLS (primary).
    static let bipbopAdvanced = URL(string:
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    )!

    /// Classic 16:9 multi-bitrate.
    static let bipbop16x9 = URL(string:
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
    )!

    /// Classic 4:3 multi-bitrate.
    static let bipbop4x3 = URL(string:
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"
    )!

    /// TS advanced stream.
    static let advancedTS = URL(string:
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/advanced_stream_ts/master.m3u8"
    )!

    /// Aliases used by demo screens.
    static let bipbopHLS = bipbopAdvanced

    static let feedItems: [FeedItem] = [
        FeedItem(id: "adv", url: bipbopAdvanced, title: "BipBop Advanced"),
        FeedItem(id: "16x9", url: bipbop16x9, title: "BipBop 16:9"),
        FeedItem(id: "4x3", url: bipbop4x3, title: "BipBop 4:3"),
        FeedItem(id: "ts", url: advancedTS, title: "Advanced TS"),
    ]

    /// Dense SRT so cues stay visible while scrubbing demos.
    static let sampleSRT: String = {
        var lines: [String] = []
        var index = 1
        let phrases = [
            "PulsePlayer — external SRT",
            "Scrub the timeline to test sync",
            "Offset slider shifts all cues",
            "Style: size, color, position",
            "Toggle off/on without reloading",
            "Chrome: full · lite · minimal",
        ]
        for start in stride(from: 0, through: 116, by: 4) {
            let end = start + 3
            let text = phrases[(index - 1) % phrases.count]
            lines.append("\(index)")
            lines.append(
                String(
                    format: "00:%02d:%02d,000 --> 00:%02d:%02d,000",
                    start / 60, start % 60, end / 60, end % 60
                )
            )
            lines.append(text)
            lines.append("")
            index += 1
        }
        return lines.joined(separator: "\n")
    }()

    static func source(
        url: URL = bipbopAdvanced,
        id: String = "demo",
        title: String = "Demo"
    ) -> MediaSource {
        MediaSource(id: id, url: url, title: title)
    }
}

struct FeedItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let title: String
}
