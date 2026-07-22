import Foundation
import PulsePlayer

enum DemoMedia {
    static let bipbopHLS = URL(string:
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    )!

    static let bigBuckBunnyMP4 = URL(string:
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    )!

    static let elephantsDreamMP4 = URL(string:
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4"
    )!

    static let forBiggerBlazesMP4 = URL(string:
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"
    )!

    static let feedItems: [FeedItem] = [
        FeedItem(id: "bbb", url: bigBuckBunnyMP4, title: "Big Buck Bunny"),
        FeedItem(id: "elephants", url: elephantsDreamMP4, title: "Elephants Dream"),
        FeedItem(id: "blazes", url: forBiggerBlazesMP4, title: "For Bigger Blazes"),
        FeedItem(id: "bipbop", url: bipbopHLS, title: "BipBop HLS"),
    ]

    /// Dense SRT so cues stay visible for the first ~2 minutes of demos.
    static let sampleSRT: String = {
        var lines: [String] = []
        var index = 1
        let phrases = [
            "PulsePlayer — external SRT",
            "Scrub the timeline to test sync",
            "Offset slider shifts all cues",
            "Style: size, color, position",
            "Toggle off/on without reloading",
            "Built-in chrome: play · seek · volume",
        ]
        // Every 4s for first 120s.
        for start in stride(from: 0, through: 116, by: 4) {
            let end = start + 3
            let text = phrases[(index - 1) % phrases.count]
            lines.append("\(index)")
            lines.append(String(format: "00:%02d:%02d,000 --> 00:%02d:%02d,000", start / 60, start % 60, end / 60, end % 60))
            lines.append(text)
            lines.append("")
            index += 1
        }
        return lines.joined(separator: "\n")
    }()

    static func source(
        url: URL = bipbopHLS,
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
