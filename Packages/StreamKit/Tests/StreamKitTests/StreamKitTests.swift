import Testing
import Foundation
@testable import StreamKit

@Suite("VideoQuality Tests")
struct VideoQualityTests {
    
    @Test("VideoQuality dimensions")
    func testDimensions() {
        #expect(VideoQuality.low.width == 960)
        #expect(VideoQuality.low.height == 540)
        #expect(VideoQuality.medium.width == 1280)
        #expect(VideoQuality.medium.height == 720)
        #expect(VideoQuality.high.width == 1920)
        #expect(VideoQuality.high.height == 1080)
    }
    
    @Test("VideoQuality fps")
    func testFPS() {
        #expect(VideoQuality.low.fps == 15)
        #expect(VideoQuality.medium.fps == 30)
        #expect(VideoQuality.high.fps == 30)
    }
    
    @Test("VideoQuality bitrate")
    func testBitrate() {
        #expect(VideoQuality.low.targetBitrate < VideoQuality.medium.targetBitrate)
        #expect(VideoQuality.medium.targetBitrate < VideoQuality.high.targetBitrate)
    }
}

@Suite("EncoderConfig Tests")
struct EncoderConfigTests {
    
    @Test("EncoderConfig default values")
    func testDefault() {
        let config = EncoderConfig.default
        
        #expect(config.quality == .medium)
        #expect(config.codec == .hevc)
        #expect(config.lowLatency == true)
    }
    
    @Test("EncoderConfig custom values")
    func testCustom() {
        let config = EncoderConfig(
            quality: .high,
            codec: .h264,
            keyFrameInterval: 30,
            lowLatency: false
        )
        
        #expect(config.quality == .high)
        #expect(config.codec == .h264)
        #expect(config.keyFrameInterval == 30)
        #expect(config.lowLatency == false)
    }
}

@Suite("EncodedPacket Tests")
struct EncodedPacketTests {
    
    @Test("EncodedPacket initialization")
    func testInit() {
        let data = Data(repeating: 0, count: 1000)
        let packet = EncodedPacket(
            data: data,
            timestamp: 12345,
            isKeyframe: true,
            width: 1280,
            height: 720
        )
        
        #expect(packet.data.count == 1000)
        #expect(packet.timestamp == 12345)
        #expect(packet.isKeyframe == true)
        #expect(packet.width == 1280)
        #expect(packet.height == 720)
    }
}

@Suite("MockEncoder Tests")
struct MockEncoderTests {
    
    @Test("MockEncoder encodes frames")
    func testEncode() async throws {
        let encoder = MockEncoder()
        let pixelData = Data(repeating: 0, count: 1280 * 720 * 4)
        
        let packet = try await encoder.encode(
            pixelData: pixelData,
            width: 1280,
            height: 720,
            timestamp: 1000
        )
        
        #expect(packet.width == 1280)
        #expect(packet.height == 720)
        #expect(packet.timestamp == 1000)
        #expect(!packet.data.isEmpty)
    }
    
    @Test("MockEncoder first frame is keyframe")
    func testFirstKeyframe() async throws {
        let encoder = MockEncoder()
        let pixelData = Data(repeating: 0, count: 1280 * 720 * 4)
        
        let packet = try await encoder.encode(
            pixelData: pixelData,
            width: 1280,
            height: 720,
            timestamp: 1000
        )
        
        #expect(packet.isKeyframe == true)
    }
    
    @Test("MockEncoder force keyframe")
    func testForceKeyframe() async throws {
        let encoder = MockEncoder()
        let pixelData = Data(repeating: 0, count: 1280 * 720 * 4)
        
        _ = try await encoder.encode(pixelData: pixelData, width: 1280, height: 720, timestamp: 1000)
        
        await encoder.forceKeyframe()
        
        let packet = try await encoder.encode(
            pixelData: pixelData,
            width: 1280,
            height: 720,
            timestamp: 2000
        )
        
        #expect(packet.isKeyframe == true)
    }
    
    @Test("MockEncoder update quality")
    func testUpdateQuality() async throws {
        let encoder = MockEncoder()
        
        #expect(encoder.config.quality == .medium)
        
        await encoder.updateQuality(.high)
        
        #expect(encoder.config.quality == .high)
    }
}

@Suite("MockDecoder Tests")
struct MockDecoderTests {
    
    @Test("MockDecoder decodes packets")
    func testDecode() async throws {
        let decoder = MockDecoder()
        let packet = EncodedPacket(
            data: Data(repeating: 0, count: 1000),
            timestamp: 1000,
            isKeyframe: true,
            width: 1280,
            height: 720
        )
        
        let pixelData = try await decoder.decode(packet)
        
        #expect(pixelData.count == 1280 * 720 * 4)
    }
}

@Suite("AdaptiveBitrateController Tests")
struct AdaptiveBitrateControllerTests {
    
    @Test("Initial quality")
    func testInitialQuality() {
        let controller = AdaptiveBitrateController(initialQuality: .high)
        
        #expect(controller.currentQuality == .high)
    }
    
    @Test("No change without enough samples")
    func testNoChangeWithoutSamples() {
        var controller = AdaptiveBitrateController(initialQuality: .medium)
        
        controller.addRttSample(200)
        controller.addRttSample(200)
        
        let quality = controller.evaluate()
        
        #expect(quality == .medium)
    }
    
    @Test("Downgrade on high RTT")
    func testDowngradeOnHighRTT() {
        var controller = AdaptiveBitrateController(initialQuality: .high)
        
        for _ in 0..<10 {
            controller.addRttSample(200)
        }
        
        let quality = controller.evaluate()
        
        #expect(quality == .medium)
    }
    
    @Test("Upgrade on low RTT")
    func testUpgradeOnLowRTT() {
        var controller = AdaptiveBitrateController(initialQuality: .low)
        
        for _ in 0..<10 {
            controller.addRttSample(20)
        }
        
        let quality = controller.evaluate()
        
        #expect(quality == .medium)
    }
    
    @Test("Average RTT calculation")
    func testAverageRTT() {
        var controller = AdaptiveBitrateController()
        
        controller.addRttSample(100)
        controller.addRttSample(200)
        controller.addRttSample(300)
        
        #expect(controller.averageRttMs == 200)
    }
    
    @Test("Reset clears samples")
    func testReset() {
        var controller = AdaptiveBitrateController()
        
        controller.addRttSample(100)
        controller.addLossSample(0.1)
        controller.reset()
        
        #expect(controller.averageRttMs == 0)
        #expect(controller.averageLoss == 0)
    }
}
