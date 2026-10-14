import Testing
import Foundation
@testable import Store

@Suite("MockStoreManager Tests")
struct MockStoreManagerTests {
    
    @Test("Initial state has no entitlements")
    func testInitialState() async {
        let store = MockStoreManager()
        
        let hasPro = await store.hasEntitlement(.pro)
        #expect(hasPro == false)
    }
    
    @Test("Purchase grants entitlement")
    func testPurchase() async throws {
        let store = MockStoreManager()
        
        let result = try await store.purchase(.pro)
        
        #expect(result == .purchased)
        let hasPro = await store.hasEntitlement(.pro)
        #expect(hasPro == true)
    }
    
    @Test("Grant entitlement directly")
    func testGrant() async {
        let store = MockStoreManager()
        
        await store.grant(.pro)
        
        let hasPro = await store.hasEntitlement(.pro)
        #expect(hasPro == true)
    }
    
    @Test("Revoke entitlement")
    func testRevoke() async {
        let store = MockStoreManager()
        await store.grant(.pro)
        
        await store.revoke(.pro)
        
        let hasPro = await store.hasEntitlement(.pro)
        #expect(hasPro == false)
    }
    
    @Test("Current entitlements")
    func testCurrentEntitlements() async {
        let store = MockStoreManager()
        await store.grant(.pro)
        
        let entitlements = await store.currentEntitlements()
        
        #expect(entitlements.contains(.pro))
    }
}

@Suite("ProductID Tests")
struct ProductIDTests {
    
    @Test("ProductID raw values")
    func testRawValues() {
        #expect(ProductID.pro.rawValue == "com.jackyu.duocamerakit.pro")
    }
}

@Suite("Entitlement Tests")
struct EntitlementTests {
    
    @Test("Entitlement display names")
    func testDisplayNames() {
        #expect(Entitlement.pro.displayName == "Camera Kit Pro")
    }
}

@Suite("PurchaseState Tests")
struct PurchaseStateTests {
    
    @Test("PurchaseState equality")
    func testEquality() {
        #expect(PurchaseState.notPurchased == PurchaseState.notPurchased)
        #expect(PurchaseState.purchased == PurchaseState.purchased)
        #expect(PurchaseState.pending == PurchaseState.pending)
        #expect(PurchaseState.failed("a") == PurchaseState.failed("a"))
        #expect(PurchaseState.failed("a") != PurchaseState.failed("b"))
    }
}

@Suite("ProFeatures Tests")
struct ProFeaturesTests {
    
    @Test("Pro tripod modes")
    func testProTripodModes() {
        #expect(ProFeatures.requiresPro(mode: "longExposure") == true)
        #expect(ProFeatures.requiresPro(mode: "starTrails") == true)
        #expect(ProFeatures.requiresPro(mode: "palmTrigger") == true)
        #expect(ProFeatures.requiresPro(mode: "timelapse") == false)
    }
    
    @Test("Pro features list")
    func testFeaturesList() {
        #expect(ProFeatures.features.count >= 5)
        #expect(ProFeatures.features.contains("ProRes video"))
        #expect(ProFeatures.features.contains("Auto-return of originals"))
    }
}
