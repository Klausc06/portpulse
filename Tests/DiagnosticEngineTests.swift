import XCTest
@testable import PortPulseCore

final class DiagnosticEngineTests: XCTestCase {
    let engine = DiagnosticEngine()
    
    func testChargingBottleneckCable() {
        var port = USBCPort(id: "test", portIndex: 0, locationName: "Test Port")
        port.connectionType = .usb3
        port.cable.maxWattage = 60
        port.charger.pdos = [ChargerPDO(voltage: 20, maxCurrent: 5)]
        
        let result = engine.diagnoseCharging(port: port)
        XCTAssertEqual(result.bottleneck, .cable)
        XCTAssertTrue(result.message.contains("Cable is limiting"))
    }
    
    func testChargingBottleneckNone() {
        var port = USBCPort(id: "test", portIndex: 0, locationName: "Test Port")
        port.connectionType = .usb4
        port.cable.maxWattage = 100
        port.charger.pdos = [ChargerPDO(voltage: 20, maxCurrent: 3)]
        port.powerReading = PowerReading(watts: 60, volts: 20, amps: 3, timestamp: Date())
        
        let result = engine.diagnoseCharging(port: port)
        XCTAssertEqual(result.bottleneck, .none)
    }
    
    func testCableTrustSignalsZeroVID() {
        var cable = CableInfo()
        cable.vendorID = 0
        cable.currentRating = 5
        cable.usbSpeed = .usb3_10
        
        let flags = engine.checkCableTrustSignals(cable: cable)
        XCTAssertTrue(flags.contains { $0.contains("0x0000") })
    }
    
    func testCableTrustSignalsMismatchedSpeed() {
        var cable = CableInfo()
        cable.vendorID = 0x05AC
        cable.currentRating = 5.0
        cable.usbSpeed = .usb2_480
        
        let flags = engine.checkCableTrustSignals(cable: cable)
        XCTAssertTrue(flags.contains { $0.contains("5A") && $0.contains("USB 2.0") })
    }
    
    func testNothingConnected() {
        let port = USBCPort(id: "test", portIndex: 0, locationName: "Test Port")
        let result = engine.diagnoseCharging(port: port)
        XCTAssertEqual(result.bottleneck, .unknown)
    }
    
    func testSpeedBottleneckCable() {
        var port = USBCPort(id: "test", portIndex: 0, locationName: "Test Port")
        port.connectionType = .usb3
        port.cable.usbSpeed = .usb2_480
        
        let result = engine.diagnoseDataSpeed(port: port)
        XCTAssertEqual(result.bottleneck, .cable)
    }
}
