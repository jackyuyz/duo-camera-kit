import Testing
import Foundation
@testable import LinkKit

@Suite("ControlMessage Tests")
struct ControlMessageTests {
    
    @Test("ControlMessage hello encoding")
    func testHelloEncoding() throws {
        let peer = PeerInfo.mock(name: "Test", role: .lens)
        let message = ControlMessage.hello(peer)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(ControlMessage.self, from: data)
        
        if case .hello(let decodedPeer) = decoded {
            #expect(decodedPeer.name == peer.name)
        } else {
            Issue.record("Wrong message type decoded")
        }
    }
    
    @Test("ControlMessage selectLens encoding")
    func testSelectLensEncoding() throws {
        let message = ControlMessage.selectLens("lens-123")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(ControlMessage.self, from: data)
        
        if case .selectLens(let lensId) = decoded {
            #expect(lensId == "lens-123")
        } else {
            Issue.record("Wrong message type decoded")
        }
    }
    
    @Test("ControlMessage zoom encoding")
    func testZoomEncoding() throws {
        let message = ControlMessage.zoom(3.5)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(ControlMessage.self, from: data)
        
        if case .zoom(let factor) = decoded {
            #expect(factor == 3.5)
        } else {
            Issue.record("Wrong message type decoded")
        }
    }
    
    @Test("ControlMessage focus encoding")
    func testFocusEncoding() throws {
        let point = CGPoint(x: 0.3, y: 0.7)
        let message = ControlMessage.focus(point)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(ControlMessage.self, from: data)
        
        if case .focus(let decodedPoint) = decoded {
            #expect(decodedPoint == point)
        } else {
            Issue.record("Wrong message type decoded")
        }
    }
    
    @Test("ControlMessage ping/pong encoding")
    func testPingPongEncoding() throws {
        let pingMessage = ControlMessage.ping(12345)
        let pongMessage = ControlMessage.pong(localTimestamp: 12345, remoteTimestamp: 12350)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let pingData = try encoder.encode(pingMessage)
        let pongData = try encoder.encode(pongMessage)
        
        let decodedPing = try decoder.decode(ControlMessage.self, from: pingData)
        let decodedPong = try decoder.decode(ControlMessage.self, from: pongData)
        
        if case .ping(let ts) = decodedPing {
            #expect(ts == 12345)
        } else {
            Issue.record("Wrong ping message type decoded")
        }
        
        if case .pong(let local, let remote) = decodedPong {
            #expect(local == 12345)
            #expect(remote == 12350)
        } else {
            Issue.record("Wrong pong message type decoded")
        }
    }
    
    @Test("ControlMessage status encoding")
    func testStatusEncoding() throws {
        let status = LensStatus.mock
        let message = ControlMessage.status(status)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(ControlMessage.self, from: data)
        
        if case .status(let decodedStatus) = decoded {
            #expect(decodedStatus.battery == status.battery)
        } else {
            Issue.record("Wrong message type decoded")
        }
    }
}

@Suite("ProtocolVersion Tests")
struct ProtocolVersionTests {
    
    @Test("ProtocolVersion current")
    func testCurrent() {
        let current = ProtocolVersion.current
        
        #expect(current.major == 1)
        #expect(current.minor == 0)
    }
    
    @Test("ProtocolVersion comparison")
    func testComparison() {
        let v1_0 = ProtocolVersion(major: 1, minor: 0)
        let v1_1 = ProtocolVersion(major: 1, minor: 1)
        let v2_0 = ProtocolVersion(major: 2, minor: 0)
        
        #expect(v1_0 < v1_1)
        #expect(v1_1 < v2_0)
        #expect(v1_0 < v2_0)
    }
    
    @Test("ProtocolVersion compatibility")
    func testCompatibility() {
        let v1_0 = ProtocolVersion(major: 1, minor: 0)
        let v1_1 = ProtocolVersion(major: 1, minor: 1)
        let v2_0 = ProtocolVersion(major: 2, minor: 0)
        
        #expect(v1_0.isCompatible(with: v1_1) == true)
        #expect(v1_0.isCompatible(with: v2_0) == false)
    }
    
    @Test("ProtocolVersion description")
    func testDescription() {
        let version = ProtocolVersion(major: 1, minor: 2)
        
        #expect(version.description == "1.2")
    }
}
