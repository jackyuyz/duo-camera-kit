import SwiftUI
import FoldKit

struct HomeView: View {
    @Environment(\.foldStateProvider) private var foldStateProvider
    @Environment(\.displayContext) private var displayContext
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            Group {
                switch displayContext {
                case .inner(.fullyOpen):
                    flatLayout
                case .inner(.partiallyOpen):
                    tentLayout
                default:
                    standardLayout
                }
            }
            .background(Color.black)
            .navigationTitle("Duo Camera Kit")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
    
    // MARK: - Flat Layout (Fully Open)
    
    /// Side-by-side cards on the inner display
    private var flatLayout: some View {
        GeometryReader { geometry in
            let halfWidth = (geometry.size.width - DuoDisplay.foldRegionWidth - DuoDisplay.foldSafeMargin * 2) / 2
            
            HStack(spacing: 0) {
                VStack(spacing: 16) {
                    headerSection
                    
                    NavigationLink {
                        LensRolePickerView()
                    } label: {
                        LargeModuleCard(
                            title: "Lens",
                            subtitle: "Remote telephoto",
                            iconName: "camera.on.rectangle",
                            gradient: [.blue, .purple]
                        )
                    }
                    
                    Spacer()
                    
                    foldStateCard
                }
                .frame(width: halfWidth)
                .padding(.trailing, DuoDisplay.foldSafeMargin)
                
                Spacer()
                    .frame(width: DuoDisplay.foldRegionWidth)
                
                VStack(spacing: 16) {
                    Spacer()
                        .frame(height: 60)
                    
                    NavigationLink {
                        TripodModePickerView()
                    } label: {
                        LargeModuleCard(
                            title: "Tripod",
                            subtitle: "Use hinge as stand",
                            iconName: "camera.aperture",
                            gradient: [.orange, .red]
                        )
                    }
                    
                    Spacer()
                    
                    quickActionsCard
                }
                .frame(width: halfWidth)
                .padding(.leading, DuoDisplay.foldSafeMargin)
            }
            .padding()
        }
    }
    
    // MARK: - Tent Layout (Partially Open)
    
    private var tentLayout: some View {
        GeometryReader { geometry in
            let halfHeight = (geometry.size.height - DuoDisplay.foldRegionWidth) / 2
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        headerSection
                        moduleCards
                    }
                    .padding()
                }
                .frame(height: halfHeight)
                
                Spacer()
                    .frame(height: DuoDisplay.foldRegionWidth)
                
                VStack(spacing: 16) {
                    foldStateCard
                    quickActionsCard
                    Spacer()
                }
                .padding()
                .frame(height: halfHeight)
            }
        }
    }
    
    // MARK: - Standard Layout (Non-Duo or Closed)
    
    private var standardLayout: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                moduleCards
                foldStateCard
            }
            .padding()
        }
    }
    
    // MARK: - Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Transform your old iPhone into a telephoto lens, or use your Duo as a tripod")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var moduleCards: some View {
        VStack(spacing: 16) {
            NavigationLink {
                LensRolePickerView()
            } label: {
                ModuleCard(
                    title: "Lens Mode",
                    subtitle: "Use your old iPhone as a telephoto camera",
                    iconName: "camera.on.rectangle",
                    gradient: [.blue, .purple]
                )
            }
            
            NavigationLink {
                TripodModePickerView()
            } label: {
                ModuleCard(
                    title: "Tripod Mode",
                    subtitle: "Time-lapse, long exposure, and more",
                    iconName: "camera.aperture",
                    gradient: [.orange, .red]
                )
            }
        }
    }
    
    private var foldStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Device Status")
                .font(.headline)
            
            HStack {
                let state = foldStateProvider.state
                Image(systemName: state.hasHinge ? "rectangle.portrait.rotate" : "iphone")
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading) {
                    Text(state.posture.displayName)
                        .font(.subheadline)
                    if let angle = state.angleDegrees {
                        Text(String(format: "%.0f°", angle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if state.hasHinge {
                    Text(displayContext.description)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentYellow.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Start")
                .font(.headline)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Time-lapse",
                    icon: "timer"
                ) {
                }
                
                QuickActionButton(
                    title: "Long Exp",
                    icon: "camera.aperture"
                ) {
                }
            }
        }
    }
}

struct LargeModuleCard: View {
    let title: String
    let subtitle: String
    let iconName: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct ModuleCard: View {
    let title: String
    let subtitle: String
    let iconName: String
    let gradient: [Color]
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .foregroundStyle(.white)
    }
}

extension FoldPosture {
    var displayName: String {
        switch self {
        case .noHinge: return "Standard iPhone"
        case .closed: return "Closed"
        case .partiallyOpen: return "Partially Open"
        case .fullyOpen: return "Fully Open"
        case .unknown: return "Unknown"
        }
    }
}

extension DisplayContext {
    var description: String {
        switch self {
        case .inner(.fullyOpen): return "Inner Display"
        case .inner(.partiallyOpen): return "Tent Mode"
        case .inner: return "Inner Display"
        case .outer: return "Cover Display"
        case .standard: return "Standard"
        }
    }
}

#Preview("Flat (Fully Open)") {
    HomeView()
        .environment(\.displayContext, .inner(.fullyOpen))
}

#Preview("Tent (Partially Open)") {
    HomeView()
        .environment(\.displayContext, .inner(.partiallyOpen))
}

#Preview("Standard") {
    HomeView()
        .environment(\.displayContext, .standard)
}
