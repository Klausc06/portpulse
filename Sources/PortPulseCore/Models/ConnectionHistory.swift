import Foundation

public struct ConnectionEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let portIndex: Int
    public let portName: String
    public let eventType: EventType
    public let cableSpeed: String?
    public let cableWattage: String?
    public let vendorName: String?
    public let headline: String
    
    public enum EventType: String, Codable {
        case connected
        case disconnected
    }
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        portIndex: Int,
        portName: String,
        eventType: EventType,
        cableSpeed: String? = nil,
        cableWattage: String? = nil,
        vendorName: String? = nil,
        headline: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.portIndex = portIndex
        self.portName = portName
        self.eventType = eventType
        self.cableSpeed = cableSpeed
        self.cableWattage = cableWattage
        self.vendorName = vendorName
        self.headline = headline
    }
}

public final class ConnectionHistory: ObservableObject {
    @Published public private(set) var events: [ConnectionEvent] = []
    
    private let maxEvents = 100
    private let storageKey = "com.portpulse.connectionHistory"
    private let userDefaults: UserDefaults
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }
    
    public func recordConnect(port: USBCPort) {
        let event = ConnectionEvent(
            portIndex: port.portIndex,
            portName: port.locationName,
            eventType: .connected,
            cableSpeed: port.cable.hasEMarker ? port.cable.usbSpeed.rawValue : nil,
            cableWattage: port.cable.hasEMarker ? port.cable.wattageDescription : nil,
            vendorName: port.cable.vendorName ?? VendorDatabase.shared.vendorName(for: port.cable.vendorID),
            headline: port.headline
        )
        append(event)
    }
    
    public func recordDisconnect(portIndex: Int, portName: String) {
        let event = ConnectionEvent(
            portIndex: portIndex,
            portName: portName,
            eventType: .disconnected,
            headline: "Disconnected"
        )
        append(event)
    }
    
    public func clearHistory() {
        events.removeAll()
        save()
    }
    
    private func append(_ event: ConnectionEvent) {
        events.insert(event, at: 0)
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
        save()
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(events)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            // Silent fail for persistence
        }
    }
    
    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        do {
            events = try JSONDecoder().decode([ConnectionEvent].self, from: data)
        } catch {
            // Schema mismatch - attempt partial decode with flexible approach
            // Store corrupted data separately for potential recovery
            let corruptedKey = storageKey + ".corrupted"
            userDefaults.set(data, forKey: corruptedKey)
            events = []
        }
    }
}
