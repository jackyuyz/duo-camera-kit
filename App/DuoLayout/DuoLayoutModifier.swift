import SwiftUI
import FoldKit

/// Layout constants for iPhone Duo displays
public enum DuoDisplay {
    /// Inner display aspect ratio (unfolded, near-square)
    public static let innerAspectRatio: CGFloat = 4.0 / 3.0
    
    /// Outer cover display aspect ratio (tall and narrow)
    public static let outerAspectRatio: CGFloat = 9.0 / 16.0
    
    /// Approximate width of the fold/crease region in points
    public static let foldRegionWidth: CGFloat = 8.0
    
    /// Safe margin from the fold region
    public static let foldSafeMargin: CGFloat = 16.0
    
    /// Camera occlusion region height (inner display punch-hole)
    public static let innerCameraHeight: CGFloat = 32.0
}

/// Describes the current display context
public enum DisplayContext: Equatable {
    /// Running on inner display (unfolded or partially folded)
    case inner(FoldPosture)
    /// Running on outer cover display (closed)
    case outer
    /// Non-Duo device
    case standard
    
    var isInner: Bool {
        if case .inner = self { return true }
        return false
    }
    
    var isOuter: Bool {
        self == .outer
    }
    
    var isFolded: Bool {
        if case .inner(.partiallyOpen) = self { return true }
        return false
    }
}

/// Determines display context from fold state
public func displayContext(from foldState: FoldState) -> DisplayContext {
    guard foldState.hasHinge else {
        return .standard
    }
    
    switch foldState.posture {
    case .closed:
        return .outer
    case .partiallyOpen:
        return .inner(.partiallyOpen)
    case .fullyOpen:
        return .inner(.fullyOpen)
    case .noHinge:
        return .standard
    case .unknown:
        return .inner(.unknown)
    }
}

/// View modifier that adapts layout for Duo displays
struct DuoLayoutModifier: ViewModifier {
    let foldState: FoldState
    
    var context: DisplayContext {
        displayContext(from: foldState)
    }
    
    func body(content: Content) -> some View {
        content
            .environment(\.displayContext, context)
            .environment(\.foldPosture, foldState.posture)
            .environment(\.hingeAngle, foldState.angleDegrees)
    }
}

extension View {
    /// Apply Duo-aware layout based on fold state
    func duoLayout(foldState: FoldState) -> some View {
        modifier(DuoLayoutModifier(foldState: foldState))
    }
}

// MARK: - Environment Keys

private struct DisplayContextKey: EnvironmentKey {
    static let defaultValue: DisplayContext = .standard
}

private struct FoldPostureKey: EnvironmentKey {
    static let defaultValue: FoldPosture = .noHinge
}

private struct HingeAngleKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    var displayContext: DisplayContext {
        get { self[DisplayContextKey.self] }
        set { self[DisplayContextKey.self] = newValue }
    }
    
    var foldPosture: FoldPosture {
        get { self[FoldPostureKey.self] }
        set { self[FoldPostureKey.self] = newValue }
    }
    
    var hingeAngle: Double? {
        get { self[HingeAngleKey.self] }
        set { self[HingeAngleKey.self] = newValue }
    }
}
