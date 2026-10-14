import SwiftUI
import FoldKit
import LinkKit
import CameraKit
import TripodKit
import Library
import Store

@main
struct DuoCameraKitApp: App {
    @State private var foldStateProvider: any FoldStateProvider = DuoCameraKitApp.makeFoldStateProvider()
    @State private var storeManager: any StoreManager = DuoCameraKitApp.makeStoreManager()
    
    var body: some Scene {
        WindowGroup {
            rootedContent
        }
    }
    
    @ViewBuilder
    private var rootedContent: some View {
        let content = ContentView()
            .environment(\.foldStateProvider, foldStateProvider)
            .environment(\.storeManager, storeManager)
            .duoLayout(foldState: foldStateProvider.state)
            .preferredColorScheme(.dark)
            .onAppear {
                configureMockStateFromLaunchArguments()
                #if DEBUG
                logRuntimeDisplayInfo()
                #endif
            }
        
        if let system = foldStateProvider as? SystemFoldStateProvider {
            content.hingeBridge(system)
        } else {
            content
        }
    }
    
    private static func makeFoldStateProvider() -> any FoldStateProvider {
        if shouldUseMockFoldState() != nil {
            return MockFoldStateProvider()
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestMode") {
            return MockFoldStateProvider()
        }
        #endif
        if DuoAPIAvailability.hingeAPIsAvailable {
            return SystemFoldStateProvider()
        }
        #if DEBUG
        return MockFoldStateProvider()
        #else
        return SystemFoldStateProvider()
        #endif
    }
    
    private static func makeStoreManager() -> any StoreManager {
        #if canImport(StoreKit)
        return StoreKitStore()
        #else
        return MockStoreManager()
        #endif
    }
    
    /// Configure mock fold state from launch arguments for testing
    private func configureMockStateFromLaunchArguments() {
        guard let mockConfig = shouldUseMockFoldState(),
              let mock = foldStateProvider as? MockFoldStateProvider else {
            if let system = foldStateProvider as? SystemFoldStateProvider {
                if !DuoAPIAvailability.hingeAPIsAvailable {
                    system.ingestNoHinge()
                }
            } else if let mock = foldStateProvider as? MockFoldStateProvider {
                #if DEBUG
                mock.set(.partiallyOpen, angle: 110)
                #endif
            }
            return
        }
        
        switch mockConfig {
        case .fixed(let posture, let angle):
            mock.set(posture, angle: angle)
        case .sweep(let from, let to, let duration):
            Task {
                await mock.sweep(from: from, to: to, duration: duration)
            }
        case .script:
            break
        }
    }
}

// MARK: - Environment Keys

private struct FoldStateProviderKey: EnvironmentKey {
    static let defaultValue: any FoldStateProvider = MockFoldStateProvider()
}

private struct StoreManagerKey: EnvironmentKey {
    static let defaultValue: any StoreManager = MockStoreManager()
}

private struct DeviceRoleKey: EnvironmentKey {
    static let defaultValue: DeviceRole? = nil
}

extension EnvironmentValues {
    var foldStateProvider: any FoldStateProvider {
        get { self[FoldStateProviderKey.self] }
        set { self[FoldStateProviderKey.self] = newValue }
    }
    
    var storeManager: any StoreManager {
        get { self[StoreManagerKey.self] }
        set { self[StoreManagerKey.self] = newValue }
    }
    
    var deviceRole: DeviceRole? {
        get { self[DeviceRoleKey.self] }
        set { self[DeviceRoleKey.self] = newValue }
    }
}
