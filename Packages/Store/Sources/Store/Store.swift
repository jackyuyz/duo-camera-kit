// Store: StoreKit 2 purchase management
// Platform-agnostic interfaces for testing

import Foundation

/// Product identifiers
public enum ProductID: String, Sendable, CaseIterable {
    /// Non-consumable, Family Sharing enabled in App Store Connect.
    case pro = "com.jackyu.duocamerakit.pro"
    
    /// StoreKit Configuration / App Store Connect display name
    public var referenceName: String { "Camera Kit Pro" }
}

/// Feature entitlements
public enum Entitlement: String, Sendable, CaseIterable {
    /// Pro features: full-res photos, ProRAW, 4K video, sync recording, all tripod modes
    case pro
    
    public var displayName: String {
        switch self {
        case .pro: return "Camera Kit Pro"
        }
    }
}

/// Purchase state
public enum PurchaseState: Sendable, Equatable {
    case notPurchased
    case purchased
    case pending
    case failed(String)
}

/// Protocol for store operations
public protocol StoreManager: AnyObject, Sendable {
    /// Currently active entitlements
    var entitlements: Set<Entitlement> { get }
    
    /// Whether a specific entitlement is active
    func hasEntitlement(_ entitlement: Entitlement) async -> Bool
    
    /// Purchase a product
    func purchase(_ productID: ProductID) async throws -> PurchaseState
    
    /// Restore purchases
    func restorePurchases() async throws
    
    /// Refresh entitlements
    func refreshEntitlements() async
}

/// Mock store for testing
public actor MockStoreManager: StoreManager {
    private var _entitlements: Set<Entitlement> = []
    
    public nonisolated var entitlements: Set<Entitlement> {
        []
    }
    
    public init() {}
    
    public func hasEntitlement(_ entitlement: Entitlement) async -> Bool {
        _entitlements.contains(entitlement)
    }
    
    public func purchase(_ productID: ProductID) async throws -> PurchaseState {
        switch productID {
        case .pro:
            _entitlements.insert(.pro)
            return .purchased
        }
    }
    
    public func restorePurchases() async throws {
    }
    
    public func refreshEntitlements() async {
    }
    
    /// For testing: grant an entitlement
    public func grant(_ entitlement: Entitlement) {
        _entitlements.insert(entitlement)
    }
    
    /// For testing: revoke an entitlement
    public func revoke(_ entitlement: Entitlement) {
        _entitlements.remove(entitlement)
    }
    
    /// For testing: check current entitlements
    public func currentEntitlements() -> Set<Entitlement> {
        _entitlements
    }
}

/// Store errors
public enum StoreError: Error, Sendable {
    case productNotFound
    case purchaseFailed(String)
    case userCancelled
    case pending
}

/// Pro feature gating helper
public struct ProFeatures: Sendable {
    /// Pro-only tripod modes
    public static let proTripodModes: Set<String> = [
        "longExposure", "starTrails", "palmTrigger"
    ]
    
    /// Check if a tripod mode requires pro
    public static func requiresPro(mode: String) -> Bool {
        proTripodModes.contains(mode)
    }
    
    /// Features included in pro
    public static let features: [String] = [
        "Full-resolution photos",
        "ProRAW capture",
        "ProRes video",
        "Auto-return of originals",
        "4K video transfer",
        "Two-angle sync recording",
        "Long exposure stacking",
        "Star trails mode",
        "Palm trigger capture",
        "Unlimited time-lapse duration"
    ]
}
