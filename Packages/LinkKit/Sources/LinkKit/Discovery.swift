import Foundation

/// Discovered peer information
public struct DiscoveredPeer: Sendable, Hashable, Identifiable {
    public var id: String { endpoint }
    
    /// Network endpoint identifier
    public let endpoint: String
    
    /// Display name from TXT record
    public let name: String
    
    /// Device model from TXT record
    public let model: String
    
    /// App version from TXT record
    public let version: String
    
    /// Role of the peer
    public let role: DeviceRole
    
    public init(endpoint: String, name: String, model: String, version: String, role: DeviceRole) {
        self.endpoint = endpoint
        self.name = name
        self.model = model
        self.version = version
        self.role = role
    }
}

/// Discovery state
public enum DiscoveryState: Sendable, Equatable {
    /// Not started
    case idle
    
    /// Actively searching
    case browsing
    
    /// Stopped
    case stopped
    
    /// Failed with reason
    case failed(String)
}

/// Protocol for Bonjour service discovery
/// Uses Network.framework NWBrowser on iOS, mock implementation for testing
@MainActor
public protocol PeerDiscovery: AnyObject, Sendable {
    /// Current discovery state
    var state: DiscoveryState { get }
    
    /// Stream of state changes
    func states() -> AsyncStream<DiscoveryState>
    
    /// Currently discovered peers
    var peers: [DiscoveredPeer] { get }
    
    /// Stream of peer updates (added, removed, updated)
    func peerUpdates() -> AsyncStream<PeerUpdate>
    
    /// Start browsing for peers
    func startBrowsing()
    
    /// Stop browsing
    func stopBrowsing()
}

/// Peer update event
public enum PeerUpdate: Sendable {
    case added(DiscoveredPeer)
    case removed(DiscoveredPeer)
    case updated(DiscoveredPeer)
}

/// Service type for Duo Camera Kit
public enum DuoCamKitService {
    /// Bonjour service type
    public static let serviceType = "_duocamkit._tcp"
    
    /// Service domain
    public static let serviceDomain = "local."
    
    /// TXT record keys
    public static let txtKeyName = "name"
    public static let txtKeyModel = "model"
    public static let txtKeyVersion = "version"
    public static let txtKeyRole = "role"
}

/// Mock implementation for testing
@MainActor
public final class MockPeerDiscovery: PeerDiscovery, @unchecked Sendable {
    
    public private(set) var state: DiscoveryState = .idle
    public private(set) var peers: [DiscoveredPeer] = []
    
    private var stateContinuations: [UUID: AsyncStream<DiscoveryState>.Continuation] = [:]
    private var peerContinuations: [UUID: AsyncStream<PeerUpdate>.Continuation] = [:]
    
    /// Simulated delay before finding peers
    public var discoveryDelay: TimeInterval = 0.5
    
    /// Peers to "discover" when browsing
    public var mockPeers: [DiscoveredPeer] = []
    
    public init(mockPeers: [DiscoveredPeer] = []) {
        self.mockPeers = mockPeers
    }
    
    public func states() -> AsyncStream<DiscoveryState> {
        let id = UUID()
        return AsyncStream { continuation in
            continuation.yield(state)
            stateContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.stateContinuations.removeValue(forKey: id)
                }
            }
        }
    }
    
    public func peerUpdates() -> AsyncStream<PeerUpdate> {
        let id = UUID()
        return AsyncStream { continuation in
            peerContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.peerContinuations.removeValue(forKey: id)
                }
            }
        }
    }
    
    public func startBrowsing() {
        setState(.browsing)
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(discoveryDelay * 1_000_000_000))
            
            for peer in mockPeers {
                addPeer(peer)
            }
        }
    }
    
    public func stopBrowsing() {
        setState(.stopped)
        peers.removeAll()
    }
    
    // MARK: - Test Helpers
    
    public func addPeer(_ peer: DiscoveredPeer) {
        peers.append(peer)
        notifyPeerUpdate(.added(peer))
    }
    
    public func removePeer(_ peer: DiscoveredPeer) {
        peers.removeAll { $0.id == peer.id }
        notifyPeerUpdate(.removed(peer))
    }
    
    public func simulateFailure(_ reason: String) {
        setState(.failed(reason))
    }
    
    private func setState(_ newState: DiscoveryState) {
        state = newState
        for continuation in stateContinuations.values {
            continuation.yield(newState)
        }
    }
    
    private func notifyPeerUpdate(_ update: PeerUpdate) {
        for continuation in peerContinuations.values {
            continuation.yield(update)
        }
    }
}

#if canImport(Network)
import Network

/// Network.framework-based discovery using NWBrowser
/// Available only on Apple platforms
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public final class NetworkPeerDiscovery: PeerDiscovery, @unchecked Sendable {
    
    public private(set) var state: DiscoveryState = .idle
    public private(set) var peers: [DiscoveredPeer] = []
    
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.duocamerakit.discovery")
    
    private var stateContinuations: [UUID: AsyncStream<DiscoveryState>.Continuation] = [:]
    private var peerContinuations: [UUID: AsyncStream<PeerUpdate>.Continuation] = [:]
    
    /// Whether to include peer-to-peer (AWDL) discovery
    public let includePeerToPeer: Bool
    
    public init(includePeerToPeer: Bool = true) {
        self.includePeerToPeer = includePeerToPeer
    }
    
    public func states() -> AsyncStream<DiscoveryState> {
        let id = UUID()
        return AsyncStream { continuation in
            continuation.yield(state)
            stateContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.stateContinuations.removeValue(forKey: id)
                }
            }
        }
    }
    
    public func peerUpdates() -> AsyncStream<PeerUpdate> {
        let id = UUID()
        return AsyncStream { continuation in
            peerContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.peerContinuations.removeValue(forKey: id)
                }
            }
        }
    }
    
    public func startBrowsing() {
        stopBrowsing()
        
        var parameters = NWParameters()
        parameters.includePeerToPeer = includePeerToPeer
        
        let descriptor = NWBrowser.Descriptor.bonjour(
            type: DuoCamKitService.serviceType,
            domain: DuoCamKitService.serviceDomain
        )
        
        let browser = NWBrowser(for: descriptor, using: parameters)
        self.browser = browser
        
        browser.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor [weak self] in
                self?.handleBrowserState(newState)
            }
        }
        
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                self?.handleBrowseResults(results, changes: changes)
            }
        }
        
        browser.start(queue: queue)
        setState(.browsing)
    }
    
    public func stopBrowsing() {
        browser?.cancel()
        browser = nil
        peers.removeAll()
        setState(.stopped)
    }
    
    private func handleBrowserState(_ newState: NWBrowser.State) {
        switch newState {
        case .ready:
            setState(.browsing)
        case .failed(let error):
            setState(.failed(error.localizedDescription))
        case .cancelled:
            setState(.stopped)
        case .waiting(let error):
            if case .dns(let dnsError) = error {
                if dnsError == kDNSServiceErr_PolicyDenied {
                    setState(.failed("Local network access denied. Enable in Settings."))
                } else {
                    setState(.failed("Network error: \(error.localizedDescription)"))
                }
            }
        default:
            break
        }
    }
    
    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                if let peer = extractPeer(from: result) {
                    peers.append(peer)
                    notifyPeerUpdate(.added(peer))
                }
            case .removed(let result):
                let endpoint = endpointString(from: result.endpoint)
                if let index = peers.firstIndex(where: { $0.endpoint == endpoint }) {
                    let peer = peers.remove(at: index)
                    notifyPeerUpdate(.removed(peer))
                }
            case .changed(_, let newResult, _):
                if let peer = extractPeer(from: newResult) {
                    if let index = peers.firstIndex(where: { $0.endpoint == peer.endpoint }) {
                        peers[index] = peer
                    }
                    notifyPeerUpdate(.updated(peer))
                }
            default:
                break
            }
        }
    }
    
    private func extractPeer(from result: NWBrowser.Result) -> DiscoveredPeer? {
        let endpoint = endpointString(from: result.endpoint)
        
        guard case .bonjour(let txtRecord) = result.metadata else {
            return DiscoveredPeer(
                endpoint: endpoint,
                name: "Unknown",
                model: "Unknown",
                version: "1.0.0",
                role: .lens
            )
        }
        
        let name = txtRecord[DuoCamKitService.txtKeyName] ?? "Unknown"
        let model = txtRecord[DuoCamKitService.txtKeyModel] ?? "Unknown"
        let version = txtRecord[DuoCamKitService.txtKeyVersion] ?? "1.0.0"
        let roleString = txtRecord[DuoCamKitService.txtKeyRole] ?? "lens"
        let role = DeviceRole(rawValue: roleString) ?? .lens
        
        return DiscoveredPeer(
            endpoint: endpoint,
            name: name,
            model: model,
            version: version,
            role: role
        )
    }
    
    private func endpointString(from endpoint: NWEndpoint) -> String {
        switch endpoint {
        case .service(let name, let type, let domain, _):
            return "\(name).\(type).\(domain)"
        default:
            return endpoint.debugDescription
        }
    }
    
    private func setState(_ newState: DiscoveryState) {
        state = newState
        for continuation in stateContinuations.values {
            continuation.yield(newState)
        }
    }
    
    private func notifyPeerUpdate(_ update: PeerUpdate) {
        for continuation in peerContinuations.values {
            continuation.yield(update)
        }
    }
}
#endif
