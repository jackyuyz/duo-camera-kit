import Testing
import Foundation
@testable import LinkKit

@Suite("CaptureItem Tests")
struct CaptureItemTests {
    
    @Test("CaptureItem initialization")
    func testInit() {
        let item = CaptureItem(
            kind: .photo,
            source: .lens,
            fileName: "IMG_001.heic",
            fileSize: 5_000_000
        )
        
        #expect(item.kind == .photo)
        #expect(item.source == .lens)
        #expect(item.fileName == "IMG_001.heic")
        #expect(item.fileSize == 5_000_000)
        #expect(item.transferred == false)
    }
    
    @Test("CaptureItem file size formatting")
    func testFileSizeFormatted() {
        let smallItem = CaptureItem(
            kind: .photo,
            source: .lens,
            fileName: "small.jpg",
            fileSize: 500_000
        )
        let largeItem = CaptureItem(
            kind: .video,
            source: .lens,
            fileName: "large.mov",
            fileSize: 2_000_000_000
        )
        
        #expect(smallItem.fileSizeFormatted.contains("KB") || smallItem.fileSizeFormatted.contains("500"))
        #expect(largeItem.fileSizeFormatted.contains("GB") || largeItem.fileSizeFormatted.contains("2"))
    }
    
    @Test("CaptureItem duration formatting")
    func testDurationFormatted() {
        let shortVideo = CaptureItem(
            kind: .video,
            source: .lens,
            fileName: "short.mov",
            duration: 45
        )
        let longVideo = CaptureItem(
            kind: .video,
            source: .lens,
            fileName: "long.mov",
            duration: 125
        )
        let photo = CaptureItem(
            kind: .photo,
            source: .lens,
            fileName: "photo.heic"
        )
        
        #expect(shortVideo.durationFormatted == "0:45")
        #expect(longVideo.durationFormatted == "2:05")
        #expect(photo.durationFormatted == nil)
    }
    
    @Test("CaptureItem is Codable")
    func testCodable() throws {
        let original = CaptureItem(
            kind: .timelapse,
            source: .control,
            fileName: "timelapse.mov",
            fileSize: 100_000_000,
            duration: 300
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(CaptureItem.self, from: data)
        
        #expect(decoded == original)
    }
    
    @Test("CaptureItem with related capture")
    func testRelatedCapture() {
        let controlId = UUID()
        let lensId = UUID()
        
        let controlCapture = CaptureItem(
            id: controlId,
            kind: .video,
            source: .control,
            fileName: "control.mov",
            relatedCaptureId: lensId
        )
        let lensCapture = CaptureItem(
            id: lensId,
            kind: .video,
            source: .lens,
            fileName: "lens.mov",
            relatedCaptureId: controlId
        )
        
        #expect(controlCapture.relatedCaptureId == lensId)
        #expect(lensCapture.relatedCaptureId == controlId)
    }
}

@Suite("CaptureKind Tests")
struct CaptureKindTests {
    
    @Test("CaptureKind values")
    func testValues() {
        #expect(CaptureKind.photo.rawValue == "photo")
        #expect(CaptureKind.video.rawValue == "video")
        #expect(CaptureKind.timelapse.rawValue == "timelapse")
        #expect(CaptureKind.longExposure.rawValue == "longExposure")
        #expect(CaptureKind.starTrails.rawValue == "starTrails")
    }
}

@Suite("SyncRecordingSidecar Tests")
struct SyncRecordingSidecarTests {
    
    @Test("SyncRecordingSidecar initialization")
    func testInit() {
        let controlId = UUID()
        let lensId = UUID()
        
        let sidecar = SyncRecordingSidecar(
            controlCaptureId: controlId,
            lensCaptureId: lensId,
            scheduledStartNs: 1_000_000_000,
            clockOffsetNs: 5_000_000
        )
        
        #expect(sidecar.controlCaptureId == controlId)
        #expect(sidecar.lensCaptureId == lensId)
        #expect(sidecar.scheduledStartNs == 1_000_000_000)
        #expect(sidecar.clockOffsetNs == 5_000_000)
        #expect(sidecar.syncClapUsed == true)
    }
    
    @Test("SyncRecordingSidecar offset calculation")
    func testOffsetCalculation() {
        var sidecar = SyncRecordingSidecar(
            controlCaptureId: UUID(),
            lensCaptureId: UUID(),
            scheduledStartNs: 1_000_000_000,
            clockOffsetNs: 5_000_000
        )
        
        #expect(sidecar.estimatedOffsetMs == nil)
        
        sidecar.controlActualStartNs = 1_000_010_000_000
        sidecar.lensActualStartNs = 1_000_000_000_000
        
        #expect(sidecar.estimatedOffsetMs != nil)
    }
    
    @Test("SyncRecordingSidecar is Codable")
    func testCodable() throws {
        var sidecar = SyncRecordingSidecar(
            controlCaptureId: UUID(),
            lensCaptureId: UUID(),
            scheduledStartNs: 1_000_000_000,
            clockOffsetNs: 5_000_000,
            syncClapUsed: false
        )
        sidecar.controlActualStartNs = 1_000_010_000
        sidecar.lensActualStartNs = 1_000_005_000
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(sidecar)
        let decoded = try decoder.decode(SyncRecordingSidecar.self, from: data)
        
        #expect(decoded.controlCaptureId == sidecar.controlCaptureId)
        #expect(decoded.syncClapUsed == false)
    }
}
