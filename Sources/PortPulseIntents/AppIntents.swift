import AppIntents
import PortPulseCore
import PortPulseHardware

/// Intent: Get current port status
struct GetPortStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get USB-C Port Status"
    static var description = IntentDescription("Returns the current status of all USB-C ports on your Mac.")
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let reader = IOKitReader()
        let ports = reader.readAllPorts()
        let engine = DiagnosticEngine.shared
        
        let summaries = ports.map { port -> String in
            if !port.isConnected {
                return "\(port.locationName): Nothing connected"
            }
            let diag = engine.diagnoseCharging(port: port)
            return "\(port.locationName): \(port.headline) — \(diag.message)"
        }
        
        let result = summaries.joined(separator: "\n")
        return .result(value: result, dialog: "Found \(ports.filter(\.isConnected).count) active ports.")
    }
}

/// Intent: Explain charging bottleneck
struct ExplainChargingBottleneckIntent: AppIntent {
    static var title: LocalizedStringResource = "Explain Charging Bottleneck"
    static var description = IntentDescription("Explains why your Mac might be charging slowly.")
    
    @Parameter(title: "Port Index")
    var portIndex: Int?
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let reader = IOKitReader()
        let ports = reader.readAllPorts()
        let engine = DiagnosticEngine.shared
        
        let targetPort: USBCPort?
        if let index = portIndex, index < ports.count {
            targetPort = ports[index]
        } else {
            targetPort = ports.first(where: \.isConnected)
        }
        
        guard let port = targetPort, port.isConnected else {
            return .result(value: "No cable connected", dialog: "I don't see any cables connected right now.")
        }
        
        let diag = engine.diagnoseCharging(port: port)
        var explanation = diag.message
        if let detail = diag.detail {
            explanation += ". \(detail)"
        }
        
        return .result(value: explanation, dialog: "\(explanation)")
    }
}

/// Intent: List connected cables
struct ListConnectedCablesIntent: AppIntent {
    static var title: LocalizedStringResource = "List Connected Cables"
    static var description = IntentDescription("Lists all USB-C cables currently connected to your Mac.")
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let reader = IOKitReader()
        let ports = reader.readAllPorts()
        
        let connected = ports.filter(\.isConnected)
        
        if connected.isEmpty {
            return .result(value: "No cables connected", dialog: "No USB-C cables are currently connected.")
        }
        
        let cableList = connected.map { port -> String in
            var info = port.locationName
            if port.cable.hasEMarker {
                info += " — \(port.cable.usbSpeed.rawValue), \(port.cable.wattageDescription)"
            }
            return info
        }
        
        let result = cableList.joined(separator: "\n")
        return .result(value: result, dialog: "Found \(connected.count) connected cable(s).")
    }
}

/// App Shortcuts provider
struct PortPulseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetPortStatusIntent(),
            phrases: [
                "What's connected to my USB-C ports",
                "Show my cable status",
                "Check USB-C ports"
            ],
            shortTitle: "Port Status",
            systemImageName: "cable.connector"
        )
        
        AppShortcut(
            intent: ExplainChargingBottleneckIntent(),
            phrases: [
                "Why is my Mac charging slowly",
                "Explain charging bottleneck",
                "What's limiting my charging"
            ],
            shortTitle: "Charging Bottleneck",
            systemImageName: "bolt.fill"
        )
        
        AppShortcut(
            intent: ListConnectedCablesIntent(),
            phrases: [
                "List my cables",
                "What cables are connected",
                "Show connected cables"
            ],
            shortTitle: "List Cables",
            systemImageName: "list.bullet"
        )
    }
}
