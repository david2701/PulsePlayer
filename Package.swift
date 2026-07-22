// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PulsePlayer",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        // macOS: enables `swift test` on developer machines; product focus remains iOS/tvOS.
        .macOS(.v14),
    ],
    products: [
        .library(name: "PulsePlayer", targets: ["PulsePlayer"]),
    ],
    targets: [
        .target(
            name: "PulsePlayer",
            path: "Sources/PulsePlayer",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "PulsePlayerTests",
            dependencies: ["PulsePlayer"],
            path: "Tests/PulsePlayerTests",
            resources: [
                .copy("Fixtures"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
