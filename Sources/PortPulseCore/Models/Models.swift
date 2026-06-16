import Foundation

public enum USBConnectionType: String, Codable {
    case thunderbolt
    case usb4
    case usb3
    case usb2
    case displayOnly
    case chargingOnly
    case nothing
}

public enum USBSpeed: String, Codable, Comparable {
    case usb2_480 = "480 Mbps"
    case usb3_5 = "5 Gbps"
    case usb3_10 = "10 Gbps"
    case usb3_20 = "20 Gbps"
    case usb4_40 = "40 Gbps"
    case usb4_80 = "80 Gbps"
    case unknown
    
    public var gbps: Double {
        switch self {
        case .usb2_480: return 0.48
        case .usb3_5: return 5
        case .usb3_10: return 10
        case .usb3_20: return 20
        case .usb4_40: return 40
        case .usb4_80: return 80
        case .unknown: return 0
        }
    }
    
    public static func < (lhs: USBSpeed, rhs: USBSpeed) -> Bool {
        lhs.gbps < rhs.gbps
    }
}

public struct CableInfo: Codable {
    public var hasEMarker: Bool
    public var usbSpeed: USBSpeed
    public var currentRating: Double
    public var maxVoltage: Double
    public var maxWattage: Double
    public var vendorID: UInt16
    public var productID: UInt16
    public var vendorName: String?
    public var productName: String?
    public var isPassive: Bool
    public var cableLatency: UInt8
    public var pdRevision: String?
    public var isCertified: Bool
    public var vdoRaw: [UInt32]
    
    public init(
        hasEMarker: Bool = false,
        usbSpeed: USBSpeed = .unknown,
        currentRating: Double = 0,
        maxVoltage: Double = 20,
        maxWattage: Double = 0,
        vendorID: UInt16 = 0,
        productID: UInt16 = 0,
        vendorName: String? = nil,
        productName: String? = nil,
        isPassive: Bool = true,
        cableLatency: UInt8 = 0,
        pdRevision: String? = nil,
        isCertified: Bool = false,
        vdoRaw: [UInt32] = []
    ) {
        self.hasEMarker = hasEMarker
        self.usbSpeed = usbSpeed
        self.currentRating = currentRating
        self.maxVoltage = maxVoltage
        self.maxWattage = maxWattage
        self.vendorID = vendorID
        self.productID = productID
        self.vendorName = vendorName
        self.productName = productName
        self.isPassive = isPassive
        self.cableLatency = cableLatency
        self.pdRevision = pdRevision
        self.isCertified = isCertified
        self.vdoRaw = vdoRaw
    }
    
    public var wattageDescription: String {
        if maxWattage > 0 {
            return "\(Int(maxWattage))W"
        }
        return "Unknown"
    }
    
    public var currentDescription: String {
        if currentRating > 0 {
            return "\(currentRating)A"
        }
        return "Unknown"
    }
}

public struct ChargerPDO: Codable {
    public var voltage: Double
    public var maxCurrent: Double
    public var isActive: Bool
    public var isExtended: Bool
    public var sourceCapability: UInt8
    
    public var maxPower: Double { voltage * maxCurrent }
    
    public init(
        voltage: Double,
        maxCurrent: Double,
        isActive: Bool = false,
        isExtended: Bool = false,
        sourceCapability: UInt8 = 0
    ) {
        self.voltage = voltage
        self.maxCurrent = maxCurrent
        self.isActive = isActive
        self.isExtended = isExtended
        self.sourceCapability = sourceCapability
    }
    
    public var description: String {
        "\(Int(voltage))V / \(String(format: "%.1f", maxCurrent))A (\(Int(maxPower))W)"
    }
}

public struct ChargerInfo: Codable {
    public var vendorName: String?
    public var pdos: [ChargerPDO]
    
    public init(vendorName: String? = nil, pdos: [ChargerPDO] = []) {
        self.vendorName = vendorName
        self.pdos = pdos
    }
    
    public var maxWattage: Double {
        pdos.map(\.maxPower).max() ?? 0
    }
}

public struct ConnectedDevice: Codable, Identifiable {
    public var id: String
    public var name: String
    public var vendorName: String?
    public var productType: String?
    public var negotiatedSpeed: USBSpeed
    public var locationID: UInt32
    
    public init(
        id: String,
        name: String,
        vendorName: String? = nil,
        productType: String? = nil,
        negotiatedSpeed: USBSpeed = .unknown,
        locationID: UInt32 = 0
    ) {
        self.id = id
        self.name = name
        self.vendorName = vendorName
        self.productType = productType
        self.negotiatedSpeed = negotiatedSpeed
        self.locationID = locationID
    }
}

public struct DisplayInfo: Codable {
    public var resolution: String?
    public var refreshRate: Double?
    public var isCompressed: Bool
    public var adapterName: String?
    public var maxResolution: String?
    public var maxRefreshRate: Double?
    
    public init(
        resolution: String? = nil,
        refreshRate: Double? = nil,
        isCompressed: Bool = false,
        adapterName: String? = nil,
        maxResolution: String? = nil,
        maxRefreshRate: Double? = nil
    ) {
        self.resolution = resolution
        self.refreshRate = refreshRate
        self.isCompressed = isCompressed
        self.adapterName = adapterName
        self.maxResolution = maxResolution
        self.maxRefreshRate = maxRefreshRate
    }
}

public struct ThunderboltInfo: Codable {
    public var generation: String?
    public var perLaneSpeed: String?
    public var laneCount: Int
    public var topology: [String]
    
    public init(
        generation: String? = nil,
        perLaneSpeed: String? = nil,
        laneCount: Int = 0,
        topology: [String] = []
    ) {
        self.generation = generation
        self.perLaneSpeed = perLaneSpeed
        self.laneCount = laneCount
        self.topology = topology
    }
}

public struct PowerReading: Codable {
    public var watts: Double
    public var volts: Double
    public var amps: Double
    public var timestamp: Date
    
    public init(watts: Double, volts: Double, amps: Double, timestamp: Date) {
        self.watts = watts
        self.volts = volts
        self.amps = amps
        self.timestamp = timestamp
    }
    
    public var description: String {
        String(format: "%.1fW (%.1fV × %.2fA)", watts, volts, amps)
    }
}

public struct PortHealth: Codable {
    public var lifetimeResets: Int
    public var shorts: Int
    public var errors: Int
    public var fetFailures: Int
    public var resistanceOhms: Double?
    
    public init(
        lifetimeResets: Int = 0,
        shorts: Int = 0,
        errors: Int = 0,
        fetFailures: Int = 0,
        resistanceOhms: Double? = nil
    ) {
        self.lifetimeResets = lifetimeResets
        self.shorts = shorts
        self.errors = errors
        self.fetFailures = fetFailures
        self.resistanceOhms = resistanceOhms
    }
}

public enum Bottleneck: String, Codable {
    case cable
    case charger
    case macPort
    case device
    case none
    case unknown
}

public struct DiagnosticResult: Codable {
    public var bottleneck: Bottleneck
    public var message: String
    public var detail: String?
    
    public init(bottleneck: Bottleneck, message: String, detail: String? = nil) {
        self.bottleneck = bottleneck
        self.message = message
        self.detail = detail
    }
}
