import Testing
import Foundation
@testable import FoldKit

@Suite("FoldState Tests")
struct FoldStateTests {
    
    @Test("FoldState initialization with all parameters")
    func testInitialization() {
        let timestamp = Date()
        let state = FoldState(posture: .partiallyOpen, angleDegrees: 90.0, timestamp: timestamp)
        
        #expect(state.posture == .partiallyOpen)
        #expect(state.angleDegrees == 90.0)
        #expect(state.timestamp == timestamp)
        #expect(state.hasHinge == true)
    }
    
    @Test("FoldState.noHinge convenience value")
    func testNoHingeConvenience() {
        let state = FoldState.noHinge
        
        #expect(state.posture == .noHinge)
        #expect(state.angleDegrees == nil)
        #expect(state.hasHinge == false)
    }
    
    @Test("hasHinge returns true for hinge postures")
    func testHasHingeForHingePostures() {
        let closedState = FoldState(posture: .closed, angleDegrees: 0)
        let partialState = FoldState(posture: .partiallyOpen, angleDegrees: 90)
        let openState = FoldState(posture: .fullyOpen, angleDegrees: 180)
        let unknownState = FoldState(posture: .unknown, angleDegrees: nil)
        
        #expect(closedState.hasHinge == true)
        #expect(partialState.hasHinge == true)
        #expect(openState.hasHinge == true)
        #expect(unknownState.hasHinge == true)
    }
    
    @Test("FoldPosture is CaseIterable")
    func testFoldPostureCaseIterable() {
        let allCases = FoldPosture.allCases
        
        #expect(allCases.count == 5)
        #expect(allCases.contains(.noHinge))
        #expect(allCases.contains(.closed))
        #expect(allCases.contains(.partiallyOpen))
        #expect(allCases.contains(.fullyOpen))
        #expect(allCases.contains(.unknown))
    }
    
    @Test("FoldPosture is Codable")
    func testFoldPostureCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for posture in FoldPosture.allCases {
            let data = try encoder.encode(posture)
            let decoded = try decoder.decode(FoldPosture.self, from: data)
            #expect(decoded == posture)
        }
    }
    
    @Test("FoldState equality")
    func testFoldStateEquality() {
        let timestamp = Date()
        let state1 = FoldState(posture: .partiallyOpen, angleDegrees: 90.0, timestamp: timestamp)
        let state2 = FoldState(posture: .partiallyOpen, angleDegrees: 90.0, timestamp: timestamp)
        let state3 = FoldState(posture: .partiallyOpen, angleDegrees: 91.0, timestamp: timestamp)
        
        #expect(state1 == state2)
        #expect(state1 != state3)
    }
}
