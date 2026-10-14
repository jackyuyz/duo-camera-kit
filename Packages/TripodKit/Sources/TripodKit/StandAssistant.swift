import Foundation
import FoldKit

/// Stand lock configuration
public struct StandLock: Sendable, Equatable {
    /// The hinge angle when locked
    public var anchorAngle: Double
    
    /// The gravity vector when locked (for motion detection)
    public var anchorGravity: SIMD3<Double>
    
    /// How much angle change is allowed before breaking the lock
    public var toleranceDegrees: Double
    
    public init(
        anchorAngle: Double,
        anchorGravity: SIMD3<Double> = .zero,
        toleranceDegrees: Double = 1.5
    ) {
        self.anchorAngle = anchorAngle
        self.anchorGravity = anchorGravity
        self.toleranceDegrees = toleranceDegrees
    }
}

/// Stand assistant for tripod modes
public struct StandAssistant: Sendable {
    /// Current hinge angle (degrees)
    public var currentAngle: Double?
    
    /// Current gravity vector from CoreMotion
    public var currentGravity: SIMD3<Double> = .zero
    
    /// Active stand lock, if any
    public var lock: StandLock?
    
    /// Whether the stand is currently stable
    public private(set) var isStable: Bool = true
    
    /// Reason for instability
    public private(set) var instabilityReason: InstabilityReason?
    
    /// Acceleration threshold for motion detection
    public var motionThreshold: Double = 0.1
    
    public init() {}
    
    /// Update with new fold state
    public mutating func update(foldState: FoldState) {
        currentAngle = foldState.angleDegrees
        checkStability()
    }
    
    /// Update with new motion data
    public mutating func update(gravity: SIMD3<Double>, userAcceleration: SIMD3<Double>) {
        currentGravity = gravity
        
        let accelMagnitude = sqrt(
            userAcceleration.x * userAcceleration.x +
            userAcceleration.y * userAcceleration.y +
            userAcceleration.z * userAcceleration.z
        )
        
        if let _ = lock, accelMagnitude > motionThreshold {
            isStable = false
            instabilityReason = .deviceMoved
        }
    }
    
    /// Lock the current stand position
    public mutating func lockStand(toleranceDegrees: Double = 1.5) {
        guard let angle = currentAngle else { return }
        
        lock = StandLock(
            anchorAngle: angle,
            anchorGravity: currentGravity,
            toleranceDegrees: toleranceDegrees
        )
        isStable = true
        instabilityReason = nil
    }
    
    /// Unlock the stand
    public mutating func unlockStand() {
        lock = nil
        isStable = true
        instabilityReason = nil
    }
    
    /// Re-lock at current position
    public mutating func relockStand() {
        guard lock != nil else { return }
        lockStand(toleranceDegrees: lock?.toleranceDegrees ?? 1.5)
    }
    
    private mutating func checkStability() {
        guard let lock = lock, let currentAngle = currentAngle else {
            isStable = true
            instabilityReason = nil
            return
        }
        
        let angleDelta = abs(currentAngle - lock.anchorAngle)
        
        if angleDelta > lock.toleranceDegrees {
            isStable = false
            instabilityReason = .angleChanged(delta: angleDelta)
        } else {
            isStable = true
            instabilityReason = nil
        }
    }
    
    /// Whether a hinge is available for stand mode
    public var hasHinge: Bool {
        currentAngle != nil
    }
    
    /// Current angle relative to lock
    public var angleFromLock: Double? {
        guard let lock = lock, let current = currentAngle else { return nil }
        return current - lock.anchorAngle
    }
}

/// Reasons why the stand became unstable
public enum InstabilityReason: Sendable, Equatable {
    case angleChanged(delta: Double)
    case deviceMoved
    case deviceClosed
    
    public var displayMessage: String {
        switch self {
        case .angleChanged(let delta):
            return String(format: "Stand moved by %.1f°", delta)
        case .deviceMoved:
            return "Device was moved"
        case .deviceClosed:
            return "Device was closed"
        }
    }
}
