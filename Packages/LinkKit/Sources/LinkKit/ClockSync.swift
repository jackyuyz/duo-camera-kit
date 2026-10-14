import Foundation

/// Clock synchronization between Control and Lens devices
/// Uses NTP-style ping exchange with median filtering
public struct ClockSync: Sendable {
    /// Number of samples to collect
    public static let sampleCount = 8
    
    private var samples: [(localSend: UInt64, remoteTime: UInt64, localReceive: UInt64)] = []
    
    public init() {}
    
    /// Add a ping/pong sample
    public mutating func addSample(localSend: UInt64, remoteTime: UInt64, localReceive: UInt64) {
        samples.append((localSend, remoteTime, localReceive))
        if samples.count > Self.sampleCount {
            samples.removeFirst()
        }
    }
    
    /// Calculate the estimated clock offset (nanoseconds)
    /// Positive means remote clock is ahead
    public var estimatedOffset: Int64 {
        guard !samples.isEmpty else { return 0 }
        
        let offsets = samples.map { sample -> Int64 in
            let rtt = Int64(sample.localReceive) - Int64(sample.localSend)
            return Int64(sample.remoteTime) - Int64(sample.localSend) - rtt / 2
        }
        
        let sorted = offsets.sorted()
        let midIndex = sorted.count / 2
        
        if sorted.count % 2 == 0 && sorted.count >= 2 {
            return (sorted[midIndex - 1] + sorted[midIndex]) / 2
        } else {
            return sorted[midIndex]
        }
    }
    
    /// Calculate the estimated RTT (milliseconds)
    public var estimatedRttMs: Double {
        guard !samples.isEmpty else { return 0 }
        
        let rtts = samples.map { sample -> Double in
            Double(sample.localReceive - sample.localSend) / 1_000_000
        }
        
        let sorted = rtts.sorted()
        let midIndex = sorted.count / 2
        
        if sorted.count % 2 == 0 && sorted.count >= 2 {
            return (sorted[midIndex - 1] + sorted[midIndex]) / 2
        } else {
            return sorted[midIndex]
        }
    }
    
    /// Calculate the jitter (variance in RTT)
    public var jitterMs: Double {
        guard samples.count >= 2 else { return 0 }
        
        let rtts = samples.map { sample -> Double in
            Double(sample.localReceive - sample.localSend) / 1_000_000
        }
        
        let mean = rtts.reduce(0, +) / Double(rtts.count)
        let variance = rtts.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(rtts.count)
        return variance.squareRoot()
    }
    
    /// Convert a local timestamp to the remote clock
    public func toRemoteClock(_ localNs: UInt64) -> UInt64 {
        let offset = estimatedOffset
        if offset >= 0 {
            return localNs + UInt64(offset)
        } else {
            return localNs - UInt64(-offset)
        }
    }
    
    /// Convert a remote timestamp to the local clock
    public func toLocalClock(_ remoteNs: UInt64) -> UInt64 {
        let offset = estimatedOffset
        if offset >= 0 {
            return remoteNs - UInt64(offset)
        } else {
            return remoteNs + UInt64(-offset)
        }
    }
    
    /// Whether sync quality is good enough for sync recording
    public var isGoodForSyncRecording: Bool {
        samples.count >= 4 && jitterMs < 20
    }
    
    /// Human-readable sync quality
    public var qualityDescription: String {
        if samples.count < 4 {
            return "Syncing..."
        }
        let offsetMs = abs(estimatedOffset) / 1_000_000
        if jitterMs > 50 {
            return "Poor (±\(Int(jitterMs))ms jitter)"
        } else if offsetMs > 100 {
            return "Fair (±\(offsetMs)ms)"
        } else {
            return "Good"
        }
    }
    
    /// Reset all samples
    public mutating func reset() {
        samples.removeAll()
    }
}
