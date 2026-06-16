import WidgetKit
import SwiftUI
import PortPulseCore
import PortPulseHardware

// MARK: - Timeline Entry

struct PortPulseEntry: TimelineEntry {
    let date: Date
    let ports: [PortSnapshot]
    let isError: Bool
    
    struct PortSnapshot: Identifiable {
        let id: String
        let portIndex: Int
        let locationName: String
        let isConnected: Bool
        let headline: String
        let chargingMessage: String?
        let cableSpeed: String?
        let wattage: String?
        let isSuboptimal: Bool
    }
    
    static func errorEntry() -> PortPulseEntry {
        PortPulseEntry(date: Date(), ports: [], isError: true)
    }
}

// MARK: - Timeline Provider

struct PortPulseProvider: TimelineProvider {
    func placeholder(in context: Context) -> PortPulseEntry {
        PortPulseEntry(date: Date(), ports: [
            PortPulseEntry.PortSnapshot(
                id: "placeholder",
                portIndex: 0,
                locationName: "USB-C Port 1",
                isConnected: true,
                headline: "Charging",
                chargingMessage: "Charging at 96W",
                cableSpeed: "USB4 40 Gbps",
                wattage: "96W",
                isSuboptimal: false
            )
        ], isError: false)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PortPulseEntry) -> Void) {
        completion(readCurrentState())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PortPulseEntry>) -> Void) {
        let entry = readCurrentState()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
    
    private func readCurrentState() -> PortPulseEntry {
        let reader = IOKitReader()
        let engine = DiagnosticEngine.shared
        let ports = reader.readAllPorts()
        
        if ports.isEmpty {
            return .errorEntry()
        }
        
        let snapshots = ports.map { port -> PortPulseEntry.PortSnapshot in
            let diag = engine.diagnoseCharging(port: port)
            let isSuboptimal = diag.bottleneck == .cable || diag.bottleneck == .charger
            return PortPulseEntry.PortSnapshot(
                id: port.id,
                portIndex: port.portIndex,
                locationName: port.locationName,
                isConnected: port.isConnected,
                headline: port.headline,
                chargingMessage: port.isConnected ? diag.message : nil,
                cableSpeed: port.cable.hasEMarker ? port.cable.usbSpeed.rawValue : nil,
                wattage: port.cable.hasEMarker ? port.cable.wattageDescription : nil,
                isSuboptimal: isSuboptimal
            )
        }
        
        return PortPulseEntry(date: Date(), ports: snapshots, isError: false)
    }
}

// MARK: - Status Color

private func statusColor(for snapshot: PortPulseEntry.PortSnapshot) -> Color {
    if !snapshot.isConnected { return .gray }
    if snapshot.isSuboptimal { return .orange }
    return .green
}

// MARK: - Widget Views

struct PortPulseSmallView: View {
    let entry: PortPulseEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "cable.connector")
                    .foregroundColor(.accentColor)
                Text("PortPulse")
                    .font(.caption2)
                    .fontWeight(.medium)
                Spacer()
            }
            
            if entry.isError {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Unable to read")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                let connectedPorts = entry.ports.filter(\.isConnected)
                if connectedPorts.isEmpty {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "cable.connector")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No cables")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ForEach(connectedPorts.prefix(2)) { port in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(port.locationName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if let msg = port.chargingMessage {
                                Text(msg)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(10)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct PortPulseMediumView: View {
    let entry: PortPulseEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cable.connector")
                    .foregroundColor(.accentColor)
                Text("PortPulse")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(entry.ports.filter(\.isConnected).count) active")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if entry.isError {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("Unable to read port data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                let connectedPorts = entry.ports.filter(\.isConnected)
                if connectedPorts.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "cable.connector")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Text("No cables connected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    ForEach(connectedPorts.prefix(3)) { port in
                        HStack {
                            Circle()
                                .fill(statusColor(for: port))
                                .frame(width: 6, height: 6)
                            Text(port.locationName)
                                .font(.footnote)
                                .lineLimit(1)
                            if let msg = port.chargingMessage {
                                Text(msg)
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if let speed = port.cableSpeed {
                                Text(speed)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct PortPulseLargeView: View {
    let entry: PortPulseEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "cable.connector")
                    .foregroundColor(.accentColor)
                Text("PortPulse")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(entry.ports.filter(\.isConnected).count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            if entry.isError {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Unable to read USB-C port data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else if entry.ports.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "cable.connector")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No USB-C ports detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.ports) { port in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor(for: port))
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(port.locationName)
                                .font(.footnote)
                                .fontWeight(.medium)
                            if let msg = port.chargingMessage {
                                Text(msg)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if port.isConnected {
                            VStack(alignment: .trailing, spacing: 2) {
                                if let watt = port.wattage {
                                    Text(watt)
                                        .font(.footnote)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.accentColor)
                                }
                                if let speed = port.cableSpeed {
                                    Text(speed)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget

struct PortPulseWidget: Widget {
    let kind: String = "PortPulseWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PortPulseProvider()) { entry in
            PortPulseWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "portpulse://widget"))
        }
        .configurationDisplayName("PortPulse")
        .description("USB-C cable diagnostics")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct PortPulseWidgetEntryView: View {
    let entry: PortPulseEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            PortPulseSmallView(entry: entry)
        case .systemMedium:
            PortPulseMediumView(entry: entry)
        case .systemLarge:
            PortPulseLargeView(entry: entry)
        default:
            PortPulseSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct PortPulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        PortPulseWidget()
    }
}
