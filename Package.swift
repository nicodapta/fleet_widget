// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "FleetWidget",
    platforms: [.macOS(.v12)],
    targets: [
        // Pure logic: registry reading, liveness, status diffing, alerting.
        // Kept free of AppKit so it can be unit tested headlessly.
        .target(name: "FleetWidgetCore"),

        // Thin AppKit shell: panel, rendering, sound.
        .executableTarget(name: "FleetWidget", dependencies: ["FleetWidgetCore"]),

        .testTarget(name: "FleetWidgetCoreTests", dependencies: ["FleetWidgetCore"]),
    ]
)
