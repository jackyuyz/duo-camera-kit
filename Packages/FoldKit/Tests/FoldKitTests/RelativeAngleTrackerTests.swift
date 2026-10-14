import Testing
import Foundation
@testable import FoldKit

@Suite("RelativeAngleTracker Tests")
struct RelativeAngleTrackerTests {
    
    @Test("Initial state")
    func testInitialState() {
        let tracker = RelativeAngleTracker()
        
        #expect(tracker.anchorDegrees == nil)
        #expect(tracker.observedMin == 0)
        #expect(tracker.observedMax == 180)
        #expect(tracker.smoothing == 0.25)
    }
    
    @Test("Custom initialization")
    func testCustomInit() {
        let tracker = RelativeAngleTracker(
            anchorDegrees: 90,
            observedMin: 30,
            observedMax: 150,
            smoothing: 0.5
        )
        
        #expect(tracker.anchorDegrees == 90)
        #expect(tracker.observedMin == 30)
        #expect(tracker.observedMax == 150)
        #expect(tracker.smoothing == 0.5)
    }
    
    @Test("begin() sets anchor")
    func testBeginSetsAnchor() {
        var tracker = RelativeAngleTracker()
        
        tracker.begin(at: 95.0)
        
        #expect(tracker.anchorDegrees == 95.0)
    }
    
    @Test("delta() returns difference from anchor")
    func testDeltaReturnsDifference() {
        var tracker = RelativeAngleTracker()
        tracker.begin(at: 90.0)
        
        let delta = tracker.delta(95.0)
        
        #expect(delta == 5.0)
    }
    
    @Test("delta() returns 0 when no anchor")
    func testDeltaReturnsZeroWithNoAnchor() {
        var tracker = RelativeAngleTracker()
        
        let delta = tracker.delta(95.0)
        
        #expect(delta == 0)
    }
    
    @Test("update() returns normalized value in 0...1 range")
    func testUpdateReturnsNormalizedValue() {
        var tracker = RelativeAngleTracker(observedMin: 0, observedMax: 180)
        
        let mid = tracker.update(90.0)
        
        #expect(mid >= 0 && mid <= 1)
        #expect(abs(mid - 0.5) < 0.01)
    }
    
    @Test("update() expands observed range")
    func testUpdateExpandsRange() {
        var tracker = RelativeAngleTracker(observedMin: 50, observedMax: 130)
        
        _ = tracker.update(30.0)
        #expect(tracker.observedMin == 30.0)
        
        _ = tracker.update(160.0)
        #expect(tracker.observedMax == 160.0)
    }
    
    @Test("update() applies smoothing on successive calls")
    func testUpdateAppliesSmoothing() {
        var tracker = RelativeAngleTracker(observedMin: 0, observedMax: 100, smoothing: 0.5)
        
        let first = tracker.update(50.0)
        let second = tracker.update(100.0)
        
        #expect(first == 0.5)
        #expect(second > 0.5 && second < 1.0)
    }
    
    @Test("reset() clears anchor")
    func testResetClearsAnchor() {
        var tracker = RelativeAngleTracker()
        tracker.begin(at: 90.0)
        _ = tracker.update(95.0)
        
        tracker.reset()
        
        #expect(tracker.anchorDegrees == nil)
    }
    
    @Test("Negative delta for closing motion")
    func testNegativeDelta() {
        var tracker = RelativeAngleTracker()
        tracker.begin(at: 90.0)
        
        let delta = tracker.delta(85.0)
        
        #expect(delta == -5.0)
    }
}
