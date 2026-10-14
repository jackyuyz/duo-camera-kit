import Foundation

/// Converts noisy absolute angles into a stable 0…1 control value.
/// Used for hinge-driven interactions that need relative motion rather than absolute position.
public struct RelativeAngleTracker: Sendable {
    /// The angle at which the interaction started
    public var anchorDegrees: Double?
    
    /// Observed minimum angle during calibration/use
    public var observedMin: Double
    
    /// Observed maximum angle during calibration/use
    public var observedMax: Double
    
    /// EMA smoothing factor (0-1); higher = more responsive, lower = smoother
    public var smoothing: Double
    
    /// Last smoothed value for EMA calculation
    private var lastSmoothedValue: Double?
    
    public init(
        anchorDegrees: Double? = nil,
        observedMin: Double = 0,
        observedMax: Double = 180,
        smoothing: Double = 0.25
    ) {
        self.anchorDegrees = anchorDegrees
        self.observedMin = observedMin
        self.observedMax = observedMax
        self.smoothing = smoothing
    }
    
    /// Begin tracking from the current angle
    public mutating func begin(at degrees: Double) {
        anchorDegrees = degrees
        lastSmoothedValue = nil
    }
    
    /// Update with a new angle reading and return normalized progress 0…1
    public mutating func update(_ degrees: Double) -> Double {
        observedMin = min(observedMin, degrees)
        observedMax = max(observedMax, degrees)
        
        let range = observedMax - observedMin
        guard range > 0 else { return 0.5 }
        
        let rawNormalized = (degrees - observedMin) / range
        let clamped = max(0, min(1, rawNormalized))
        
        if let last = lastSmoothedValue {
            let smoothed = last + smoothing * (clamped - last)
            lastSmoothedValue = smoothed
            return smoothed
        } else {
            lastSmoothedValue = clamped
            return clamped
        }
    }
    
    /// Return signed degrees since anchor
    public mutating func delta(_ degrees: Double) -> Double {
        guard let anchor = anchorDegrees else { return 0 }
        return degrees - anchor
    }
    
    /// Reset the tracker
    public mutating func reset() {
        anchorDegrees = nil
        lastSmoothedValue = nil
    }
}
