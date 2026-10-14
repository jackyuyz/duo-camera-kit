import SwiftUI
import FoldKit

/// A split view that adapts to Duo's fold state
/// - Fully open: side-by-side with fold region avoided
/// - Partially open: top/bottom split (tent/stand mode)
/// - Closed: primary only on outer display
struct DuoSplitView<Primary: View, Secondary: View>: View {
    @Environment(\.displayContext) private var displayContext
    @Environment(\.hingeAngle) private var hingeAngle
    
    let primary: Primary
    let secondary: Secondary
    
    /// Whether to flip primary/secondary in tent mode
    var flipInTentMode: Bool = false
    
    init(
        flipInTentMode: Bool = false,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.flipInTentMode = flipInTentMode
        self.primary = primary()
        self.secondary = secondary()
    }
    
    var body: some View {
        GeometryReader { geometry in
            switch displayContext {
            case .outer:
                outerLayout
                
            case .inner(.partiallyOpen):
                tentLayout(in: geometry)
                
            case .inner(.fullyOpen):
                flatLayout(in: geometry)
                
            case .inner:
                flatLayout(in: geometry)
                
            case .standard:
                standardLayout
            }
        }
    }
    
    /// Outer display: show only primary content, compact
    private var outerLayout: some View {
        primary
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Tent/stand mode: vertical split, respecting hinge
    private func tentLayout(in geometry: GeometryProxy) -> some View {
        let halfHeight = (geometry.size.height - DuoDisplay.foldRegionWidth) / 2
        let shouldFlip = flipInTentMode
        
        return VStack(spacing: 0) {
            Group {
                if shouldFlip {
                    secondary
                } else {
                    primary
                }
            }
            .frame(height: halfHeight)
            
            Spacer()
                .frame(height: DuoDisplay.foldRegionWidth)
            
            Group {
                if shouldFlip {
                    primary
                } else {
                    secondary
                }
            }
            .frame(height: halfHeight)
        }
    }
    
    /// Flat/fully open: horizontal split avoiding fold
    private func flatLayout(in geometry: GeometryProxy) -> some View {
        let halfWidth = (geometry.size.width - DuoDisplay.foldRegionWidth - DuoDisplay.foldSafeMargin * 2) / 2
        
        return HStack(spacing: 0) {
            primary
                .frame(width: halfWidth)
                .padding(.trailing, DuoDisplay.foldSafeMargin)
            
            Spacer()
                .frame(width: DuoDisplay.foldRegionWidth)
            
            secondary
                .frame(width: halfWidth)
                .padding(.leading, DuoDisplay.foldSafeMargin)
        }
    }
    
    /// Standard iPhone: stack vertically or use bottom sheet
    private var standardLayout: some View {
        VStack(spacing: 0) {
            primary
                .frame(maxHeight: .infinity)
            
            secondary
                .frame(height: 200)
        }
    }
}

/// A view that spans both halves when flat, or shows on one half when folded
struct DuoFullView<Content: View>: View {
    @Environment(\.displayContext) private var displayContext
    
    let content: Content
    
    /// Which half to show on when in tent mode
    var tentPosition: TentPosition = .top
    
    enum TentPosition {
        case top, bottom
    }
    
    init(
        tentPosition: TentPosition = .top,
        @ViewBuilder content: () -> Content
    ) {
        self.tentPosition = tentPosition
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            switch displayContext {
            case .inner(.partiallyOpen):
                tentLayout(in: geometry)
            default:
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func tentLayout(in geometry: GeometryProxy) -> some View {
        let halfHeight = (geometry.size.height - DuoDisplay.foldRegionWidth) / 2
        
        return VStack(spacing: 0) {
            if tentPosition == .top {
                content
                    .frame(height: halfHeight)
                Spacer()
            } else {
                Spacer()
                content
                    .frame(height: halfHeight)
            }
        }
    }
}

#Preview("Flat Layout") {
    DuoSplitView {
        Color.blue.opacity(0.3)
            .overlay(Text("Primary"))
    } secondary: {
        Color.green.opacity(0.3)
            .overlay(Text("Secondary"))
    }
    .environment(\.displayContext, .inner(.fullyOpen))
}

#Preview("Tent Layout") {
    DuoSplitView {
        Color.blue.opacity(0.3)
            .overlay(Text("Primary"))
    } secondary: {
        Color.green.opacity(0.3)
            .overlay(Text("Secondary"))
    }
    .environment(\.displayContext, .inner(.partiallyOpen))
}

#Preview("Outer Display") {
    DuoSplitView {
        Color.blue.opacity(0.3)
            .overlay(Text("Primary"))
    } secondary: {
        Color.green.opacity(0.3)
            .overlay(Text("Secondary"))
    }
    .environment(\.displayContext, .outer)
}
