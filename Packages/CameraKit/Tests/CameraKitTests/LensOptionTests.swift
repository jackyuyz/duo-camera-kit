import Testing
import Foundation
@testable import CameraKit

@Suite("LensOption Tests")
struct LensOptionTests {
    
    @Test("LensOption initialization")
    func testLensOptionInit() {
        let lens = LensOption(
            id: "test-lens",
            kind: .telephoto,
            zoomFactors: [3.0, 5.0],
            displayName: "Telephoto"
        )
        
        #expect(lens.id == "test-lens")
        #expect(lens.kind == .telephoto)
        #expect(lens.zoomFactors == [3.0, 5.0])
        #expect(lens.displayName == "Telephoto")
    }
    
    @Test("LensOption shortLabel for different kinds")
    func testShortLabel() {
        let ultraWide = LensOption(id: "uw", kind: .ultraWide, zoomFactors: [0.5], displayName: "Ultra Wide")
        let wide = LensOption(id: "w", kind: .wide, zoomFactors: [1.0], displayName: "Wide")
        let tele = LensOption(id: "t", kind: .telephoto, zoomFactors: [3.0, 5.0], displayName: "Tele")
        
        #expect(ultraWide.shortLabel == "0.5×")
        #expect(wide.shortLabel == "1×")
        #expect(tele.shortLabel == "5×")
    }
    
    @Test("LensKind allCases")
    func testLensKindAllCases() {
        let allCases = LensKind.allCases
        
        #expect(allCases.count == 3)
        #expect(allCases.contains(.ultraWide))
        #expect(allCases.contains(.wide))
        #expect(allCases.contains(.telephoto))
    }
    
    @Test("LensOption is Codable")
    func testLensOptionCodable() throws {
        let original = LensOption(
            id: "test",
            kind: .wide,
            zoomFactors: [1.0, 2.0],
            displayName: "Test"
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(LensOption.self, from: data)
        
        #expect(decoded == original)
    }
    
    @Test("LensCapabilities mockIPhonePro")
    func testMockIPhonePro() {
        let caps = LensCapabilities.mockIPhonePro
        
        #expect(caps.lenses.count == 3)
        #expect(caps.proRAW == true)
        #expect(caps.proRes == true)
        #expect(caps.lenses.contains { $0.kind == .telephoto })
    }
    
    @Test("LensCapabilities mockIPhoneDuo")
    func testMockIPhoneDuo() {
        let caps = LensCapabilities.mockIPhoneDuo
        
        #expect(caps.lenses.count == 2)
        #expect(caps.proRAW == false)
        #expect(caps.proRes == false)
        #expect(!caps.lenses.contains { $0.kind == .telephoto })
    }
}

@Suite("VideoFormatOption Tests")
struct VideoFormatOptionTests {
    
    @Test("VideoFormatOption displayName")
    func testDisplayName() {
        #expect(VideoFormatOption.h264_1080p30.displayName == "H.264 1080p30")
        #expect(VideoFormatOption.hevc4K60.displayName == "HEVC 4K60")
        #expect(VideoFormatOption.proRes422.displayName == "ProRes 422")
    }
    
    @Test("VideoFormatOption isProRes")
    func testIsProRes() {
        #expect(VideoFormatOption.proRes422.isProRes == true)
        #expect(VideoFormatOption.proRes422HQ.isProRes == true)
        #expect(VideoFormatOption.hevc4K60.isProRes == false)
        #expect(VideoFormatOption.h264_1080p30.isProRes == false)
    }
}

@Suite("WBPreset Tests")
struct WBPresetTests {
    
    @Test("WBPreset allCases")
    func testAllCases() {
        let allCases = WBPreset.allCases
        
        #expect(allCases.count == 8)
    }
    
    @Test("WBPreset temperatureKelvin")
    func testTemperatureKelvin() {
        #expect(WBPreset.tungsten.temperatureKelvin == 3200)
        #expect(WBPreset.sunny.temperatureKelvin == 5500)
        #expect(WBPreset.shade.temperatureKelvin == 7500)
    }
}
