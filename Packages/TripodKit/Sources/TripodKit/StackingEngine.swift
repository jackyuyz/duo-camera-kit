import Foundation

/// Blending modes for frame stacking
public enum StackingMode: String, Codable, Sendable, CaseIterable {
    /// Average of all frames (silky water)
    case mean
    /// Maximum brightness per pixel (light trails)
    case lighten
    /// Median value per pixel (crowd removal)
    case median
    
    public var displayName: String {
        switch self {
        case .mean: return "Mean (Silky)"
        case .lighten: return "Lighten (Trails)"
        case .median: return "Median (Remove)"
        }
    }
    
    public var description: String {
        switch self {
        case .mean:
            return "Averages frames for smooth water and motion blur"
        case .lighten:
            return "Keeps brightest pixels for light trails and star trails"
        case .median:
            return "Takes median value to remove moving objects"
        }
    }
}

/// Configuration for long exposure stacking
public struct StackingConfig: Sendable, Equatable {
    /// Blending mode
    public var mode: StackingMode
    
    /// Virtual exposure duration in seconds
    public var exposureSeconds: Double
    
    /// Whether to align frames
    public var alignFrames: Bool
    
    /// Maximum frames to stack (for memory management)
    public static let maxFrames = 900
    
    public init(
        mode: StackingMode = .mean,
        exposureSeconds: Double = 10,
        alignFrames: Bool = false
    ) {
        self.mode = mode
        self.exposureSeconds = exposureSeconds
        self.alignFrames = alignFrames
    }
}

/// Stacking engine for long exposure effects
/// Uses running accumulation to avoid storing all frames
public actor StackingEngine {
    private var config: StackingConfig
    private var frameCount: Int = 0
    private var width: Int = 0
    private var height: Int = 0
    
    private var accumulator: [Float] = []
    
    private var medianFrames: [[UInt8]] = []
    
    public init(config: StackingConfig) {
        self.config = config
    }
    
    /// Add a frame to the stack
    public func addFrame(_ pixelData: Data, width: Int, height: Int) {
        if self.frameCount == 0 {
            self.width = width
            self.height = height
            let pixelCount = width * height * 4
            self.accumulator = [Float](repeating: 0, count: pixelCount)
        }
        
        guard self.width == width && self.height == height else { return }
        guard frameCount < StackingConfig.maxFrames else { return }
        
        switch config.mode {
        case .mean:
            addFrameMean(pixelData)
        case .lighten:
            addFrameLighten(pixelData)
        case .median:
            addFrameMedian(pixelData)
        }
        
        frameCount += 1
    }
    
    private func addFrameMean(_ pixelData: Data) {
        pixelData.withUnsafeBytes { buffer in
            let pixels = buffer.bindMemory(to: UInt8.self)
            for i in 0..<accumulator.count {
                accumulator[i] += Float(pixels[i])
            }
        }
    }
    
    private func addFrameLighten(_ pixelData: Data) {
        pixelData.withUnsafeBytes { buffer in
            let pixels = buffer.bindMemory(to: UInt8.self)
            for i in 0..<accumulator.count {
                accumulator[i] = max(accumulator[i], Float(pixels[i]))
            }
        }
    }
    
    private func addFrameMedian(_ pixelData: Data) {
        var frameData = [UInt8](repeating: 0, count: pixelData.count)
        pixelData.withUnsafeBytes { buffer in
            let pixels = buffer.bindMemory(to: UInt8.self)
            for i in 0..<frameData.count {
                frameData[i] = pixels[i]
            }
        }
        medianFrames.append(frameData)
    }
    
    /// Get the resulting stacked image
    public func getResult() -> Data {
        switch config.mode {
        case .mean:
            return getMeanResult()
        case .lighten:
            return getLightenResult()
        case .median:
            return getMedianResult()
        }
    }
    
    private func getMeanResult() -> Data {
        guard frameCount > 0 else { return Data() }
        
        var result = Data(count: accumulator.count)
        result.withUnsafeMutableBytes { buffer in
            let pixels = buffer.bindMemory(to: UInt8.self)
            for i in 0..<accumulator.count {
                let avg = accumulator[i] / Float(frameCount)
                pixels[i] = UInt8(clamping: Int(avg))
            }
        }
        return result
    }
    
    private func getLightenResult() -> Data {
        var result = Data(count: accumulator.count)
        result.withUnsafeMutableBytes { buffer in
            let pixels = buffer.bindMemory(to: UInt8.self)
            for i in 0..<accumulator.count {
                pixels[i] = UInt8(clamping: Int(accumulator[i]))
            }
        }
        return result
    }
    
    private func getMedianResult() -> Data {
        guard !medianFrames.isEmpty else { return Data() }
        
        let pixelCount = medianFrames[0].count
        var result = Data(count: pixelCount)
        
        result.withUnsafeMutableBytes { buffer in
            let pixels = buffer.bindMemory(to: UInt8.self)
            for i in 0..<pixelCount {
                var values = medianFrames.map { $0[i] }
                values.sort()
                pixels[i] = values[values.count / 2]
            }
        }
        
        return result
    }
    
    /// Get current frame count
    public func getFrameCount() -> Int {
        frameCount
    }
    
    /// Get progress (0-1)
    public func getProgress(targetFPS: Int) -> Double {
        let targetFrames = Int(config.exposureSeconds) * targetFPS
        return min(1.0, Double(frameCount) / Double(targetFrames))
    }
    
    /// Reset the engine
    public func reset() {
        frameCount = 0
        accumulator.removeAll()
        medianFrames.removeAll()
        width = 0
        height = 0
    }
}
