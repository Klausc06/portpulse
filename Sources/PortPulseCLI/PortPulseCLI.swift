import Foundation
import PortPulseCore
import PortPulseHardware
import PortPulseMonitor

@main
struct PortPulseCLI {
    static func main() {
        let args = CommandLine.arguments
        
        if args.contains("--help") || args.contains("-h") {
            printHelp()
            return
        }
        
        if args.contains("--version") || args.contains("-v") {
            print("portpulse 0.1.0")
            return
        }
        
        if args.contains("--json") {
            outputJSON()
            return
        }
        
        if args.contains("--watch") {
            watchMode()
            return
        }
        
        if args.contains("--raw") {
            outputRaw()
            return
        }
        
        if args.contains("--dashboard") {
            runDashboard()
            return
        }
        
        if args.contains("--debug-iokit") {
            debugIOKit()
            return
        }
        
        if args.contains("--snapshot") {
            snapshotExport()
            return
        }
        
        if let fromIndex = args.firstIndex(of: "--from") {
            let path = args.index(after: fromIndex) < args.count ? args[args.index(after: fromIndex)] : nil
            snapshotImport(path: path)
            return
        }
        
        if let portIndex = args.firstIndex(of: "--explain-port") {
            let n = args.index(after: portIndex) < args.count ? Int(args[args.index(after: portIndex)]) : nil
            explainPort(n)
            return
        }
        
        // Default: human-readable summary
        outputSummary()
    }
    
    static func printHelp() {
        print("""
        portpulse - USB-C cable diagnostics for macOS
        
        Usage:
          portpulse                    Human-readable summary of every port
          portpulse --json             Structured JSON output
          portpulse --watch            Stream updates as cables come and go
          portpulse --raw              Include underlying IOKit properties
          portpulse --dashboard        Live terminal dashboard
          portpulse --debug-iokit      Dump raw IOKit service data (JSON)
          portpulse --snapshot <file>  Export current state to JSON file
          portpulse --from <file>      Import snapshot and run diagnostics
          portpulse --explain-port N   Detailed info for port N
          portpulse --version          Show version
          portpulse --help             Show this help
        
        Dashboard controls:
          1/2/3    Switch screens (Overview/Negotiation/Power)
          Tab      Cycle through screens
          Q        Quit
        
        Requires macOS 14+ on Apple Silicon.
        """)
    }
    
    static func outputSummary() {
        let reader = IOKitReader()
        let engine = DiagnosticEngine.shared
        let ports = reader.readAllPorts()
        
        if ports.isEmpty {
            print("No USB-C ports found. Requires Apple Silicon Mac.")
            return
        }
        
        for port in ports {
            print(engine.buildPortSummary(port: port))
            print()
        }
    }
    
    static func outputJSON() {
        let reader = IOKitReader()
        let ports = reader.readAllPorts()
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try encoder.encode(ports.map { PortJSON(from: $0) })
            if let json = String(data: data, encoding: .utf8) {
                print(json)
            }
        } catch {
            fputs("Error encoding JSON: \(error)\n", stderr)
            exit(1)
        }
    }
    
    static func outputRaw() {
        let reader = IOKitReader()
        let ports = reader.readAllPorts()
        
        for port in ports {
            print("=== \(port.locationName) ===")
            print("  ID: \(port.id)")
            print("  Connection: \(port.connectionType.rawValue)")
            print("  Cable e-marker: \(port.cable.hasEMarker)")
            print("  Cable speed: \(port.cable.usbSpeed.rawValue)")
            print("  Cable current: \(port.cable.currentDescription)")
            print("  Cable max voltage: \(Int(port.cable.maxVoltage))V")
            print("  Cable max wattage: \(port.cable.wattageDescription)")
            print("  Cable vendor ID: 0x\(String(format: "%04X", port.cable.vendorID))")
            print("  Cable product ID: 0x\(String(format: "%04X", port.cable.productID))")
            if let revision = port.cable.pdRevision {
                print("  PD revision: \(revision)")
            }
            print("  Cable certified: \(port.cable.isCertified ? "Yes" : "No")")
            print("  Active transports: \(port.activeTransports.sorted().joined(separator: ", "))")
            print("  VCONN: \(port.hasVCONN)")
            if let orientation = port.plugOrientation {
                print("  Plug orientation: \(orientation)")
            }
            if let health = port.portHealth {
                print("  Port health: resets=\(health.lifetimeResets), shorts=\(health.shorts), errors=\(health.errors)")
            }
            print()
        }
    }
    
    static func debugIOKit() {
        let reader = IOKitReader()
        let dump = reader.dumpDebugInfo()
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: dump, options: [.prettyPrinted, .sortedKeys])
            if let json = String(data: data, encoding: .utf8) {
                print(json)
            }
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
    
    static func snapshotExport() {
        let args = CommandLine.arguments
        guard let pathIndex = args.firstIndex(of: "--snapshot"),
              args.index(after: pathIndex) < args.count else {
            fputs("Usage: portpulse --snapshot <output.json>\n", stderr)
            exit(1)
        }
        let path = args[args.index(after: pathIndex)]
        
        let reader = IOKitReader()
        let ports = reader.readAllPorts()
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        struct Snapshot: Codable {
            let timestamp: String
            let version: String
            let ports: [PortJSON]
        }
        
        let snapshot = Snapshot(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            version: "0.1.0",
            ports: ports.map { PortJSON(from: $0) }
        )
        
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: URL(fileURLWithPath: path))
            print("Snapshot saved to \(path)")
        } catch {
            fputs("Error writing snapshot: \(error)\n", stderr)
            exit(1)
        }
    }
    
    static func snapshotImport(path: String?) {
        guard let path = path else {
            fputs("Usage: portpulse --from <snapshot.json>\n", stderr)
            exit(1)
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            fputs("Error reading snapshot: \(error)\n", stderr)
            exit(1)
        }
        
        let engine = DiagnosticEngine.shared
        
        struct Snapshot: Codable {
            let timestamp: String?
            let version: String?
            let ports: [PortJSON]
        }
        
        do {
            let decoder = JSONDecoder()
            let snapshot = try decoder.decode(Snapshot.self, from: data)
            
            if let ts = snapshot.timestamp {
                print("Snapshot from: \(ts)")
                print()
            }
            
            for portJSON in snapshot.ports {
                let port = portJSON.toPort()
                print(engine.buildPortSummary(port: port))
                print()
            }
        } catch {
            fputs("Error parsing snapshot: \(error)\n", stderr)
            exit(1)
        }
    }
    
    static func explainPort(_ portNumber: Int?) {
        let reader = IOKitReader()
        let engine = DiagnosticEngine.shared
        let ports = reader.readAllPorts()
        
        if ports.isEmpty {
            print("No USB-C ports found. Requires Apple Silicon Mac.")
            return
        }
        
        let port: USBCPort
        if let n = portNumber, n >= 1, n <= ports.count {
            port = ports[n - 1]
        } else if let n = portNumber {
            fputs("Port \(n) not found. Available: 1-\(ports.count)\n", stderr)
            exit(1)
        } else {
            port = ports.first(where: \.isConnected) ?? ports[0]
        }
        
        print("Port \(port.portIndex + 1): \(port.locationName)")
        print(String(repeating: "─", count: 50))
        
        // Connection
        print("Connection:    \(port.connectionType.rawValue)")
        print("Status:        \(port.isConnected ? "Connected" : "Nothing connected")")
        
        if port.isConnected {
            print("Headline:      \(port.headline)")
            print()
            
            // Cable
            print("Cable")
            print("  e-Marker:    \(port.cable.hasEMarker ? "Yes" : "No")")
            print("  Speed:       \(port.cable.usbSpeed.rawValue)")
            print("  Current:     \(port.cable.currentDescription)")
            print("  Max Voltage: \(Int(port.cable.maxVoltage))V")
            print("  Max Power:   \(port.cable.wattageDescription)")
            print("  Passive:     \(port.cable.isPassive ? "Yes" : "No")")
            print("  Vendor ID:   0x\(String(format: "%04X", port.cable.vendorID))")
            print("  Product ID:  0x\(String(format: "%04X", port.cable.productID))")
            if let vendor = port.cable.vendorName ?? VendorDatabase.shared.vendorName(for: port.cable.vendorID) {
                print("  Vendor:      \(vendor)")
            }
            if let revision = port.cable.pdRevision {
                print("  PD Revision: \(revision)")
            }
            print("  Certified:   \(port.cable.isCertified ? "Yes" : "No")")
            print("  Latency:     \(port.cable.cableLatency)")
            print()
            
            // Charger
            print("Charger")
            if port.charger.pdos.isEmpty {
                print("  No PDO data")
            } else {
                print("  Vendor:      \(port.charger.vendorName ?? "Unknown")")
                print("  Max Power:   \(Int(port.charger.maxWattage))W")
                print("  Profiles:")
                for pdo in port.charger.pdos {
                    let active = pdo.isActive ? " ← active" : ""
                    print("    \(pdo.description)\(active)")
                }
            }
            print()
            
            // Power
            if let power = port.powerReading {
                print("Power Reading")
                print("  \(power.description)")
                print()
            }
            
            // Devices
            if !port.devices.isEmpty {
                print("Connected Devices")
                for device in port.devices {
                    print("  \(device.name)")
                    if let vendor = device.vendorName {
                        print("    Vendor:  \(vendor)")
                    }
                    print("    Speed:   \(device.negotiatedSpeed.rawValue)")
                    print("    Location: 0x\(String(format: "%08X", device.locationID))")
                }
                print()
            }
            
            // Thunderbolt
            if let tb = port.thunderbolt {
                print("Thunderbolt")
                if let gen = tb.generation { print("  Generation:  \(gen)") }
                if let speed = tb.perLaneSpeed { print("  Lane Speed:  \(speed)") }
                print("  Lanes:       \(tb.laneCount)")
                if !tb.topology.isEmpty {
                    print("  Topology:    \(tb.topology.joined(separator: " → "))")
                }
                print()
            }
            
            // Display
            if let display = port.display {
                print("Display")
                if let res = display.resolution { print("  Resolution:  \(res)") }
                if let hz = display.refreshRate { print("  Refresh:     \(Int(hz))Hz") }
                print("  DSC:         \(display.isCompressed ? "Yes" : "No")")
                if let maxRes = display.maxResolution { print("  Max Res:     \(maxRes)") }
                if let maxHz = display.maxRefreshRate { print("  Max Refresh: \(Int(maxHz))Hz") }
                print()
            }
            
            // Transports
            if !port.activeTransports.isEmpty {
                print("Transports:    \(port.activeTransports.sorted().joined(separator: ", "))")
            }
            if let orientation = port.plugOrientation {
                print("Orientation:   \(orientation)")
            }
            print("VCONN:         \(port.hasVCONN ? "Active" : "Inactive")")
            print()
            
            // Diagnostics
            print("Diagnostics")
            let chargeDiag = engine.diagnoseCharging(port: port)
            print("  Charging:    \(chargeDiag.message)")
            if let detail = chargeDiag.detail { print("               \(detail)") }
            
            let speedDiag = engine.diagnoseDataSpeed(port: port)
            print("  Data Speed:  \(speedDiag.message)")
            if let detail = speedDiag.detail { print("               \(detail)") }
            
            if let displayDiag = engine.diagnoseDisplay(port: port) {
                print("  Display:     \(displayDiag.message)")
                if let detail = displayDiag.detail { print("               \(detail)") }
            }
            
            let trustFlags = engine.checkCableTrustSignals(cable: port.cable)
            if !trustFlags.isEmpty {
                print("  Trust:")
                for flag in trustFlags {
                    print("    ⚠ \(flag)")
                }
            }
            
            // Port health
            if let health = port.portHealth {
                print()
                print("Port Health")
                print("  Resets:      \(health.lifetimeResets)")
                print("  Shorts:      \(health.shorts)")
                print("  Errors:      \(health.errors)")
                print("  FET Failures: \(health.fetFailures)")
                if let r = health.resistanceOhms {
                    print("  Resistance:  \(r)Ω")
                }
            }
        }
    }
    
    static func watchMode() {
        print("Watching for USB-C changes... (Ctrl+C to exit)\n")
        
        let monitor = PortMonitor()
        let delegate = WatchDelegate()
        monitor.delegate = delegate
        monitor.start(interval: 1.0)
        
        // Keep running
        RunLoop.main.run()
    }
    
    static func runDashboard() {
        let dashboard = TerminalDashboard()
        dashboard.run()
    }
}

class WatchDelegate: PortMonitorDelegate {
    func portMonitor(_ monitor: PortMonitor, didUpdatePorts ports: [USBCPort]) {
        // Only print on actual changes, handled by connect/disconnect
    }
    
    func portMonitor(_ monitor: PortMonitor, didConnectPort port: USBCPort) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] Connected to \(port.locationName)")
        print(DiagnosticEngine.shared.buildPortSummary(port: port))
        print()
    }
    
    func portMonitor(_ monitor: PortMonitor, didDisconnectPort portIndex: Int) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] Disconnected from USB-C Port \(portIndex + 1)")
        print()
    }
}
