import SwiftUI
import FoldKit

/// Layout constants for iPhone Duo displays
///
/// Display specifications based on public research (not yet Apple-doc-confirmed):
/// - Outer display: 5.4" portrait, 1398×2034 px
/// - Inner display: 7.6" unfolded landscape, 2670×1878 px
///
/// Scale factor and point sizes are ASSUMPTIONS pending device confirmation.
/// Fold region dimensions come from runtime `reservedRegions(kind: .division)` - NOT hardcoded.
public enum DuoDisplay {
    
    // MARK: - Researched Values (public, not Apple-doc-confirmed)
    
    /// Inner display pixel dimensions (landscape orientation, unfolded)
    public static let innerPixelWidth: CGFloat = 2670
    public static let innerPixelHeight: CGFloat = 1878
    
    /// Outer display pixel dimensions (portrait orientation)
    public static let outerPixelWidth: CGFloat = 1398
    public static let outerPixelHeight: CGFloat = 2034
    
    /// Inner display aspect ratio: 2670/1878 ≈ 1.4217 (wider than tall in landscape)
    /// This is NOT 4:3; the inner display is landscape-oriented when unfolded
    public static let innerAspectRatio: CGFloat = innerPixelWidth / innerPixelHeight  // ~1.42:1
    
    /// Outer display aspect ratio: 1398/2034 ≈ 0.6874 (~1:1.455 portrait)
    public static let outerAspectRatio: CGFloat = outerPixelWidth / outerPixelHeight  // ~0.69:1
    
    /// Inner display diagonal (inches)
    public static let innerDiagonalInches: CGFloat = 7.6
    
    /// Outer display diagonal (inches)
    public static let outerDiagonalInches: CGFloat = 5.4
    
    // MARK: - Assumptions (pending device confirmation)
    
    /// Assumed scale factor (3x like iPhone Pro Max)
    /// ASSUMPTION: Not confirmed for Duo
    public static let assumedScaleFactor: CGFloat = 3.0
    
    /// Assumed inner display point dimensions (pixels / scale)
    /// ASSUMPTION: Based on 3x scale factor
    public static let innerPointWidth: CGFloat = innerPixelWidth / assumedScaleFactor   // 890pt
    public static let innerPointHeight: CGFloat = innerPixelHeight / assumedScaleFactor // 626pt
    
    /// Assumed outer display point dimensions (pixels / scale)
    /// ASSUMPTION: Based on 3x scale factor
    public static let outerPointWidth: CGFloat = outerPixelWidth / assumedScaleFactor   // 466pt
    public static let outerPointHeight: CGFloat = outerPixelHeight / assumedScaleFactor // 678pt
    
    /// Camera occlusion region height on inner display (punch-hole/Dynamic Island)
    /// ASSUMPTION: Estimated based on iPhone Pro
    public static let innerCameraHeight: CGFloat = 32.0
}

/// Runtime fold region information from system reservedRegions API
/// The fold region exists only when half-folded and has 0 width when fully unfolded
public struct FoldRegionInfo: Equatable {
    /// Width of the fold/crease region (0 when fully open or closed)
    public var width: CGFloat
    
    /// Safe margin from the fold region
    public var safeMargin: CGFloat
    
    /// Total width including safe margins on both sides
    public var totalAvoidanceWidth: CGFloat {
        width > 0 ? width + safeMargin * 2 : 0
    }
    
    public init(width: CGFloat = 0, safeMargin: CGFloat = ReservedRegionDefaults.divisionSafeMargin) {
        self.width = width
        self.safeMargin = safeMargin
    }
    
    /// Default for when no fold region is present
    public static let none = FoldRegionInfo(width: 0, safeMargin: 0)
    
    /// Mock value for testing (~40pt when half-folded)
    public static let mockPartiallyOpen = FoldRegionInfo(
        width: ReservedRegionDefaults.mockDivisionWidth,
        safeMargin: ReservedRegionDefaults.divisionSafeMargin
    )
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
    let reservedRegionProvider: (any ReservedRegionProvider)?
    
    var context: DisplayContext {
        displayContext(from: foldState)
    }
    
    var foldRegionInfo: FoldRegionInfo {
        guard let provider = reservedRegionProvider else {
            return foldRegionForPosture(foldState.posture)
        }
        return FoldRegionInfo(
            width: provider.divisionWidth,
            safeMargin: provider.divisionSafeMargin
        )
    }
    
    func body(content: Content) -> some View {
        content
            .environment(\.displayContext, context)
            .environment(\.foldPosture, foldState.posture)
            .environment(\.hingeAngle, foldState.angleDegrees)
            .environment(\.foldRegionInfo, foldRegionInfo)
    }
}

/// Determine fold region info based on posture (for mocking without a provider)
func foldRegionForPosture(_ posture: FoldPosture) -> FoldRegionInfo {
    switch posture {
    case .partiallyOpen:
        return .mockPartiallyOpen
    default:
        return .none
    }
}

extension View {
    /// Apply Duo-aware layout based on fold state
    func duoLayout(foldState: FoldState) -> some View {
        modifier(DuoLayoutModifier(foldState: foldState, reservedRegionProvider: nil))
    }
    
    /// Apply Duo-aware layout with a reserved region provider for runtime fold region queries
    func duoLayout(foldState: FoldState, reservedRegionProvider: (any ReservedRegionProvider)?) -> some View {
        modifier(DuoLayoutModifier(foldState: foldState, reservedRegionProvider: reservedRegionProvider))
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

private struct FoldRegionInfoKey: EnvironmentKey {
    static let defaultValue: FoldRegionInfo = .none
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
    
    var foldRegionInfo: FoldRegionInfo {
        get { self[FoldRegionInfoKey.self] }
        set { self[FoldRegionInfoKey.self] = newValue }
    }
}
