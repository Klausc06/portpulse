import SwiftUI
import PortPulseCore
import PortPulseHardware
import PortPulseMonitor

@main
struct PortPulseApp: App {
    @StateObject private var portState = USBCPortState()
    @StateObject private var connectionHistory = ConnectionHistory()
    @StateObject private var powerStore = PowerMonitorStore()
    @State private var monitor: PortMonitor?
    @State private var powerPoller: PowerPoller?
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(portState: portState, history: connectionHistory, powerStore: powerStore)
        } label: {
            MenuBarLabel(ports: portState.ports)
        }
        .menuBarExtraStyle(.window)
    }
    
    func startMonitoring() {
        let m = PortMonitor()
        m.delegate = PortMonitorDelegateHandler(
            portState: portState,
            history: connectionHistory
        )
        m.start(interval: 2.0)
        monitor = m
        
        // Start power polling
        let reader = IOKitReader()
        let poller = PowerPoller(reader: reader, store: powerStore, interval: 2.0)
        poller.start()
        powerPoller = poller
    }
}

/// Menu bar label with dynamic icon
struct MenuBarLabel: View {
    let ports: [USBCPort]
    
    private var connectedCount: Int {
        ports.filter(\.isConnected).count
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "cable.connector")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    connectedCount > 0 ? Color.green : Color.secondary
                )
            if connectedCount > 0 {
                Text("\(connectedCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Menu bar popover content
struct MenuBarView: View {
    @ObservedObject var portState: USBCPortState
    @ObservedObject var history: ConnectionHistory
    @ObservedObject var powerStore: PowerMonitorStore
    @State private var showHistory = false
    @State private var showPowerMonitor = false
    @State private var showSettings = false
    
    private var connectedPorts: [USBCPort] {
        portState.ports.filter(\.isConnected)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cable.connector")
                    .foregroundColor(.accentColor)
                Text("PortPulse")
                    .font(.headline)
                Spacer()
                Text("\(connectedPorts.count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            // Port list
            if portState.ports.isEmpty {
                ContentUnavailableView(
                    "Scanning Ports",
                    systemImage: "cable.connector",
                    description: Text("Looking for USB-C ports...")
                )
            } else if connectedPorts.isEmpty {
                ContentUnavailableView(
                    "No Cables Connected",
                    systemImage: "cable.connector",
                    description: Text("Connect a cable to see diagnostics")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(connectedPorts) { port in
                            PortRow(port: port)
                        }
                    }
                    .padding()
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Connection History")
                
                Button {
                    showPowerMonitor = true
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                .buttonStyle(.plain)
                .help("Power Monitor")
                
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Settings")
                
                Spacer()
                
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 360, height: 400)
        .sheet(isPresented: $showHistory) {
            HistoryView(history: history)
        }
        .sheet(isPresented: $showPowerMonitor) {
            PowerMonitorView(store: powerStore)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

/// Individual port row
struct PortRow: View {
    let port: USBCPort
    @State private var isExpanded = false
    
    private let engine = DiagnosticEngine.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main info
            HStack {
                Circle()
                    .fill(port.isConnected ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                
                Text(port.locationName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(port.headline)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            // Diagnostics
            let chargeDiag = engine.diagnoseCharging(port: port)
            DiagnosticBadge(result: chargeDiag)
            
            // Cable info
            if port.cable.hasEMarker {
                HStack {
                    Image(systemName: "cable.connector.horizontal")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("\(port.cable.usbSpeed.rawValue) · \(port.cable.wattageDescription)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Expanded details
            if isExpanded {
                Divider()
                
                if let power = port.powerReading {
                    Label(power.description, systemImage: "bolt.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
                
                ForEach(port.devices) { device in
                    Label(device.name, systemImage: "externaldevice.fill")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// Diagnostic badge
struct DiagnosticBadge: View {
    let result: DiagnosticResult
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)
                .foregroundColor(iconColor)
            Text(result.message)
                .font(.caption2)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private var iconName: String {
        switch result.bottleneck {
        case .none: return "checkmark.circle.fill"
        case .cable, .charger, .device, .macPort: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var iconColor: Color {
        switch result.bottleneck {
        case .none: return .green
        case .cable, .charger, .device, .macPort: return .orange
        case .unknown: return .secondary
        }
    }
    
    private var backgroundColor: Color {
        switch result.bottleneck {
        case .none: return .green
        case .cable, .charger, .device, .macPort: return .orange
        case .unknown: return .gray
        }
    }
}

/// Port monitor delegate handler
class PortMonitorDelegateHandler: PortMonitorDelegate {
    let portState: USBCPortState
    let history: ConnectionHistory
    
    init(portState: USBCPortState, history: ConnectionHistory) {
        self.portState = portState
        self.history = history
    }
    
    func portMonitor(_ monitor: PortMonitor, didUpdatePorts ports: [USBCPort]) {
        DispatchQueue.main.async {
            self.portState.ports = ports
        }
    }
    
    func portMonitor(_ monitor: PortMonitor, didConnectPort port: USBCPort) {
        DispatchQueue.main.async {
            self.history.recordConnect(port: port)
        }
    }
    
    func portMonitor(_ monitor: PortMonitor, didDisconnectPort portIndex: Int) {
        DispatchQueue.main.async {
            self.history.recordDisconnect(
                portIndex: portIndex,
                portName: "USB-C Port \(portIndex + 1)"
            )
        }
    }
}
