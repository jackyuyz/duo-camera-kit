import Testing
import Foundation
@testable import FoldKit

@Suite("SystemFoldStateProvider Tests")
struct SystemFoldStateProviderTests {
    
    @Test("Starts as noHinge")
    func startsNoHinge() {
        let provider = SystemFoldStateProvider()
        #expect(provider.state.posture == .noHinge)
        #expect(!provider.state.hasHinge)
    }
    
    @Test("ingestNoHinge stays noHinge")
    func ingestNoHinge() {
        let provider = SystemFoldStateProvider()
        provider.ingest(hingeAvailable: true, statusRaw: "fullyOpen", angleDegrees: 180)
        provider.ingestNoHinge()
        #expect(provider.state.posture == .noHinge)
        #expect(provider.state.angleDegrees == nil)
    }
    
    @Test("Nil hinge maps to noHinge")
    func nilHinge() {
        let provider = SystemFoldStateProvider()
        provider.ingest(hingeAvailable: false, statusRaw: "fullyOpen", angleDegrees: 180)
        #expect(provider.state.posture == .noHinge)
    }
    
    @Test("Maps system status strings")
    func mapsStatus() {
        let provider = SystemFoldStateProvider()
        provider.ingest(hingeAvailable: true, statusRaw: "closed", angleDegrees: 0)
        #expect(provider.state.posture == .closed)
        
        provider.ingest(hingeAvailable: true, statusRaw: "partiallyOpen", angleDegrees: 110)
        #expect(provider.state.posture == .partiallyOpen)
        #expect(provider.state.angleDegrees == 110)
        
        provider.ingest(hingeAvailable: true, statusRaw: "fullyOpen", angleDegrees: 180)
        #expect(provider.state.posture == .fullyOpen)
        
        provider.ingest(hingeAvailable: true, statusRaw: "somethingElse", angleDegrees: 90)
        #expect(provider.state.posture == .unknown)
    }
    
    @Test("FoldPosture.fromSystemHingeStatus")
    func postureMapping() {
        #expect(FoldPosture.fromSystemHingeStatus("closed") == .closed)
        #expect(FoldPosture.fromSystemHingeStatus("partiallyOpen") == .partiallyOpen)
        #expect(FoldPosture.fromSystemHingeStatus("fullyOpen") == .fullyOpen)
        #expect(FoldPosture.fromSystemHingeStatus("unknown") == .unknown)
        #expect(FoldPosture.fromSystemHingeStatus("??") == .unknown)
    }
}

@Suite("DuoAPIAvailability Tests")
struct DuoAPIAvailabilityTests {
    
    @Test("Version constants")
    func versions() {
        #expect(DuoAPIAvailability.minimumOS == "26.0")
        #expect(DuoAPIAvailability.duoAPIs == "27.1")
    }
    
    @Test("Hinge APIs unavailable on Linux")
    func hingeUnavailableOnLinux() {
        #if os(Linux)
        #expect(DuoAPIAvailability.hingeAPIsAvailable == false)
        #endif
    }
}
