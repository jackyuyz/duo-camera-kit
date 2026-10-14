import SwiftUI
import LinkKit

struct DiagnosticsView: View {
    @State private var latencyMs: Double = 45
    @State private var bitrateKbps: Int = 3200
    @State private var clockOffsetMs: Int64 = 5
    @State private var packetLoss: Double = 0.1
    
    var body: some View {
        List {
            Section("Connection") {
                DiagnosticRow(label: "Status", value: "Connected", color: .green)
                DiagnosticRow(label: "Peer", value: "iPhone 15 Pro")
                DiagnosticRow(label: "Protocol", value: "v1.0")
            }
            
            Section("Latency") {
                DiagnosticRow(label: "Current", value: String(format: "%.0f ms", latencyMs))
                DiagnosticRow(label: "Average", value: "48 ms")
                DiagnosticRow(label: "P95", value: "85 ms")
            }
            
            Section("Bandwidth") {
                DiagnosticRow(label: "Bitrate", value: "\(bitrateKbps) kbps")
                DiagnosticRow(label: "Quality", value: "720p30")
                DiagnosticRow(label: "Packet Loss", value: String(format: "%.1f%%", packetLoss))
            }
            
            Section("Clock Sync") {
                DiagnosticRow(label: "Offset", value: "\(clockOffsetMs) ms")
                DiagnosticRow(label: "Jitter", value: "2 ms")
                DiagnosticRow(label: "Quality", value: "Good", color: .green)
            }
            
            Section("Device") {
                DiagnosticRow(label: "Thermal", value: "Normal", color: .green)
                DiagnosticRow(label: "Battery", value: "85%")
                DiagnosticRow(label: "Storage", value: "45.2 GB free")
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DiagnosticRow: View {
    let label: String
    let value: String
    var color: Color? = nil
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(color ?? .secondary)
        }
    }
}

#Preview {
    NavigationStack {
        DiagnosticsView()
    }
}
