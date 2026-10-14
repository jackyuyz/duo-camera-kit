import Testing
import Foundation
@testable import LinkKit

@Suite("TransferProgress Tests")
struct TransferProgressTests {
    
    @Test("TransferProgress initialization")
    func transferProgressInit() {
        let progress = TransferProgress(
            fileId: UUID(),
            fileName: "test.jpg",
            totalBytes: 1000,
            transferredBytes: 500,
            state: .transferring
        )
        
        #expect(progress.fileName == "test.jpg")
        #expect(progress.totalBytes == 1000)
        #expect(progress.transferredBytes == 500)
        #expect(progress.state == .transferring)
        #expect(progress.progress == 0.5)
        #expect(!progress.isComplete)
    }
    
    @Test("TransferProgress completion")
    func transferProgressCompletion() {
        let progress = TransferProgress(
            fileId: UUID(),
            fileName: "test.jpg",
            totalBytes: 1000,
            transferredBytes: 1000,
            state: .completed
        )
        
        #expect(progress.progress == 1.0)
        #expect(progress.isComplete)
    }
    
    @Test("TransferProgress with zero bytes")
    func transferProgressZeroBytes() {
        let progress = TransferProgress(
            fileId: UUID(),
            fileName: "empty.txt",
            totalBytes: 0,
            transferredBytes: 0,
            state: .pending
        )
        
        #expect(progress.progress == 0)
    }
}

@Suite("TransferState Tests")
struct TransferStateTests {
    
    @Test("TransferState raw values")
    func transferStateRawValues() {
        #expect(TransferState.pending.rawValue == "pending")
        #expect(TransferState.transferring.rawValue == "transferring")
        #expect(TransferState.paused.rawValue == "paused")
        #expect(TransferState.completed.rawValue == "completed")
        #expect(TransferState.failed.rawValue == "failed")
        #expect(TransferState.cancelled.rawValue == "cancelled")
    }
}

@Suite("TransferRequest Tests")
struct TransferRequestTests {
    
    @Test("TransferRequest initialization")
    func transferRequestInit() {
        let fileId = UUID()
        let request = TransferRequest(
            fileId: fileId,
            fileName: "video.mov",
            totalBytes: 5_000_000,
            resumeOffset: 1_000_000,
            checksum: "abc123"
        )
        
        #expect(request.fileId == fileId)
        #expect(request.fileName == "video.mov")
        #expect(request.totalBytes == 5_000_000)
        #expect(request.resumeOffset == 1_000_000)
        #expect(request.checksum == "abc123")
    }
    
    @Test("TransferRequest default values")
    func transferRequestDefaults() {
        let request = TransferRequest(
            fileId: UUID(),
            fileName: "test.jpg",
            totalBytes: 1000
        )
        
        #expect(request.resumeOffset == 0)
        #expect(request.checksum == nil)
    }
    
    @Test("TransferRequest is Codable")
    func transferRequestCodable() throws {
        let request = TransferRequest(
            fileId: UUID(),
            fileName: "test.jpg",
            totalBytes: 1000,
            resumeOffset: 500,
            checksum: "hash"
        )
        
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(TransferRequest.self, from: data)
        
        #expect(decoded.fileId == request.fileId)
        #expect(decoded.fileName == request.fileName)
        #expect(decoded.totalBytes == request.totalBytes)
        #expect(decoded.resumeOffset == request.resumeOffset)
        #expect(decoded.checksum == request.checksum)
    }
}

@Suite("TransferChunk Tests")
struct TransferChunkTests {
    
    @Test("TransferChunk initialization")
    func transferChunkInit() {
        let fileId = UUID()
        let data = Data([0x01, 0x02, 0x03])
        let chunk = TransferChunk(
            fileId: fileId,
            offset: 1000,
            data: data,
            isLast: false
        )
        
        #expect(chunk.fileId == fileId)
        #expect(chunk.offset == 1000)
        #expect(chunk.data == data)
        #expect(!chunk.isLast)
    }
    
    @Test("TransferChunk is Codable")
    func transferChunkCodable() throws {
        let chunk = TransferChunk(
            fileId: UUID(),
            offset: 0,
            data: Data([0xFF, 0xFE]),
            isLast: true
        )
        
        let data = try JSONEncoder().encode(chunk)
        let decoded = try JSONDecoder().decode(TransferChunk.self, from: data)
        
        #expect(decoded.fileId == chunk.fileId)
        #expect(decoded.offset == chunk.offset)
        #expect(decoded.data == chunk.data)
        #expect(decoded.isLast == chunk.isLast)
    }
}

@Suite("MessageFramer Tests")
struct MessageFramerTests {
    
    @Test("Frame message adds length prefix")
    func frameMessage() {
        let payload = Data([0x01, 0x02, 0x03, 0x04])
        let framed = MessageFramer.frame(payload)
        
        #expect(framed.count == 8)
        
        let extractedLength = MessageFramer.extractLength(from: framed)
        #expect(extractedLength == 4)
    }
    
    @Test("Extract length from empty data")
    func extractLengthEmpty() {
        let length = MessageFramer.extractLength(from: Data())
        #expect(length == nil)
    }
    
    @Test("Extract length from short data")
    func extractLengthShort() {
        let length = MessageFramer.extractLength(from: Data([0x01, 0x02]))
        #expect(length == nil)
    }
    
    @Test("Frame empty payload")
    func frameEmpty() {
        let framed = MessageFramer.frame(Data())
        
        #expect(framed.count == 4)
        #expect(MessageFramer.extractLength(from: framed) == 0)
    }
}

@Suite("FileTransferManager Tests")
struct FileTransferManagerTests {
    
    @Test("Default chunk size")
    func defaultChunkSize() {
        #expect(FileTransferManager.defaultChunkSize == 64 * 1024)
    }
    
    @Test("Handle transfer request")
    func handleTransferRequest() async {
        let manager = FileTransferManager()
        let fileId = UUID()
        
        let request = TransferRequest(
            fileId: fileId,
            fileName: "test.jpg",
            totalBytes: 10000,
            resumeOffset: 0
        )
        
        await manager.handleTransferRequest(request)
        
        let progress = await manager.getProgress(for: fileId)
        #expect(progress != nil)
        #expect(progress?.fileName == "test.jpg")
        #expect(progress?.totalBytes == 10000)
        #expect(progress?.state == .pending)
    }
    
    @Test("Cancel transfer")
    func cancelTransfer() async {
        let manager = FileTransferManager()
        let fileId = UUID()
        
        let request = TransferRequest(
            fileId: fileId,
            fileName: "test.jpg",
            totalBytes: 10000
        )
        
        await manager.handleTransferRequest(request)
        await manager.cancelTransfer(fileId)
        
        let progress = await manager.getProgress(for: fileId)
        #expect(progress == nil)
    }
    
    @Test("Get all transfers")
    func getAllTransfers() async {
        let manager = FileTransferManager()
        
        await manager.handleTransferRequest(TransferRequest(
            fileId: UUID(),
            fileName: "file1.jpg",
            totalBytes: 1000
        ))
        
        await manager.handleTransferRequest(TransferRequest(
            fileId: UUID(),
            fileName: "file2.jpg",
            totalBytes: 2000
        ))
        
        let transfers = await manager.getAllTransfers()
        #expect(transfers.count == 2)
    }
}
