import SwiftUI
import TripodKit
import FoldKit

struct TripodModePickerView: View {
    @Environment(\.foldStateProvider) private var foldStateProvider
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                standAssistantCard
                
                ForEach(TripodMode.allCases, id: \.self) { mode in
                    NavigationLink {
                        TripodCaptureView(mode: mode)
                    } label: {
                        TripodModeCard(
                            mode: mode,
                            isEnabled: isModeEnabled(mode)
                        )
                    }
                    .disabled(!isModeEnabled(mode))
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Tripod Mode")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var standAssistantCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "level")
                    .foregroundStyle(.green)
                Text("Stand Assistant")
                    .font(.headline)
            }
            
            if foldStateProvider.state.hasHinge {
                HStack(spacing: 24) {
                    VStack {
                        Text(String(format: "%.0f°", foldStateProvider.state.angleDegrees ?? 0))
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                        Text("Angle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Level")
                                .font(.subheadline)
                        }
                        Text("Place on a flat surface")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Half-open your iPhone to use as a stand")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func isModeEnabled(_ mode: TripodMode) -> Bool {
        if mode.requiresHinge && !foldStateProvider.state.hasHinge {
            return false
        }
        return true
    }
}

struct TripodModeCard: View {
    let mode: TripodMode
    let isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: mode.iconName)
                .font(.title2)
                .foregroundStyle(isEnabled ? .orange : .secondary)
                .frame(width: 44, height: 44)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundStyle(isEnabled ? .white : .secondary)
                    
                    if mode.requiresPro {
                        Text("PRO")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
                
                Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isEnabled {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(isEnabled ? 0.15 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(isEnabled ? 1 : 0.6)
    }
}

#Preview {
    NavigationStack {
        TripodModePickerView()
    }
}
