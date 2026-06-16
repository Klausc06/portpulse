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
        
        // Default: human-readable summary
        outputSummary()
    }
    
    static func printHelp() {
        print("""
        portpulse - USB-C cable diagnostics for macOS
        
        Usage:
          portpulse              Human-readable summary of every port
          portpulse --json       Structured JSON output
          portpulse --watch      Stream updates as cables come and go
          portpulse --raw        Include underlying IOKit properties
          portpulse --dashboard  Live terminal dashboard (Pro)
          portpulse --version    Show version
          portpulse --help       Show this help
        
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
