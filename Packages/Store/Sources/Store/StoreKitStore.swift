#if canImport(StoreKit)
import Foundation
import StoreKit

/// StoreKit 2 implementation.
///
/// - Loads `Product.products(for:)`
/// - Listens to `Transaction.updates`
/// - Recomputes entitlements from `Transaction.currentEntitlements`
/// - Unverified transactions grant nothing
/// - `revocationDate != nil` drops Pro immediately
/// - Family Sharing: enable for `com.jackyu.duocamerakit.pro` in App Store Connect.
///   `Transaction.currentEntitlements` then unlocks Pro on every device with the
///   same Apple ID (and family members) with no extra code path.
public final class StoreKitStore: StoreManager, @unchecked Sendable {
    private let lock = NSLock()
    private var _entitlements: Set<Entitlement>
    private var _products: [Product] = []
    private var _productIsFamilyShareable = false
    private var updatesTask: Task<Void, Never>?
    private let resolver = EntitlementResolver()
    private let defaults: UserDefaults
    
    public var entitlements: Set<Entitlement> {
        lock.withLock { _entitlements }
    }
    
    public var products: [Product] {
        lock.withLock { _products }
    }
    
    public var productIsFamilyShareable: Bool {
        lock.withLock { _productIsFamilyShareable }
    }
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self._entitlements = EntitlementCache.read(from: defaults) ? [.pro] : []
        updatesTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }
    
    public func hasEntitlement(_ entitlement: Entitlement) async -> Bool {
        entitlements.contains(entitlement)
    }
    
    public func purchase(_ productID: ProductID) async throws -> PurchaseState {
        if products.isEmpty {
            await loadProducts()
        }
        guard let product = products.first(where: { $0.id == productID.rawValue }) else {
            throw StoreError.productNotFound
        }
        
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .notPurchased
        @unknown default:
            return .failed("Unknown purchase result")
        }
    }
    
    public func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }
    
    public func refreshEntitlements() async {
        var snapshots: [EntitlementResolver.TransactionSnapshot] = []
        for await result in Transaction.currentEntitlements {
            switch result {
            case .unverified:
                continue
            case .verified(let transaction):
                let ownership: EntitlementResolver.TransactionSnapshot.OwnershipType =
                    transaction.ownershipType == .familyShared ? .familyShared : .purchased
                snapshots.append(
                    EntitlementResolver.TransactionSnapshot(
                        productID: transaction.productID,
                        isVerified: true,
                        isRevoked: transaction.revocationDate != nil,
                        ownershipType: ownership
                    )
                )
            }
        }
        let resolved = resolver.entitlements(from: snapshots)
        lock.withLock { _entitlements = resolved }
        EntitlementCache.write(resolved.contains(.pro), to: defaults)
    }
    
    private func loadProducts() async {
        do {
            let loaded = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            let family = loaded.first(where: { $0.id == ProductID.pro.rawValue })?.isFamilyShareable ?? false
            lock.withLock {
                _products = loaded
                _productIsFamilyShareable = family
            }
        } catch {
            lock.withLock { _products = [] }
        }
    }
    
    private func listenForTransactions() async {
        for await _ in Transaction.updates {
            await refreshEntitlements()
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.purchaseFailed("Unverified transaction")
        case .verified(let value):
            return value
        }
    }
}
#endif
