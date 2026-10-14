import Testing
import Foundation
@testable import LinkKit

@Suite("DiscoveredPeer Tests")
struct DiscoveredPeerTests {
    
    @Test("DiscoveredPeer initialization")
    func discoveredPeerInit() {
        let peer = DiscoveredPeer(
            endpoint: "test._duocamkit._tcp.local.",
            name: "Jack's iPhone",
            model: "iPhone 15 Pro",
            version: "1.0.0",
            role: .lens
        )
        
        #expect(peer.endpoint == "test._duocamkit._tcp.local.")
        #expect(peer.name == "Jack's iPhone")
        #expect(peer.model == "iPhone 15 Pro")
        #expect(peer.version == "1.0.0")
        #expect(peer.role == .lens)
        #expect(peer.id == "test._duocamkit._tcp.local.")
    }
    
    @Test("DiscoveredPeer equality")
    func discoveredPeerEquality() {
        let peer1 = DiscoveredPeer(
            endpoint: "test",
            name: "iPhone",
            model: "Model",
            version: "1.0",
            role: .lens
        )
        let peer2 = DiscoveredPeer(
            endpoint: "test",
            name: "iPhone",
            model: "Model",
            version: "1.0",
            role: .lens
        )
        
        #expect(peer1 == peer2)
    }
}

@Suite("DiscoveryState Tests")
struct DiscoveryStateTests {
    
    @Test("DiscoveryState values")
    func discoveryStateValues() {
        let idle = DiscoveryState.idle
        let browsing = DiscoveryState.browsing
        let stopped = DiscoveryState.stopped
        let failed = DiscoveryState.failed("Network error")
        
        #expect(idle == .idle)
        #expect(browsing == .browsing)
        #expect(stopped == .stopped)
        #expect(failed == .failed("Network error"))
    }
}

@Suite("DuoCamKitService Tests")
struct DuoCamKitServiceTests {
    
    @Test("Service constants")
    func serviceConstants() {
        #expect(DuoCamKitService.serviceType == "_duocamkit._tcp")
        #expect(DuoCamKitService.udpServiceType == "_duocamkit._udp")
        #expect(DuoCamKitService.serviceDomain == "local.")
        #expect(DuoCamKitService.txtKeyName == "name")
        #expect(DuoCamKitService.txtKeyModel == "model")
        #expect(DuoCamKitService.txtKeyVersion == "version")
        #expect(DuoCamKitService.txtKeyRole == "role")
    }
}

@Suite("MockPeerDiscovery Tests")
struct MockPeerDiscoveryTests {
    
    @MainActor
    @Test("Initial state is idle")
    func initialState() async {
        let discovery = MockPeerDiscovery()
        
        #expect(discovery.state == .idle)
        #expect(discovery.peers.isEmpty)
    }
    
    @MainActor
    @Test("Start browsing changes state")
    func startBrowsing() async {
        let discovery = MockPeerDiscovery()
        
        discovery.startBrowsing()
        
        #expect(discovery.state == .browsing)
    }
    
    @MainActor
    @Test("Stop browsing changes state")
    func stopBrowsing() async {
        let discovery = MockPeerDiscovery()
        
        discovery.startBrowsing()
        discovery.stopBrowsing()
        
        #expect(discovery.state == .stopped)
        #expect(discovery.peers.isEmpty)
    }
    
    @MainActor
    @Test("Add peer manually")
    func addPeer() async {
        let discovery = MockPeerDiscovery()
        let peer = DiscoveredPeer(
            endpoint: "test",
            name: "Test iPhone",
            model: "iPhone",
            version: "1.0",
            role: .lens
        )
        
        discovery.addPeer(peer)
        
        #expect(discovery.peers.count == 1)
        #expect(discovery.peers.first?.name == "Test iPhone")
    }
    
    @MainActor
    @Test("Remove peer")
    func removePeer() async {
        let discovery = MockPeerDiscovery()
        let peer = DiscoveredPeer(
            endpoint: "test",
            name: "Test iPhone",
            model: "iPhone",
            version: "1.0",
            role: .lens
        )
        
        discovery.addPeer(peer)
        #expect(discovery.peers.count == 1)
        
        discovery.removePeer(peer)
        #expect(discovery.peers.isEmpty)
    }
    
    @MainActor
    @Test("Simulate failure")
    func simulateFailure() async {
        let discovery = MockPeerDiscovery()
        
        discovery.simulateFailure("Network denied")
        
        #expect(discovery.state == .failed("Network denied"))
    }
    
    @MainActor
    @Test("Mock peers discovered on start")
    func mockPeersDiscovered() async throws {
        let mockPeer = DiscoveredPeer(
            endpoint: "mock",
            name: "Mock iPhone",
            model: "iPhone 15",
            version: "1.0",
            role: .lens
        )
        
        let discovery = MockPeerDiscovery(mockPeers: [mockPeer])
        discovery.discoveryDelay = 0.1
        
        discovery.startBrowsing()
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(discovery.peers.count == 1)
        #expect(discovery.peers.first?.name == "Mock iPhone")
    }
}
