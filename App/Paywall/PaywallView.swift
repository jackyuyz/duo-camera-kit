import SwiftUI
import Store

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    featuresSection
                    
                    purchaseSection
                }
                .padding()
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
            
            Text("One-time purchase. No subscription.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
            Button {
                isPurchasing = true
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    isPurchasing = false
                    dismiss()
                }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    VStack {
                        Text("$7.99")
                            .font(.title2.bold())
                        Text("Launch Price (Regular $9.99)")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isPurchasing)
            
            Text("One-time purchase. Works on all your devices with the same Apple Account.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    PaywallView()
}
