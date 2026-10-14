import SwiftUI
import TripodKit
import FoldKit

struct TripodCaptureView: View {
    let mode: TripodMode
    
    @Environment(\.foldStateProvider) private var foldStateProvider
    @Environment(\.displayContext) private var displayContext
    @Environment(\.hingeAngle) private var hingeAngle
    
    @State private var isCapturing = false
    @State private var framesCaptured = 0
    @State private var standAssistant = StandAssistant()
    
    @State private var intervalSeconds: Double = 1.0
    @State private var durationMinutes: Double = 5.0
    @State private var stackingMode: StackingMode = .mean
    @State private var exposureSeconds: Double = 10.0
    
    var body: some View {
        Group {
            switch displayContext {
            case .outer:
                outerDisplayLayout
            case .inner(.partiallyOpen):
                tentModeLayout
            default:
                standardLayout
            }
        }
        .background(Color.black)
        .navigationTitle(mode.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: foldStateProvider.state) { _, newState in
            standAssistant.update(foldState: newState)
            
            if let lock = standAssistant.lock, !standAssistant.isStable {
                if isCapturing {
                    isCapturing = false
                }
            }
        }
    }
    
    // MARK: - Outer Display (Closed, using as tripod in a stand)
    
    private var outerDisplayLayout: some View {
        VStack(spacing: 0) {
            compactPreview
            compactControls
        }
    }
    
    private var compactPreview: some View {
        ZStack {
            Color.gray.opacity(0.3)
            
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            if isCapturing {
                VStack {
                    Spacer()
                    compactProgressBar
                }
            }
        }
    }
    
    private var compactControls: some View {
        VStack(spacing: 12) {
            if isCapturing {
                Button {
                    isCapturing = false
                } label: {
                    Text("Stop")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                Button {
                    isCapturing = true
                } label: {
                    Text("Start \(mode.displayName)")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentYellow)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
    }
    
    private var compactProgressBar: some View {
        HStack {
            Text("\(framesCaptured)")
                .font(.caption.monospaced())
            ProgressView(value: progress)
                .tint(.accentYellow)
        }
        .padding(8)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Tent Mode (Primary Tripod Mode)
    
    /// Best tripod layout: preview on upper half, controls on lower half
    private var tentModeLayout: some View {
        GeometryReader { geometry in
            let halfHeight = (geometry.size.height - DuoDisplay.foldRegionWidth) / 2
            
            VStack(spacing: 0) {
                tentPreviewArea
                    .frame(height: halfHeight)
                
                Spacer()
                    .frame(height: DuoDisplay.foldRegionWidth)
                
                tentControlsArea
                    .frame(height: halfHeight)
            }
        }
    }
    
    private var tentPreviewArea: some View {
        ZStack {
            Color.gray.opacity(0.3)
            
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            VStack {
                Spacer()
                
                if isCapturing {
                    captureProgressBar
                }
                
                standStatusBar
            }
        }
    }
    
    private var tentControlsArea: some View {
        VStack(spacing: 16) {
            standAssistantView
            
            modeSpecificSettings
            
            Spacer()
            
            captureButton
                .padding(.bottom, 8)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Standard Layout (Fully open or non-Duo)
    
    private var standardLayout: some View {
        VStack(spacing: 0) {
            previewArea
            settingsArea
            captureButton
                .padding(.vertical, 24)
        }
    }
    
    private var previewArea: some View {
        ZStack {
            Color.gray.opacity(0.3)
            
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            VStack {
                Spacer()
                
                if isCapturing {
                    captureProgressBar
                }
                
                standStatusBar
            }
        }
        .aspectRatio(4/3, contentMode: .fit)
    }
    
    // MARK: - Shared Components
    
    private var standAssistantView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: standAssistant.isStable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(standAssistant.isStable ? .green : .orange)
                
                Text(standAssistant.isStable ? "Stand Locked" : (standAssistant.instabilityReason?.displayMessage ?? "Unlocked"))
                    .font(.subheadline)
                
                Spacer()
                
                if let angle = hingeAngle {
                    Text(String(format: "%.0f°", angle))
                        .font(.headline.monospaced())
                }
            }
            
            if standAssistant.lock == nil {
                Button {
                    standAssistant.lockStand()
                } label: {
                    Text("Lock Stand Position")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentYellow)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else if !standAssistant.isStable {
                Button {
                    standAssistant.relockStand()
                } label: {
                    Text("Re-lock at Current Position")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var captureProgressBar: some View {
        HStack {
            Text("\(framesCaptured)")
                .font(.headline.monospaced())
            
            ProgressView(value: progress)
                .tint(.accentYellow)
            
            Text(remainingTimeFormatted)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var standStatusBar: some View {
        HStack(spacing: 16) {
            if foldStateProvider.state.hasHinge {
                HStack(spacing: 4) {
                    Image(systemName: "angle")
                    Text(String(format: "%.0f°", foldStateProvider.state.angleDegrees ?? 0))
                        .font(.caption.monospaced())
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(standAssistant.isStable ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(standAssistant.isStable ? "Stable" : "Moved")
                        .font(.caption)
                }
            }
            
            HStack(spacing: 4) {
                Image(systemName: "level")
                Text("Level")
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private var modeSpecificSettings: some View {
        switch mode {
        case .timelapse:
            timelapseSettings
        case .longExposure:
            longExposureSettings
        case .starTrails:
            starTrailsSettings
        case .palmTrigger:
            palmTriggerSettings
        case .lapCam, .topDown:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var settingsArea: some View {
        ScrollView {
            VStack(spacing: 20) {
                modeSpecificSettings
            }
            .padding()
        }
        .frame(maxHeight: 200)
    }
    
    private var timelapseSettings: some View {
        VStack(spacing: 12) {
            SettingRow(title: "Interval") {
                Picker("Interval", selection: $intervalSeconds) {
                    Text("0.5s").tag(0.5)
                    Text("1s").tag(1.0)
                    Text("2s").tag(2.0)
                    Text("5s").tag(5.0)
                }
                .pickerStyle(.segmented)
            }
            
            SettingRow(title: "Duration") {
                Picker("Duration", selection: $durationMinutes) {
                    Text("1m").tag(1.0)
                    Text("5m").tag(5.0)
                    Text("10m").tag(10.0)
                    Text("∞").tag(Double.infinity)
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private var longExposureSettings: some View {
        VStack(spacing: 12) {
            SettingRow(title: "Effect") {
                Picker("Mode", selection: $stackingMode) {
                    ForEach(StackingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName.components(separatedBy: " ").first ?? "").tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            SettingRow(title: "Exposure") {
                Picker("Exposure", selection: $exposureSeconds) {
                    Text("2s").tag(2.0)
                    Text("5s").tag(5.0)
                    Text("10s").tag(10.0)
                    Text("30s").tag(30.0)
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private var starTrailsSettings: some View {
        SettingRow(title: "Duration") {
            Picker("Duration", selection: $durationMinutes) {
                Text("15m").tag(15.0)
                Text("30m").tag(30.0)
                Text("1h").tag(60.0)
                Text("2h").tag(120.0)
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var palmTriggerSettings: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.raised")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text("Show your palm to capture")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private var captureButton: some View {
        Button {
            if isCapturing {
                isCapturing = false
            } else {
                isCapturing = true
                if standAssistant.lock == nil {
                    standAssistant.lockStand()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(isCapturing ? .red : .white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                
                if isCapturing {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.red)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 58, height: 58)
                }
            }
        }
    }
    
    private var progress: Double {
        guard durationMinutes.isFinite else { return 0 }
        let totalFrames = Int(durationMinutes * 60 / intervalSeconds)
        return Double(framesCaptured) / Double(totalFrames)
    }
    
    private var remainingTimeFormatted: String {
        guard durationMinutes.isFinite else { return "∞" }
        let remainingSeconds = (durationMinutes * 60) - (Double(framesCaptured) * intervalSeconds)
        let minutes = Int(remainingSeconds) / 60
        let seconds = Int(remainingSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview("Tent Mode") {
    NavigationStack {
        TripodCaptureView(mode: .timelapse)
            .environment(\.displayContext, .inner(.partiallyOpen))
            .environment(\.hingeAngle, 110.0)
    }
}

#Preview("Standard") {
    NavigationStack {
        TripodCaptureView(mode: .timelapse)
            .environment(\.displayContext, .standard)
    }
}
