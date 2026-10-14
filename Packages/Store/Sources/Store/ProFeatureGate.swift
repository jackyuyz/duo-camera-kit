import Foundation

/// Features that require Camera Kit Pro on the **Control** device.
/// The Lens role never consults entitlements (Pro is checked only on Control).
public enum ProGatedFeature: String, Sendable, CaseIterable {
    /// Photos above the free 12 MP cap
    case fullResolution
    /// Apple ProRAW
    case proRAW
    /// Apple ProRes video
    case proRes
    /// Automatic file return after capture
    case autoTransfer
    /// 4K (and above 1080p30) video
    case fourKVideo
    /// Two-angle sync recording
    case syncRecording
    /// Time-lapse longer than 10 minutes
    case unlimitedTimelapse
    case longExposure
    case starTrails
    case palmTrigger
}

/// Who is asking for a Pro feature.
public enum EntitlementAudience: String, Sendable, Equatable {
    /// Controlling Duo (or any Control iPhone). Entitlements apply.
    case control
    /// Lens phone. Entitlements are ignored — Lens role is always free.
    case lens
}

/// Maps StoreKit 2 `Transaction.currentEntitlements` into app entitlements.
///
/// Family Sharing: when the non-consumable is family-shareable in App Store Connect,
/// `Transaction.currentEntitlements` includes the purchase on every device signed
/// into the same Apple ID (and Family Sharing members). No server is required.
public struct EntitlementResolver: Sendable {
    public init() {}
    
    /// A verified, non-revoked transaction for a product ID.
    public struct TransactionSnapshot: Sendable, Equatable {
        public var productID: String
        public var isVerified: Bool
        public var isRevoked: Bool
        /// True when StoreKit reports this transaction as family-shared
        /// (`Transaction.ownershipType == .familyShared`) or the original purchaser.
        public var ownershipType: OwnershipType
        
        public enum OwnershipType: String, Sendable, Equatable {
            case purchased
            case familyShared
        }
        
        public init(
            productID: String,
            isVerified: Bool,
            isRevoked: Bool,
            ownershipType: OwnershipType = .purchased
        ) {
            self.productID = productID
            self.isVerified = isVerified
            self.isRevoked = isRevoked
            self.ownershipType = ownershipType
        }
    }
    
    /// Recompute entitlements from StoreKit 2 current entitlements.
    /// `.unverified` grants nothing. `revocationDate != nil` removes Pro.
    public func entitlements(from snapshots: [TransactionSnapshot]) -> Set<Entitlement> {
        var result: Set<Entitlement> = []
        for snapshot in snapshots {
            guard snapshot.isVerified, !snapshot.isRevoked else { continue }
            if snapshot.productID == ProductID.pro.rawValue {
                result.insert(.pro)
            }
        }
        return result
    }
    
    /// Both paired phones with the same Apple ID unlock from the same entitlement set.
    public func isUnlockedOnPairedDevices(entitlements: Set<Entitlement>) -> Bool {
        entitlements.contains(.pro)
    }
}

/// Gates Pro-only capture and transfer features.
public struct ProFeatureGate: Sendable, Equatable {
    public var hasPro: Bool
    public var audience: EntitlementAudience
    
    public init(hasPro: Bool, audience: EntitlementAudience) {
        self.hasPro = hasPro
        self.audience = audience
    }
    
    /// Lens role always allows requested capture (Control already gated the command).
    public var isEffectivelyPro: Bool {
        audience == .lens || hasPro
    }
    
    public func isAllowed(_ feature: ProGatedFeature) -> Bool {
        isEffectivelyPro
    }
    
    /// Free tier: photos up to 12 MP.
    public static let freeMaxMegapixels = 12
    
    /// Free tier: video up to 1080p30.
    public static let freeMaxVideoHeight = 1080
    public static let freeMaxVideoFPS = 30
    
    /// Cap a requested photo size to the free 12 MP limit when Pro is locked.
    public func photoPixelSize(width: Int, height: Int) -> (width: Int, height: Int) {
        guard !isAllowed(.fullResolution) else { return (width, height) }
        let megapixels = Double(width * height) / 1_000_000.0
        guard megapixels > Double(Self.freeMaxMegapixels) else { return (width, height) }
        let scale = sqrt(Double(Self.freeMaxMegapixels) / megapixels)
        return (Int(Double(width) * scale), Int(Double(height) * scale))
    }
}

/// Cached last-known Pro flag to avoid a paywall flash offline.
/// Always re-verify from `Transaction.currentEntitlements` when available.
public enum EntitlementCache {
    public static let userDefaultsKey = "com.jackyu.duocamerakit.cachedPro"
    
    public static func read(from defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: userDefaultsKey)
    }
    
    public static func write(_ hasPro: Bool, to defaults: UserDefaults = .standard) {
        defaults.set(hasPro, forKey: userDefaultsKey)
    }
}
