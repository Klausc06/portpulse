import SwiftUI
import PortPulseCore

struct HistoryView: View {
    @ObservedObject var history: ConnectionHistory
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.accentColor)
                Text("Connection History")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }
            .padding()
            
            Divider()
            
            if history.events.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No history yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Connection events will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                // Events list
                List {
                    ForEach(history.events) { event in
                        HStack(spacing: 10) {
                            // Icon
                            Image(systemName: event.eventType == .connected ? "plus.circle.fill" : "minus.circle.fill")
                                .foregroundColor(event.eventType == .connected ? .green : .red)
                                .font(.system(size: 16))
                            
                            // Details
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(event.portName)
                                        .font(.system(size: 12, weight: .medium))
                                    Text("·")
                                        .foregroundColor(.secondary)
                                    Text(event.headline)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                if event.eventType == .connected {
                                    HStack(spacing: 6) {
                                        if let speed = event.cableSpeed {
                                            Text(speed)
                                                .font(.caption2)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(3)
                                        }
                                        if let wattage = event.cableWattage {
                                            Text(wattage)
                                                .font(.caption2)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.green.opacity(0.1))
                                                .cornerRadius(3)
                                        }
                                        if let vendor = event.vendorName {
                                            Text(vendor)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Timestamp
                            Text(Self.dateFormatter.string(from: event.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(history.events.count) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clear History") {
                    showClearConfirmation = true
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.red)
                .confirmationDialog("Clear all history?", isPresented: $showClearConfirmation) {
                    Button("Clear All", role: .destructive) {
                        history.clearHistory()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This action cannot be undone.")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 450, height: 500)
    }
}
