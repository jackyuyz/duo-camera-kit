import SwiftUI
import LinkKit

struct LensDeviceView: View {
    @State private var pairingCode = PairingCode()
    @State private var connectionState: ConnectionState = .disconnected
    @State private var lensStatus = LensStatus.mock
    
    var body: some View {
        VStack(spacing: 24) {
            switch connectionState {
            case .disconnected, .searching:
                waitingForControlView
            case .connecting:
                connectingView
            case .connected:
                connectedView
            case .failed(let reason):
                failedView(reason: reason)
            }
        }
        .padding()
        .background(Color.black)
        .navigationTitle("Lens")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var waitingForControlView: some View {
        VStack(spacing: 32) {
            Image(systemName: "qrcode")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 16) {
                Text("Pairing Code")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text(pairingCode.displayString)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                
                Text("Enter this code on your other iPhone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if !pairingCode.isValid {
                Button("Generate New Code") {
                    pairingCode = PairingCode()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            statusBar
        }
    }
    
    private var connectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Connecting...")
                .font(.headline)
        }
    }
    
    private var connectedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Connected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This iPhone is now a remote camera")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            statusBar
            
            Text("Keep this app open")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func failedView(reason: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            
            Text("Connection Failed")
                .font(.headline)
            
            Text(reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                connectionState = .disconnected
                pairingCode = PairingCode()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var statusBar: some View {
        HStack(spacing: 24) {
            Label("\(Int(lensStatus.battery * 100))%", systemImage: "battery.100")
                .foregroundStyle(lensStatus.battery > 0.2 ? .green : .red)
            
            Label(lensStatus.thermalDescription, systemImage: "thermometer.medium")
                .foregroundStyle(lensStatus.isThermalWarning ? .orange : .secondary)
            
            Label(lensStatus.freeStorageFormatted, systemImage: "internaldrive")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding()
        .background(Color.gray.opacity(0.2))
        .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        LensDeviceView()
    }
}
