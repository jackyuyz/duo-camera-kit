import Testing
import Foundation
@testable import Library
@testable import LinkKit

@Suite("MockCaptureLibrary Tests")
struct MockCaptureLibraryTests {
    
    @Test("Add and retrieve capture")
    func testAddAndRetrieve() async throws {
        let library = MockCaptureLibrary()
        let item = CaptureItem(
            kind: .photo,
            source: .lens,
            fileName: "test.heic",
            fileSize: 1000
        )
        
        try await library.addCapture(item)
        let retrieved = await library.capture(id: item.id)
        
        #expect(retrieved?.id == item.id)
        #expect(retrieved?.fileName == "test.heic")
    }
    
    @Test("All captures sorted by date")
    func testAllCapturesSorted() async throws {
        let library = MockCaptureLibrary()
        
        let older = CaptureItem(
            kind: .photo,
            source: .lens,
            fileName: "older.heic",
            createdAt: Date().addingTimeInterval(-100)
        )
        let newer = CaptureItem(
            kind: .photo,
            source: .lens,
            fileName: "newer.heic",
            createdAt: Date()
        )
        
        try await library.addCapture(older)
        try await library.addCapture(newer)
        
        let all = await library.allCaptures()
        
        #expect(all.count == 2)
        #expect(all[0].fileName == "newer.heic")
    }
    
    @Test("Update capture")
    func testUpdateCapture() async throws {
        let library = MockCaptureLibrary()
        var item = CaptureItem(
            kind: .photo,
            source: .lens,
            fileName: "test.heic",
            transferred: false
        )
        
        try await library.addCapture(item)
        
        item.transferred = true
        try await library.updateCapture(item)
        
        let retrieved = await library.capture(id: item.id)
        #expect(retrieved?.transferred == true)
    }
    
    @Test("Delete capture")
    func testDeleteCapture() async throws {
        let library = MockCaptureLibrary()
        let item = CaptureItem(
            kind: .photo,
            source: .lens,
            fileName: "test.heic"
        )
        
        try await library.addCapture(item)
        try await library.deleteCapture(id: item.id)
        
        let retrieved = await library.capture(id: item.id)
        #expect(retrieved == nil)
    }
    
    @Test("Delete non-existent throws")
    func testDeleteNonExistent() async {
        let library = MockCaptureLibrary()
        
        do {
            try await library.deleteCapture(id: UUID())
            Issue.record("Should have thrown")
        } catch LibraryError.notFound {
            // Expected
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }
    
    @Test("Filter by kind")
    func testFilterByKind() async throws {
        let library = MockCaptureLibrary()
        
        try await library.addCapture(CaptureItem(kind: .photo, source: .lens, fileName: "photo.heic"))
        try await library.addCapture(CaptureItem(kind: .video, source: .lens, fileName: "video.mov"))
        try await library.addCapture(CaptureItem(kind: .photo, source: .lens, fileName: "photo2.heic"))
        
        let photos = await library.captures(kind: .photo)
        let videos = await library.captures(kind: .video)
        
        #expect(photos.count == 2)
        #expect(videos.count == 1)
    }
    
    @Test("Untransferred captures")
    func testUntransferredCaptures() async throws {
        let library = MockCaptureLibrary()
        
        try await library.addCapture(CaptureItem(kind: .photo, source: .lens, fileName: "a.heic", transferred: false))
        try await library.addCapture(CaptureItem(kind: .photo, source: .lens, fileName: "b.heic", transferred: true))
        try await library.addCapture(CaptureItem(kind: .photo, source: .lens, fileName: "c.heic", transferred: false))
        
        let untransferred = await library.untransferredCaptures()
        
        #expect(untransferred.count == 2)
    }
}
