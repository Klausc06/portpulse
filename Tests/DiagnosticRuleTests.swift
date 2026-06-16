import XCTest
@testable import PortPulseCore

final class DiagnosticRuleTests: XCTestCase {
    let engine = DiagnosticEngine()
    
    // MARK: - Charging Tests
    
    func testCharging100WCharger60WCable() {
        let port = TestFixtures.charger100wCable60w()
        let result = engine.diagnoseCharging(port: port)
        
        XCTAssertEqual(result.bottleneck, .cable)
        XCTAssertTrue(result.message.contains("Cable is limiting"))
    }
    
    func testChargingUSB2ChargeOnly() {
        let port = TestFixtures.usb2ChargeOnlyCable()
        let result = engine.diagnoseCharging(port: port)
        
        // Should have a charging result
        XCTAssertNotEqual(result.bottleneck, .unknown)
    }
    
    func testChargingEmptyPorts() {
        let ports = TestFixtures.emptyPorts()
        let result = engine.diagnoseCharging(port: ports[0])
        
        XCTAssertEqual(result.bottleneck, .unknown)
    }
    
    // MARK: - Data Speed Tests
    
    func testDataSpeedUnknownCable() {
        var port = USBCPort(id: "test", portIndex: 0, locationName: "Test")
        port.connectionType = .usb3
        port.cable = CableInfo(hasEMarker: false, usbSpeed: .unknown)
        
        let result = engine.diagnoseDataSpeed(port: port)
        
        XCTAssertEqual(result.bottleneck, .unknown)
    }
    
    func testDataSpeedThunderbolt4() {
        let port = TestFixtures.thunderbolt4Dock()
        let result = engine.diagnoseDataSpeed(port: port)
        
        // Should report OK or device limiting
        XCTAssertNotEqual(result.bottleneck, .unknown)
    }
    
    // MARK: - Cable Trust Tests
    
    func testTrustZeroVID() {
        var cable = CableInfo(hasEMarker: true, vendorID: 0, usbSpeed: .usb3_10)
        let flags = engine.checkCableTrustSignals(cable: cable)
        
        XCTAssertTrue(flags.contains { $0.contains("0x0000") })
    }
    
    func testTrustNormalCable() {
        var cable = CableInfo(
            hasEMarker: true,
            usbSpeed: .usb4_40,
            currentRating: 5.0,
            vendorID: 0x05AC
        )
        let flags = engine.checkCableTrustSignals(cable: cable)
        
        // Apple vendor should not trigger trust warnings
        XCTAssertTrue(flags.isEmpty)
    }
}
