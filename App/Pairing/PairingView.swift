import SwiftUI
import LinkKit

struct PairingView: View {
    @Binding var connectionState: ConnectionState
    var onConnected: () -> Void
    
    @State private var enteredCode = ""
    @State private var isScanning = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                headerSection
                
                codeEntrySection
                
                searchingSection
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            .navigationTitle("Pair Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            Text("Connect to Lens Device")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Open Duo Camera Kit on your other iPhone and select 'Lens' mode")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var codeEntrySection: some View {
        VStack(spacing: 16) {
            Text("Enter Pairing Code")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    CodeDigitField(
                        digit: index < enteredCode.count ? String(enteredCode[enteredCode.index(enteredCode.startIndex, offsetBy: index)]) : ""
                    )
                }
            }
            
            numberPad
            
            Button {
                if enteredCode.count == 6 {
                    connectionState = .connecting
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        connectionState = .connected
                        onConnected()
                    }
                }
            } label: {
                Text("Connect")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentYellow)
            .disabled(enteredCode.count < 6)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var numberPad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
            ForEach(1...9, id: \.self) { number in
                numberButton(String(number))
            }
            
            Spacer()
            
            numberButton("0")
            
            Button {
                if !enteredCode.isEmpty {
                    enteredCode.removeLast()
                }
            } label: {
                Image(systemName: "delete.left")
                    .font(.title2)
                    .frame(width: 60, height: 44)
            }
        }
    }
    
    private func numberButton(_ digit: String) -> some View {
        Button {
            if enteredCode.count < 6 {
                enteredCode.append(digit)
            }
        } label: {
            Text(digit)
                .font(.title2)
                .frame(width: 60, height: 44)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .foregroundStyle(.white)
    }
    
    @ViewBuilder
    private var searchingSection: some View {
        if connectionState == .searching {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Searching for nearby devices...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("Make sure both devices are on the same Wi-Fi network or have Wi-Fi enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

struct CodeDigitField: View {
    let digit: String
    
    var body: some View {
        Text(digit.isEmpty ? " " : digit)
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .frame(width: 44, height: 56)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(digit.isEmpty ? Color.gray.opacity(0.3) : Color.accentYellow, lineWidth: 2)
            )
    }
}

#Preview {
    PairingView(
        connectionState: .constant(.searching),
        onConnected: {}
    )
}
