import Testing
import Foundation
@testable import FoldKit

@Suite("MockFoldStateProvider Tests")
struct MockFoldStateProviderTests {
    
    @Test("Initial state is noHinge by default")
    func testDefaultInitialState() {
        let provider = MockFoldStateProvider()
        
        #expect(provider.state.posture == .noHinge)
        #expect(provider.state.angleDegrees == nil)
    }
    
    @Test("Initial state can be customized")
    func testCustomInitialState() {
        let initialState = FoldState(posture: .partiallyOpen, angleDegrees: 110.0)
        let provider = MockFoldStateProvider(initialState: initialState)
        
        #expect(provider.state.posture == .partiallyOpen)
        #expect(provider.state.angleDegrees == 110.0)
    }
    
    @Test("set() updates state and posture")
    func testSetUpdatesState() {
        let provider = MockFoldStateProvider()
        
        provider.set(.closed, angle: 5.0)
        
        #expect(provider.state.posture == .closed)
        #expect(provider.state.angleDegrees == 5.0)
    }
    
    @Test("setState() updates complete state")
    func testSetStateUpdatesCompleteState() {
        let provider = MockFoldStateProvider()
        let newState = FoldState(posture: .fullyOpen, angleDegrees: 175.0)
        
        provider.setState(newState)
        
        #expect(provider.state.posture == .fullyOpen)
        #expect(provider.state.angleDegrees == 175.0)
    }
    
    @Test("states() yields current value immediately")
    func testStatesYieldsCurrentValue() async {
        let provider = MockFoldStateProvider(initialState: FoldState(posture: .partiallyOpen, angleDegrees: 90))
        
        var receivedStates: [FoldState] = []
        let stream = provider.states()
        
        for await state in stream {
            receivedStates.append(state)
            break
        }
        
        #expect(receivedStates.count == 1)
        #expect(receivedStates[0].posture == .partiallyOpen)
    }
    
    @Test("states() yields changes")
    func testStatesYieldsChanges() async {
        let provider = MockFoldStateProvider()
        
        var receivedStates: [FoldState] = []
        let stream = provider.states()
        
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            provider.set(.closed, angle: 0)
            try? await Task.sleep(for: .milliseconds(50))
            provider.set(.partiallyOpen, angle: 90)
        }
        
        for await state in stream {
            receivedStates.append(state)
            if receivedStates.count >= 3 {
                break
            }
        }
        
        #expect(receivedStates.count >= 3)
        #expect(receivedStates[0].posture == .noHinge)
        #expect(receivedStates[1].posture == .closed)
        #expect(receivedStates[2].posture == .partiallyOpen)
    }
    
    @Test("Script step initialization")
    func testScriptStepInit() {
        let step = FoldScriptStep(posture: .partiallyOpen, angleDegrees: 95.0, durationSeconds: 0.5)
        
        #expect(step.posture == .partiallyOpen)
        #expect(step.angleDegrees == 95.0)
        #expect(step.durationSeconds == 0.5)
    }
}
