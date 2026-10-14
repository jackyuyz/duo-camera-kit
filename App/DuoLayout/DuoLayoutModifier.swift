import SwiftUI
import FoldKit
import os.log

/// Layout constants for iPhone Duo displays
///
/// Display specifications based on public research (not yet Apple-doc-confirmed):
/// - Outer display: 5.4" portrait, 1398×2034 px (panel), renders @3x then downsamples
/// - Inner display: 7.6" unfolded landscape, 2670×1878 px (panel), renders @3x as 2007×2853 then downsamples
///
/// **Important:** Do NOT derive point sizes from panel pixels / 3.
/// The inner screen renders at @3x (like old Plus models) then downsamples to the panel.
/// Use runtime `UIScreen.main.bounds` and `UIScreen.main.scale` for actual values.
/// Third-party reported point sizes are kept as mock/default values only.
public enum DuoDisplay {
    
    // MARK: - Panel Pixel Dimensions (public research, not Apple-doc-confirmed)
    
    /// Inner display panel pixels (landscape orientation, unfolded)
    /// Note: Rendering resolution is different (2007×2853 @3x, downsampled to panel)
    public static let innerPanelPixelWidth: CGFloat = 2670
    public static let innerPanelPixelHeight: CGFloat = 1878
    
    /// Outer display panel pixels (portrait orientation)
    public static let outerPanelPixelWidth: CGFloat = 1398
    public static let outerPanelPixelHeight: CGFloat = 2034
    
    /// Inner display aspect ratio from panel pixels
    public static let innerAspectRatio: CGFloat = innerPanelPixelWidth / innerPanelPixelHeight  // ~1.42:1
    
    /// Outer display aspect ratio from panel pixels
    public static let outerAspectRatio: CGFloat = outerPanelPixelWidth / outerPanelPixelHeight  // ~0.69:1
    
    /// Inner display diagonal (inches)
    public static let innerDiagonalInches: CGFloat = 7.6
    
    /// Outer display diagonal (inches)
    public static let outerDiagonalInches: CGFloat = 5.4
    
    // MARK: - Third-Party Reported Point Sizes (for mocks/defaults only)
    // Source: Third-party analysis. Use runtime values in production.
    // Inner renders @3x as 2853×2007 pixels → 951×669pt landscape
    // Do NOT use panel pixels / 3 to derive these!
    
    /// Third-party reported inner display point size (landscape)
    /// THIRD-PARTY VALUE: Use runtime UIScreen.main.bounds instead
    public static let thirdPartyInnerPointWidth: CGFloat = 951
    public static let thirdPartyInnerPointHeight: CGFloat = 669
    
    /// Third-party reported outer display point size (portrait)
    /// THIRD-PARTY VALUE: Use runtime UIScreen.main.bounds instead
    public static let thirdPartyOuterPointWidth: CGFloat = 466
    public static let thirdPartyOuterPointHeight: CGFloat = 678
    
    /// Camera occlusion region height on inner display (punch-hole/Dynamic Island)
    /// ASSUMPTION: Estimated based on iPhone Pro
    public static let innerCameraHeight: CGFloat = 32.0
}

/// Runtime display information read from UIScreen
/// Use this instead of hardcoded constants
public struct RuntimeDisplayInfo: CustomStringConvertible, Sendable {
    /// Screen bounds in points
    public let bounds: CGRect
    
    /// Display scale factor (@1x, @2x, @3x)
    public let scale: CGFloat
    
    /// Native bounds in pixels
    public let nativeBounds: CGRect
    
    /// Native scale
    public let nativeScale: CGFloat
    
    public var description: String {
        "RuntimeDisplayInfo(bounds: \(bounds.width)×\(bounds.height)pt, scale: \(scale)x, native: \(nativeBounds.width)×\(nativeBounds.height)px, nativeScale: \(nativeScale)x)"
    }
    
    /// Mock info using third-party inner display values (landscape)
    public static let mockInner = RuntimeDisplayInfo(
        bounds: CGRect(x: 0, y: 0, width: DuoDisplay.thirdPartyInnerPointWidth, height: DuoDisplay.thirdPartyInnerPointHeight),
        scale: 3.0,
        nativeBounds: CGRect(x: 0, y: 0, width: 2853, height: 2007),
        nativeScale: 3.0
    )
    
    /// Mock info using third-party outer display values (portrait)
    public static let mockOuter = RuntimeDisplayInfo(
        bounds: CGRect(x: 0, y: 0, width: DuoDisplay.thirdPartyOuterPointWidth, height: DuoDisplay.thirdPartyOuterPointHeight),
        scale: 3.0,
        nativeBounds: CGRect(x: 0, y: 0, width: DuoDisplay.outerPanelPixelWidth, height: DuoDisplay.outerPanelPixelHeight),
        nativeScale: 3.0
    )
}

#if canImport(UIKit)
import UIKit

extension RuntimeDisplayInfo {
    /// Read current display info from UIScreen.main
    @MainActor
    public static func current() -> RuntimeDisplayInfo {
        let screen = UIScreen.main
        return RuntimeDisplayInfo(
            bounds: screen.bounds,
            scale: screen.scale,
            nativeBounds: screen.nativeBounds,
            nativeScale: screen.nativeScale
        )
    }
}

/// Logger for display diagnostics
private let displayLogger = Logger(subsystem: "com.duocamerakit", category: "Display")

/// Log current runtime display values for debugging
/// Call this on app launch to verify display dimensions in simulator/device
@MainActor
public func logRuntimeDisplayInfo() {
    let info = RuntimeDisplayInfo.current()
    displayLogger.info("📱 Runtime Display Info: \(info.description)")
    displayLogger.info("  bounds: \(info.bounds.width, privacy: .public)×\(info.bounds.height, privacy: .public)pt")
    displayLogger.info("  scale: \(info.scale, privacy: .public)x")
    displayLogger.info("  nativeBounds: \(info.nativeBounds.width, privacy: .public)×\(info.nativeBounds.height, privacy: .public)px")
    displayLogger.info("  nativeScale: \(info.nativeScale, privacy: .public)x")
    
    #if DEBUG
    print("🖥️ [DuoDisplay] Runtime Display Info:")
    print("   bounds: \(info.bounds.width)×\(info.bounds.height)pt")
    print("   scale: \(info.scale)x")
    print("   nativeBounds: \(info.nativeBounds.width)×\(info.nativeBounds.height)px")
    print("   nativeScale: \(info.nativeScale)x")
    print("   Third-party inner (expected): \(DuoDisplay.thirdPartyInnerPointWidth)×\(DuoDisplay.thirdPartyInnerPointHeight)pt")
    print("   Third-party outer (expected): \(DuoDisplay.thirdPartyOuterPointWidth)×\(DuoDisplay.thirdPartyOuterPointHeight)pt")
    #endif
}
#else
/// Stub for non-UIKit platforms (Linux testing)
public func logRuntimeDisplayInfo() {
    #if DEBUG
    print("🖥️ [DuoDisplay] Runtime display info unavailable (no UIKit)")
    print("   Using third-party values for mocks:")
    print("   Inner: \(DuoDisplay.thirdPartyInnerPointWidth)×\(DuoDisplay.thirdPartyInnerPointHeight)pt")
    print("   Outer: \(DuoDisplay.thirdPartyOuterPointWidth)×\(DuoDisplay.thirdPartyOuterPointHeight)pt")
    #endif
}
#endif

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
