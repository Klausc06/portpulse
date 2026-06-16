import Foundation

public struct VendorDatabase {
    public static let shared = VendorDatabase()
    
    // Common USB-IF vendor IDs
    private let vendors: [UInt16: String] = [
        0x05AC: "Apple",
        0x0451: "Texas Instruments",
        0x0BDA: "Realtek",
        0x8087: "Intel",
        0x17EF: "Lenovo",
        0x046D: "Logitech",
        0x04E8: "Samsung",
        0x0951: "Kingston",
        0x1058: "Western Digital",
        0x174C: "ASMedia",
        0x1D5C: "Fresco Logic",
        0x2109: "VIA Labs",
        0x1A40: "Terminus Technology",
        0x05E3: "Genesys Logic",
        0x0424: "Microchip",
        0x0483: "STMicroelectronics",
        0x2972: "FiiO",
        0x2717: "Xiaomi",
        0x18D1: "Google",
        0x0BB4: "HTC",
        0x2A70: "OnePlus",
        0x12D1: "Huawei",
        0x0FCE: "Sony",
        0x2C7C: "Quectel",
        0x1286: "Marvell",
        0x1106: "VIA",
        0x1B21: "ASMedia",
        0x1C7A: "LighTuning",
        0x06CB: "Synaptics",
        0x2B3E: "Cypress",
        0x03EB: "Atmel",
        0x0FCF: "Garmin",
        0x13D3: "IMC Networks",
        0x04F3: "ELAN",
        0x062A: "MosArt",
        0x093A: "PixArt",
        0x1BCF: "Sunplus",
        0x0461: "Primax",
        0x046A: "Cherry",
    ]
    
    // Known cable fingerprints (VID:PID → name)
    private let cableFingerprints: [String: String] = [
        "05AC:0001": "Apple USB-C Charge Cable",
        "05AC:0002": "Apple Thunderbolt 4 Pro Cable",
        "05AC:0003": "Apple Thunderbolt 4 Cable",
        "17EF:3001": "Lenovo USB-C Cable",
        "04E8:A001": "Samsung USB-C Cable",
    ]
    
    public init() {}
    
    public func vendorName(for vid: UInt16) -> String? {
        vendors[vid]
    }
    
    public func cableName(vid: UInt16, pid: UInt16) -> String? {
        let key = String(format: "%04X:%04X", vid, pid)
        return cableFingerprints[key]
    }
    
    public func isValidVID(_ vid: UInt16) -> Bool {
        vid != 0 && vendors[vid] != nil
    }
}
