// StreamKit: Video encoding/decoding for preview streaming
// Uses VideoToolbox on iOS, with protocols for testing

import Foundation

/// Video encoding quality presets
public enum VideoQuality: String, Codable, Sendable, CaseIterable {
    case low      // 540p15
    case medium   // 720p30
    case high     // 1080p30
    
    public var width: Int {
        switch self {
        case .low: return 960
        case .medium: return 1280
        case .high: return 1920
        }
    }
    
    public var height: Int {
        switch self {
        case .low: return 540
        case .medium: return 720
        case .high: return 1080
        }
    }
    
    public var fps: Int {
        switch self {
        case .low: return 15
        case .medium: return 30
        case .high: return 30
        }
    }
    
    public var targetBitrate: Int {
        switch self {
        case .low: return 1_000_000
        case .medium: return 3_000_000
        case .high: return 6_000_000
        }
    }
}

/// Video codec type
public enum VideoCodec: String, Codable, Sendable {
    case h264
    case hevc
}

/// Configuration for video encoding
public struct EncoderConfig: Sendable, Equatable {
    public var quality: VideoQuality
    public var codec: VideoCodec
    public var keyFrameInterval: Int
    public var lowLatency: Bool
    
    public init(
        quality: VideoQuality = .medium,
        codec: VideoCodec = .hevc,
        keyFrameInterval: Int = 60,
        lowLatency: Bool = true
    ) {
        self.quality = quality
        self.codec = codec
        self.keyFrameInterval = keyFrameInterval
        self.lowLatency = lowLatency
    }
    
    public static let `default` = EncoderConfig()
}

/// An encoded video packet
public struct EncodedPacket: Sendable {
    /// Raw encoded data
    public let data: Data
    
    /// Presentation timestamp (nanoseconds)
    public let timestamp: UInt64
    
    /// Whether this is a keyframe
    public let isKeyframe: Bool
    
    /// Frame width
    public let width: Int
    
    /// Frame height
    public let height: Int
    
    public init(data: Data, timestamp: UInt64, isKeyframe: Bool, width: Int, height: Int) {
        self.data = data
        self.timestamp = timestamp
        self.isKeyframe = isKeyframe
        self.width = width
        self.height = height
    }
}

/// Protocol for video encoders
public protocol VideoEncoder: AnyObject, Sendable {
    var config: EncoderConfig { get }
    
    /// Encode a raw frame and return the encoded packet
    func encode(pixelData: Data, width: Int, height: Int, timestamp: UInt64) async throws -> EncodedPacket
    
    /// Force generation of a keyframe
    func forceKeyframe() async
    
    /// Update encoding quality (for adaptive bitrate)
    func updateQuality(_ quality: VideoQuality) async
    
    /// Reset the encoder
    func reset() async
}

/// Protocol for video decoders
public protocol VideoDecoder: AnyObject, Sendable {
    /// Decode an encoded packet and return raw pixel data
    func decode(_ packet: EncodedPacket) async throws -> Data
    
    /// Reset the decoder
    func reset() async
}

/// Errors from encoding/decoding
public enum StreamError: Error, Sendable, Equatable {
    case encodingFailed(String)
    case decodingFailed(String)
    case invalidFormat
    case resourceUnavailable
}
