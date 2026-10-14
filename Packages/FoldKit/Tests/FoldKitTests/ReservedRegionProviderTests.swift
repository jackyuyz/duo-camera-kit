import Testing
import Foundation
@testable import FoldKit

@Suite("ReservedRegion Tests")
struct ReservedRegionTests {
    
    @Test("ReservedRegion initialization")
    func reservedRegionInit() {
        let bounds = CGRect(x: 100, y: 0, width: 40, height: 600)
        let region = ReservedRegion(bounds: bounds, kind: .division)
        
        #expect(region.bounds == bounds)
        #expect(region.kind == .division)
        #expect(region.width == 40)
        #expect(region.height == 600)
    }
    
    @Test("ReservedRegion kind values")
    func reservedRegionKinds() {
        let division = ReservedRegion.Kind.division
        let occlusion = ReservedRegion.Kind.occlusion
        
        #expect(division.rawValue == "division")
        #expect(occlusion.rawValue == "occlusion")
    }
}

@Suite("MockReservedRegionProvider Tests")
struct MockReservedRegionProviderTests {
    
    @MainActor
    @Test("Default initialization")
    func defaultInit() async {
        let provider = MockReservedRegionProvider()
        
        #expect(provider.posture == .fullyOpen)
        #expect(provider.mockDivisionWidth == 40.0)
        #expect(provider.mockDivisionSafeMargin == 16.0)
    }
    
    @MainActor
    @Test("No division region when fully open")
    func noDivisionWhenFullyOpen() async {
        let provider = MockReservedRegionProvider(posture: .fullyOpen)
        
        let regions = provider.regions(of: .division)
        #expect(regions.isEmpty)
        #expect(provider.divisionWidth == 0)
    }
    
    @MainActor
    @Test("No division region when closed")
    func noDivisionWhenClosed() async {
        let provider = MockReservedRegionProvider(posture: .closed)
        
        let regions = provider.regions(of: .division)
        #expect(regions.isEmpty)
        #expect(provider.divisionWidth == 0)
    }
    
    @MainActor
    @Test("Division region present when partially open")
    func divisionWhenPartiallyOpen() async {
        let provider = MockReservedRegionProvider(
            posture: .partiallyOpen,
            mockDivisionWidth: 40.0,
            screenSize: CGSize(width: 890, height: 626)
        )
        
        let regions = provider.regions(of: .division)
        #expect(regions.count == 1)
        
        let region = regions[0]
        #expect(region.kind == .division)
        #expect(region.width == 40.0)
        #expect(region.height == 626)
        #expect(provider.divisionWidth == 40.0)
    }
    
    @MainActor
    @Test("Division region centered on screen")
    func divisionCentered() async {
        let screenWidth: CGFloat = 890
        let divisionWidth: CGFloat = 40
        let provider = MockReservedRegionProvider(
            posture: .partiallyOpen,
            mockDivisionWidth: divisionWidth,
            screenSize: CGSize(width: screenWidth, height: 626)
        )
        
        let regions = provider.regions(of: .division)
        let region = regions[0]
        
        let expectedX = (screenWidth - divisionWidth) / 2
        #expect(region.bounds.minX == expectedX)
    }
    
    @MainActor
    @Test("Occlusion regions returned")
    func occlusionRegions() async {
        let occlusion = ReservedRegion(
            bounds: CGRect(x: 0, y: 0, width: 100, height: 32),
            kind: .occlusion
        )
        let provider = MockReservedRegionProvider(
            mockOcclusionRegions: [occlusion]
        )
        
        let regions = provider.regions(of: .occlusion)
        #expect(regions.count == 1)
        #expect(regions[0].kind == .occlusion)
    }
    
    @MainActor
    @Test("Set posture updates division availability")
    func setPosture() async {
        let provider = MockReservedRegionProvider(posture: .fullyOpen)
        
        #expect(provider.divisionWidth == 0)
        
        provider.setPosture(.partiallyOpen)
        #expect(provider.divisionWidth == 40.0)
        
        provider.setPosture(.closed)
        #expect(provider.divisionWidth == 0)
    }
    
    @MainActor
    @Test("Safe margin always available")
    func safeMargin() async {
        let provider = MockReservedRegionProvider(mockDivisionSafeMargin: 16.0)
        
        #expect(provider.divisionSafeMargin == 16.0)
    }
    
    @MainActor
    @Test("No division for noHinge posture")
    func noDivisionForNoHinge() async {
        let provider = MockReservedRegionProvider(posture: .noHinge)
        
        #expect(provider.divisionWidth == 0)
        #expect(provider.regions(of: .division).isEmpty)
    }
}

@Suite("ReservedRegionDefaults Tests")
struct ReservedRegionDefaultsTests {
    
    @Test("Default values")
    func defaultValues() {
        #expect(ReservedRegionDefaults.mockDivisionWidth == 40.0)
        #expect(ReservedRegionDefaults.divisionSafeMargin == 16.0)
        #expect(ReservedRegionDefaults.innerCameraHeight == 32.0)
    }
}
