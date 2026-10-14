import Foundation

/// Production fold-state holder. Fed by `HingeBridge` on iOS 27.1+,
/// or by `ingestNoHinge()` on iOS 26 and non-Duo devices.
///
/// Duo hinge APIs (`onHingeChange`, `DeviceHinge`) are **iOS 27.1+ only**.
/// The older paired phone (Lens role) runs iOS 26 and must never call them.
public final class SystemFoldStateProvider: FoldStateProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _state: FoldState = .noHinge
    private var continuations: [UUID: AsyncStream<FoldState>.Continuation] = [:]
    
    public init() {}
    
    public var state: FoldState {
        lock.withLock { _state }
    }
    
    public func states() -> AsyncStream<FoldState> {
        let id = UUID()
        return AsyncStream { continuation in
            self.lock.withLock {
                continuation.yield(self._state)
                self.continuations[id] = continuation
            }
            continuation.onTermination = { @Sendable _ in
                self.lock.withLock {
                    _ = self.continuations.removeValue(forKey: id)
                }
            }
        }
    }
    
    /// Called when the device has no hinge, or when running below iOS 27.1.
    public func ingestNoHinge() {
        apply(FoldState.noHinge)
    }
    
    /// Map a system hinge status string to FoldPosture.
    ///
    /// Expected values from DeviceHinge.status / UIHinge.status:
    /// `closed`, `partiallyOpen`, `fullyOpen`, `unknown`.
    /// A nil hinge maps to `.noHinge`.
    public func ingest(
        hingeAvailable: Bool,
        statusRaw: String?,
        angleDegrees: Double?
    ) {
        guard hingeAvailable, let statusRaw else {
            ingestNoHinge()
            return
        }
        let posture = FoldPosture.fromSystemHingeStatus(statusRaw)
        apply(FoldState(posture: posture, angleDegrees: angleDegrees, timestamp: .now))
    }
    
    private func apply(_ newState: FoldState) {
        lock.withLock {
            _state = newState
            for continuation in continuations.values {
                continuation.yield(newState)
            }
        }
    }
}

extension FoldPosture {
    /// Maps DeviceHinge.status / UIHinge.status raw values.
    /// `@unknown default` becomes `.unknown`.
    public static func fromSystemHingeStatus(_ raw: String) -> FoldPosture {
        switch raw {
        case "closed": return .closed
        case "partiallyOpen": return .partiallyOpen
        case "fullyOpen": return .fullyOpen
        case "unknown": return .unknown
        default: return .unknown
        }
    }
}

/// Minimum OS for Duo-specific hinge and reserved-region APIs.
public enum DuoAPIAvailability {
    /// Lens role and the rest of the app run on iOS 26.
    public static let minimumOS = "26.0"
    
    /// Hinge, ArrangementView, reservedRegions(.division), Duo camera types.
    public static let duoAPIs = "27.1"
    
    /// Whether the current process can use Duo APIs. Always false on Linux tests.
    public static var hingeAPIsAvailable: Bool {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            return true
        }
        return false
        #else
        return false
        #endif
    }
}
