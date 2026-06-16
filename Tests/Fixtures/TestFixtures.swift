import Foundation
import PortPulseCore

/// Test fixtures for diagnostic testing
public enum TestFixtures {
    
    /// Empty ports — nothing connected
    public static func emptyPorts() -> [USBCPort] {
        [
            USBCPort(id: "port_0", portIndex: 0, locationName: "USB-C Port 1"),
            USBCPort(id: "port_1", portIndex: 1, locationName: "USB-C Port 2"),
        ]
    }
    
    /// 100W charger with 60W cable
    public static func charger100wCable60w() -> USBCPort {
        var port = USBCPort(id: "port_0", portIndex: 0, locationName: "USB-C Port 1")
        port.connectionType = .usb3
        port.cable = CableInfo(
            hasEMarker: true,
            usbSpeed: .usb3_10,
            currentRating: 3.0,
            maxVoltage: 20,
            maxWattage: 60,
            vendorID: 0x1234,
            isPassive: true
        )
        port.charger = ChargerInfo(pdos: [
            ChargerPDO(voltage: 20, maxCurrent: 5, isActive: true)
        ])
        port.powerReading = PowerReading(watts: 60, volts: 20, amps: 3, timestamp: Date())
        return port
    }
    
    /// USB 2.0 charge-only cable
    public static func usb2ChargeOnlyCable() -> USBCPort {
        var port = USBCPort(id: "port_0", portIndex: 0, locationName: "USB-C Port 1")
        port.connectionType = .chargingOnly
        port.cable = CableInfo(
            hasEMarker: false,
            usbSpeed: .unknown,
            currentRating: 3.0,
            maxVoltage: 20,
            maxWattage: 60
        )
        port.charger = ChargerInfo(pdos: [
            ChargerPDO(voltage: 20, maxCurrent: 3, isActive: true)
        ])
        return port
    }
    
    /// Thunderbolt 4 dock
    public static func thunderbolt4Dock() -> USBCPort {
        var port = USBCPort(id: "port_0", portIndex: 0, locationName: "USB-C Port 1")
        port.connectionType = .thunderbolt
        port.cable = CableInfo(
            hasEMarker: true,
            usbSpeed: .usb4_40,
            currentRating: 5.0,
            maxVoltage: 20,
            maxWattage: 100,
            vendorID: 0x05AC,
            isPassive: false
        )
        port.thunderbolt = ThunderboltInfo(
            generation: "TB4",
            perLaneSpeed: "20 Gbps",
            laneCount: 2,
            topology: ["Router #0", "Link: 20 Gbps"]
        )
        port.devices = [
            ConnectedDevice(id: "dock", name: "CalDigit TS4", negotiatedSpeed: .usb3_10)
        ]
        return port
    }
    
    /// Display via USB-C
    public static func displayAltMode() -> USBCPort {
        var port = USBCPort(id: "port_0", portIndex: 0, locationName: "USB-C Port 1")
        port.connectionType = .displayOnly
        port.cable = CableInfo(
            hasEMarker: true,
            usbSpeed: .usb3_10,
            currentRating: 3.0,
            maxVoltage: 20,
            maxWattage: 60,
            vendorID: 0x1234
        )
        port.display = DisplayInfo(
            resolution: "3840x2160",
            refreshRate: 60,
            isCompressed: false,
            maxResolution: "3840x2160",
            maxRefreshRate: 60
        )
        return port
    }
}
