// swift-tools-version: 6.0
import PackageDescription

// Aurora — native macOS ambient lighting controller.
// Built with SwiftPM so it can be compiled headlessly with Command Line Tools
// (no full Xcode required). See docs/adr/0002-build-system-spm.md.
let package = Package(
    name: "Aurora",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AuroraApp", targets: ["AuroraApp"]),
        .library(name: "AuroraCore", targets: ["AuroraCore"]),
    ],
    targets: [
        .target(name: "AuroraCore"),
        .target(name: "AuroraDevice", dependencies: ["AuroraCore"]),
        .target(name: "AuroraCircadian", dependencies: ["AuroraCore"]),
        .target(name: "AuroraCapture", dependencies: ["AuroraCore"]),
        .target(name: "AuroraAudio", dependencies: ["AuroraCore"]),
        .target(
            name: "AuroraEngine",
            dependencies: ["AuroraCore", "AuroraDevice", "AuroraCircadian"]
        ),
        .executableTarget(
            name: "AuroraApp",
            dependencies: ["AuroraCore", "AuroraDevice", "AuroraCircadian", "AuroraEngine", "AuroraCapture", "AuroraAudio"]
        ),
        // Hardware bring-up CLI (M2): port detection, handshake, color/order test,
        // and live circadian on the real controller. See docs/protocol/.
        .executableTarget(
            name: "AuroraProbe",
            dependencies: ["AuroraCore", "AuroraDevice", "AuroraCircadian", "AuroraCapture", "AuroraAudio"]
        ),
        .testTarget(
            name: "AuroraTests",
            dependencies: ["AuroraCore", "AuroraCircadian", "AuroraDevice", "AuroraCapture", "AuroraAudio"]
        ),
    ]
)
