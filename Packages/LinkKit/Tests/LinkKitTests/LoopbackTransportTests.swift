import Testing
import Foundation
@testable import LinkKit

@Suite("LoopbackTransport Tests")
struct LoopbackTransportTests {
    
    @Test("LoopbackTransport pair creation")
    func testPairCreation() {
        let (control, lens) = LoopbackTransport.createPair()
        
        #expect(control.peer === lens)
        #expect(lens.peer === control)
    }
    
    @Test("LoopbackTransport initial state")
    func testInitialState() {
        let transport = LoopbackTransport()
        
        #expect(transport.connectionState == .disconnected)
        #expect(transport.clockOffset == 0)
        #expect(transport.rttMs == 0)
    }
    
    @Test("LoopbackTransport connect without peer fails")
    func testConnectWithoutPeer() async {
        let transport = LoopbackTransport()
        
        do {
            try await transport.connect()
            Issue.record("Should have thrown")
        } catch TransportError.connectionFailed {
            // Expected
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }
    
    @Test("LoopbackTransport connect with peer succeeds")
    func testConnectWithPeer() async throws {
        let (control, lens) = LoopbackTransport.createPair()
        
        try await control.connect()
        
        #expect(control.connectionState == .connected)
        #expect(lens.connectionState == .connected)
    }
    
    @Test("LoopbackTransport disconnect")
    func testDisconnect() async throws {
        let (control, lens) = LoopbackTransport.createPair()
        
        try await control.connect()
        await control.disconnect()
        
        #expect(control.connectionState == .disconnected)
        #expect(lens.connectionState == .disconnected)
    }
    
    @Test("LoopbackTransport send without connection fails")
    func testSendWithoutConnection() async {
        let (control, _) = LoopbackTransport.createPair()
        
        do {
            try await control.send(.goodbye)
            Issue.record("Should have thrown")
        } catch TransportError.notConnected {
            // Expected
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }
    
    @Test("ConnectionState properties")
    func testConnectionStateProperties() {
        #expect(ConnectionState.disconnected.isConnected == false)
        #expect(ConnectionState.searching.isConnected == false)
        #expect(ConnectionState.connecting.isConnected == false)
        #expect(ConnectionState.connected.isConnected == true)
        #expect(ConnectionState.failed("test").isConnected == false)
    }
    
    @Test("ConnectionState display descriptions")
    func testConnectionStateDescriptions() {
        #expect(ConnectionState.disconnected.displayDescription == "Disconnected")
        #expect(ConnectionState.searching.displayDescription == "Searching...")
        #expect(ConnectionState.connecting.displayDescription == "Connecting...")
        #expect(ConnectionState.connected.displayDescription == "Connected")
        #expect(ConnectionState.failed("reason").displayDescription == "Failed: reason")
    }
    
    @Test("TransportError equality")
    func testTransportErrorEquality() {
        #expect(TransportError.notConnected == TransportError.notConnected)
        #expect(TransportError.timeout == TransportError.timeout)
        #expect(TransportError.connectionFailed("a") == TransportError.connectionFailed("a"))
        #expect(TransportError.connectionFailed("a") != TransportError.connectionFailed("b"))
    }
    
    @Test("LoopbackTransport clock sync update")
    func testClockSyncUpdate() {
        let transport = LoopbackTransport()
        
        transport.updateClockSync(
            localSend: 1_000_000_000,
            remoteReceive: 1_050_000_000,
            localReceive: 1_100_000_000
        )
        
        #expect(transport.rttMs == 100.0)
    }
    
    @Test("LoopbackTransport simulated latency")
    func testSimulatedLatency() async throws {
        let (control, lens) = LoopbackTransport.createPair()
        control.simulatedLatencyMs = 100
        
        let startTime = Date()
        try await control.connect()
        let elapsed = Date().timeIntervalSince(startTime)
        
        #expect(elapsed >= 0.09)
        #expect(control.connectionState == .connected)
        #expect(lens.connectionState == .connected)
    }
}
