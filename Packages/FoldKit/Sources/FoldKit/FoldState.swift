import Foundation

/// Represents the posture of a foldable device.
/// Maps to DeviceHinge.status on iOS 27.1+ and to `.noHinge` on devices without a hinge.
public enum FoldPosture: String, Codable, Sendable, CaseIterable, Equatable {
    /// Non-Duo iPhone, iPad, Mac, or hinge context unavailable
    case noHinge
    /// Folded; app is (assumed) on the outer display
    case closed
    /// Flexed / half-folded (laptop, book, tent… system does not tell which)
    case partiallyOpen
    /// Flat; app on inner display
    case fullyOpen
    /// UIKit `.unknown`, or transient states
    case unknown
}

/// Complete fold state including posture and optional angle.
public struct FoldState: Equatable, Sendable {
    public var posture: FoldPosture
    
    /// Degrees exactly as reported by the system. `nil` when there is no hinge.
    /// The range is NOT documented. Never compare to absolute thresholds without calibration.
    public var angleDegrees: Double?
    
    public var timestamp: Date
    
    public init(posture: FoldPosture, angleDegrees: Double?, timestamp: Date = .now) {
        self.posture = posture
        self.angleDegrees = angleDegrees
        self.timestamp = timestamp
    }
    
    /// Convenience for non-hinge devices
    public static let noHinge = FoldState(posture: .noHinge, angleDegrees: nil, timestamp: .distantPast)
    
    /// Whether the device has a hinge
    public var hasHinge: Bool { posture != .noHinge }
}
