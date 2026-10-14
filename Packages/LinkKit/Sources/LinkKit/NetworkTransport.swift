import Foundation

/// Configuration for network transport
public struct NetworkTransportConfig: Sendable {
    /// Port for the control channel
    public var controlPort: UInt16
    
    /// Port for the video channel (preview streaming)
    public var videoPort: UInt16
    
    /// Whether to include peer-to-peer (AWDL) for discovery and connection
    public var includePeerToPeer: Bool
    
    /// Connection timeout in seconds
    public var connectionTimeout: TimeInterval
    
    /// Reconnection attempts before giving up
    public var maxReconnectAttempts: Int
    
    /// Base delay between reconnection attempts (exponential backoff)
    public var reconnectBaseDelay: TimeInterval
    
    public init(
        controlPort: UInt16 = 32581,
        videoPort: UInt16 = 32582,
        includePeerToPeer: Bool = true,
        connectionTimeout: TimeInterval = 10.0,
        maxReconnectAttempts: Int = 3,
        reconnectBaseDelay: TimeInterval = 1.0
    ) {
        self.controlPort = controlPort
        self.videoPort = videoPort
        self.includePeerToPeer = includePeerToPeer
        self.connectionTimeout = connectionTimeout
        self.maxReconnectAttempts = maxReconnectAttempts
        self.reconnectBaseDelay = reconnectBaseDelay
    }
    
    public static let `default` = NetworkTransportConfig()
}

/// Message framing for control channel
/// Format: [4-byte length (big-endian)] [payload]
public struct MessageFramer {
    
    /// Frame a message with length prefix
    public static func frame(_ data: Data) -> Data {
        var framed = Data(capacity: 4 + data.count)
        var length = UInt32(data.count).bigEndian
        withUnsafeBytes(of: &length) { framed.append(contentsOf: $0) }
        framed.append(data)
        return framed
    }
    
    /// Extract length from frame header (handles unaligned data)
    public static func extractLength(from data: Data) -> UInt32? {
        guard data.count >= 4 else { return nil }
        let bytes = [UInt8](data.prefix(4))
        let length = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        return length
    }
}

#if canImport(Network) && canImport(Security)
import Network
import Security

/// Network.framework-based transport with TLS-PSK
/// Available only on Apple platforms
@available(iOS 13.0, macOS 10.15, *)
public actor NetworkTransport: Transport {
    
    public private(set) var connectionState: ConnectionState = .disconnected
    public private(set) var clockOffset: Int64 = 0
    public private(set) var rttMs: Double = 0
    
    private let config: NetworkTransportConfig
    private let psk: Data
    private let peerEndpoint: NWEndpoint
    
    private var controlConnection: NWConnection?
    private var videoConnection: NWConnection?
    private var listener: NWListener?
    
    private let queue = DispatchQueue(label: "com.duocamerakit.transport")
    
    private var messageContinuation: AsyncStream<ControlMessage>.Continuation?
    private var videoContinuation: AsyncStream<Data>.Continuation?
    private var stateContinuation: AsyncStream<ConnectionState>.Continuation?
    
    private var messageBuffer = Data()
    private var reconnectAttempt = 0
    private var clockSync = ClockSync()
    
    public init(endpoint: NWEndpoint, psk: Data, config: NetworkTransportConfig = .default) {
        self.peerEndpoint = endpoint
        self.psk = psk
        self.config = config
    }
    
    public nonisolated var messages: AsyncStream<ControlMessage> {
        AsyncStream { continuation in
            Task { await setMessageContinuation(continuation) }
        }
    }
    
    public nonisolated var video: AsyncStream<Data> {
        AsyncStream { continuation in
            Task { await setVideoContinuation(continuation) }
        }
    }
    
    public nonisolated func connectionStates() -> AsyncStream<ConnectionState> {
        AsyncStream { continuation in
            Task {
                await continuation.yield(connectionState)
                await setStateContinuation(continuation)
            }
        }
    }
    
    private func setMessageContinuation(_ continuation: AsyncStream<ControlMessage>.Continuation) {
        messageContinuation = continuation
    }
    
    private func setVideoContinuation(_ continuation: AsyncStream<Data>.Continuation) {
        videoContinuation = continuation
    }
    
    private func setStateContinuation(_ continuation: AsyncStream<ConnectionState>.Continuation) {
        stateContinuation = continuation
    }
    
    public func connect() async throws {
        await setState(.connecting)
        
        let tlsOptions = createTLSOptions()
        var parameters = NWParameters(tls: tlsOptions)
        parameters.includePeerToPeer = config.includePeerToPeer
        
        let connection = NWConnection(to: peerEndpoint, using: parameters)
        controlConnection = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleConnectionState(state)
            }
        }
        
        connection.start(queue: queue)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task {
                let timeout = Task {
                    try await Task.sleep(nanoseconds: UInt64(config.connectionTimeout * 1_000_000_000))
                    continuation.resume(throwing: TransportError.timeout)
                }
                
                for await state in connectionStates() {
                    switch state {
                    case .connected:
                        timeout.cancel()
                        continuation.resume()
                        return
                    case .failed(let reason):
                        timeout.cancel()
                        continuation.resume(throwing: TransportError.connectionFailed(reason))
                        return
                    default:
                        break
                    }
                }
            }
        }
        
        startReceiving()
        startClockSync()
    }
    
    public func disconnect() async {
        controlConnection?.cancel()
        videoConnection?.cancel()
        listener?.cancel()
        
        controlConnection = nil
        videoConnection = nil
        listener = nil
        
        await setState(.disconnected)
    }
    
    public func send(_ message: ControlMessage) async throws {
        guard connectionState == .connected, let connection = controlConnection else {
            throw TransportError.notConnected
        }
        
        let data = try JSONEncoder().encode(message)
        let framed = MessageFramer.frame(data)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: framed, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: TransportError.sendFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    public func sendVideo(_ packet: Data) async throws {
        guard connectionState == .connected else {
            throw TransportError.notConnected
        }
        
        if videoConnection == nil {
            try await setupVideoConnection()
        }
        
        guard let connection = videoConnection else {
            throw TransportError.notConnected
        }
        
        let framed = MessageFramer.frame(packet)
        
        connection.send(content: framed, completion: .contentProcessed { _ in })
    }
    
    private func createTLSOptions() -> NWProtocolTLS.Options {
        let tlsOptions = NWProtocolTLS.Options()
        
        sec_protocol_options_set_min_tls_protocol_version(
            tlsOptions.securityProtocolOptions,
            .TLSv12
        )
        
        sec_protocol_options_add_pre_shared_key(
            tlsOptions.securityProtocolOptions,
            psk as NSData,
            "DuoCameraKit" as NSString
        )
        
        sec_protocol_options_append_tls_ciphersuite(
            tlsOptions.securityProtocolOptions,
            tls_ciphersuite_t.PSK_WITH_AES_256_GCM_SHA384
        )
        
        return tlsOptions
    }
    
    private func handleConnectionState(_ state: NWConnection.State) async {
        switch state {
        case .ready:
            reconnectAttempt = 0
            await setState(.connected)
        case .preparing:
            await setState(.connecting)
        case .waiting(let error):
            await handleWaitingState(error)
        case .failed(let error):
            await handleFailure(error)
        case .cancelled:
            await setState(.disconnected)
        default:
            break
        }
    }
    
    private func handleWaitingState(_ error: NWError) async {
        if case .posix(let code) = error, code == .ECONNREFUSED {
            await attemptReconnect()
        }
    }
    
    private func handleFailure(_ error: NWError) async {
        if reconnectAttempt < config.maxReconnectAttempts {
            await attemptReconnect()
        } else {
            await setState(.failed(error.localizedDescription))
        }
    }
    
    private func attemptReconnect() async {
        reconnectAttempt += 1
        let delay = config.reconnectBaseDelay * pow(2.0, Double(reconnectAttempt - 1))
        
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        do {
            try await connect()
        } catch {
            if reconnectAttempt >= config.maxReconnectAttempts {
                await setState(.failed("Max reconnection attempts reached"))
            }
        }
    }
    
    private func startReceiving() {
        guard let connection = controlConnection else { return }
        
        receiveNextMessage(on: connection)
    }
    
    private func receiveNextMessage(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    await self.setState(.failed(error.localizedDescription))
                    return
                }
                
                if let data = data {
                    await self.processReceivedData(data)
                }
                
                if !isComplete {
                    await MainActor.run { [weak self] in
                        self?.receiveNextMessage(on: connection)
                    }
                }
            }
        }
    }
    
    private func processReceivedData(_ data: Data) async {
        messageBuffer.append(data)
        
        while messageBuffer.count >= 4 {
            guard let length = MessageFramer.extractLength(from: messageBuffer) else { break }
            let totalLength = Int(length) + 4
            
            guard messageBuffer.count >= totalLength else { break }
            
            let payloadData = messageBuffer.subdata(in: 4..<totalLength)
            messageBuffer.removeFirst(totalLength)
            
            if let message = try? JSONDecoder().decode(ControlMessage.self, from: payloadData) {
                await handleMessage(message)
            }
        }
    }
    
    private func handleMessage(_ message: ControlMessage) async {
        switch message {
        case .ping(let t1):
            let t2 = UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
            try? await send(.pong(t1, t2))
            
        case .pong(let t1, let t2):
            let t3 = UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
            clockSync.addSample(t1: t1, t2: t2, t3: t3)
            clockOffset = clockSync.estimatedOffset
            rttMs = clockSync.averageRTT
            
        default:
            messageContinuation?.yield(message)
        }
    }
    
    private func setupVideoConnection() async throws {
        let tlsOptions = createTLSOptions()
        var parameters = NWParameters(tls: tlsOptions)
        parameters.includePeerToPeer = config.includePeerToPeer
        
        let connection = NWConnection(to: peerEndpoint, using: parameters)
        videoConnection = connection
        
        connection.stateUpdateHandler = { _ in }
        connection.start(queue: queue)
    }
    
    private func startClockSync() {
        Task {
            while connectionState == .connected {
                let t1 = UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
                try? await send(.ping(t1))
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
    
    private func setState(_ newState: ConnectionState) async {
        connectionState = newState
        stateContinuation?.yield(newState)
    }
}
#endif
