import Foundation
import PortPulseCore
import PortPulseHardware

/// Collects and stores power readings over time
public final class PowerMonitorStore: ObservableObject {
    @Published public private(set) var readings: [PowerReading] = []
    @Published public private(set) var currentPower: PowerReading?
    
    private let maxReadings = 300 // 5 minutes at 1 reading/second
    private let userDefaults: UserDefaults
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    /// Add a new power reading
    public func addReading(_ reading: PowerReading) {
        currentPower = reading
        readings.append(reading)
        
        // Trim old readings
        if readings.count > maxReadings {
            readings = Array(readings.suffix(maxReadings))
        }
    }
    
    /// Clear all readings
    public func clear() {
        readings.removeAll()
        currentPower = nil
    }
    
    /// Get average power over last N seconds
    public func averagePower(seconds: Int) -> Double {
        let cutoff = Date().addingTimeInterval(-Double(seconds))
        let recent = readings.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.watts).reduce(0, +) / Double(recent.count)
    }
    
    /// Get peak power over last N seconds
    public func peakPower(seconds: Int) -> Double {
        let cutoff = Date().addingTimeInterval(-Double(seconds))
        let recent = readings.filter { $0.timestamp >= cutoff }
        return recent.map(\.watts).max() ?? 0
    }
    
    /// Get min power over last N seconds
    public func minPower(seconds: Int) -> Double {
        let cutoff = Date().addingTimeInterval(-Double(seconds))
        let recent = readings.filter { $0.timestamp >= cutoff }
        return recent.map(\.watts).min() ?? 0
    }
}

/// Continuous power poller
public final class PowerPoller {
    private var timer: Timer?
    private let reader: IOKitReader
    private let store: PowerMonitorStore
    private var pollInterval: TimeInterval
    
    public init(reader: IOKitReader, store: PowerMonitorStore, interval: TimeInterval = 2.0) {
        self.reader = reader
        self.store = store
        self.pollInterval = interval
    }
    
    public func start() {
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        // Initial poll
        poll()
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func poll() {
        let ports = reader.readAllPorts()
        for port in ports where port.isConnected {
            if let reading = port.powerReading {
                store.addReading(reading)
            }
        }
    }
}
