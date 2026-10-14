import Foundation

/// Mock video encoder for testing
public final class MockEncoder: VideoEncoder, @unchecked Sendable {
    private let lock = NSLock()
    
    private var _config: EncoderConfig
    public var config: EncoderConfig {
        lock.withLock { _config }
    }
    
    private var frameCount: UInt64 = 0
    private var forceNextKeyframe = false
    
    public init(config: EncoderConfig = .default) {
        self._config = config
    }
    
    public func encode(pixelData: Data, width: Int, height: Int, timestamp: UInt64) async throws -> EncodedPacket {
        let (isKeyframe, count) = lock.withLock { () -> (Bool, UInt64) in
            frameCount += 1
            let isKey = forceNextKeyframe || (frameCount % UInt64(_config.keyFrameInterval) == 1)
            forceNextKeyframe = false
            return (isKey, frameCount)
        }
        
        let compressedSize = isKeyframe ? pixelData.count / 4 : pixelData.count / 10
        let mockData = Data(repeating: isKeyframe ? 0x65 : 0x41, count: compressedSize)
        
        return EncodedPacket(
            data: mockData,
            timestamp: timestamp,
            isKeyframe: isKeyframe,
            width: width,
            height: height
        )
    }
    
    public func forceKeyframe() async {
        lock.withLock {
            forceNextKeyframe = true
        }
    }
    
    public func updateQuality(_ quality: VideoQuality) async {
        lock.withLock {
            _config.quality = quality
        }
    }
    
    public func reset() async {
        lock.withLock {
            frameCount = 0
            forceNextKeyframe = false
        }
    }
}

/// Mock video decoder for testing
public final class MockDecoder: VideoDecoder, @unchecked Sendable {
    private let lock = NSLock()
    
    public init() {}
    
    public func decode(_ packet: EncodedPacket) async throws -> Data {
        let pixelCount = packet.width * packet.height * 4
        return Data(repeating: 0x80, count: pixelCount)
    }
    
    public func reset() async {
    }
}
