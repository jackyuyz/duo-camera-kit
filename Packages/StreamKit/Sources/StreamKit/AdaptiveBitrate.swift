import Foundation

/// Adaptive bitrate controller based on network conditions
public struct AdaptiveBitrateController: Sendable {
    /// Current quality level
    public private(set) var currentQuality: VideoQuality
    
    /// Target quality (may differ from current during transitions)
    public var targetQuality: VideoQuality
    
    /// Minimum RTT samples before making decisions
    private let minSamples = 5
    
    /// RTT threshold for downgrade (ms)
    private let highRttThreshold: Double = 150
    
    /// RTT threshold for upgrade (ms)
    private let lowRttThreshold: Double = 50
    
    /// Recent RTT samples
    private var rttSamples: [Double] = []
    
    /// Recent packet loss samples
    private var lossSamples: [Double] = []
    
    /// Time of last quality change
    private var lastChangeTime: Date = .distantPast
    
    /// Minimum time between quality changes
    private let minChangeInterval: TimeInterval = 5.0
    
    public init(initialQuality: VideoQuality = .medium) {
        self.currentQuality = initialQuality
        self.targetQuality = initialQuality
    }
    
    /// Add a RTT sample
    public mutating func addRttSample(_ rttMs: Double) {
        rttSamples.append(rttMs)
        if rttSamples.count > 20 {
            rttSamples.removeFirst()
        }
    }
    
    /// Add a packet loss sample (0.0 - 1.0)
    public mutating func addLossSample(_ loss: Double) {
        lossSamples.append(loss)
        if lossSamples.count > 10 {
            lossSamples.removeFirst()
        }
    }
    
    /// Evaluate current conditions and return recommended quality
    public mutating func evaluate() -> VideoQuality {
        guard rttSamples.count >= minSamples else {
            return currentQuality
        }
        
        guard Date().timeIntervalSince(lastChangeTime) >= minChangeInterval else {
            return currentQuality
        }
        
        let avgRtt = rttSamples.reduce(0, +) / Double(rttSamples.count)
        let avgLoss = lossSamples.isEmpty ? 0 : lossSamples.reduce(0, +) / Double(lossSamples.count)
        
        var newQuality = currentQuality
        
        if avgRtt > highRttThreshold || avgLoss > 0.05 {
            newQuality = downgrade(from: currentQuality)
        } else if avgRtt < lowRttThreshold && avgLoss < 0.01 {
            newQuality = upgrade(from: currentQuality)
        }
        
        if newQuality != currentQuality {
            lastChangeTime = Date()
            currentQuality = newQuality
        }
        
        return currentQuality
    }
    
    private func downgrade(from quality: VideoQuality) -> VideoQuality {
        switch quality {
        case .high: return .medium
        case .medium: return .low
        case .low: return .low
        }
    }
    
    private func upgrade(from quality: VideoQuality) -> VideoQuality {
        switch quality {
        case .low: return .medium
        case .medium: return .high
        case .high: return .high
        }
    }
    
    /// Reset the controller
    public mutating func reset() {
        rttSamples.removeAll()
        lossSamples.removeAll()
        lastChangeTime = .distantPast
    }
    
    /// Current average RTT
    public var averageRttMs: Double {
        guard !rttSamples.isEmpty else { return 0 }
        return rttSamples.reduce(0, +) / Double(rttSamples.count)
    }
    
    /// Current average packet loss
    public var averageLoss: Double {
        guard !lossSamples.isEmpty else { return 0 }
        return lossSamples.reduce(0, +) / Double(lossSamples.count)
    }
}
