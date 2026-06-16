import Foundation

public struct DiagnosticEngine {
    public static let shared = DiagnosticEngine()
    
    public init() {}
    
    public func diagnoseCharging(port: USBCPort) -> DiagnosticResult {
        guard port.isConnected else {
            return DiagnosticResult(bottleneck: .unknown, message: "Nothing connected")
        }
        
        let cableW = port.cable.maxWattage
        let chargerW = port.charger.maxWattage
        
        if cableW > 0 && chargerW > 0 && cableW < chargerW {
            return DiagnosticResult(
                bottleneck: .cable,
                message: "Cable is limiting charging speed",
                detail: "Cable rated at \(Int(cableW))W but charger can deliver \(Int(chargerW))W"
            )
        }
        
        if chargerW > 0 {
            if let reading = port.powerReading {
                if reading.watts < chargerW * 0.5 && reading.watts > 0 {
                    return DiagnosticResult(
                        bottleneck: .macPort,
                        message: "Charging at \(Int(reading.watts))W (charger can do up to \(Int(chargerW))W)",
                        detail: "Mac is requesting less power, possibly battery near full"
                    )
                }
                return DiagnosticResult(
                    bottleneck: .none,
                    message: "Charging well at \(Int(reading.watts))W",
                    detail: nil
                )
            }
            return DiagnosticResult(
                bottleneck: .none,
                message: "Charging up to \(Int(chargerW))W",
                detail: nil
            )
        }
        
        return DiagnosticResult(
            bottleneck: .unknown,
            message: "Charging",
            detail: nil
        )
    }
    
    public func diagnoseDataSpeed(port: USBCPort) -> DiagnosticResult {
        guard port.isConnected else {
            return DiagnosticResult(bottleneck: .unknown, message: "Nothing connected")
        }
        
        let cableSpeed = port.cable.usbSpeed
        
        if cableSpeed == .usb2_480 && port.connectionType != .usb2 {
            return DiagnosticResult(
                bottleneck: .cable,
                message: "Cable is limiting data speed",
                detail: "Cable only supports USB 2.0 (480 Mbps)"
            )
        }
        
        if let firstDevice = port.devices.first {
            let deviceSpeed = firstDevice.negotiatedSpeed
            if deviceSpeed < cableSpeed {
                return DiagnosticResult(
                    bottleneck: .device,
                    message: "Device runs at \(deviceSpeed.rawValue), this is the fastest it supports",
                    detail: "Not a cable problem"
                )
            }
        }
        
        if cableSpeed == .unknown {
            return DiagnosticResult(
                bottleneck: .unknown,
                message: "Cable speed unknown",
                detail: "No e-marker data; cannot determine cable capability"
            )
        }
        
        if cableSpeed == .usb2_480 {
            return DiagnosticResult(
                bottleneck: .cable,
                message: "Cable is limiting data speed",
                detail: "Cable only supports USB 2.0 (480 Mbps)"
            )
        }
        
        return DiagnosticResult(
            bottleneck: .none,
            message: "Running at \(cableSpeed.rawValue)",
            detail: nil
        )
    }
    
    public func diagnoseDisplay(port: USBCPort) -> DiagnosticResult? {
        guard let display = port.display else { return nil }
        
        // Normalize resolution strings for comparison
        // Handle "3840x2160" vs "3840×2160" (ASCII 'x' vs Unicode '×')
        if let maxRes = display.maxResolution, let currentRes = display.resolution {
            let normalizedCurrent = currentRes
                .replacingOccurrences(of: "×", with: "x")
                .replacingOccurrences(of: " ", with: "")
                .lowercased()
            let normalizedMax = maxRes
                .replacingOccurrences(of: "×", with: "x")
                .replacingOccurrences(of: " ", with: "")
                .lowercased()
            
            if normalizedCurrent != normalizedMax {
                return DiagnosticResult(
                    bottleneck: .cable,
                    message: "Display below maximum resolution",
                    detail: "Running \(currentRes), max supported is \(maxRes)"
                )
            }
        }
        
        if let maxHz = display.maxRefreshRate, let currentHz = display.refreshRate,
           currentHz < maxHz - 1.0 {  // Allow 1Hz tolerance for rounding
            return DiagnosticResult(
                bottleneck: .cable,
                message: "Display below maximum refresh rate",
                detail: "Running \(Int(currentHz))Hz, max supported is \(Int(maxHz))Hz"
            )
        }
        
        return DiagnosticResult(
            bottleneck: .none,
            message: "Display running at full capability",
            detail: display.isCompressed ? "Using DSC compression" : nil
        )
    }
    
    public func checkCableTrustSignals(cable: CableInfo) -> [String] {
        var flags: [String] = []
        
        if cable.vendorID == 0 {
            flags.append("Vendor ID is 0x0000 (not registered with USB-IF)")
        }
        
        if cable.cableLatency > 0x0A {
            flags.append("Cable latency field uses a reserved value")
        }
        
        if cable.currentRating >= 5.0 && cable.usbSpeed == .usb2_480 {
            flags.append("Claims 5A current but reports USB 2.0 speed")
        }
        
        return flags
    }
    
    public func buildPortSummary(port: USBCPort) -> String {
        var lines: [String] = []
        
        let statusIcon: String
        switch diagnoseCharging(port: port).bottleneck {
        case .none: statusIcon = "✓"
        case .cable, .charger, .device, .macPort: statusIcon = "!"
        case .unknown: statusIcon = "·"
        }
        
        lines.append("USB-C Port \(port.portIndex)")
        lines.append("  \(statusIcon) \(port.headline)")
        
        if port.isConnected {
            let chargeDiag = diagnoseCharging(port: port)
            lines.append("  \(chargeDiag.message)")
            
            if port.cable.hasEMarker {
                lines.append("  Cable: \(port.cable.currentDescription), \(port.cable.wattageDescription), \(port.cable.usbSpeed.rawValue)")
            } else {
                lines.append("  Cable: No e-marker data")
            }
            
            let speedDiag = diagnoseDataSpeed(port: port)
            if speedDiag.bottleneck != .unknown || port.connectionType != .chargingOnly {
                lines.append("  Data: \(speedDiag.message)")
            }
            
            if !port.charger.pdos.isEmpty {
                let pdos = port.charger.pdos.map { "\($0.description)" }.joined(separator: " / ")
                lines.append("  Charger: \(pdos)")
            }
            
            for device in port.devices {
                lines.append("  Device: \(device.name), \(device.negotiatedSpeed.rawValue)")
            }
            
            let trustFlags = checkCableTrustSignals(cable: port.cable)
            if !trustFlags.isEmpty {
                lines.append("  ⚠ Trust signals:")
                for flag in trustFlags {
                    lines.append("    - \(flag)")
                }
            }
        }
        
        return lines.joined(separator: "\n")
    }
}
