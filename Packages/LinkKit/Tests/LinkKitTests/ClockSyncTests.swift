import Testing
import Foundation
@testable import LinkKit

@Suite("ClockSync Tests")
struct ClockSyncTests {
    
    @Test("ClockSync initial state")
    func testInitialState() {
        let sync = ClockSync()
        
        #expect(sync.estimatedOffset == 0)
        #expect(sync.estimatedRttMs == 0)
        #expect(sync.jitterMs == 0)
    }
    
    @Test("ClockSync single sample")
    func testSingleSample() {
        var sync = ClockSync()
        
        sync.addSample(localSend: 1000, remoteTime: 1100, localReceive: 1200)
        
        #expect(sync.estimatedRttMs == 0.0002)
    }
    
    @Test("ClockSync median offset calculation")
    func testMedianOffset() {
        var sync = ClockSync()
        
        sync.addSample(localSend: 1_000_000_000, remoteTime: 1_050_000_000, localReceive: 1_100_000_000)
        sync.addSample(localSend: 2_000_000_000, remoteTime: 2_050_000_000, localReceive: 2_100_000_000)
        sync.addSample(localSend: 3_000_000_000, remoteTime: 3_050_000_000, localReceive: 3_100_000_000)
        
        #expect(sync.estimatedRttMs == 100.0)
    }
    
    @Test("ClockSync RTT calculation")
    func testRTTCalculation() {
        var sync = ClockSync()
        
        sync.addSample(localSend: 0, remoteTime: 5_000_000, localReceive: 10_000_000)
        
        #expect(sync.estimatedRttMs == 10.0)
    }
    
    @Test("ClockSync clock conversion")
    func testClockConversion() {
        var sync = ClockSync()
        
        sync.addSample(localSend: 0, remoteTime: 100_000_000, localReceive: 100_000_000)
        
        let localTime: UInt64 = 1_000_000_000
        let remoteTime = sync.toRemoteClock(localTime)
        let backToLocal = sync.toLocalClock(remoteTime)
        
        #expect(backToLocal == localTime)
    }
    
    @Test("ClockSync jitter calculation")
    func testJitterCalculation() {
        var sync = ClockSync()
        
        sync.addSample(localSend: 0, remoteTime: 5_000_000, localReceive: 10_000_000)
        sync.addSample(localSend: 0, remoteTime: 5_000_000, localReceive: 20_000_000)
        
        #expect(sync.jitterMs > 0)
    }
    
    @Test("ClockSync sync quality")
    func testSyncQuality() {
        var sync = ClockSync()
        
        #expect(sync.isGoodForSyncRecording == false)
        
        for i in 0..<8 {
            let base = UInt64(i) * 100_000_000
            sync.addSample(
                localSend: base,
                remoteTime: base + 5_000_000,
                localReceive: base + 10_000_000
            )
        }
        
        #expect(sync.isGoodForSyncRecording == true)
    }
    
    @Test("ClockSync quality description")
    func testQualityDescription() {
        var sync = ClockSync()
        
        #expect(sync.qualityDescription == "Syncing...")
        
        for i in 0..<4 {
            let base = UInt64(i) * 100_000_000
            sync.addSample(
                localSend: base,
                remoteTime: base + 5_000_000,
                localReceive: base + 10_000_000
            )
        }
        
        #expect(sync.qualityDescription.contains("Good") || sync.qualityDescription.contains("Fair"))
    }
    
    @Test("ClockSync reset")
    func testReset() {
        var sync = ClockSync()
        
        sync.addSample(localSend: 0, remoteTime: 100, localReceive: 200)
        sync.reset()
        
        #expect(sync.estimatedOffset == 0)
        #expect(sync.estimatedRttMs == 0)
    }
    
    @Test("ClockSync sample limit")
    func testSampleLimit() {
        var sync = ClockSync()
        
        for i in 0..<20 {
            let base = UInt64(i) * 1_000_000_000
            sync.addSample(localSend: base, remoteTime: base + 50_000_000, localReceive: base + 100_000_000)
        }
        
        #expect(sync.estimatedRttMs == 100.0)
    }
}
