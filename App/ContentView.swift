import SwiftUI
import FoldKit

struct ContentView: View {
    @Environment(\.foldStateProvider) private var foldStateProvider
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home
        case gallery
    }
    
    private var displayContext: DisplayContext {
        displayContext(from: foldStateProvider.state)
    }
    
    var body: some View {
        Group {
            switch displayContext {
            case .outer:
                outerDisplayContent
            default:
                innerDisplayContent
            }
        }
        .duoLayout(foldState: foldStateProvider.state)
        .tint(Color.accentYellow)
    }
    
    /// Full app on inner display
    private var innerDisplayContent: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Camera", systemImage: "camera.fill")
                }
                .tag(Tab.home)
            
            GalleryView()
                .tabItem {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                }
                .tag(Tab.gallery)
        }
    }
    
    /// Compact layout for outer cover display
    private var outerDisplayContent: some View {
        OuterDisplayView()
    }
}

/// Compact UI for the outer cover display (when closed)
struct OuterDisplayView: View {
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 0) {
            cameraPreview
            compactControls
        }
        .background(Color.black)
    }
    
    private var cameraPreview: some View {
        ZStack {
            Color.gray.opacity(0.3)
            
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            VStack {
                HStack {
                    statusBadge
                    Spacer()
                }
                .padding(8)
                Spacer()
            }
        }
        .aspectRatio(DuoDisplay.outerAspectRatio, contentMode: .fit)
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isRecording ? .red : .green)
                .frame(width: 6, height: 6)
            Text(isRecording ? "REC" : "Ready")
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    private var compactControls: some View {
        HStack(spacing: 24) {
            Button {
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title3)
            }
            
            Button {
            } label: {
                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: 44, height: 44)
                    )
            }
            
            Button {
                isRecording.toggle()
            } label: {
                Circle()
                    .strokeBorder(isRecording ? .red : .white, lineWidth: 3)
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: isRecording ? 6 : 22)
                            .fill(isRecording ? .red : .red)
                            .frame(width: isRecording ? 22 : 44, height: isRecording ? 22 : 44)
                    )
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 16)
    }
}

extension Color {
    static let accentYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
}

#Preview("Inner Display") {
    ContentView()
        .environment(\.displayContext, .inner(.fullyOpen))
}

#Preview("Outer Display") {
    ContentView()
        .environment(\.displayContext, .outer)
        .frame(width: 200, height: 400)
}
