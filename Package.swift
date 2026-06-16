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
        // Core models, diagnostics, serialization
        .target(
            name: "PortPulseCore",
            path: "Sources/PortPulseCore"
        ),
        
        // IOKit hardware interface
        .target(
            name: "PortPulseHardware",
            dependencies: ["PortPulseCore"],
            path: "Sources/PortPulseHardware"
        ),
        
        // Port monitoring and event diffing
        .target(
            name: "PortPulseMonitor",
            dependencies: ["PortPulseCore", "PortPulseHardware"],
            path: "Sources/PortPulseMonitor"
        ),
        
        // CLI tool
        .executableTarget(
            name: "PortPulseCLI",
            dependencies: ["PortPulseCore", "PortPulseHardware", "PortPulseMonitor"],
            path: "Sources/PortPulseCLI"
        ),
        
        // Widget extension
        .executableTarget(
            name: "PortPulseWidget",
            dependencies: ["PortPulseCore", "PortPulseHardware"],
            path: "Sources/PortPulseWidget"
        ),
        
        // Tests
        .testTarget(
            name: "PortPulseTests",
            dependencies: ["PortPulseCore", "PortPulseHardware"],
            path: "Tests"
        ),
    ]
)
