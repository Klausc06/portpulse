import SwiftUI
import PortPulseCore
import PortPulseMonitor

struct PowerMonitorView: View {
    @ObservedObject var store: PowerMonitorStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text("Power Monitor")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }
            .padding()
            
            Divider()
            
            // Current power
            if let current = store.currentPower {
                VStack(spacing: 8) {
                    Text("\(Int(current.watts))W")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                    
                    HStack(spacing: 16) {
                        StatBadge(label: "Voltage", value: String(format: "%.1fV", current.volts))
                        StatBadge(label: "Current", value: String(format: "%.2fA", current.amps))
                    }
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "bolt.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No power data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Connect a charger to see power readings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
            
            // Statistics
            HStack(spacing: 12) {
                StatCard(
                    title: "Avg (1min)",
                    value: String(format: "%.0fW", store.averagePower(seconds: 60)),
                    icon: "chart.line.flattrendxy"
                )
                StatCard(
                    title: "Peak",
                    value: String(format: "%.0fW", store.peakPower(seconds: 300)),
                    icon: "arrow.up.circle"
                )
                StatCard(
                    title: "Min",
                    value: String(format: "%.0fW", store.minPower(seconds: 300)),
                    icon: "arrow.down.circle"
                )
            }
            .padding()
            
            Divider()
            
            // Power chart (simplified)
            if !store.readings.isEmpty {
                PowerChart(readings: store.readings)
                    .frame(height: 120)
                    .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(store.readings.count) readings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clear") {
                    store.clear()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.red)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 400, height: 500)
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct PowerChart: View {
    let readings: [PowerReading]
    
    private var maxWatts: Double {
        readings.map(\.watts).max() ?? 100
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let count = readings.count
            
            if count > 1 {
                Path { path in
                    let stepX = width / CGFloat(count - 1)
                    
                    for (index, reading) in readings.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = reading.watts / max(maxWatts, 1)
                        let y = height * (1 - CGFloat(normalizedY))
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.yellow, lineWidth: 2)
                
                // Fill
                Path { path in
                    let stepX = width / CGFloat(count - 1)
                    
                    path.move(to: CGPoint(x: 0, y: height))
                    
                    for (index, reading) in readings.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = reading.watts / max(maxWatts, 1)
                        let y = height * (1 - CGFloat(normalizedY))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(Color.yellow.opacity(0.1))
            }
        }
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
