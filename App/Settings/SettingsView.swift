import SwiftUI
import Store

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.storeManager) private var storeManager
    @Environment(\.deviceRole) private var deviceRole
    
    @State private var previewQuality = "720p"
    @State private var autoTransfer = false
    @State private var hasPro = false
    
    private var isLensRole: Bool { deviceRole == .lens }
    
    var body: some View {
        NavigationStack {
            List {
                Section("General") {
                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        Label("Diagnostics", systemImage: "waveform.path.ecg")
                    }
                }
                
                Section("Lens Mode") {
                    Picker("Preview Quality", selection: $previewQuality) {
                        Text("540p (Low)").tag("540p")
                        Text("720p (Medium)").tag("720p")
                        Text("1080p (High)").tag("1080p")
                    }
                    
                    Toggle("Auto-return originals", isOn: $autoTransfer)
                        .disabled(!hasPro && !isLensRole)
                    
                    if !hasPro && !isLensRole {
                        Text("Auto-return of full-resolution files is a Pro feature.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if !isLensRole {
                    Section("Purchases") {
                        NavigationLink {
                            PaywallView()
                        } label: {
                            Label(hasPro ? "Camera Kit Pro (Unlocked)" : "Camera Kit Pro", systemImage: "star.fill")
                                .foregroundStyle(.orange)
                        }
                        
                        Button("Restore Purchases") {
                            Task {
                                try? await storeManager.restorePurchases()
                                hasPro = await storeManager.hasEntitlement(.pro)
                            }
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Minimum iOS")
                        Spacer()
                        Text("26.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                hasPro = await storeManager.hasEntitlement(.pro)
                if !hasPro { autoTransfer = false }
            }
        }
    }
}

#Preview {
    SettingsView()
}
