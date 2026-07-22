import Foundation
import PulsePlayer

enum DemoMedia {
    /// Apple sample HLS (public).
    static let bipbopHLS = URL(string:
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    )!

    /// Short Big Buck Bunny progressive (often used in demos).
    static let bigBuckBunnyMP4 = URL(string:
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    )!

    static let feedItems: [FeedItem] = [
        FeedItem(
            id: "bipbop",
            url: bipbopHLS,
            title: "BipBop HLS"
        ),
        FeedItem(
            id: "bbb",
            url: bigBuckBunnyMP4,
            title: "Big Buck Bunny"
        ),
        FeedItem(
            id: "bipbop2",
            url: bipbopHLS,
            title: "BipBop again"
        ),
    ]

    static let sampleSRT = """
    1
    00:00:00,000 --> 00:00:03,000
    PulsePlayer demo subtitles

    2
    00:00:03,000 --> 00:00:07,000
    SRT track loaded in-memory

    3
    00:00:07,000 --> 00:00:12,000
    Offset and selection work live

    4
    00:00:12,000 --> 00:00:20,000
    Enjoy the playback
    """

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
