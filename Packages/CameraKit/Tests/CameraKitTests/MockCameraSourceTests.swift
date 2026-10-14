import Testing
import Foundation
@testable import CameraKit

@Suite("MockCameraSource Tests")
struct MockCameraSourceTests {
    
    @Test("MockCameraSource initialization with default capabilities")
    func testDefaultInit() {
        let source = MockCameraSource()
        
        #expect(source.capabilities.lenses.count == 3)
        #expect(source.currentLensID == source.capabilities.defaultLensID)
        #expect(source.isRecording == false)
    }
    
    @Test("MockCameraSource initialization with custom capabilities")
    func testCustomInit() {
        let source = MockCameraSource(capabilities: .mockIPhoneDuo)
        
        #expect(source.capabilities.lenses.count == 2)
        #expect(source.capabilities.proRAW == false)
    }
    
    @Test("selectLens succeeds for valid lens")
    func testSelectLensValid() async throws {
        let source = MockCameraSource()
        let lens = source.capabilities.lenses[0]
        
        try await source.selectLens(lens.id)
        #expect(source.currentLensID == lens.id)
    }
    
    @Test("selectLens throws for invalid lens")
    func testSelectLensInvalid() async {
        let source = MockCameraSource()
        
        do {
            try await source.selectLens("nonexistent-lens")
            Issue.record("Should have thrown")
        } catch CameraError.lensNotFound(let id) {
            #expect(id == "nonexistent-lens")
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    @Test("setZoom updates state")
    func testSetZoom() async throws {
        let source = MockCameraSource()
        
        try await source.setZoom(3.0)
        
        #expect(source.state.zoomFactor == 3.0)
    }
    
    @Test("setZoom clamps to valid range")
    func testSetZoomClamped() async throws {
        let source = MockCameraSource()
        
        try await source.setZoom(0.1)
        #expect(source.state.zoomFactor == 0.5)
        
        try await source.setZoom(100.0)
        #expect(source.state.zoomFactor == source.capabilities.supportedZoomRange.upperBound)
    }
    
    @Test("setFocusPoint updates state")
    func testSetFocusPoint() async throws {
        let source = MockCameraSource()
        let point = CGPoint(x: 0.3, y: 0.7)
        
        try await source.setFocusPoint(point)
        
        #expect(source.state.focusPoint == point)
    }
    
    @Test("setFocusPoint clamps to valid range")
    func testSetFocusPointClamped() async throws {
        let source = MockCameraSource()
        
        try await source.setFocusPoint(CGPoint(x: -0.5, y: 1.5))
        
        #expect(source.state.focusPoint?.x == 0)
        #expect(source.state.focusPoint?.y == 1)
    }
    
    @Test("setExposureBias updates state")
    func testSetExposureBias() async throws {
        let source = MockCameraSource()
        
        try await source.setExposureBias(1.5)
        
        #expect(source.state.exposureBias == 1.5)
    }
    
    @Test("setExposureBias clamps to valid range")
    func testSetExposureBiasClamped() async throws {
        let source = MockCameraSource()
        
        try await source.setExposureBias(-5.0)
        #expect(source.state.exposureBias == -3.0)
        
        try await source.setExposureBias(5.0)
        #expect(source.state.exposureBias == 3.0)
    }
    
    @Test("setWhiteBalance updates state")
    func testSetWhiteBalance() async throws {
        let source = MockCameraSource()
        
        try await source.setWhiteBalance(.tungsten)
        
        #expect(source.state.whiteBalance == .tungsten)
    }
    
    @Test("lockAEAF updates state")
    func testLockAEAF() async throws {
        let source = MockCameraSource()
        
        try await source.lockAEAF(true)
        
        #expect(source.state.aeLocked == true)
        #expect(source.state.afLocked == true)
        
        try await source.lockAEAF(false)
        
        #expect(source.state.aeLocked == false)
        #expect(source.state.afLocked == false)
    }
    
    @Test("capturePhoto requires session running")
    func testCapturePhotoRequiresSession() async {
        let source = MockCameraSource()
        
        do {
            _ = try await source.capturePhoto(settings: .default)
            Issue.record("Should have thrown")
        } catch CameraError.sessionNotRunning {
            // Expected
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }
    
    @Test("VideoFrame initialization")
    func testVideoFrame() {
        let data = Data(repeating: 0, count: 100)
        let frame = VideoFrame(
            data: data,
            width: 1280,
            height: 720,
            timestamp: 12345,
            orientation: 90
        )
        
        #expect(frame.width == 1280)
        #expect(frame.height == 720)
        #expect(frame.timestamp == 12345)
        #expect(frame.orientation == 90)
        #expect(frame.data.count == 100)
    }
    
    @Test("CapturedPhoto initialization")
    func testCapturedPhoto() {
        let data = Data(repeating: 0, count: 1000)
        let thumbnail = Data(repeating: 1, count: 100)
        let timestamp = Date()
        
        let photo = CapturedPhoto(
            data: data,
            format: .heif,
            width: 4032,
            height: 3024,
            timestamp: timestamp,
            thumbnail: thumbnail,
            metadata: ["key": "value"]
        )
        
        #expect(photo.data.count == 1000)
        #expect(photo.format == .heif)
        #expect(photo.width == 4032)
        #expect(photo.height == 3024)
        #expect(photo.timestamp == timestamp)
        #expect(photo.thumbnail?.count == 100)
        #expect(photo.metadata["key"] == "value")
    }
    
    @Test("RecordedVideo initialization")
    func testRecordedVideo() {
        let timestamp = Date()
        let thumbnail = Data(repeating: 0, count: 100)
        
        let video = RecordedVideo(
            filePath: "/path/to/video.mov",
            duration: 10.5,
            startTimestamp: timestamp,
            fileSize: 1_000_000,
            thumbnail: thumbnail
        )
        
        #expect(video.filePath == "/path/to/video.mov")
        #expect(video.duration == 10.5)
        #expect(video.startTimestamp == timestamp)
        #expect(video.fileSize == 1_000_000)
        #expect(video.thumbnail?.count == 100)
    }
    
    @Test("CameraState default values")
    func testCameraStateDefault() {
        let state = CameraState.default
        
        #expect(state.zoomFactor == 1.0)
        #expect(state.exposureBias == 0.0)
        #expect(state.whiteBalance == .auto)
        #expect(state.aeLocked == false)
        #expect(state.afLocked == false)
        #expect(state.focusPoint == nil)
    }
    
    @Test("PhotoSettings default values")
    func testPhotoSettingsDefault() {
        let settings = PhotoSettings.default
        
        #expect(settings.format == .heif)
        #expect(settings.flashEnabled == false)
        #expect(settings.hdrEnabled == true)
    }
    
    @Test("VideoSettings default values")
    func testVideoSettingsDefault() {
        let settings = VideoSettings.default
        
        #expect(settings.format == .hevc1080p30)
        #expect(settings.audioEnabled == true)
        #expect(settings.stabilizationEnabled == true)
    }
    
    @Test("CameraError equality")
    func testCameraErrorEquality() {
        let error1 = CameraError.notAuthorized
        let error2 = CameraError.notAuthorized
        let error3 = CameraError.deviceNotAvailable
        
        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}
