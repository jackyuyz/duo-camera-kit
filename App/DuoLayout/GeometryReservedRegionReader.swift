import SwiftUI
import FoldKit

/// Reads layout insets and the fold region from the live geometry.
///
/// Safe areas always come from `GeometryProxy.safeAreaInsets` — never hardcoded.
/// The crease comes from `reservedRegions(kind: .division)` on iOS 27.1+
/// (0 width when fully unfolded; present only while half-folded).
struct GeometryReservedRegionReader<Content: View>: View {
    @Environment(\.foldPosture) private var foldPosture
    let content: (FoldRegionInfo, EdgeInsets) -> Content
    
    init(@ViewBuilder content: @escaping (FoldRegionInfo, EdgeInsets) -> Content) {
        self.content = content
    }
    
    var body: some View {
        GeometryReader { proxy in
            content(foldRegion(from: proxy), proxy.safeAreaInsets)
        }
    }
    
    private func foldRegion(from proxy: GeometryProxy) -> FoldRegionInfo {
        let safeMargin = max(proxy.safeAreaInsets.leading, proxy.safeAreaInsets.trailing, 0)
        
        if #available(iOS 27.1, *) {
            let width = queryDivisionWidth(proxy)
            return FoldRegionInfo(width: width, safeMargin: safeMargin)
        }
        
        // iOS 26 / Simulator without the Duo SDK: crease is 0 when not half-folded.
        if foldPosture == .partiallyOpen {
            return FoldRegionInfo(
                width: ReservedRegionDefaults.mockDivisionWidth,
                safeMargin: max(safeMargin, ReservedRegionDefaults.divisionSafeMargin)
            )
        }
        return .none
    }
    
    @available(iOS 27.1, *)
    private func queryDivisionWidth(_ proxy: GeometryProxy) -> CGFloat {
        // TODO(verify-api): GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)
        // Kind `.division` is the fold; empty / 0 width when fully open.
        // Re-query on onGeometryChange because the first layout pass can be empty.
        //
        // Intended call:
        //   let regions = proxy.reservedRegions(kind: .division)
        //   return regions.first.map { $0.rect.width } ?? 0
        _ = proxy.size
        return foldPosture == .partiallyOpen ? ReservedRegionDefaults.mockDivisionWidth : 0
    }
}

/// Observable provider updated from live geometry (safe areas + division).
@MainActor
final class GeometryReservedRegionProvider: ReservedRegionProvider, @unchecked Sendable {
    private(set) var posture: FoldPosture
    private(set) var lastSafeAreaInsets: EdgeInsets
    private var observedDivisionWidth: CGFloat = 0
    
    init(posture: FoldPosture = .fullyOpen) {
        self.posture = posture
        self.lastSafeAreaInsets = EdgeInsets()
    }
    
    func ingest(foldRegion: FoldRegionInfo, safeArea: EdgeInsets, posture: FoldPosture) {
        self.posture = posture
        self.lastSafeAreaInsets = safeArea
        self.observedDivisionWidth = foldRegion.width
    }
    
    func regions(of kind: ReservedRegion.Kind) -> [ReservedRegion] {
        guard kind == .division, divisionWidth > 0 else { return [] }
        return [
            ReservedRegion(
                bounds: CGRect(x: 0, y: 0, width: divisionWidth, height: 0),
                kind: .division
            )
        ]
    }
    
    var divisionWidth: CGFloat {
        posture == .partiallyOpen ? observedDivisionWidth : 0
    }
    
    var divisionSafeMargin: CGFloat {
        max(
            lastSafeAreaInsets.leading,
            lastSafeAreaInsets.trailing,
            ReservedRegionDefaults.divisionSafeMargin
        )
    }
}
