import Foundation

/// Protocol for transport layer between Control and Lens devices
public protocol Transport: AnyObject, Sendable {
    /// Connection state
    var connectionState: ConnectionState { get }
    
    /// Stream of connection state changes
    func connectionStates() -> AsyncStream<ConnectionState>
    
    /// Send a control message
    func send(_ message: ControlMessage) async throws
    
    /// Stream of incoming control messages
    var messages: AsyncStream<ControlMessage> { get }
    
    /// Send video frame data (for preview streaming)
    func sendVideo(_ packet: Data) async throws
    
    /// Stream of incoming video data packets
    var video: AsyncStream<Data> { get }
    
    /// Connect to a peer
    func connect() async throws
    
    /// Disconnect from the peer
    func disconnect() async
    
    /// Estimated clock offset with peer in nanoseconds
    var clockOffset: Int64 { get }
    
    /// Current round-trip time estimate in milliseconds
    var rttMs: Double { get }
}

/// Connection state between peers
public enum ConnectionState: Sendable, Equatable {
    /// Not connected
    case disconnected
    
    /// Searching for peer
    case searching
    
    /// Connecting to peer
    case connecting
    
    /// Connected and ready
    case connected
    
    /// Connection failed with reason
    case failed(String)
    
    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    public var displayDescription: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .searching: return "Searching..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .failed(let reason): return "Failed: \(reason)"
        }
    }
}

/// Errors from transport operations
public enum TransportError: Error, Sendable, Equatable {
    case notConnected
    case connectionFailed(String)
    case sendFailed(String)
    case timeout
    case invalidMessage
    case peerDisconnected
    case authenticationFailed
}
