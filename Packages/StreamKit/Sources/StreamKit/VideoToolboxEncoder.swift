import Foundation

#if canImport(VideoToolbox) && canImport(CoreMedia) && canImport(CoreVideo)
import VideoToolbox
import CoreMedia
import CoreVideo

/// VideoToolbox-based H.264/HEVC encoder
/// Available only on Apple platforms
@available(iOS 11.0, macOS 10.13, *)
public actor VideoToolboxEncoder: VideoEncoder {
    
    public private(set) var config: EncoderConfig
    
    private var compressionSession: VTCompressionSession?
    private var frameCount: Int = 0
    private var forceNextKeyframe = false
    
    public init(config: EncoderConfig = .default) {
        self.config = config
    }
    
    public func encode(pixelData: Data, width: Int, height: Int, timestamp: UInt64) async throws -> EncodedPacket {
        if compressionSession == nil {
            try setupSession(width: width, height: height)
        }
        
        guard let session = compressionSession else {
            throw StreamError.resourceUnavailable
        }
        
        let pixelBuffer = try createPixelBuffer(from: pixelData, width: width, height: height)
        
        let presentationTime = CMTime(value: Int64(timestamp), timescale: 1_000_000_000)
        let duration = CMTime(value: 1, timescale: Int32(config.quality.fps))
        
        var properties: [CFString: CFTypeRef] = [:]
        
        let needsKeyframe = forceNextKeyframe || (frameCount % config.keyFrameInterval == 0)
        if needsKeyframe {
            properties[kVTEncodeFrameOptionKey_ForceKeyFrame] = kCFBooleanTrue
            forceNextKeyframe = false
        }
        
        var outputData = Data()
        var isKeyframe = false
        
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: duration,
            frameProperties: properties as CFDictionary,
            infoFlagsOut: nil
        ) { status, _, sampleBuffer in
            guard status == noErr, let buffer = sampleBuffer else { return }
            
            if let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[CFString: Any]],
               let first = attachments.first {
                isKeyframe = !(first[kCMSampleAttachmentKey_NotSync] as? Bool ?? false)
            }
            
            if let dataBuffer = CMSampleBufferGetDataBuffer(buffer) {
                var length = 0
                var pointer: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer)
                
                if let pointer = pointer {
                    outputData = Data(bytes: pointer, count: length)
                }
            }
        }
        
        guard status == noErr else {
            throw StreamError.encodingFailed("VTCompressionSessionEncodeFrame failed: \(status)")
        }
        
        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: presentationTime)
        
        frameCount += 1
        
        return EncodedPacket(
            data: outputData,
            timestamp: timestamp,
            isKeyframe: isKeyframe,
            width: width,
            height: height
        )
    }
    
    public func forceKeyframe() async {
        forceNextKeyframe = true
    }
    
    public func updateQuality(_ quality: VideoQuality) async {
        if quality != config.quality {
            config.quality = quality
            if let session = compressionSession {
                VTSessionSetProperty(
                    session,
                    key: kVTCompressionPropertyKey_AverageBitRate,
                    value: NSNumber(value: quality.targetBitrate)
                )
            }
            forceNextKeyframe = true
        }
    }
    
    public func reset() async {
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
        }
        compressionSession = nil
        frameCount = 0
        forceNextKeyframe = false
    }
    
    private func setupSession(width: Int, height: Int) throws {
        let codecType: CMVideoCodecType
        switch config.codec {
        case .h264:
            codecType = kCMVideoCodecType_H264
        case .hevc:
            codecType = kCMVideoCodecType_HEVC
        }
        
        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: codecType,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )
        
        guard status == noErr, let compressionSession = session else {
            throw StreamError.resourceUnavailable
        }
        
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_AverageBitRate, value: NSNumber(value: config.quality.targetBitrate))
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: NSNumber(value: config.quality.fps))
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: config.keyFrameInterval))
        
        if config.lowLatency {
            VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        }
        
        VTCompressionSessionPrepareToEncodeFrames(compressionSession)
        
        self.compressionSession = compressionSession
    }
    
    private func createPixelBuffer(from data: Data, width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw StreamError.encodingFailed("Failed to create pixel buffer")
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            data.copyBytes(to: baseAddress.assumingMemoryBound(to: UInt8.self), count: min(data.count, width * height * 4))
        }
        
        return buffer
    }
}

/// VideoToolbox-based H.264/HEVC decoder
@available(iOS 11.0, macOS 10.13, *)
public actor VideoToolboxDecoder: VideoDecoder {
    
    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMFormatDescription?
    
    public init() {}
    
    public func decode(_ packet: EncodedPacket) async throws -> Data {
        if decompressionSession == nil && packet.isKeyframe {
            try setupSession(from: packet)
        }
        
        guard let session = decompressionSession, let format = formatDescription else {
            throw StreamError.decodingFailed("Decoder not initialized - waiting for keyframe")
        }
        
        let blockBuffer = try createBlockBuffer(from: packet.data)
        let sampleBuffer = try createSampleBuffer(from: blockBuffer, format: format, timestamp: packet.timestamp)
        
        var outputData = Data()
        var outputPixelBuffer: CVPixelBuffer?
        
        let status = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: [._EnableAsynchronousDecompression],
            infoFlagsOut: nil
        ) { status, _, imageBuffer, _, _ in
            guard status == noErr, let pixelBuffer = imageBuffer else { return }
            outputPixelBuffer = pixelBuffer
        }
        
        guard status == noErr else {
            throw StreamError.decodingFailed("VTDecompressionSessionDecodeFrame failed: \(status)")
        }
        
        VTDecompressionSessionWaitForAsynchronousFrames(session)
        
        if let pixelBuffer = outputPixelBuffer {
            outputData = extractPixelData(from: pixelBuffer)
        }
        
        return outputData
    }
    
    public func reset() async {
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
        }
        decompressionSession = nil
        formatDescription = nil
    }
    
    private func setupSession(from packet: EncodedPacket) throws {
        let codecType: CMVideoCodecType = kCMVideoCodecType_H264
        
        var format: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: codecType,
            width: Int32(packet.width),
            height: Int32(packet.height),
            extensions: nil,
            formatDescriptionOut: &format
        )
        
        guard status == noErr, let formatDescription = format else {
            throw StreamError.decodingFailed("Failed to create format description")
        }
        
        self.formatDescription = formatDescription
        
        let destinationAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: packet.width,
            kCVPixelBufferHeightKey: packet.height
        ]
        
        var session: VTDecompressionSession?
        let sessionStatus = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: nil,
            imageBufferAttributes: destinationAttributes as CFDictionary,
            outputCallback: nil,
            decompressionSessionOut: &session
        )
        
        guard sessionStatus == noErr, let decompressionSession = session else {
            throw StreamError.resourceUnavailable
        }
        
        self.decompressionSession = decompressionSession
    }
    
    private func createBlockBuffer(from data: Data) throws -> CMBlockBuffer {
        var blockBuffer: CMBlockBuffer?
        
        let status = data.withUnsafeBytes { pointer in
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: UnsafeMutableRawPointer(mutating: pointer.baseAddress),
                blockLength: data.count,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: data.count,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
        }
        
        guard status == noErr, let buffer = blockBuffer else {
            throw StreamError.decodingFailed("Failed to create block buffer")
        }
        
        return buffer
    }
    
    private func createSampleBuffer(from blockBuffer: CMBlockBuffer, format: CMFormatDescription, timestamp: UInt64) throws -> CMSampleBuffer {
        var sampleBuffer: CMSampleBuffer?
        
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(value: Int64(timestamp), timescale: 1_000_000_000),
            decodeTimeStamp: .invalid
        )
        
        var sampleSize = CMBlockBufferGetDataLength(blockBuffer)
        
        let status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )
        
        guard status == noErr, let buffer = sampleBuffer else {
            throw StreamError.decodingFailed("Failed to create sample buffer")
        }
        
        return buffer
    }
    
    private func extractPixelData(from pixelBuffer: CVPixelBuffer) -> Data {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return Data()
        }
        
        return Data(bytes: baseAddress, count: bytesPerRow * height)
    }
}
#endif
