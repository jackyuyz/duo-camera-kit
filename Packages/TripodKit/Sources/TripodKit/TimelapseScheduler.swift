import Foundation

/// Configuration for timelapse capture
public struct TimelapseConfig: Sendable, Equatable {
    /// Interval between captures in seconds
    public var intervalSeconds: Double
    
    /// Total duration in seconds (nil = unlimited)
    public var durationSeconds: Double?
    
    /// Lock exposure/focus/white balance
    public var lockSettings: Bool
    
    /// Output video frame rate
    public var outputFPS: Int
    
    public init(
        intervalSeconds: Double = 1.0,
        durationSeconds: Double? = nil,
        lockSettings: Bool = true,
        outputFPS: Int = 30
    ) {
        self.intervalSeconds = intervalSeconds
        self.durationSeconds = durationSeconds
        self.lockSettings = lockSettings
        self.outputFPS = outputFPS
    }
    
    /// Total number of frames (nil if unlimited)
    public var totalFrames: Int? {
        guard let duration = durationSeconds else { return nil }
        return Int(duration / intervalSeconds)
    }
    
    /// Expected output video duration in seconds
    public var outputDuration: Double? {
        guard let total = totalFrames else { return nil }
        return Double(total) / Double(outputFPS)
    }
}

/// State of a timelapse capture session
public struct TimelapseState: Sendable {
    /// Current frame number
    public var framesCaptured: Int = 0
    
    /// Time of first capture
    public var startTime: Date?
    
    /// Time of last capture
    public var lastCaptureTime: Date?
    
    /// Whether capture is active
    public var isCapturing: Bool = false
    
    /// Whether capture is paused
    public var isPaused: Bool = false
    
    /// Error message if capture failed
    public var error: String?
    
    public init() {}
    
    /// Elapsed time since start
    public var elapsedTime: TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    /// Progress (0-1) for bounded timelapse
    public func progress(for config: TimelapseConfig) -> Double? {
        guard let total = config.totalFrames, total > 0 else { return nil }
        return Double(framesCaptured) / Double(total)
    }
    
    /// Remaining time estimate
    public func remainingTime(for config: TimelapseConfig) -> TimeInterval? {
        guard let duration = config.durationSeconds else { return nil }
        return max(0, duration - elapsedTime)
    }
    
    /// Formatted frame count
    public func frameCountFormatted(for config: TimelapseConfig) -> String {
        if let total = config.totalFrames {
            return "\(framesCaptured) / \(total)"
        } else {
            return "\(framesCaptured)"
        }
    }
}

/// Timelapse capture scheduler using virtual time for testing
public actor TimelapseScheduler {
    private var config: TimelapseConfig
    private var state: TimelapseState
    private var captureTask: Task<Void, Never>?
    
    /// Callback when a frame should be captured
    public var onCapture: (@Sendable () async -> Void)?
    
    /// Callback when state changes
    public var onStateChange: (@Sendable (TimelapseState) -> Void)?
    
    /// Time scale for testing (1.0 = real time)
    public var timeScale: Double = 1.0
    
    public init(config: TimelapseConfig) {
        self.config = config
        self.state = TimelapseState()
    }
    
    /// Start the timelapse capture
    public func start() {
        guard !state.isCapturing else { return }
        
        state = TimelapseState()
        state.isCapturing = true
        state.startTime = Date()
        onStateChange?(state)
        
        captureTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                let currentState = await self.getState()
                let currentConfig = await self.getConfig()
                
                if !currentState.isCapturing { break }
                if currentState.isPaused {
                    try? await Task.sleep(for: .milliseconds(100))
                    continue
                }
                
                if let total = currentConfig.totalFrames, currentState.framesCaptured >= total {
                    break
                }
                
                await self.captureFrame()
                
                let scale = await self.getTimeScale()
                let interval = currentConfig.intervalSeconds / scale
                try? await Task.sleep(for: .seconds(interval))
            }
            
            await self.finishCapture()
        }
    }
    
    /// Pause the timelapse
    public func pause() {
        state.isPaused = true
        onStateChange?(state)
    }
    
    /// Resume the timelapse
    public func resume() {
        state.isPaused = false
        onStateChange?(state)
    }
    
    /// Stop the timelapse
    public func stop() {
        captureTask?.cancel()
        captureTask = nil
        state.isCapturing = false
        onStateChange?(state)
    }
    
    /// Get current state
    public func getState() -> TimelapseState {
        state
    }
    
    /// Get current config
    public func getConfig() -> TimelapseConfig {
        config
    }
    
    /// Get time scale
    public func getTimeScale() -> Double {
        timeScale
    }
    
    private func captureFrame() async {
        state.framesCaptured += 1
        state.lastCaptureTime = Date()
        onStateChange?(state)
        await onCapture?()
    }
    
    private func finishCapture() {
        state.isCapturing = false
        onStateChange?(state)
    }
}
