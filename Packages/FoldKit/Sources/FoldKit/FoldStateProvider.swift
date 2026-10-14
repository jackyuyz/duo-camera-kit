import Foundation

/// Protocol for providing fold state to the application.
/// Feature code depends on this protocol, never on concrete implementations.
public protocol FoldStateProvider: AnyObject, Sendable {
    /// The current fold state
    var state: FoldState { get }
    
    /// Yields the current value immediately, then every change.
    func states() -> AsyncStream<FoldState>
}

/// Test/preview/UI-test provider. Driven by code or by launch arguments.
/// Thread-safe for use from any context.
public final class MockFoldStateProvider: FoldStateProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _state: FoldState
    private var continuations: [UUID: AsyncStream<FoldState>.Continuation] = [:]
    
    public init(initialState: FoldState = .noHinge) {
        self._state = initialState
    }
    
    public var state: FoldState {
        lock.withLock { _state }
    }
    
    /// Set a new posture and optionally angle
    public func set(_ posture: FoldPosture, angle: Double? = nil) {
        let newState = FoldState(posture: posture, angleDegrees: angle, timestamp: .now)
        lock.withLock {
            _state = newState
            for continuation in continuations.values {
                continuation.yield(newState)
            }
        }
    }
    
    /// Set a complete state
    public func setState(_ newState: FoldState) {
        lock.withLock {
            _state = newState
            for continuation in continuations.values {
                continuation.yield(newState)
            }
        }
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
    
    /// Play a scripted sequence of fold state changes
    public func play(_ script: [FoldScriptStep]) async {
        for step in script {
            set(step.posture, angle: step.angleDegrees)
            if step.durationSeconds > 0 {
                try? await Task.sleep(for: .seconds(step.durationSeconds))
            }
        }
    }
    
    /// Sweep from one angle to another over a duration
    public func sweep(from startAngle: Double, to endAngle: Double, duration: Double, steps: Int = 30) async {
        let stepDuration = duration / Double(steps)
        let angleStep = (endAngle - startAngle) / Double(steps)
        
        for i in 0...steps {
            let angle = startAngle + angleStep * Double(i)
            let posture: FoldPosture = if angle <= 10 {
                .closed
            } else if angle >= 170 {
                .fullyOpen
            } else {
                .partiallyOpen
            }
            set(posture, angle: angle)
            if i < steps {
                try? await Task.sleep(for: .seconds(stepDuration))
            }
        }
    }
}

/// A step in a fold state script for testing
public struct FoldScriptStep: Sendable {
    public let posture: FoldPosture
    public let angleDegrees: Double?
    public let durationSeconds: Double
    
    public init(posture: FoldPosture, angleDegrees: Double? = nil, durationSeconds: Double = 0) {
        self.posture = posture
        self.angleDegrees = angleDegrees
        self.durationSeconds = durationSeconds
    }
}
