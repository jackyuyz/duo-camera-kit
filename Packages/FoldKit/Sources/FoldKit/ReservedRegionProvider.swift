import Foundation

/// Represents a reserved region on the display (fold crease, camera cutout, etc.)
public struct ReservedRegion: Equatable, Sendable {
    /// The region's bounds in points
    public var bounds: CGRect
    
    /// The kind of reserved region
    public var kind: Kind
    
    public enum Kind: String, Codable, Sendable {
        /// The fold/crease region (only present when device is partially folded)
        case division
        /// Camera or sensor occlusion region
        case occlusion
    }
    
    public init(bounds: CGRect, kind: Kind) {
        self.bounds = bounds
        self.kind = kind
    }
    
    /// Width of the region (for vertical fold regions)
    public var width: CGFloat { bounds.width }
    
    /// Height of the region (for horizontal fold regions)
    public var height: CGFloat { bounds.height }
}

/// Protocol for querying reserved regions at runtime
/// Apple exposes the fold via `GeometryProxy.reservedRegions(kind: .division)` at runtime.
/// The fold region exists only when half-folded and has 0 width when fully unfolded.
@MainActor
public protocol ReservedRegionProvider: AnyObject, Sendable {
    /// Get reserved regions of a specific kind
    /// - Parameter kind: The kind of region to query
    /// - Returns: Array of reserved regions (empty if none exist for current state)
    func regions(of kind: ReservedRegion.Kind) -> [ReservedRegion]
    
    /// The current fold/division region width (0 when fully open or closed)
    var divisionWidth: CGFloat { get }
    
    /// Recommended safe margin from the division region
    var divisionSafeMargin: CGFloat { get }
}

/// Mock provider for testing and previews
/// Uses ~40pt width for half-folded state as per PM guidance
@MainActor
public final class MockReservedRegionProvider: ReservedRegionProvider, @unchecked Sendable {
    
    /// The current fold posture (affects whether division region is present)
    public var posture: FoldPosture
    
    /// The mock division width when partially open (~40pt per PM guidance)
    public let mockDivisionWidth: CGFloat
    
    /// Safe margin from the division region
    public let mockDivisionSafeMargin: CGFloat
    
    /// Mock occlusion regions (camera cutouts)
    public var mockOcclusionRegions: [ReservedRegion]
    
    /// Screen size for calculating region bounds
    public var screenSize: CGSize
    
    public init(
        posture: FoldPosture = .fullyOpen,
        mockDivisionWidth: CGFloat = 40.0,
        mockDivisionSafeMargin: CGFloat = 16.0,
        screenSize: CGSize = CGSize(width: 890, height: 626),
        mockOcclusionRegions: [ReservedRegion] = []
    ) {
        self.posture = posture
        self.mockDivisionWidth = mockDivisionWidth
        self.mockDivisionSafeMargin = mockDivisionSafeMargin
        self.screenSize = screenSize
        self.mockOcclusionRegions = mockOcclusionRegions
    }
    
    public func regions(of kind: ReservedRegion.Kind) -> [ReservedRegion] {
        switch kind {
        case .division:
            guard posture == .partiallyOpen else {
                return []
            }
            let centerX = screenSize.width / 2
            let divisionBounds = CGRect(
                x: centerX - mockDivisionWidth / 2,
                y: 0,
                width: mockDivisionWidth,
                height: screenSize.height
            )
            return [ReservedRegion(bounds: divisionBounds, kind: .division)]
            
        case .occlusion:
            return mockOcclusionRegions
        }
    }
    
    public var divisionWidth: CGFloat {
        guard posture == .partiallyOpen else {
            return 0
        }
        return mockDivisionWidth
    }
    
    public var divisionSafeMargin: CGFloat {
        mockDivisionSafeMargin
    }
    
    /// Update the posture (for testing state changes)
    public func setPosture(_ newPosture: FoldPosture) {
        posture = newPosture
    }
}

/// Default assumptions for reserved regions when runtime values are unavailable
/// These are clearly marked as assumptions pending device confirmation
public enum ReservedRegionDefaults {
    /// Default division width for mocks (~40pt when half-folded)
    /// ASSUMPTION: Based on typical foldable display crease widths
    public static let mockDivisionWidth: CGFloat = 40.0
    
    /// Default safe margin from the division region
    /// ASSUMPTION: Estimated for comfortable viewing/touch
    public static let divisionSafeMargin: CGFloat = 16.0
    
    /// Default camera occlusion height on inner display
    /// ASSUMPTION: Based on iPhone Pro Dynamic Island
    public static let innerCameraHeight: CGFloat = 32.0
}
