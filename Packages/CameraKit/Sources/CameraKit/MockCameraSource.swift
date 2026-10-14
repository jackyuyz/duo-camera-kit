import Foundation

/// Mock camera source for testing and preview
/// Generates synthetic frames and simulates capture operations
public final class MockCameraSource: CameraSource, @unchecked Sendable {
    private let lock = NSLock()
    
    public let capabilities: LensCapabilities
    
    private var _currentLensID: String?
    public var currentLensID: String? {
        lock.withLock { _currentLensID }
    }
    
    private var _state: CameraState = .default
    public var state: CameraState {
        lock.withLock { _state }
    }
    
    private var _isRecording: Bool = false
    public var isRecording: Bool {
        lock.withLock { _isRecording }
    }
    
    private var isRunning = false
    private var frameTask: Task<Void, Never>?
    private var frameContinuations: [UUID: AsyncStream<VideoFrame>.Continuation] = [:]
    
    private var recordingStartTime: Date?
    
    /// Configuration for mock behavior
    public struct Configuration: Sendable {
        /// Frames per second for preview
        public var fps: Int = 30
        
        /// Frame width
        public var width: Int = 1280
        
        /// Frame height
        public var height: Int = 720
        
        /// Simulated latency in milliseconds
        public var latencyMs: Int = 0
        
        /// Whether to simulate occasional frame drops
        public var simulateDrops: Bool = false
        
        public init() {}
    }
    
    private let configuration: Configuration
    
    public init(capabilities: LensCapabilities = .mockIPhonePro, configuration: Configuration = Configuration()) {
        self.capabilities = capabilities
        self.configuration = configuration
        self._currentLensID = capabilities.lenses.first?.id
    }
    
    public func frames() -> AsyncStream<VideoFrame> {
        let id = UUID()
        return AsyncStream { continuation in
            self.lock.withLock {
                self.frameContinuations[id] = continuation
            }
            continuation.onTermination = { @Sendable _ in
                self.lock.withLock {
                    _ = self.frameContinuations.removeValue(forKey: id)
                }
            }
        }
    }
    
    public func selectLens(_ lensID: String) async throws {
        guard capabilities.lenses.contains(where: { $0.id == lensID }) else {
            throw CameraError.lensNotFound(lensID)
        }
        lock.withLock {
            _currentLensID = lensID
        }
    }
    
    public func setZoom(_ factor: Double) async throws {
        let clampedFactor = max(0.5, min(factor, 15.0))
        lock.withLock {
            _state.zoomFactor = clampedFactor
        }
    }
    
    public func setFocusPoint(_ point: CGPoint) async throws {
        let clampedPoint = CGPoint(
            x: max(0, min(1, point.x)),
            y: max(0, min(1, point.y))
        )
        lock.withLock {
            _state.focusPoint = clampedPoint
        }
    }
    
    public func setExposureBias(_ bias: Float) async throws {
        let clamped = max(-3.0, min(3.0, bias))
        lock.withLock {
            _state.exposureBias = clamped
        }
    }
    
    public func setWhiteBalance(_ preset: WBPreset) async throws {
        lock.withLock {
            _state.whiteBalance = preset
        }
    }
    
    public func lockAEAF(_ locked: Bool) async throws {
        lock.withLock {
            _state.aeLocked = locked
            _state.afLocked = locked
        }
    }
    
    public func capturePhoto(settings: PhotoSettings) async throws -> CapturedPhoto {
        guard isRunning else {
            throw CameraError.sessionNotRunning
        }
        
        try await Task.sleep(for: .milliseconds(100))
        
        let mockData = generateMockImageData(width: 4032, height: 3024)
        let thumbnailData = generateMockImageData(width: 320, height: 240)
        
        return CapturedPhoto(
            data: mockData,
            format: settings.format,
            width: 4032,
            height: 3024,
            thumbnail: thumbnailData,
            metadata: ["MockCapture": "true"]
        )
    }
    
    public func startRecording(settings: VideoSettings, at scheduledTime: UInt64?) async throws {
        guard isRunning else {
            throw CameraError.sessionNotRunning
        }
        
        let alreadyRecording = lock.withLock { _isRecording }
        guard !alreadyRecording else {
            throw CameraError.captureInProgress
        }
        
        if let scheduledTime = scheduledTime {
            let now = UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
            if scheduledTime > now {
                let delayNs = scheduledTime - now
                try await Task.sleep(nanoseconds: delayNs)
            }
        }
        
        lock.withLock {
            _isRecording = true
            recordingStartTime = Date()
        }
    }
    
    public func stopRecording() async throws -> RecordedVideo {
        let (wasRecording, startTime) = lock.withLock {
            let recording = _isRecording
            let start = recordingStartTime
            _isRecording = false
            recordingStartTime = nil
            return (recording, start)
        }
        
        guard wasRecording, let startTime = startTime else {
            throw CameraError.noRecordingInProgress
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let mockPath = "/mock/video_\(UUID().uuidString).mov"
        
        return RecordedVideo(
            filePath: mockPath,
            duration: duration,
            startTimestamp: startTime,
            fileSize: Int64(duration * 10_000_000),
            thumbnail: generateMockImageData(width: 320, height: 180)
        )
    }
    
    public func start() async throws {
        guard !isRunning else { return }
        
        isRunning = true
        startFrameGeneration()
    }
    
    public func stop() async {
        isRunning = false
        frameTask?.cancel()
        frameTask = nil
        
        lock.withLock {
            for continuation in frameContinuations.values {
                continuation.finish()
            }
            frameContinuations.removeAll()
        }
    }
    
    private func startFrameGeneration() {
        let fps = configuration.fps
        let width = configuration.width
        let height = configuration.height
        let latencyMs = configuration.latencyMs
        let simulateDrops = configuration.simulateDrops
        
        frameTask = Task { [weak self] in
            var frameCount: UInt64 = 0
            let frameInterval = 1.0 / Double(fps)
            
            while !Task.isCancelled {
                guard let self = self, self.isRunning else { break }
                
                if simulateDrops && Int.random(in: 0..<100) < 2 {
                    try? await Task.sleep(for: .seconds(frameInterval))
                    continue
                }
                
                let frameData = generateMockFrameData(width: width, height: height, frameNumber: frameCount)
                let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
                
                let frame = VideoFrame(
                    data: frameData,
                    width: width,
                    height: height,
                    timestamp: timestamp,
                    orientation: 0
                )
                
                self.lock.withLock {
                    for continuation in self.frameContinuations.values {
                        continuation.yield(frame)
                    }
                }
                
                frameCount += 1
                
                if latencyMs > 0 {
                    try? await Task.sleep(for: .milliseconds(latencyMs))
                }
                
                try? await Task.sleep(for: .seconds(frameInterval))
            }
        }
    }
    
    private func generateMockFrameData(width: Int, height: Int, frameNumber: UInt64) -> Data {
        var data = Data(count: width * height * 4)
        let color = UInt8((frameNumber * 3) % 256)
        data.withUnsafeMutableBytes { buffer in
            let ptr = buffer.bindMemory(to: UInt8.self)
            for i in stride(from: 0, to: width * height * 4, by: 4) {
                ptr[i] = color
                ptr[i + 1] = UInt8((128 + Int(frameNumber)) % 256)
                ptr[i + 2] = 128
                ptr[i + 3] = 255
            }
        }
        return data
    }
    
    private func generateMockImageData(width: Int, height: Int) -> Data {
        var data = Data(count: width * height * 4)
        data.withUnsafeMutableBytes { buffer in
            let ptr = buffer.bindMemory(to: UInt8.self)
            for i in stride(from: 0, to: width * height * 4, by: 4) {
                ptr[i] = 100
                ptr[i + 1] = 100
                ptr[i + 2] = 100
                ptr[i + 3] = 255
            }
        }
        return data
    }
}

/// Convenience function to generate mock image data
func generateMockImageData(width: Int, height: Int) -> Data {
    var data = Data(count: width * height * 4)
    data.withUnsafeMutableBytes { buffer in
        let ptr = buffer.bindMemory(to: UInt8.self)
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            ptr[i] = 100
            ptr[i + 1] = 100
            ptr[i + 2] = 100
            ptr[i + 3] = 255
        }
    }
    return data
}
