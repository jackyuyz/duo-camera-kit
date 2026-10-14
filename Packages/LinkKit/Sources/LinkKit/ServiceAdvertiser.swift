import Foundation

/// State of service advertisement
public enum AdvertiserState: Sendable, Equatable {
    case idle
    case advertising
    case stopped
    case failed(String)
}

/// Protocol for advertising the Lens service
@MainActor
public protocol ServiceAdvertiser: AnyObject, Sendable {
    /// Current advertiser state
    var state: AdvertiserState { get }
    
    /// Stream of state changes
    func states() -> AsyncStream<AdvertiserState>
    
    /// Start advertising with the given pairing code
    func startAdvertising(pairingCode: PairingCode, deviceInfo: PeerInfo)
    
    /// Stop advertising
    func stopAdvertising()
    
    /// Accept an incoming connection with PSK verification
    func acceptConnection(psk: Data) async throws -> any Transport
}

/// Mock advertiser for testing
@MainActor
public final class MockServiceAdvertiser: ServiceAdvertiser, @unchecked Sendable {
    
    public private(set) var state: AdvertiserState = .idle
    
    private var stateContinuations: [UUID: AsyncStream<AdvertiserState>.Continuation] = [:]
    
    /// Simulated incoming connection transport
    public var mockTransport: (any Transport)?
    
    /// Callback when advertising starts
    public var onStartAdvertising: ((PairingCode, PeerInfo) -> Void)?
    
    public init() {}
    
    public func states() -> AsyncStream<AdvertiserState> {
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
    
    public func startAdvertising(pairingCode: PairingCode, deviceInfo: PeerInfo) {
        onStartAdvertising?(pairingCode, deviceInfo)
        setState(.advertising)
    }
    
    public func stopAdvertising() {
        setState(.stopped)
    }
    
    public func acceptConnection(psk: Data) async throws -> any Transport {
        guard let transport = mockTransport else {
            throw TransportError.connectionFailed("No mock transport configured")
        }
        return transport
    }
    
    // MARK: - Test Helpers
    
    public func simulateFailure(_ reason: String) {
        setState(.failed(reason))
    }
    
    private func setState(_ newState: AdvertiserState) {
        state = newState
        for continuation in stateContinuations.values {
            continuation.yield(newState)
        }
    }
}

#if canImport(Network)
import Network

/// Network.framework-based service advertiser using NWListener
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public final class NetworkServiceAdvertiser: ServiceAdvertiser, @unchecked Sendable {
    
    public private(set) var state: AdvertiserState = .idle
    
    private var listener: NWListener?
    private var pendingConnection: NWConnection?
    private var currentPairingCode: PairingCode?
    
    private let queue = DispatchQueue(label: "com.duocamerakit.advertiser")
    private var stateContinuations: [UUID: AsyncStream<AdvertiserState>.Continuation] = [:]
    
    public init() {}
    
    public func states() -> AsyncStream<AdvertiserState> {
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
    
    public func startAdvertising(pairingCode: PairingCode, deviceInfo: PeerInfo) {
        stopAdvertising()
        
        currentPairingCode = pairingCode
        
        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true
            
            let listener = try NWListener(using: parameters)
            self.listener = listener
            
            listener.service = NWListener.Service(
                name: deviceInfo.id.uuidString,
                type: DuoCamKitService.serviceType,
                domain: DuoCamKitService.serviceDomain,
                txtRecord: createTXTRecord(for: deviceInfo)
            )
            
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleListenerState(state)
                }
            }
            
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(connection)
                }
            }
            
            listener.start(queue: queue)
            
        } catch {
            setState(.failed(error.localizedDescription))
        }
    }
    
    public func stopAdvertising() {
        listener?.cancel()
        listener = nil
        pendingConnection?.cancel()
        pendingConnection = nil
        currentPairingCode = nil
        setState(.stopped)
    }
    
    public func acceptConnection(psk: Data) async throws -> any Transport {
        guard let connection = pendingConnection else {
            throw TransportError.connectionFailed("No pending connection")
        }
        
        let endpoint = connection.endpoint
        
        return await NetworkTransport(endpoint: endpoint, psk: psk)
    }
    
    private func createTXTRecord(for info: PeerInfo) -> NWTXTRecord {
        var record = NWTXTRecord()
        record[DuoCamKitService.txtKeyName] = info.name
        record[DuoCamKitService.txtKeyModel] = info.model
        record[DuoCamKitService.txtKeyVersion] = info.appVersion
        record[DuoCamKitService.txtKeyRole] = DeviceRole.lens.rawValue
        return record
    }
    
    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            setState(.advertising)
        case .failed(let error):
            setState(.failed(error.localizedDescription))
        case .cancelled:
            setState(.stopped)
        default:
            break
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        pendingConnection?.cancel()
        pendingConnection = connection
    }
    
    private func setState(_ newState: AdvertiserState) {
        state = newState
        for continuation in stateContinuations.values {
            continuation.yield(newState)
        }
    }
}
#endif
