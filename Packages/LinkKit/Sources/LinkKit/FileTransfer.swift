import Foundation

/// File transfer progress
public struct TransferProgress: Sendable, Equatable {
    public let fileId: UUID
    public let fileName: String
    public let totalBytes: Int64
    public let transferredBytes: Int64
    public let state: TransferState
    
    public var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(transferredBytes) / Double(totalBytes)
    }
    
    public var isComplete: Bool {
        state == .completed
    }
    
    public init(
        fileId: UUID,
        fileName: String,
        totalBytes: Int64,
        transferredBytes: Int64,
        state: TransferState
    ) {
        self.fileId = fileId
        self.fileName = fileName
        self.totalBytes = totalBytes
        self.transferredBytes = transferredBytes
        self.state = state
    }
}

/// Transfer state
public enum TransferState: String, Codable, Sendable {
    case pending
    case transferring
    case paused
    case completed
    case failed
    case cancelled
}

/// Transfer request message
public struct TransferRequest: Codable, Sendable {
    public let fileId: UUID
    public let fileName: String
    public let totalBytes: Int64
    public let resumeOffset: Int64
    public let checksum: String?
    
    public init(
        fileId: UUID,
        fileName: String,
        totalBytes: Int64,
        resumeOffset: Int64 = 0,
        checksum: String? = nil
    ) {
        self.fileId = fileId
        self.fileName = fileName
        self.totalBytes = totalBytes
        self.resumeOffset = resumeOffset
        self.checksum = checksum
    }
}

/// Transfer chunk message
public struct TransferChunk: Codable, Sendable {
    public let fileId: UUID
    public let offset: Int64
    public let data: Data
    public let isLast: Bool
    
    public init(fileId: UUID, offset: Int64, data: Data, isLast: Bool) {
        self.fileId = fileId
        self.offset = offset
        self.data = data
        self.isLast = isLast
    }
}

/// File transfer manager
public actor FileTransferManager {
    
    /// Default chunk size (64KB)
    public static let defaultChunkSize: Int = 64 * 1024
    
    private var activeTransfers: [UUID: TransferProgress] = [:]
    private var progressContinuations: [UUID: AsyncStream<TransferProgress>.Continuation] = [:]
    
    /// Transport for sending/receiving
    private weak var transport: (any Transport)?
    
    public init() {}
    
    /// Set the transport to use for transfers
    public func setTransport(_ transport: any Transport) {
        self.transport = transport
    }
    
    /// Start sending a file
    public func sendFile(
        at url: URL,
        fileId: UUID = UUID(),
        chunkSize: Int = defaultChunkSize
    ) async throws -> UUID {
        guard let transport = transport else {
            throw TransportError.notConnected
        }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let fileName = url.lastPathComponent
        
        let progress = TransferProgress(
            fileId: fileId,
            fileName: fileName,
            totalBytes: fileSize,
            transferredBytes: 0,
            state: .pending
        )
        activeTransfers[fileId] = progress
        
        let request = TransferRequest(
            fileId: fileId,
            fileName: fileName,
            totalBytes: fileSize,
            resumeOffset: 0,
            checksum: nil
        )
        
        try await transport.send(.transferRequest(request))
        
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        var offset: Int64 = 0
        var transferredBytes: Int64 = 0
        
        while offset < fileSize {
            let data = handle.readData(ofLength: chunkSize)
            guard !data.isEmpty else { break }
            
            let isLast = offset + Int64(data.count) >= fileSize
            let chunk = TransferChunk(
                fileId: fileId,
                offset: offset,
                data: data,
                isLast: isLast
            )
            
            try await transport.send(.transferChunk(chunk))
            
            offset += Int64(data.count)
            transferredBytes = offset
            
            let newProgress = TransferProgress(
                fileId: fileId,
                fileName: fileName,
                totalBytes: fileSize,
                transferredBytes: transferredBytes,
                state: isLast ? .completed : .transferring
            )
            await updateProgress(newProgress)
        }
        
        return fileId
    }
    
    /// Receive file data
    public func receiveChunk(_ chunk: TransferChunk, to directory: URL) async throws {
        let fileName = activeTransfers[chunk.fileId]?.fileName ?? "received_\(chunk.fileId.uuidString)"
        let fileURL = directory.appendingPathComponent(fileName)
        
        if chunk.offset == 0 {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        
        try handle.seek(toOffset: UInt64(chunk.offset))
        handle.write(chunk.data)
        
        if var progress = activeTransfers[chunk.fileId] {
            let newProgress = TransferProgress(
                fileId: progress.fileId,
                fileName: progress.fileName,
                totalBytes: progress.totalBytes,
                transferredBytes: chunk.offset + Int64(chunk.data.count),
                state: chunk.isLast ? .completed : .transferring
            )
            await updateProgress(newProgress)
        }
    }
    
    /// Handle incoming transfer request
    public func handleTransferRequest(_ request: TransferRequest) async {
        let progress = TransferProgress(
            fileId: request.fileId,
            fileName: request.fileName,
            totalBytes: request.totalBytes,
            transferredBytes: request.resumeOffset,
            state: .pending
        )
        activeTransfers[request.fileId] = progress
        await updateProgress(progress)
    }
    
    /// Get progress stream for a transfer
    public func progressStream(for fileId: UUID) -> AsyncStream<TransferProgress> {
        AsyncStream { continuation in
            if let current = activeTransfers[fileId] {
                continuation.yield(current)
            }
            progressContinuations[fileId] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeProgressContinuation(for: fileId)
                }
            }
        }
    }
    
    /// Cancel a transfer
    public func cancelTransfer(_ fileId: UUID) async {
        if var progress = activeTransfers[fileId] {
            let cancelled = TransferProgress(
                fileId: progress.fileId,
                fileName: progress.fileName,
                totalBytes: progress.totalBytes,
                transferredBytes: progress.transferredBytes,
                state: .cancelled
            )
            await updateProgress(cancelled)
            activeTransfers.removeValue(forKey: fileId)
        }
    }
    
    /// Get current progress for a transfer
    public func getProgress(for fileId: UUID) -> TransferProgress? {
        activeTransfers[fileId]
    }
    
    /// Get all active transfers
    public func getAllTransfers() -> [TransferProgress] {
        Array(activeTransfers.values)
    }
    
    private func updateProgress(_ progress: TransferProgress) async {
        activeTransfers[progress.fileId] = progress
        progressContinuations[progress.fileId]?.yield(progress)
    }
    
    private func removeProgressContinuation(for fileId: UUID) {
        progressContinuations.removeValue(forKey: fileId)
    }
}

/// Extension to ControlMessage for transfer messages
extension ControlMessage {
    public static func transferRequest(_ request: TransferRequest) -> ControlMessage {
        .fileTransferRequest(request)
    }
    
    public static func transferChunk(_ chunk: TransferChunk) -> ControlMessage {
        .fileTransferChunk(chunk)
    }
}
