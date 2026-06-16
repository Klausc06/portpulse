// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PortPulse",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PortPulseCore", targets: ["PortPulseCore"]),
        .library(name: "PortPulseHardware", targets: ["PortPulseHardware"]),
        .library(name: "PortPulseMonitor", targets: ["PortPulseMonitor"]),
        .executable(name: "portpulse", targets: ["PortPulseCLI"]),
    ],
    targets: [
        .target(
            name: "PortPulseCore",
            path: "Sources/PortPulseCore"
        ),
        .target(
            name: "PortPulseHardware",
            dependencies: ["PortPulseCore"],
            path: "Sources/PortPulseHardware"
        ),
        .target(
            name: "PortPulseMonitor",
            dependencies: ["PortPulseCore", "PortPulseHardware"],
            path: "Sources/PortPulseMonitor"
        ),
        .executableTarget(
            name: "PortPulseCLI",
            dependencies: ["PortPulseCore", "PortPulseHardware", "PortPulseMonitor"],
            path: "Sources/PortPulseCLI"
        ),
        .executableTarget(
            name: "PortPulseWidget",
            dependencies: ["PortPulseCore", "PortPulseHardware"],
            path: "Sources/PortPulseWidget"
        ),
        .executableTarget(
            name: "PortPulseIntents",
            dependencies: ["PortPulseCore", "PortPulseHardware"],
            path: "Sources/PortPulseIntents"
        ),
        .testTarget(
            name: "PortPulseTests",
            dependencies: ["PortPulseCore"],
            path: "Tests"
        ),
    ]
)
