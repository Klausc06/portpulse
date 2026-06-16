import Foundation

public struct PortJSON: Codable {
    public let portIndex: Int
    public let locationName: String
    public let connectionType: String
    public let cable: CableInfoJSON
    public let charger: ChargerInfoJSON
    public let devices: [DeviceJSON]
    public let headline: String
    
    public init(from port: USBCPort) {
        self.portIndex = port.portIndex
        self.locationName = port.locationName
        self.connectionType = port.connectionType.rawValue
        self.cable = CableInfoJSON(from: port.cable)
        self.charger = ChargerInfoJSON(from: port.charger)
        self.devices = port.devices.map { DeviceJSON(from: $0) }
        self.headline = port.headline
    }
}

public struct CableInfoJSON: Codable {
    public let hasEMarker: Bool
    public let usbSpeed: String
    public let currentRating: Double
    public let maxVoltage: Double
    public let maxWattage: Double
    public let vendorID: String
    public let productID: String
    public let vendorName: String?
    public let isPassive: Bool
    public let pdRevision: String?
    public let isCertified: Bool
    
    public init(from cable: CableInfo) {
        self.hasEMarker = cable.hasEMarker
        self.usbSpeed = cable.usbSpeed.rawValue
        self.currentRating = cable.currentRating
        self.maxVoltage = cable.maxVoltage
        self.maxWattage = cable.maxWattage
        self.vendorID = String(format: "0x%04X", cable.vendorID)
        self.productID = String(format: "0x%04X", cable.productID)
        self.vendorName = cable.vendorName
        self.isPassive = cable.isPassive
        self.pdRevision = cable.pdRevision
        self.isCertified = cable.isCertified
    }
}

public struct ChargerInfoJSON: Codable {
    public let vendorName: String?
    public let maxWattage: Double
    public let pdos: [PDOJSON]
    
    public init(from charger: ChargerInfo) {
        self.vendorName = charger.vendorName
        self.maxWattage = charger.maxWattage
        self.pdos = charger.pdos.map { PDOJSON(from: $0) }
    }
}

public struct PDOJSON: Codable {
    public let voltage: Double
    public let maxCurrent: Double
    public let maxPower: Double
    public let isActive: Bool
    
    public init(from pdo: ChargerPDO) {
        self.voltage = pdo.voltage
        self.maxCurrent = pdo.maxCurrent
        self.maxPower = pdo.maxPower
        self.isActive = pdo.isActive
    }
}

public struct DeviceJSON: Codable {
    public let name: String
    public let vendorName: String?
    public let negotiatedSpeed: String
    
    public init(from device: ConnectedDevice) {
        self.name = device.name
        self.vendorName = device.vendorName
        self.negotiatedSpeed = device.negotiatedSpeed.rawValue
    }
}
