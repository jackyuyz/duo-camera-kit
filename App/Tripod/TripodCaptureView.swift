import SwiftUI
import TripodKit
import FoldKit

struct TripodCaptureView: View {
    let mode: TripodMode
    
    @Environment(\.foldStateProvider) private var foldStateProvider
    @State private var isCapturing = false
    @State private var framesCaptured = 0
    @State private var standAssistant = StandAssistant()
    
    @State private var intervalSeconds: Double = 1.0
    @State private var durationMinutes: Double = 5.0
    @State private var stackingMode: StackingMode = .mean
    @State private var exposureSeconds: Double = 10.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                previewArea
                
                settingsArea
                
                captureButton
            }
        }
        .navigationTitle(mode.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: foldStateProvider.state) { _, newState in
            standAssistant.update(foldState: newState)
        }
    }
    
    private var previewArea: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
            
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
                    Text(standAssistant.isStable ? "Locked" : "Moved")
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
    private var settingsArea: some View {
        ScrollView {
            VStack(spacing: 20) {
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
            .padding()
        }
        .frame(maxHeight: 200)
    }
    
    private var timelapseSettings: some View {
        VStack(spacing: 16) {
            SettingRow(title: "Interval") {
                Picker("Interval", selection: $intervalSeconds) {
                    Text("0.5s").tag(0.5)
                    Text("1s").tag(1.0)
                    Text("2s").tag(2.0)
                    Text("5s").tag(5.0)
                    Text("10s").tag(10.0)
                }
                .pickerStyle(.segmented)
            }
            
            SettingRow(title: "Duration") {
                Picker("Duration", selection: $durationMinutes) {
                    Text("1 min").tag(1.0)
                    Text("5 min").tag(5.0)
                    Text("10 min").tag(10.0)
                    Text("30 min").tag(30.0)
                    Text("∞").tag(Double.infinity)
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private var longExposureSettings: some View {
        VStack(spacing: 16) {
            SettingRow(title: "Mode") {
                Picker("Mode", selection: $stackingMode) {
                    ForEach(StackingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            SettingRow(title: "Exposure") {
                Picker("Exposure", selection: $exposureSeconds) {
                    Text("2s").tag(2.0)
                    Text("5s").tag(5.0)
                    Text("10s").tag(10.0)
                    Text("20s").tag(20.0)
                    Text("30s").tag(30.0)
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private var starTrailsSettings: some View {
        VStack(spacing: 16) {
            SettingRow(title: "Duration") {
                Picker("Duration", selection: $durationMinutes) {
                    Text("15 min").tag(15.0)
                    Text("30 min").tag(30.0)
                    Text("1 hr").tag(60.0)
                    Text("2 hr").tag(120.0)
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private var palmTriggerSettings: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.raised")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text("Show your palm to the camera to trigger capture")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var captureButton: some View {
        Button {
            if isCapturing {
                isCapturing = false
            } else {
                isCapturing = true
                standAssistant.lockStand()
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
        .padding(.vertical, 24)
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

struct SettingRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

#Preview {
    NavigationStack {
        TripodCaptureView(mode: .timelapse)
    }
}
