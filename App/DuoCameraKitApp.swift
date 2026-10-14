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
                .duoLayout(foldState: foldStateProvider.state)
                .preferredColorScheme(.dark)
                .onAppear {
                    configureMockStateFromLaunchArguments()
                }
        }
    }
    
    /// Configure mock fold state from launch arguments for testing
    private func configureMockStateFromLaunchArguments() {
        if let mockConfig = shouldUseMockFoldState() {
            switch mockConfig {
            case .fixed(let posture, let angle):
                foldStateProvider.set(posture, angle: angle)
            case .sweep(let from, let to, let duration):
                Task {
                    await foldStateProvider.sweep(from: from, to: to, duration: duration)
                }
            case .script:
                break
            }
        } else {
            #if DEBUG
            foldStateProvider.set(.partiallyOpen, angle: 110)
            #endif
        }
    }
}

// MARK: - Environment Keys

private struct FoldStateProviderKey: EnvironmentKey {
    static let defaultValue: any FoldStateProvider = MockFoldStateProvider()
}

extension EnvironmentValues {
    var foldStateProvider: any FoldStateProvider {
        get { self[FoldStateProviderKey.self] }
        set { self[FoldStateProviderKey.self] = newValue }
    }
}
