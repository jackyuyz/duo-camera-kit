import Foundation

/// A pair of in-process transports for testing
/// Each endpoint connects to the other directly
public final class LoopbackTransport: Transport, @unchecked Sendable {
    private let lock = NSLock()
    
    /// The other endpoint of this loopback
    public weak var peer: LoopbackTransport?
    
    private var _connectionState: ConnectionState = .disconnected
    public var connectionState: ConnectionState {
        lock.withLock { _connectionState }
    }
    
    private var connectionContinuations: [UUID: AsyncStream<ConnectionState>.Continuation] = [:]
    private var messageContinuations: [UUID: AsyncStream<ControlMessage>.Continuation] = [:]
    private var videoContinuations: [UUID: AsyncStream<Data>.Continuation] = [:]
    
    /// Simulated latency in milliseconds
    public var simulatedLatencyMs: Int = 0
    
    /// Simulated packet loss rate (0.0 - 1.0)
    public var simulatedLossRate: Double = 0.0
    
    /// Simulated clock offset for testing (nanoseconds)
    public var simulatedClockOffset: Int64 = 0
    
    private var _clockOffset: Int64 = 0
    public var clockOffset: Int64 {
        lock.withLock { _clockOffset }
    }
    
    private var _rttMs: Double = 0
    public var rttMs: Double {
        lock.withLock { _rttMs }
    }
    
    public init() {}
    
    /// Create a connected pair of loopback transports
    public static func createPair() -> (control: LoopbackTransport, lens: LoopbackTransport) {
        let control = LoopbackTransport()
        let lens = LoopbackTransport()
        control.peer = lens
        lens.peer = control
        return (control, lens)
    }
    
    public func connectionStates() -> AsyncStream<ConnectionState> {
        let id = UUID()
        return AsyncStream { continuation in
            self.lock.withLock {
                continuation.yield(self._connectionState)
                self.connectionContinuations[id] = continuation
            }
            continuation.onTermination = { @Sendable _ in
                self.lock.withLock {
                    _ = self.connectionContinuations.removeValue(forKey: id)
                }
            }
        }
    }
    
    private var _messages: AsyncStream<ControlMessage>?
    public var messages: AsyncStream<ControlMessage> {
        let id = UUID()
        return AsyncStream { continuation in
            self.lock.withLock {
                self.messageContinuations[id] = continuation
            }
            continuation.onTermination = { @Sendable _ in
                self.lock.withLock {
                    _ = self.messageContinuations.removeValue(forKey: id)
                }
            }
        }
    }
    
    public var video: AsyncStream<Data> {
        let id = UUID()
        return AsyncStream { continuation in
            self.lock.withLock {
                self.videoContinuations[id] = continuation
            }
            continuation.onTermination = { @Sendable _ in
                self.lock.withLock {
                    _ = self.videoContinuations.removeValue(forKey: id)
                }
            }
        }
    }
    
    public func connect() async throws {
        guard let peer = peer else {
            throw TransportError.connectionFailed("No peer configured")
        }
        
        setConnectionState(.connecting)
        
        if simulatedLatencyMs > 0 {
            try await Task.sleep(for: .milliseconds(simulatedLatencyMs))
        }
        
        setConnectionState(.connected)
        peer.setConnectionState(.connected)
    }
    
    public func disconnect() async {
        setConnectionState(.disconnected)
        peer?.setConnectionState(.disconnected)
        
        lock.withLock {
            for continuation in messageContinuations.values {
                continuation.finish()
            }
            messageContinuations.removeAll()
            
            for continuation in videoContinuations.values {
                continuation.finish()
            }
            videoContinuations.removeAll()
        }
    }
    
    public func send(_ message: ControlMessage) async throws {
        guard connectionState.isConnected else {
            throw TransportError.notConnected
        }
        
        guard let peer = peer else {
            throw TransportError.peerDisconnected
        }
        
        if shouldDropPacket() {
            return
        }
        
        if simulatedLatencyMs > 0 {
            try await Task.sleep(for: .milliseconds(simulatedLatencyMs / 2))
        }
        
        peer.receiveMessage(message)
    }
    
    public func sendVideo(_ packet: Data) async throws {
        guard connectionState.isConnected else {
            throw TransportError.notConnected
        }
        
        guard let peer = peer else {
            throw TransportError.peerDisconnected
        }
        
        if shouldDropPacket() {
            return
        }
        
        if simulatedLatencyMs > 0 {
            try await Task.sleep(for: .milliseconds(simulatedLatencyMs / 2))
        }
        
        peer.receiveVideo(packet)
    }
    
    private func setConnectionState(_ state: ConnectionState) {
        lock.withLock {
            _connectionState = state
            for continuation in connectionContinuations.values {
                continuation.yield(state)
            }
        }
    }
    
    func receiveMessage(_ message: ControlMessage) {
        lock.withLock {
            for continuation in messageContinuations.values {
                continuation.yield(message)
            }
        }
    }
    
    func receiveVideo(_ packet: Data) {
        lock.withLock {
            for continuation in videoContinuations.values {
                continuation.yield(packet)
            }
        }
    }
    
    private func shouldDropPacket() -> Bool {
        guard simulatedLossRate > 0 else { return false }
        return Double.random(in: 0..<1) < simulatedLossRate
    }
    
    /// Update clock offset from ping/pong measurements
    public func updateClockSync(localSend: UInt64, remoteReceive: UInt64, localReceive: UInt64) {
        let rtt = Int64(localReceive) - Int64(localSend)
        let offset = Int64(remoteReceive) - Int64(localSend) - rtt / 2 + simulatedClockOffset
        
        lock.withLock {
            _clockOffset = offset
            _rttMs = Double(rtt) / 1_000_000
        }
    }
}
