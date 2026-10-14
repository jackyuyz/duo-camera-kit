import SwiftUI
import LinkKit
import CameraKit

struct LensControlView: View {
    @State private var connectionState: ConnectionState = .searching
    @State private var selectedLens: LensOption?
    @State private var zoomFactor: Double = 1.0
    @State private var isRecording = false
    @State private var showPairingSheet = true
    
    private let mockCapabilities = LensCapabilities.mockIPhonePro
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                previewArea
                
                controlsArea
            }
        }
        .navigationTitle("Control")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPairingSheet) {
            PairingView(
                connectionState: $connectionState,
                onConnected: { showPairingSheet = false }
            )
        }
    }
    
    private var previewArea: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
            
            if connectionState.isConnected {
                Image(systemName: "video.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(connectionState.displayDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack {
                HStack {
                    latencyBadge
                    Spacer()
                    recordingIndicator
                }
                .padding()
                
                Spacer()
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
    }
    
    private var latencyBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionState.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(connectionState.isConnected ? "45ms" : "---")
                .font(.caption.monospaced())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    @ViewBuilder
    private var recordingIndicator: some View {
        if isRecording {
            HStack(spacing: 4) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("REC")
                    .font(.caption.bold())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
    }
    
    private var controlsArea: some View {
        VStack(spacing: 20) {
            lensPicker
            
            zoomSlider
            
            captureControls
        }
        .padding()
        .background(Color.black)
    }
    
    private var lensPicker: some View {
        HStack(spacing: 12) {
            ForEach(mockCapabilities.lenses) { lens in
                Button {
                    selectedLens = lens
                } label: {
                    Text(lens.shortLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(selectedLens?.id == lens.id ? .black : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedLens?.id == lens.id ? Color.accentYellow : Color.gray.opacity(0.3))
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private var zoomSlider: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Zoom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f×", zoomFactor))
                    .font(.caption.monospaced())
            }
            
            Slider(value: $zoomFactor, in: 0.5...15.0)
                .tint(.accentYellow)
        }
    }
    
    private var captureControls: some View {
        HStack(spacing: 40) {
            Button {
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            Button {
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 58, height: 58)
                }
            }
            
            Button {
                isRecording.toggle()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(isRecording ? .red : .white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    
                    RoundedRectangle(cornerRadius: isRecording ? 8 : 29)
                        .fill(isRecording ? .red : .red)
                        .frame(width: isRecording ? 28 : 58, height: isRecording ? 28 : 58)
                        .animation(.easeInOut(duration: 0.2), value: isRecording)
                }
            }
        }
        .padding(.vertical)
    }
}

#Preview {
    NavigationStack {
        LensControlView()
    }
}
