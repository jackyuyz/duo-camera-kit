import Testing
import Foundation
@testable import Store

@Suite("EntitlementResolver Tests")
struct EntitlementResolverTests {
    
    let resolver = EntitlementResolver()
    
    @Test("Verified Pro transaction unlocks")
    func verifiedUnlocks() {
        let snapshots = [
            EntitlementResolver.TransactionSnapshot(
                productID: ProductID.pro.rawValue,
                isVerified: true,
                isRevoked: false,
                ownershipType: .purchased
            )
        ]
        #expect(resolver.entitlements(from: snapshots).contains(.pro))
    }
    
    @Test("Family-shared transaction unlocks both paired phones")
    func familySharedUnlocks() {
        let snapshots = [
            EntitlementResolver.TransactionSnapshot(
                productID: ProductID.pro.rawValue,
                isVerified: true,
                isRevoked: false,
                ownershipType: .familyShared
            )
        ]
        let entitlements = resolver.entitlements(from: snapshots)
        #expect(entitlements.contains(.pro))
        #expect(resolver.isUnlockedOnPairedDevices(entitlements: entitlements))
    }
    
    @Test("Unverified grants nothing")
    func unverifiedGrantsNothing() {
        let snapshots = [
            EntitlementResolver.TransactionSnapshot(
                productID: ProductID.pro.rawValue,
                isVerified: false,
                isRevoked: false
            )
        ]
        #expect(resolver.entitlements(from: snapshots).isEmpty)
    }
    
    @Test("Revoked removes Pro")
    func revokedRemoves() {
        let snapshots = [
            EntitlementResolver.TransactionSnapshot(
                productID: ProductID.pro.rawValue,
                isVerified: true,
                isRevoked: true
            )
        ]
        #expect(resolver.entitlements(from: snapshots).isEmpty)
    }
}

@Suite("ProFeatureGate Tests")
struct ProFeatureGateTests {
    
    @Test("Control without Pro blocks gated features")
    func controlFreeBlocks() {
        let gate = ProFeatureGate(hasPro: false, audience: .control)
        #expect(!gate.isAllowed(.fullResolution))
        #expect(!gate.isAllowed(.proRAW))
        #expect(!gate.isAllowed(.proRes))
        #expect(!gate.isAllowed(.autoTransfer))
        #expect(!gate.isAllowed(.fourKVideo))
        #expect(!gate.isAllowed(.syncRecording))
    }
    
    @Test("Control with Pro allows gated features")
    func controlProAllows() {
        let gate = ProFeatureGate(hasPro: true, audience: .control)
        for feature in ProGatedFeature.allCases {
            #expect(gate.isAllowed(feature))
        }
    }
    
    @Test("Lens role never checks entitlements")
    func lensNeverGates() {
        let gate = ProFeatureGate(hasPro: false, audience: .lens)
        #expect(gate.isAllowed(.proRAW))
        #expect(gate.isAllowed(.fullResolution))
        #expect(gate.isAllowed(.autoTransfer))
        #expect(gate.isEffectivelyPro)
    }
    
    @Test("Free photo size caps at 12 MP")
    func caps12MP() {
        let gate = ProFeatureGate(hasPro: false, audience: .control)
        let capped = gate.photoPixelSize(width: 8000, height: 6000)
        let mp = Double(capped.width * capped.height) / 1_000_000.0
        #expect(mp <= Double(ProFeatureGate.freeMaxMegapixels) + 0.05)
        
        let pro = ProFeatureGate(hasPro: true, audience: .control)
        let full = pro.photoPixelSize(width: 8000, height: 6000)
        #expect(full.width == 8000)
        #expect(full.height == 6000)
    }
}

@Suite("EntitlementCache Tests")
struct EntitlementCacheTests {
    
    @Test("Round-trip cache")
    func roundTrip() {
        let defaults = UserDefaults(suiteName: "EntitlementCacheTests.\(UUID().uuidString)")!
        EntitlementCache.write(true, to: defaults)
        #expect(EntitlementCache.read(from: defaults) == true)
        EntitlementCache.write(false, to: defaults)
        #expect(EntitlementCache.read(from: defaults) == false)
    }
}

#if canImport(StoreKitTest) && canImport(StoreKit)
import StoreKit
import StoreKitTest

/// StoreKit 2 tests using SKTestSession. Apple platforms only; skipped on Linux.
@Suite("StoreKitTest Session Tests")
struct StoreKit2SessionTests {
    
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Configuration")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }
    
    @Test("Configuration product is family-shareable non-consumable")
    func familyShareableProduct() async throws {
        _ = try makeSession()
        
        let products = try await Product.products(for: [ProductID.pro.rawValue])
        #expect(!products.isEmpty)
        #expect(products[0].id == ProductID.pro.rawValue)
        #expect(products[0].isFamilyShareable == true)
        #expect(products[0].type == .nonConsumable)
    }
    
    @Test("Purchase appears in Transaction.currentEntitlements on both devices")
    func purchaseUnlocksCurrentEntitlements() async throws {
        let session = try makeSession()
        try await session.buyProduct(identifier: ProductID.pro.rawValue)
        
        var unlocked = false
        var ownership: Transaction.OwnershipType?
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == ProductID.pro.rawValue,
               transaction.revocationDate == nil {
                unlocked = true
                ownership = transaction.ownershipType
            }
        }
        #expect(unlocked)
        #expect(ownership == .purchased || ownership == .familyShared)
        
        let store = StoreKitStore()
        await store.refreshEntitlements()
        #expect(await store.hasEntitlement(.pro))
    }
}
#endif
