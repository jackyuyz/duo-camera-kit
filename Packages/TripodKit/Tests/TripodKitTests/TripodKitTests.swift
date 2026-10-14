import Testing
import Foundation
@testable import TripodKit
@testable import FoldKit

@Suite("TripodMode Tests")
struct TripodModeTests {
    
    @Test("TripodMode allCases")
    func testAllCases() {
        #expect(TripodMode.allCases.count == 6)
    }
    
    @Test("TripodMode display names")
    func testDisplayNames() {
        #expect(TripodMode.timelapse.displayName == "Time-lapse")
        #expect(TripodMode.longExposure.displayName == "Long Exposure")
        #expect(TripodMode.starTrails.displayName == "Star Trails")
    }
    
    @Test("TripodMode pro requirements")
    func testProRequirements() {
        #expect(TripodMode.timelapse.requiresPro == false)
        #expect(TripodMode.longExposure.requiresPro == true)
        #expect(TripodMode.starTrails.requiresPro == true)
        #expect(TripodMode.palmTrigger.requiresPro == true)
        #expect(TripodMode.lapCam.requiresPro == false)
        #expect(TripodMode.topDown.requiresPro == false)
    }
    
    @Test("TripodMode hinge requirements")
    func testHingeRequirements() {
        #expect(TripodMode.timelapse.requiresHinge == false)
        #expect(TripodMode.lapCam.requiresHinge == true)
        #expect(TripodMode.topDown.requiresHinge == true)
    }
}

@Suite("StandAssistant Tests")
struct StandAssistantTests {
    
    @Test("StandAssistant initial state")
    func testInitialState() {
        let assistant = StandAssistant()
        
        #expect(assistant.currentAngle == nil)
        #expect(assistant.lock == nil)
        #expect(assistant.isStable == true)
        #expect(assistant.hasHinge == false)
    }
    
    @Test("StandAssistant update with fold state")
    func testUpdateWithFoldState() {
        var assistant = StandAssistant()
        let state = FoldState(posture: .partiallyOpen, angleDegrees: 110)
        
        assistant.update(foldState: state)
        
        #expect(assistant.currentAngle == 110)
        #expect(assistant.hasHinge == true)
    }
    
    @Test("StandAssistant lock stand")
    func testLockStand() {
        var assistant = StandAssistant()
        let state = FoldState(posture: .partiallyOpen, angleDegrees: 110)
        assistant.update(foldState: state)
        
        assistant.lockStand()
        
        #expect(assistant.lock != nil)
        #expect(assistant.lock?.anchorAngle == 110)
        #expect(assistant.isStable == true)
    }
    
    @Test("StandAssistant detect angle change")
    func testDetectAngleChange() {
        var assistant = StandAssistant()
        assistant.update(foldState: FoldState(posture: .partiallyOpen, angleDegrees: 110))
        assistant.lockStand(toleranceDegrees: 1.5)
        
        assistant.update(foldState: FoldState(posture: .partiallyOpen, angleDegrees: 113))
        
        #expect(assistant.isStable == false)
        if case .angleChanged(let delta) = assistant.instabilityReason {
            #expect(delta == 3.0)
        } else {
            Issue.record("Wrong instability reason")
        }
    }
    
    @Test("StandAssistant stable within tolerance")
    func testStableWithinTolerance() {
        var assistant = StandAssistant()
        assistant.update(foldState: FoldState(posture: .partiallyOpen, angleDegrees: 110))
        assistant.lockStand(toleranceDegrees: 2.0)
        
        assistant.update(foldState: FoldState(posture: .partiallyOpen, angleDegrees: 111))
        
        #expect(assistant.isStable == true)
        #expect(assistant.instabilityReason == nil)
    }
    
    @Test("StandAssistant unlock stand")
    func testUnlockStand() {
        var assistant = StandAssistant()
        assistant.update(foldState: FoldState(posture: .partiallyOpen, angleDegrees: 110))
        assistant.lockStand()
        
        assistant.unlockStand()
        
        #expect(assistant.lock == nil)
        #expect(assistant.isStable == true)
    }
    
    @Test("StandAssistant relock stand")
    func testRelockStand() {
        var assistant = StandAssistant()
        assistant.update(foldState: FoldState(posture: .partiallyOpen, angleDegrees: 110))
        assistant.lockStand()
        
        assistant.update(foldState: FoldState(posture: .partiallyOpen, angleDegrees: 115))
        #expect(assistant.isStable == false)
        
        assistant.relockStand()
        
        #expect(assistant.lock?.anchorAngle == 115)
        #expect(assistant.isStable == true)
    }
    
    @Test("StandAssistant motion detection")
    func testMotionDetection() {
        var assistant = StandAssistant()
        assistant.update(foldState: FoldState(posture: .partiallyOpen, angleDegrees: 110))
        assistant.lockStand()
        
        assistant.update(
            gravity: SIMD3(0, -1, 0),
            userAcceleration: SIMD3(0.2, 0.2, 0)
        )
        
        #expect(assistant.isStable == false)
        #expect(assistant.instabilityReason == .deviceMoved)
    }
}

@Suite("TimelapseConfig Tests")
struct TimelapseConfigTests {
    
    @Test("TimelapseConfig default values")
    func testDefaults() {
        let config = TimelapseConfig()
        
        #expect(config.intervalSeconds == 1.0)
        #expect(config.durationSeconds == nil)
        #expect(config.lockSettings == true)
        #expect(config.outputFPS == 30)
    }
    
    @Test("TimelapseConfig total frames calculation")
    func testTotalFrames() {
        let bounded = TimelapseConfig(intervalSeconds: 2.0, durationSeconds: 60)
        let unbounded = TimelapseConfig(intervalSeconds: 1.0, durationSeconds: nil)
        
        #expect(bounded.totalFrames == 30)
        #expect(unbounded.totalFrames == nil)
    }
    
    @Test("TimelapseConfig output duration")
    func testOutputDuration() {
        let config = TimelapseConfig(intervalSeconds: 1.0, durationSeconds: 300, outputFPS: 30)
        
        #expect(config.outputDuration == 10.0)
    }
}

@Suite("TimelapseState Tests")
struct TimelapseStateTests {
    
    @Test("TimelapseState initial values")
    func testInitial() {
        let state = TimelapseState()
        
        #expect(state.framesCaptured == 0)
        #expect(state.isCapturing == false)
        #expect(state.isPaused == false)
    }
    
    @Test("TimelapseState progress calculation")
    func testProgress() {
        var state = TimelapseState()
        state.framesCaptured = 15
        
        let config = TimelapseConfig(intervalSeconds: 1.0, durationSeconds: 30)
        
        #expect(state.progress(for: config) == 0.5)
    }
    
    @Test("TimelapseState frame count formatted")
    func testFrameCountFormatted() {
        var state = TimelapseState()
        state.framesCaptured = 10
        
        let bounded = TimelapseConfig(intervalSeconds: 1.0, durationSeconds: 30)
        let unbounded = TimelapseConfig(intervalSeconds: 1.0, durationSeconds: nil)
        
        #expect(state.frameCountFormatted(for: bounded) == "10 / 30")
        #expect(state.frameCountFormatted(for: unbounded) == "10")
    }
}

@Suite("StackingMode Tests")
struct StackingModeTests {
    
    @Test("StackingMode allCases")
    func testAllCases() {
        #expect(StackingMode.allCases.count == 3)
    }
    
    @Test("StackingMode display names")
    func testDisplayNames() {
        #expect(StackingMode.mean.displayName.contains("Silky"))
        #expect(StackingMode.lighten.displayName.contains("Trails"))
        #expect(StackingMode.median.displayName.contains("Remove"))
    }
}

@Suite("StackingEngine Tests")
struct StackingEngineTests {
    
    @Test("StackingEngine initial state")
    func testInitialState() async {
        let engine = StackingEngine(config: StackingConfig())
        
        let count = await engine.getFrameCount()
        #expect(count == 0)
    }
    
    @Test("StackingEngine add frames")
    func testAddFrames() async {
        let engine = StackingEngine(config: StackingConfig(mode: .mean))
        let frame = Data(repeating: 128, count: 100 * 100 * 4)
        
        await engine.addFrame(frame, width: 100, height: 100)
        await engine.addFrame(frame, width: 100, height: 100)
        
        let count = await engine.getFrameCount()
        #expect(count == 2)
    }
    
    @Test("StackingEngine mean blending")
    func testMeanBlending() async {
        let engine = StackingEngine(config: StackingConfig(mode: .mean))
        let darkFrame = Data(repeating: 0, count: 4)
        let brightFrame = Data(repeating: 200, count: 4)
        
        await engine.addFrame(darkFrame, width: 1, height: 1)
        await engine.addFrame(brightFrame, width: 1, height: 1)
        
        let result = await engine.getResult()
        #expect(result.count == 4)
        #expect(result[0] == 100)
    }
    
    @Test("StackingEngine lighten blending")
    func testLightenBlending() async {
        let engine = StackingEngine(config: StackingConfig(mode: .lighten))
        let darkFrame = Data(repeating: 50, count: 4)
        let brightFrame = Data(repeating: 200, count: 4)
        
        await engine.addFrame(darkFrame, width: 1, height: 1)
        await engine.addFrame(brightFrame, width: 1, height: 1)
        
        let result = await engine.getResult()
        #expect(result[0] == 200)
    }
    
    @Test("StackingEngine progress calculation")
    func testProgress() async {
        let config = StackingConfig(mode: .mean, exposureSeconds: 10)
        let engine = StackingEngine(config: config)
        let frame = Data(repeating: 128, count: 4)
        
        await engine.addFrame(frame, width: 1, height: 1)
        await engine.addFrame(frame, width: 1, height: 1)
        await engine.addFrame(frame, width: 1, height: 1)
        
        let progress = await engine.getProgress(targetFPS: 30)
        #expect(progress == 0.01)
    }
    
    @Test("StackingEngine reset")
    func testReset() async {
        let engine = StackingEngine(config: StackingConfig())
        let frame = Data(repeating: 128, count: 4)
        
        await engine.addFrame(frame, width: 1, height: 1)
        await engine.reset()
        
        let count = await engine.getFrameCount()
        #expect(count == 0)
    }
}

@Suite("InstabilityReason Tests")
struct InstabilityReasonTests {
    
    @Test("InstabilityReason display messages")
    func testDisplayMessages() {
        let angleReason = InstabilityReason.angleChanged(delta: 2.5)
        let movedReason = InstabilityReason.deviceMoved
        let closedReason = InstabilityReason.deviceClosed
        
        #expect(angleReason.displayMessage.contains("2.5"))
        #expect(movedReason.displayMessage.contains("moved"))
        #expect(closedReason.displayMessage.contains("closed"))
    }
}
