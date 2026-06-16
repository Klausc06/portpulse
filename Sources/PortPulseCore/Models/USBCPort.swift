import Foundation

public struct USBCPort: Identifiable {
    public let id: String
    public let portIndex: Int
    public let locationName: String
    
    public var connectionType: USBConnectionType
    public var cable: CableInfo
    public var charger: ChargerInfo
    public var devices: [ConnectedDevice]
    public var display: DisplayInfo?
    public var thunderbolt: ThunderboltInfo?
    public var powerReading: PowerReading?
    public var portHealth: PortHealth?
    public var activeTransports: Set<String>
    public var plugOrientation: String?
    public var hasVCONN: Bool
    
    public init(
        id: String,
        portIndex: Int,
        locationName: String,
        connectionType: USBConnectionType = .nothing,
        cable: CableInfo = CableInfo(),
        charger: ChargerInfo = ChargerInfo(),
        devices: [ConnectedDevice] = [],
        display: DisplayInfo? = nil,
        thunderbolt: ThunderboltInfo? = nil,
        powerReading: PowerReading? = nil,
        portHealth: PortHealth? = nil,
        activeTransports: Set<String> = [],
        plugOrientation: String? = nil,
        hasVCONN: Bool = false
    ) {
        self.id = id
        self.portIndex = portIndex
        self.locationName = locationName
        self.connectionType = connectionType
        self.cable = cable
        self.charger = charger
        self.devices = devices
        self.display = display
        self.thunderbolt = thunderbolt
        self.powerReading = powerReading
        self.portHealth = portHealth
        self.activeTransports = activeTransports
        self.plugOrientation = plugOrientation
        self.hasVCONN = hasVCONN
    }
    
    public var isConnected: Bool {
        connectionType != .nothing
    }
    
    public var headline: String {
        switch connectionType {
        case .thunderbolt:
            let gen = thunderbolt?.generation ?? "Thunderbolt"
            return "\(gen) \(NSLocalizedString("Connected", comment: ""))"
        case .usb4:
            return NSLocalizedString("USB4 Connected", comment: "")
        case .usb3:
            return NSLocalizedString("USB Device Connected", comment: "")
        case .usb2:
            if charger.maxWattage > 0 {
                return NSLocalizedString("Charging Only", comment: "")
            }
            return NSLocalizedString("Slow USB / Charge-only Cable", comment: "")
        case .displayOnly:
            return NSLocalizedString("Display Connected", comment: "")
        case .chargingOnly:
            return NSLocalizedString("Charging Only", comment: "")
        case .nothing:
            return NSLocalizedString("Nothing Connected", comment: "")
        }
    }
}

public class USBCPortState: ObservableObject {
    @Published public var ports: [USBCPort] = []
    
    public init() {}
}
