import SwiftUI
import FoldKit

struct ContentView: View {
    @Environment(\.foldStateProvider) private var foldStateProvider
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home
        case gallery
    }
    
    var body: some View {
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
        .tint(Color.accentYellow)
    }
}

extension Color {
    static let accentYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
}

#Preview {
    ContentView()
}
