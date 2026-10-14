import SwiftUI
import Store

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var previewQuality = "720p"
    @State private var autoTransfer = true
    
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
                    
                    Toggle("Auto-transfer Captures", isOn: $autoTransfer)
                }
                
                Section("Purchases") {
                    NavigationLink {
                        PaywallView()
                    } label: {
                        Label("Camera Kit Pro", systemImage: "star.fill")
                            .foregroundStyle(.orange)
                    }
                    
                    Button("Restore Purchases") {
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
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
        }
    }
}

#Preview {
    SettingsView()
}
