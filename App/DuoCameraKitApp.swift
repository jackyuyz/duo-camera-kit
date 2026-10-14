import SwiftUI
import FoldKit
import LinkKit
import CameraKit
import TripodKit
import Library
import Store

@main
struct DuoCameraKitApp: App {
    @State private var foldStateProvider = MockFoldStateProvider()
    @State private var storeManager = MockStoreManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.foldStateProvider, foldStateProvider)
                .preferredColorScheme(.dark)
        }
    }
}

private struct FoldStateProviderKey: EnvironmentKey {
    static let defaultValue: any FoldStateProvider = MockFoldStateProvider()
}

extension EnvironmentValues {
    var foldStateProvider: any FoldStateProvider {
        get { self[FoldStateProviderKey.self] }
        set { self[FoldStateProviderKey.self] = newValue }
    }
}
