import SwiftUI
import LinkKit
import CameraKit
import FoldKit

struct LensControlView: View {
    @Environment(\.displayContext) private var displayContext
    @Environment(\.foldPosture) private var foldPosture
    
    @State private var connectionState: ConnectionState = .searching
    @State private var selectedLens: LensOption?
    @State private var zoomFactor: Double = 1.0
    @State private var isRecording = false
    @State private var showPairingSheet = true
    
    private let mockCapabilities = LensCapabilities.mockIPhonePro
    
    var body: some View {
        Group {
            switch displayContext {
            case .outer:
                outerDisplayLayout
            case .inner(.partiallyOpen):
                tentModeLayout
            case .inner(.fullyOpen), .inner:
                flatModeLayout
            case .standard:
                standardLayout
            }
        }
        .background(Color.black)
        .navigationTitle("Control")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPairingSheet) {
            PairingView(
                connectionState: $connectionState,
                onConnected: { showPairingSheet = false }
            )
        }
    }
    
    // MARK: - Outer Display Layout (Closed)
    
    /// Compact control for outer cover display
    private var outerDisplayLayout: some View {
        VStack(spacing: 0) {
            compactPreview
            outerControls
        }
    }
    
    private var compactPreview: some View {
        ZStack {
            Color.gray.opacity(0.3)
            
            if connectionState.isConnected {
                Image(systemName: "video.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Connecting...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack {
                HStack {
                    compactLatencyBadge
                    Spacer()
                    if isRecording {
                        compactRecordingIndicator
                    }
                }
                .padding(8)
                Spacer()
            }
        }
    }
    
    private var outerControls: some View {
        VStack(spacing: 12) {
            compactLensPicker
            
            HStack(spacing: 32) {
                photoButton(size: 48)
                recordButton(size: 48)
            }
            .padding(.vertical, 8)
        }
        .padding()
    }
    
    // MARK: - Tent Mode Layout (Half-Folded)
    
    /// Director desk mode: preview on upper half, controls on lower half
    private var tentModeLayout: some View {
        GeometryReader { geometry in
            let halfHeight = (geometry.size.height - DuoDisplay.foldRegionWidth) / 2
            
            VStack(spacing: 0) {
                previewArea
                    .frame(height: halfHeight)
                
                Spacer()
                    .frame(height: DuoDisplay.foldRegionWidth)
                
                tentControlsArea
                    .frame(height: halfHeight)
            }
        }
    }
    
    private var tentControlsArea: some View {
        VStack(spacing: 16) {
            lensPicker
            
            HStack(spacing: 8) {
                zoomSlider
                    .frame(maxWidth: .infinity)
            }
            
            HStack(spacing: 40) {
                photoButton(size: 64)
                recordButton(size: 64)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Flat Mode Layout (Fully Open)
    
    /// Split view: preview on left half, controls on right half
    private var flatModeLayout: some View {
        GeometryReader { geometry in
            let halfWidth = (geometry.size.width - DuoDisplay.foldRegionWidth - DuoDisplay.foldSafeMargin * 2) / 2
            
            HStack(spacing: 0) {
                previewArea
                    .frame(width: halfWidth)
                    .padding(.trailing, DuoDisplay.foldSafeMargin)
                
                Spacer()
                    .frame(width: DuoDisplay.foldRegionWidth)
                
                flatControlsArea
                    .frame(width: halfWidth)
                    .padding(.leading, DuoDisplay.foldSafeMargin)
            }
        }
    }
    
    private var flatControlsArea: some View {
        VStack(spacing: 20) {
            Spacer()
            
            lensPicker
            
            zoomSlider
            
            exposureControl
            
            Spacer()
            
            captureControls
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Standard Layout (Non-Duo)
    
    private var standardLayout: some View {
        VStack(spacing: 0) {
            previewArea
            controlsArea
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
    
    // MARK: - Shared Components
    
    private var previewArea: some View {
        ZStack {
            Color.gray.opacity(0.3)
            
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
    
    private var compactLatencyBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(connectionState.isConnected ? .green : .red)
                .frame(width: 6, height: 6)
            Text(connectionState.isConnected ? "45ms" : "---")
                .font(.caption2.monospaced())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
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
    
    @ViewBuilder
    private var compactRecordingIndicator: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
            Text("REC")
                .font(.caption2.bold())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
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
    
    private var compactLensPicker: some View {
        HStack(spacing: 8) {
            ForEach(mockCapabilities.lenses) { lens in
                Button {
                    selectedLens = lens
                } label: {
                    Text(lens.shortLabel)
                        .font(.caption.bold())
                        .foregroundStyle(selectedLens?.id == lens.id ? .black : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
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
    
    private var exposureControl: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Exposure")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("0")
                    .font(.caption.monospaced())
            }
            
            Slider(value: .constant(0.0), in: -3...3)
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
            
            photoButton(size: 72)
            recordButton(size: 72)
        }
        .padding(.vertical)
    }
    
    private func photoButton(size: CGFloat) -> some View {
        Button {
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: size > 60 ? 4 : 3)
                    .frame(width: size, height: size)
                
                Circle()
                    .fill(.white)
                    .frame(width: size - 14, height: size - 14)
            }
        }
    }
    
    private func recordButton(size: CGFloat) -> some View {
        Button {
            isRecording.toggle()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(isRecording ? .red : .white, lineWidth: size > 60 ? 4 : 3)
                    .frame(width: size, height: size)
                
                RoundedRectangle(cornerRadius: isRecording ? size * 0.11 : size * 0.4)
                    .fill(isRecording ? .red : .red)
                    .frame(
                        width: isRecording ? size * 0.39 : size - 14,
                        height: isRecording ? size * 0.39 : size - 14
                    )
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            }
        }
    }
}

#Preview("Flat Mode (Fully Open)") {
    NavigationStack {
        LensControlView()
            .environment(\.displayContext, .inner(.fullyOpen))
    }
}

#Preview("Tent Mode (Half-Folded)") {
    NavigationStack {
        LensControlView()
            .environment(\.displayContext, .inner(.partiallyOpen))
    }
}

#Preview("Outer Display (Closed)") {
    NavigationStack {
        LensControlView()
            .environment(\.displayContext, .outer)
    }
    .frame(width: 200, height: 400)
}
