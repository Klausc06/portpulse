import Foundation
import IOKit
import IOKit.usb
import PortPulseCore

public final class IOKitReader {
    public init() {}
    
    public func readAllPorts() -> [USBCPort] {
        var ports: [USBCPort] = []
        
        // Read HPM (Host Port Manager) services for USB-C port state
        let hpmPorts = readHPMPorts()
        ports.append(contentsOf: hpmPorts)
        
        // Read power source information
        let powerSources = readPowerSources()
        
        // Read USB devices
        let usbDevices = readUSBDevices()
        
        // Read PD Discover Identity VDOs from transport component services
        let pdIdentities = readPDIdentities()
        
        // Correlate data
        for i in ports.indices {
            let portIndex = ports[i].portIndex
            
            // Match power source to port
            if portIndex < powerSources.count {
                ports[i].charger = powerSources[portIndex]
            }
            
            // Match USB devices to port
            ports[i].devices = usbDevices.filter { $0.locationID & 0xFF00 == UInt32(portIndex) << 8 }
            
            // Enrich with PD identity data if available
            if let identity = pdIdentities[portIndex] {
                enrichWithPDIdentity(&ports[i], identity: identity)
            }
        }
        
        return ports
    }
    
    private func readHPMPorts() -> [USBCPort] {
        var ports: [USBCPort] = []
        var portIndex = 0
        
        // Try M3-era AppleHPMInterfaceType10/11/12
        let hpmClasses = [
            "AppleHPMInterfaceType10",
            "AppleHPMInterfaceType11",
            "AppleHPMInterfaceType12",
            "AppleTCControllerType10",
            "AppleTCControllerType11"
        ]
        
        for className in hpmClasses {
            var iterator: io_iterator_t = 0
            let matching = IOServiceMatching(className)
            let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
            
            guard result == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iterator) }
            
            var service = IOIteratorNext(iterator)
            while service != IO_OBJECT_NULL {
                defer { IOObjectRelease(service) }
                
                var port = USBCPort(
                    id: "\(className)_\(portIndex)",
                    portIndex: portIndex,
                    locationName: "USB-C Port \(portIndex + 1)"
                )
                
                // Read connection state
                port.connectionType = readConnectionType(service: service)
                port.cable = readCableInfo(service: service)
                port.activeTransports = readActiveTransports(service: service)
                port.plugOrientation = readPlugOrientation(service: service)
                port.hasVCONN = readVCONN(service: service)
                
                // Read PD revision and certification
                if let props = IOKitReader.readProperties(service) {
                    if let revision = props["PDRevision"] as? String {
                        port.cable.pdRevision = revision
                    }
                    if let certified = props["CableCertified"] as? Bool {
                        port.cable.isCertified = certified
                    }
                }
                
                // Read Thunderbolt info if applicable
                if port.connectionType == .thunderbolt || port.connectionType == .usb4 {
                    port.thunderbolt = readThunderboltInfo(service: service)
                }
                
                // Read display info
                port.display = readDisplayInfo(service: service)
                
                // Read power reading
                port.powerReading = readPowerReading(service: service)
                
                // Read port health counters
                port.portHealth = readPortHealth(service: service)
                
                ports.append(port)
                portIndex += 1
                
                service = IOIteratorNext(iterator)
            }
        }
        
        // Fallback: if no HPM ports found, create synthetic ports from XHCI controllers
        if ports.isEmpty {
            ports = createSyntheticPorts()
        }
        
        return ports
    }
    
    private func readConnectionType(service: io_object_t) -> USBConnectionType {
        guard let props = IOKitReader.readProperties(service) else { return .nothing }
        
        // Check ConnectionCount first (most reliable indicator)
        if let count = props["ConnectionCount"] as? Int, count > 0 {
            // Verify connection is actually active by checking power/pin state
            // ConnectionCount can be cumulative; check if power is actually flowing
            let hasPower = hasActivePower(props: props)
            let hasActivePin = hasActivePinConfiguration(props: props)
            
            if !hasPower && !hasActivePin {
                // ConnectionCount > 0 but no active power or pins - phantom connection
                return .nothing
            }
            
            // Check transport types if available
            if let transports = props["TransportTypes"] as? [String] {
                if transports.contains("Thunderbolt") { return .thunderbolt }
                if transports.contains("USB4") { return .usb4 }
                if transports.contains("USB3") { return .usb3 }
                if transports.contains("USB2") { return .usb2 }
                if transports.contains("DisplayPort") { return .displayOnly }
            }
            
            // Check port type description
            if let portType = props["PortTypeDescription"] as? String {
                if portType.contains("MagSafe") { return .chargingOnly }
                if portType.contains("Thunderbolt") { return .thunderbolt }
            }
            
            // Check if it's an active cable
            if let active = props["ActiveCable"] as? Bool, active {
                return .usb3
            }
            
            // Default to charging if connected but no data transport
            return .chargingOnly
        }
        
        // Check IOAccessoryUSBConnectType
        if let connectType = props["IOAccessoryUSBConnectType"] as? Int, connectType != 0 {
            return .usb2
        }
        
        return .nothing
    }
    
    private func hasActivePower(props: [String: Any]) -> Bool {
        // Check if any power current limit is non-zero
        if let limits = props["IOAccessoryPowerCurrentLimits"] as? [Int] {
            return limits.contains { $0 > 0 }
        }
        return false
    }
    
    private func hasActivePinConfiguration(props: [String: Any]) -> Bool {
        // Check IOAccessoryUSBConnectType first - most reliable indicator
        // 0 = no connection, non-zero = active connection type
        if let connectType = props["IOAccessoryUSBConnectType"] as? Int, connectType != 0 {
            return true
        }
        
        // Check pin configuration for active data transfer
        if let pins = props["Pin Configuration"] as? [String: Int] {
            let nonZeroCount = pins.values.filter { $0 != 0 }.count
            // Multiple non-zero pins indicate active connection
            if nonZeroCount >= 2 {
                return true
            }
        }
        return false
    }
    
    private func readCableInfo(service: io_object_t) -> CableInfo {
        var cable = CableInfo()
        guard let props = IOKitReader.readProperties(service) else { return cable }
        
        // Read e-marker data from SOP' (cable near-end)
        if let emarker = props["CableEMarker"] as? [String: Any] {
            cable.hasEMarker = true
            
            if let speed = emarker["MaxSpeed"] as? String {
                cable.usbSpeed = parseSpeed(speed)
            }
            
            if let current = emarker["CurrentRating"] as? Double {
                cable.currentRating = current
            }
            
            if let voltage = emarker["MaxVoltage"] as? Double {
                cable.maxVoltage = voltage
            }
            
            if let vid = emarker["VendorID"] as? UInt16 {
                cable.vendorID = vid
            }
            
            if let pid = emarker["ProductID"] as? UInt16 {
                cable.productID = pid
            }
            
            if let latency = emarker["CableLatency"] as? UInt8 {
                cable.cableLatency = latency
            }
            
            if let passive = emarker["IsPassive"] as? Bool {
                cable.isPassive = passive
            }
            
            if let vdo = emarker["VDO"] as? [UInt32] {
                cable.vdoRaw = vdo
            }
        }
        
        // Also check CableVDO from PD identity
        if let cableVDO = props["CableVDO"] as? UInt32 {
            cable.hasEMarker = true
            parseCableVDO(cableVDO, into: &cable)
        }
        
        // Calculate wattage from current × voltage
        if cable.currentRating > 0 && cable.maxVoltage > 0 {
            cable.maxWattage = cable.currentRating * cable.maxVoltage
        }
        
        return cable
    }
    
    private func parseCableVDO(_ vdo: UInt32, into cable: inout CableInfo) {
        // USB-PD Cable VDO parsing (per PD R3.2 V1.2 spec)
        // Bits [4:0] = Cable Speed
        let speedBits = vdo & 0x1F
        switch speedBits {
        case 0b00001: cable.usbSpeed = .usb2_480
        case 0b00010: cable.usbSpeed = .usb3_5
        case 0b00011: cable.usbSpeed = .usb3_10
        case 0b00100: cable.usbSpeed = .usb3_20
        case 0b01000: cable.usbSpeed = .usb4_40
        case 0b10000: cable.usbSpeed = .usb4_80
        default: break
        }
        
        // Bits [9:8] = VBUS Current Handling
        let currentBits = (vdo >> 8) & 0x3
        switch currentBits {
        case 0b01: cable.currentRating = 3.0
        case 0b10: cable.currentRating = 5.0
        default: break
        }
        
        // Bits [11:10] = VBUS Voltage Handling (EPR support)
        let voltageBits = (vdo >> 10) & 0x3
        switch voltageBits {
        case 0b00: cable.maxVoltage = 20  // SPR: 20V
        case 0b01: cable.maxVoltage = 28  // EPR: 28V
        case 0b10: cable.maxVoltage = 36  // EPR: 36V
        case 0b11: cable.maxVoltage = 48  // EPR: 48V
        default:   cable.maxVoltage = 20
        }
        
        // Bit [12] = Passive/Active
        cable.isPassive = ((vdo >> 12) & 1) == 0
        
        // Bits [15:13] = Cable latency
        cable.cableLatency = UInt8((vdo >> 13) & 0x7)
    }
    
    private func readActiveTransports(service: io_object_t) -> Set<String> {
        var transports = Set<String>()
        guard let props = IOKitReader.readProperties(service) else { return transports }
        
        if let types = props["TransportTypes"] as? [String] {
            for type in types {
                transports.insert(type)
            }
        }
        
        return transports
    }
    
    private func readPlugOrientation(service: io_object_t) -> String? {
        guard let props = IOKitReader.readProperties(service) else { return nil }
        return props["PlugOrientation"] as? String
    }
    
    private func readVCONN(service: io_object_t) -> Bool {
        guard let props = IOKitReader.readProperties(service) else { return false }
        return props["VCONNActive"] as? Bool ?? false
    }
    
    private func readThunderboltInfo(service: io_object_t) -> ThunderboltInfo? {
        guard let props = IOKitReader.readProperties(service) else { return nil }
        
        var tb = ThunderboltInfo()
        
        if let gen = props["TBGeneration"] as? String {
            tb.generation = gen
        }
        
        if let speed = props["PerLaneSpeed"] as? String {
            tb.perLaneSpeed = speed
        }
        
        if let lanes = props["LaneCount"] as? Int {
            tb.laneCount = lanes
        }
        
        // Read Thunderbolt topology
        if let routerID = props["TBRouterID"] as? Int {
            tb.topology.append("Router #\(routerID)")
        }
        
        if let linkSpeed = props["TBLinkSpeed"] as? String {
            tb.topology.append("Link: \(linkSpeed)")
        }
        
        if let protocols = props["TBTunnelledProtocols"] as? [String] {
            tb.topology.append("Tunnelled: \(protocols.joined(separator: ", "))")
        }
        
        return tb
    }
    
    private func readDisplayInfo(service: io_object_t) -> DisplayInfo? {
        guard let props = IOKitReader.readProperties(service) else { return nil }
        
        var display = DisplayInfo()
        
        if let res = props["DisplayResolution"] as? String {
            display.resolution = res
        }
        
        if let hz = props["DisplayRefreshRate"] as? Double {
            display.refreshRate = hz
        }
        
        if let compressed = props["DSCEnabled"] as? Bool {
            display.isCompressed = compressed
        }
        
        return display.resolution != nil ? display : nil
    }
    
    private func readPowerReading(service: io_object_t) -> PowerReading? {
        guard let props = IOKitReader.readProperties(service) else { return nil }
        
        if let watts = props["CurrentPower"] as? Double,
           let volts = props["Voltage"] as? Double {
            return PowerReading(
                watts: watts,
                volts: volts,
                amps: watts / max(volts, 1),
                timestamp: Date()
            )
        }
        
        return nil
    }
    
    private func readPortHealth(service: io_object_t) -> PortHealth? {
        guard let props = IOKitReader.readProperties(service) else { return nil }
        
        var health = PortHealth()
        var hasData = false
        
        if let resets = props["LifetimeResets"] as? Int {
            health.lifetimeResets = resets
            hasData = true
        }
        
        if let shorts = props["ShortCount"] as? Int {
            health.shorts = shorts
            hasData = true
        }
        
        if let errors = props["ErrorCount"] as? Int {
            health.errors = errors
            hasData = true
        }
        
        if let fets = props["FETFailureCount"] as? Int {
            health.fetFailures = fets
            hasData = true
        }
        
        return hasData ? health : nil
    }
    
    private func readPowerSources() -> [ChargerInfo] {
        var chargers: [ChargerInfo] = []
        
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOPortFeaturePowerSource")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        
        guard result == KERN_SUCCESS else { return chargers }
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }
            
            var charger = ChargerInfo()
            if let props = IOKitReader.readProperties(service) {
                charger.vendorName = props["VendorName"] as? String
                
                if let pdoArray = props["PDOList"] as? [[String: Any]] {
                    charger.pdos = pdoArray.compactMap { dict in
                        guard let voltage = dict["Voltage"] as? Double,
                              let current = dict["MaxCurrent"] as? Double else { return nil }
                        var pdo = ChargerPDO(voltage: voltage, maxCurrent: current)
                        pdo.isActive = dict["IsActive"] as? Bool ?? false
                        return pdo
                    }
                }
            }
            
            chargers.append(charger)
            service = IOIteratorNext(iterator)
        }
        
        return chargers
    }
    
    private func readUSBDevices() -> [ConnectedDevice] {
        var devices: [ConnectedDevice] = []
        
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOUSBDevice")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        
        guard result == KERN_SUCCESS else { return devices }
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }
            
            if let props = IOKitReader.readProperties(service) {
                let name = (props["USB Product Name"] as? String) ?? "Unknown Device"
                let vendor = props["USB Vendor Name"] as? String
                let locationID = props["locationID"] as? UInt32 ?? 0
                
                var speed: USBSpeed = .unknown
                if let speedStr = props["USB Speed"] as? String {
                    speed = parseSpeed(speedStr)
                }
                
                let device = ConnectedDevice(
                    id: "usb_\(locationID)",
                    name: name,
                    vendorName: vendor,
                    negotiatedSpeed: speed,
                    locationID: locationID
                )
                
                devices.append(device)
            }
            
            service = IOIteratorNext(iterator)
        }
        
        return devices
    }
    
    private struct PDIdentityData {
        var portVDO: UInt32?
        var cableVDO: UInt32?
        var cableVDO2: UInt32?
        var amaVDO: UInt32?
    }
    
    private func readPDIdentities() -> [Int: PDIdentityData] {
        var identities: [Int: PDIdentityData] = [:]
        
        let sopClasses = [
            "IOPortTransportComponentCCUSBPDSOP",
            "IOPortTransportComponentCCUSBPDSOPp",
            "IOPortTransportComponentCCUSBPDSOPpp"
        ]
        
        for className in sopClasses {
            var iterator: io_iterator_t = 0
            let matching = IOServiceMatching(className)
            let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
            
            guard result == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iterator) }
            
            var service = IOIteratorNext(iterator)
            while service != IO_OBJECT_NULL {
                defer { IOObjectRelease(service) }
                
                if let props = IOKitReader.readProperties(service) {
                    // Extract port index from registry path or parent
                    let portIndex = extractPortIndex(from: service, props: props)
                    
                    var identity = identities[portIndex] ?? PDIdentityData()
                    
                    if let vdo = props["PDIdentityVDO"] as? UInt32 {
                        switch className {
                        case "IOPortTransportComponentCCUSBPDSOP":
                            identity.portVDO = vdo
                        case "IOPortTransportComponentCCUSBPDSOPp":
                            identity.cableVDO = vdo
                        case "IOPortTransportComponentCCUSBPDSOPpp":
                            identity.cableVDO2 = vdo
                        default:
                            break
                        }
                    }
                    
                    if let amaVDO = props["PDAMAVDO"] as? UInt32 {
                        identity.amaVDO = amaVDO
                    }
                    
                    identities[portIndex] = identity
                }
                
                service = IOIteratorNext(iterator)
            }
        }
        
        return identities
    }
    
    private func extractPortIndex(from service: io_object_t, props: [String: Any]) -> Int {
        // Try to get port index from the registry entry path
        var path = [CChar](repeating: 0, count: 512)
        IORegistryEntryGetPath(service, kIOServicePlane, &path)
        let pathStr = String(cString: path)
        
        // Look for port number in path (e.g., "...Port@1..." or "...port-usb-c@0")
        if let range = pathStr.range(of: #"[@ ](\d+)"#, options: .regularExpression) {
            let numStr = pathStr[range].dropFirst()
            if let num = Int(numStr) {
                return num
            }
        }
        
        // Fallback: try PortNumber property
        if let portNum = props["PortNumber"] as? Int {
            return portNum
        }
        
        return 0
    }
    
    private func enrichWithPDIdentity(_ port: inout USBCPort, identity: PDIdentityData) {
        // Enrich cable info from SOP' (cable near-end) VDO
        if let cableVDO = identity.cableVDO {
            port.cable.hasEMarker = true
            parseCableVDO(cableVDO, into: &port.cable)
        }
        
        // Enrich from far-end VDO (SOP'') if available
        if identity.cableVDO2 != nil {
            // Far-end VDO confirms e-marker presence
            port.cable.hasEMarker = true
        }
        
        // Enrich device info from SOP (port partner) VDO
        if let amaVDO = identity.amaVDO {
            // AMA (Alternate Mode Adapter) VDO contains device info
            let vendorID = UInt16(amaVDO & 0xFFFF)
            if vendorID != 0 {
                port.cable.vendorID = vendorID
            }
        }
    }
    
    private func createSyntheticPorts() -> [USBCPort] {
        // Discover USB-C ports from XHCI controller topology
        var ports: [USBCPort] = []
        var portIndex = 0
        
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleUSBXHCI")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        
        guard result == KERN_SUCCESS else {
            // Last resort: create placeholder ports
            return [
                USBCPort(id: "port_0", portIndex: 0, locationName: "USB-C Port 1"),
                USBCPort(id: "port_1", portIndex: 1, locationName: "USB-C Port 2")
            ]
        }
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }
            
            if let props = IOKitReader.readProperties(service),
               let portCount = props["port-count"] as? Int {
                for _ in 0..<portCount {
                    let port = USBCPort(
                        id: "xhci_\(portIndex)",
                        portIndex: portIndex,
                        locationName: "USB-C Port \(portIndex + 1)"
                    )
                    ports.append(port)
                    portIndex += 1
                }
            }
            
            service = IOIteratorNext(iterator)
        }
        
        return ports
    }
    
    private func parseSpeed(_ str: String) -> USBSpeed {
        let lower = str.lowercased()
        
        // Use regex with word boundaries to avoid false matches
        // e.g., "5" should not match "50" or "15"
        let patterns: [(String, USBSpeed)] = [
            (#"\b80\b|\busb4.*80\b|\b80gbps\b"#, .usb4_80),
            (#"\b48\b|\busb4.*48\b|\b48gbps\b"#, .usb4_80),  // USB4 Gen3x2
            (#"\b40\b|\bthunderbolt\b|\btb[34]\b|\b40gbps\b"#, .usb4_40),
            (#"\b20\b|\busb.*20\b|\b20gbps\b"#, .usb3_20),
            (#"\b10\b|\busb.*10\b|\b10gbps\b"#, .usb3_10),
            (#"\b5\b|\busb.*5\b|\b5gbps\b"#, .usb3_5),
            (#"\b2\.0\b|\b480\b|\b480mbps\b"#, .usb2_480),
        ]
        
        for (pattern, speed) in patterns {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                return speed
            }
        }
        
        return .unknown
    }
}

extension IOKitReader {
    static func readProperties(_ service: io_object_t) -> [String: Any]? {
        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        
        guard result == KERN_SUCCESS, let dict = properties?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        
        return dict
    }
}
