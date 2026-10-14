import SwiftUI
import Store

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.storeManager) private var storeManager
    @Environment(\.deviceRole) private var deviceRole
    
    @State private var isPurchasing = false
    @State private var purchaseState: PurchaseState = .notPurchased
    @State private var hasPro = false
    
    var body: some View {
        NavigationStack {
            Group {
                if deviceRole == .lens {
                    lensNeverPaywall
                } else {
                    paywallContent
                }
            }
            .background(Color.black)
            .navigationTitle("Camera Kit Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                hasPro = await storeManager.hasEntitlement(.pro)
            }
        }
    }
    
    /// Spec AC10: the Lens role never shows a paywall.
    private var lensNeverPaywall: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("The Lens role is always free")
                .font(.headline)
            Text("Pro is checked only on the controlling iPhone. One purchase on that Apple Account unlocks both phones.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var paywallContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                featuresSection
                purchaseSection
            }
            .padding()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            Text("Unlock All Features")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("One-time purchase. Family Sharing enabled. No subscription.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(ProFeatures.features, id: \.self) { feature in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    
                    Text(feature)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var purchaseSection: some View {
        VStack(spacing: 16) {
            if hasPro {
                Text("Pro Unlocked")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else {
                Button {
                    Task { await buy() }
                } label: {
                    if isPurchasing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        VStack {
                            Text("Unlock Camera Kit Pro")
                                .font(.headline)
                            Text("Price shown by the App Store")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isPurchasing)
            }
            
            Button("Restore Purchases") {
                Task {
                    try? await storeManager.restorePurchases()
                    hasPro = await storeManager.hasEntitlement(.pro)
                }
            }
            .font(.subheadline)
            
            Text("One-time purchase. Works on all your devices with the same Apple Account, including Family Sharing.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if case .pending = purchaseState {
                Text("Waiting for approval")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private func buy() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            purchaseState = try await storeManager.purchase(.pro)
            hasPro = await storeManager.hasEntitlement(.pro)
            if hasPro { dismiss() }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }
}

#Preview {
    PaywallView()
}
