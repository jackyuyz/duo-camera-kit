import Testing
import Foundation
@testable import CameraKit

@Suite("ProCapturePolicy Tests")
struct ProCapturePolicyTests {
    
    @Test("Free blocks ProRAW")
    func freeBlocksProRAW() {
        let gated = ProCapturePolicy.free.gatedPhotoSettings(PhotoSettings(format: .proRAW))
        #expect(gated.format == .heif)
    }
    
    @Test("Pro keeps ProRAW")
    func proKeepsProRAW() {
        let gated = ProCapturePolicy.pro.gatedPhotoSettings(PhotoSettings(format: .proRAW))
        #expect(gated.format == .proRAW)
    }
    
    @Test("Free blocks ProRes and 4K")
    func freeBlocksVideo() {
        let proRes = ProCapturePolicy.free.gatedVideoSettings(VideoSettings(format: .proRes422))
        #expect(proRes.format == .hevc1080p30)
        
        let fourK = ProCapturePolicy.free.gatedVideoSettings(VideoSettings(format: .hevc4K60))
        #expect(fourK.format == .hevc1080p30)
        #expect(!fourK.format.is4K)
        #expect(!fourK.format.isProRes)
    }
    
    @Test("Free caps full-resolution photos at 12 MP")
    func capsResolution() {
        let capped = ProCapturePolicy.free.photoPixelSize(width: 8064, height: 6048)
        let mp = Double(capped.width * capped.height) / 1_000_000.0
        #expect(mp <= Double(ProCapturePolicy.freeMaxMegapixels) + 0.05)
    }
    
    @Test("Pro keeps full resolution")
    func proFullRes() {
        let size = ProCapturePolicy.pro.photoPixelSize(width: 8064, height: 6048)
        #expect(size.width == 8064)
    }
    
    @Test("Auto-transfer is Pro-only")
    func autoTransfer() {
        #expect(!ProCapturePolicy.free.allowsAutoTransfer)
        #expect(ProCapturePolicy.pro.allowsAutoTransfer)
    }
}

@Suite("Telephoto Detection Tests")
struct TelephotoDetectionTests {
    
    @Test("Pro has telephoto")
    func proHasTele() {
        #expect(LensCapabilities.mockIPhonePro.hasTelephoto)
        #expect(LensCapabilities.mockIPhonePro.telephotoLens != nil)
        #expect(LensCapabilities.mockIPhonePro.missingTelephotoMessage == nil)
        #expect(LensCapabilities.mockIPhonePro.supportedZoomRange.upperBound >= 3.0)
    }
    
    @Test("Non-Pro degrades without telephoto")
    func nonProDegrades() {
        let caps = LensCapabilities.mockIPhone
        #expect(!caps.hasTelephoto)
        #expect(caps.telephotoLens == nil)
        #expect(caps.missingTelephotoMessage != nil)
        #expect(caps.supportedZoomRange.upperBound <= 2.0)
        #expect(caps.defaultLensID == "mock-wide")
    }
    
    @Test("Duo has no telephoto")
    func duoNoTele() {
        #expect(!LensCapabilities.mockIPhoneDuo.hasTelephoto)
        #expect(LensCapabilities.mockIPhoneDuo.missingTelephotoMessage != nil)
    }
    
    @Test("Mock camera clamps zoom without telephoto")
    func mockClampsZoom() async throws {
        let source = MockCameraSource(capabilities: .mockIPhone)
        try await source.start()
        try await source.setZoom(10)
        #expect(source.state.zoomFactor <= LensCapabilities.mockIPhone.supportedZoomRange.upperBound)
        await source.stop()
    }
    
    @Test("VideoFormatOption is4K")
    func is4K() {
        #expect(VideoFormatOption.hevc4K30.is4K)
        #expect(VideoFormatOption.hevc4K60.is4K)
        #expect(!VideoFormatOption.hevc1080p30.is4K)
        #expect(VideoFormatOption.hevc4K60.exceedsFreeTier)
        #expect(!VideoFormatOption.hevc1080p30.exceedsFreeTier)
    }
}
