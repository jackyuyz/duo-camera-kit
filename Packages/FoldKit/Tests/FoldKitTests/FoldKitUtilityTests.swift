import Testing
import Foundation
@testable import FoldKit

@Suite("FoldKit Utility Tests")
struct FoldKitUtilityTests {
    
    @Test("parseFoldMockArgument - nohinge")
    func testParseNoHinge() {
        let config = parseFoldMockArgument("nohinge")
        
        guard case .fixed(let posture, let angle) = config else {
            Issue.record("Expected .fixed configuration")
            return
        }
        
        #expect(posture == .noHinge)
        #expect(angle == nil)
    }
    
    @Test("parseFoldMockArgument - closed")
    func testParseClosed() {
        let config = parseFoldMockArgument("closed")
        
        guard case .fixed(let posture, let angle) = config else {
            Issue.record("Expected .fixed configuration")
            return
        }
        
        #expect(posture == .closed)
        #expect(angle == 0)
    }
    
    @Test("parseFoldMockArgument - open")
    func testParseOpen() {
        let config = parseFoldMockArgument("open")
        
        guard case .fixed(let posture, let angle) = config else {
            Issue.record("Expected .fixed configuration")
            return
        }
        
        #expect(posture == .fullyOpen)
        #expect(angle == 180)
    }
    
    @Test("parseFoldMockArgument - half:95")
    func testParseHalfWithAngle() {
        let config = parseFoldMockArgument("half:95")
        
        guard case .fixed(let posture, let angle) = config else {
            Issue.record("Expected .fixed configuration")
            return
        }
        
        #expect(posture == .partiallyOpen)
        #expect(angle == 95)
    }
    
    @Test("parseFoldMockArgument - half:110.5")
    func testParseHalfWithDecimalAngle() {
        let config = parseFoldMockArgument("half:110.5")
        
        guard case .fixed(let posture, let angle) = config else {
            Issue.record("Expected .fixed configuration")
            return
        }
        
        #expect(posture == .partiallyOpen)
        #expect(angle == 110.5)
    }
    
    @Test("parseFoldMockArgument - sweep:180-0:2")
    func testParseSweep() {
        let config = parseFoldMockArgument("sweep:180-0:2")
        
        guard case .sweep(let from, let to, let duration) = config else {
            Issue.record("Expected .sweep configuration")
            return
        }
        
        #expect(from == 180)
        #expect(to == 0)
        #expect(duration == 2)
    }
    
    @Test("parseFoldMockArgument - script:test-script")
    func testParseScript() {
        let config = parseFoldMockArgument("script:test-script")
        
        guard case .script(let name) = config else {
            Issue.record("Expected .script configuration")
            return
        }
        
        #expect(name == "test-script")
    }
    
    @Test("parseFoldMockArgument - invalid returns nil")
    func testParseInvalid() {
        let config = parseFoldMockArgument("invalid")
        
        #expect(config == nil)
    }
    
    @Test("parseFoldMockArgument - case insensitive")
    func testParseCaseInsensitive() {
        let config1 = parseFoldMockArgument("NoHinge")
        let config2 = parseFoldMockArgument("CLOSED")
        let config3 = parseFoldMockArgument("Half:90")
        
        #expect(config1 != nil)
        #expect(config2 != nil)
        #expect(config3 != nil)
    }
    
    @Test("parseFoldMockArgument - half with invalid angle")
    func testParseHalfInvalidAngle() {
        let config = parseFoldMockArgument("half:abc")
        
        #expect(config == nil)
    }
    
    @Test("parseFoldMockArgument - sweep with invalid format")
    func testParseSweepInvalidFormat() {
        let config1 = parseFoldMockArgument("sweep:180:2")
        let config2 = parseFoldMockArgument("sweep:180-0")
        
        #expect(config1 == nil)
        #expect(config2 == nil)
    }
}
