import SwiftUI
import FoldKit

struct HomeView: View {
    @Environment(\.foldStateProvider) private var foldStateProvider
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    moduleCards
                    
                    foldStateInfo
                }
                .padding()
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
    
    private var foldStateInfo: some View {
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
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
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

#Preview {
    HomeView()
}
