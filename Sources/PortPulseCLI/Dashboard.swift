import Foundation
import PortPulseCore
import PortPulseHardware

/// Terminal dashboard for live port monitoring
public struct TerminalDashboard {
    private let reader: IOKitReader
    private let engine: DiagnosticEngine
    
    public init() {
        self.reader = IOKitReader()
        self.engine = DiagnosticEngine.shared
    }
    
    public func run() {
        // Simple polling dashboard (no raw mode needed)
        print("\u{1B}[2J\u{1B}[H", terminator: "")
        fflush(stdout)
        
        while true {
            render()
            Thread.sleep(forTimeInterval: 2.0)
        }
    }
    
    private func render() {
        let ports = reader.readAllPorts()
        
        // Clear screen
        print("\u{1B}[2J\u{1B}[H", terminator: "")
        fflush(stdout)
        
        // Header
        let width = 70
        print("┌" + String(repeating: "─", count: width - 2) + "┐")
        print("│  PortPulse Terminal Dashboard" + String(repeating: " ", count: width - 32) + "│")
        print("├" + String(repeating: "─", count: width - 2) + "┤")
        
        // Port overview
        for port in ports {
            let statusIcon = port.isConnected ? "●" : "○"
            let name = port.locationName.padding(toLength: 18, withPad: " ", startingAt: 0)
            
            if port.isConnected {
                let headline = port.headline.padding(toLength: 22, withPad: " ", startingAt: 0)
                let diag = engine.diagnoseCharging(port: port)
                
                // Color based on bottleneck
                let color: String
                switch diag.bottleneck {
                case .none: color = "\u{1B}[32m"      // Green
                case .cable, .charger: color = "\u{1B}[33m"  // Yellow
                default: color = "\u{1B}[37m"         // White
                }
                let reset = "\u{1B}[0m"
                
                print("│ \(color)\(statusIcon)\(reset) \(name)\(headline)\(diag.message)")
            } else {
                print("│ \u{1B}[37m\(statusIcon)\u{1B}[0m \(name)Nothing connected")
            }
        }
        
        // Power info
        print("├" + String(repeating: "─", count: width - 2) + "┤")
        print("│  Power")
        
        for port in ports where port.isConnected {
            if let power = port.powerReading {
                let watts = String(format: "%.1f", power.watts)
                let volts = String(format: "%.1f", power.volts)
                let amps = String(format: "%.2f", power.amps)
                
                let barWidth = Int(min(power.watts / 100.0 * 40.0, 40.0))
                let bar = String(repeating: "█", count: barWidth) + String(repeating: "░", count: 40 - barWidth)
                
                print("│   \(port.locationName): \u{1B}[33m\(watts)W\u{1B}[0m (\(volts)V × \(amps)A)")
                print("│   [\(bar)]")
            }
        }
        
        // Cable info
        print("├" + String(repeating: "─", count: width - 2) + "┤")
        print("│  Cables")
        
        for port in ports where port.isConnected && port.cable.hasEMarker {
            let speed = port.cable.usbSpeed.rawValue.padding(toLength: 15, withPad: " ", startingAt: 0)
            let wattage = port.cable.wattageDescription.padding(toLength: 8, withPad: " ", startingAt: 0)
            print("│   \(port.locationName): \(speed) \(wattage)")
        }
        
        // Footer
        print("├" + String(repeating: "─", count: width - 2) + "┤")
        print("│  Press Ctrl+C to exit" + String(repeating: " ", count: width - 24) + "│")
        print("└" + String(repeating: "─", count: width - 2) + "┘")
        
        fflush(stdout)
    }
}
