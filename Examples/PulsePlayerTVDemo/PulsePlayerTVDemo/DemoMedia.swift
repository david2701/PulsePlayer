import Foundation
import PulsePlayer

enum DemoMedia {
    static let bipbopAdvanced = URL(string:
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    )!

    static let bipbop16x9 = URL(string:
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
    )!

    static let bipbop4x3 = URL(string:
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"
    )!

    static let catalog: [CatalogItem] = [
        CatalogItem(id: "adv", url: bipbopAdvanced, title: "BipBop Advanced", subtitle: "fMP4 multi-bitrate"),
        CatalogItem(id: "16x9", url: bipbop16x9, title: "BipBop 16:9", subtitle: "Classic ladder"),
        CatalogItem(id: "4x3", url: bipbop4x3, title: "BipBop 4:3", subtitle: "Legacy aspect"),
    ]

    static func source(from item: CatalogItem) -> MediaSource {
        MediaSource(
            id: item.id,
            url: item.url,
            fallbackURLs: catalog
                .map(\.url)
                .filter { $0 != item.url },
            title: item.title,
            subtitle: item.subtitle,
            interstitials: item.id == "adv"
                ? [
                    InterstitialDescriptor(
                        id: "pulse-demo-midroll",
                        time: 12,
                        assetURLs: [bipbop4x3],
                        playoutLimit: 6,
                        skipAfter: 3
                    ),
                ]
                : [],
            editorialMarkers: [
                EditorialMarker(
                    id: "\(item.id)-intro",
                    kind: .intro,
                    title: "Intro",
                    start: 2,
                    end: 6
                ),
                EditorialMarker(
                    id: "\(item.id)-chapter",
                    kind: .chapter,
                    title: "Main chapter",
                    start: 6,
                    end: 24
                ),
                EditorialMarker(
                    id: "\(item.id)-credits",
                    kind: .credits,
                    title: "Credits",
                    start: 24,
                    end: 30
                ),
            ]
        )
    }

    static func next(after item: CatalogItem) -> CatalogItem? {
        guard let index = catalog.firstIndex(of: item) else { return nil }
        return catalog.indices.contains(index + 1) ? catalog[index + 1] : nil
    }
}

struct CatalogItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let title: String
    let subtitle: String
}
