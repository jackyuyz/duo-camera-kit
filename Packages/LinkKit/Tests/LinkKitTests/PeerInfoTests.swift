import Testing
import Foundation
@testable import LinkKit

@Suite("PeerInfo Tests")
struct PeerInfoTests {
    
    @Test("PeerInfo initialization")
    func testInit() {
        let capabilities = LensCapabilities.mockIPhonePro
        let peer = PeerInfo(
            name: "Test iPhone",
            model: "iPhone 15 Pro",
            appVersion: "1.0.0",
            capabilities: capabilities
        )
        
        #expect(peer.name == "Test iPhone")
        #expect(peer.model == "iPhone 15 Pro")
        #expect(peer.appVersion == "1.0.0")
        #expect(peer.capabilities != nil)
    }
    
    @Test("PeerInfo mock creation")
    func testMock() {
        let lensPeer = PeerInfo.mock(name: "Lens", role: .lens)
        let controlPeer = PeerInfo.mock(name: "Control", role: .control)
        
        #expect(lensPeer.capabilities != nil)
        #expect(controlPeer.capabilities == nil)
    }
    
    @Test("PeerInfo is Codable")
    func testCodable() throws {
        let original = PeerInfo.mock(name: "Test", role: .lens)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PeerInfo.self, from: data)
        
        #expect(decoded.name == original.name)
        #expect(decoded.model == original.model)
    }
}

@Suite("LensStatus Tests")
struct LensStatusTests {
    
    @Test("LensStatus initialization")
    func testInit() {
        let status = LensStatus(
            battery: 0.75,
            thermal: 1,
            isRecording: true,
            freeBytes: 10_000_000_000
        )
        
        #expect(status.battery == 0.75)
        #expect(status.thermal == 1)
        #expect(status.isRecording == true)
        #expect(status.freeBytes == 10_000_000_000)
    }
    
    @Test("LensStatus thermal descriptions")
    func testThermalDescription() {
        #expect(LensStatus(battery: 1, thermal: 0, isRecording: false, freeBytes: 0).thermalDescription == "Normal")
        #expect(LensStatus(battery: 1, thermal: 1, isRecording: false, freeBytes: 0).thermalDescription == "Fair")
        #expect(LensStatus(battery: 1, thermal: 2, isRecording: false, freeBytes: 0).thermalDescription == "Serious")
        #expect(LensStatus(battery: 1, thermal: 3, isRecording: false, freeBytes: 0).thermalDescription == "Critical")
    }
    
    @Test("LensStatus thermal warning")
    func testThermalWarning() {
        #expect(LensStatus(battery: 1, thermal: 0, isRecording: false, freeBytes: 0).isThermalWarning == false)
        #expect(LensStatus(battery: 1, thermal: 1, isRecording: false, freeBytes: 0).isThermalWarning == false)
        #expect(LensStatus(battery: 1, thermal: 2, isRecording: false, freeBytes: 0).isThermalWarning == true)
        #expect(LensStatus(battery: 1, thermal: 3, isRecording: false, freeBytes: 0).isThermalWarning == true)
    }
    
    @Test("LensStatus free storage formatting")
    func testFreeStorageFormatted() {
        let status = LensStatus(battery: 1, thermal: 0, isRecording: false, freeBytes: 50_000_000_000)
        
        #expect(status.freeStorageFormatted.contains("GB") || status.freeStorageFormatted.contains("50"))
    }
}

@Suite("DeviceRole Tests")
struct DeviceRoleTests {
    
    @Test("DeviceRole values")
    func testValues() {
        #expect(DeviceRole.control.rawValue == "control")
        #expect(DeviceRole.lens.rawValue == "lens")
    }
    
    @Test("DeviceRole is Codable")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for role in [DeviceRole.control, DeviceRole.lens] {
            let data = try encoder.encode(role)
            let decoded = try decoder.decode(DeviceRole.self, from: data)
            #expect(decoded == role)
        }
    }
}
