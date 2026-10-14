import Foundation

#if canImport(AVFoundation) && canImport(UIKit)
import AVFoundation
import UIKit

/// AVFoundation-based camera source for iOS
/// Handles real camera capture, preview streaming, and photo/video recording
@available(iOS 13.0, *)
public actor AVCameraSource: NSObject, CameraSource {
    
    public private(set) var capabilities: LensCapabilities
    public private(set) var currentLensID: String?
    public private(set) var state: CameraState = CameraState()
    public private(set) var isRecording: Bool = false
    
    private var captureSession: AVCaptureSession?
    private var currentDevice: AVCaptureDevice?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    
    private var frameContinuation: AsyncStream<VideoFrame>.Continuation?
    private var pendingPhotoCapture: CheckedContinuation<CapturedPhoto, Error>?
    private var pendingRecording: RecordingState?
    
    private let sessionQueue = DispatchQueue(label: "com.duocamerakit.camera.session")
    private let outputQueue = DispatchQueue(label: "com.duocamerakit.camera.output")
    
    struct RecordingState {
        let id: UUID
        let startTime: Date
        let scheduledTime: UInt64?
        var continuation: CheckedContinuation<RecordedVideo, Error>?
    }
    
    public override init() {
        self.capabilities = LensCapabilities(lenses: [], proRAW: false, proRes: false, maxVideo: .hd1080p30)
        super.init()
    }
    
    public nonisolated func frames() -> AsyncStream<VideoFrame> {
        AsyncStream { continuation in
            Task { await setFrameContinuation(continuation) }
        }
    }
    
    private func setFrameContinuation(_ continuation: AsyncStream<VideoFrame>.Continuation) {
        frameContinuation = continuation
    }
    
    public func start() async throws {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authStatus {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { throw CameraError.notAuthorized }
        case .denied, .restricted:
            throw CameraError.notAuthorized
        case .authorized:
            break
        @unknown default:
            break
        }
        
        await discoverDevices()
        try await setupSession()
        
        captureSession?.startRunning()
    }
    
    public func stop() async {
        captureSession?.stopRunning()
        frameContinuation?.finish()
        frameContinuation = nil
    }
    
    public func selectLens(_ lensID: String) async throws {
        guard let lens = capabilities.lenses.first(where: { $0.id == lensID }) else {
            throw CameraError.lensNotFound(lensID)
        }
        
        guard let device = AVCaptureDevice(uniqueID: lensID) else {
            throw CameraError.deviceNotAvailable
        }
        
        try await switchToDevice(device)
        currentLensID = lensID
    }
    
    public func setZoom(_ factor: Double) async throws {
        guard let device = currentDevice else { return }
        
        let range = capabilities.supportedZoomRange
        let deviceMax = Double(device.maxAvailableVideoZoomFactor)
        let clampedFactor = min(max(factor, range.lowerBound), min(range.upperBound, deviceMax))
        
        try device.lockForConfiguration()
        device.videoZoomFactor = CGFloat(clampedFactor)
        device.unlockForConfiguration()
        
        state.zoomFactor = clampedFactor
    }
    
    public func setFocusPoint(_ point: CGPoint) async throws {
        guard let device = currentDevice, device.isFocusPointOfInterestSupported else { return }
        
        let clampedPoint = CGPoint(
            x: max(0, min(1, point.x)),
            y: max(0, min(1, point.y))
        )
        
        try device.lockForConfiguration()
        device.focusPointOfInterest = clampedPoint
        device.focusMode = .autoFocus
        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = clampedPoint
            device.exposureMode = .autoExpose
        }
        device.unlockForConfiguration()
        
        state.focusPoint = clampedPoint
    }
    
    public func setExposureBias(_ bias: Float) async throws {
        guard let device = currentDevice else { return }
        
        let clampedBias = max(device.minExposureTargetBias, min(bias, device.maxExposureTargetBias))
        
        try device.lockForConfiguration()
        device.setExposureTargetBias(clampedBias, completionHandler: nil)
        device.unlockForConfiguration()
        
        state.exposureBias = clampedBias
    }
    
    public func setWhiteBalance(_ preset: WBPreset) async throws {
        guard let device = currentDevice else { return }
        
        try device.lockForConfiguration()
        
        if preset == .auto {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        } else {
            let temperature = Float(preset.temperatureKelvin)
            let tint: Float = 0
            
            let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: temperature,
                tint: tint
            )
            
            let gains = device.deviceWhiteBalanceGains(for: temperatureAndTint)
            let normalizedGains = normalizeGains(gains, for: device)
            
            device.setWhiteBalanceModeLocked(with: normalizedGains, completionHandler: nil)
        }
        
        device.unlockForConfiguration()
        state.whiteBalance = preset
    }
    
    public func lockAEAF(_ locked: Bool) async throws {
        guard let device = currentDevice else { return }
        
        try device.lockForConfiguration()
        
        if locked {
            if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
            }
            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }
        } else {
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        }
        
        device.unlockForConfiguration()
        state.aeLocked = locked
        state.afLocked = locked
    }
    
    public func capturePhoto(settings: PhotoSettings) async throws -> CapturedPhoto {
        guard captureSession?.isRunning == true else {
            throw CameraError.sessionNotRunning
        }
        
        guard let photoOutput = photoOutput else {
            throw CameraError.configurationFailed("Photo output not configured")
        }
        
        let captureSettings = createPhotoCaptureSettings(from: settings)
        
        return try await withCheckedThrowingContinuation { continuation in
            self.pendingPhotoCapture = continuation
            photoOutput.capturePhoto(with: captureSettings, delegate: PhotoCaptureDelegate(source: self))
        }
    }
    
    public func startRecording(settings: VideoSettings, at scheduledTime: UInt64?) async throws {
        guard !isRecording else { throw CameraError.captureInProgress }
        guard captureSession?.isRunning == true else { throw CameraError.sessionNotRunning }
        
        guard let movieOutput = movieOutput else {
            throw CameraError.configurationFailed("Movie output not configured")
        }
        
        let outputURL = generateOutputURL(for: .video)
        
        pendingRecording = RecordingState(
            id: UUID(),
            startTime: Date(),
            scheduledTime: scheduledTime
        )
        
        if let scheduledTime = scheduledTime {
            let delay = Int64(scheduledTime) - Int64(Date().timeIntervalSince1970 * 1_000_000_000)
            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay))
            }
        }
        
        movieOutput.startRecording(to: outputURL, recordingDelegate: MovieRecordingDelegate(source: self))
        isRecording = true
    }
    
    public func stopRecording() async throws -> RecordedVideo {
        guard isRecording, let movieOutput = movieOutput else {
            throw CameraError.noRecordingInProgress
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            pendingRecording?.continuation = continuation
            movieOutput.stopRecording()
        }
    }
    
    // MARK: - Private Methods
    
    private func discoverDevices() async {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera
        ]
        
        // Duo inner/outer ultra-wide are iOS 27.1+. Lens phones on iOS 26 skip these.
        if #available(iOS 27.1, *) {
            // TODO(verify-api): AVCaptureDevice.DeviceType.builtInOuterUltraWideCamera
            // TODO(verify-api): AVCaptureDevice.DeviceType.builtInInnerUltraWideCamera
        }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        
        var lenses: [LensOption] = []
        var hasProRAW = false
        var hasProRes = false
        
        for device in discoverySession.devices {
            let kind: LensKind
            switch device.deviceType {
            case .builtInUltraWideCamera:
                kind = .ultraWide
            case .builtInTelephotoCamera:
                kind = .telephoto
            default:
                kind = .wide
            }
            
            var zoomFactors: [Double] = [1.0]
            if device.maxAvailableVideoZoomFactor > 1 {
                zoomFactors.append(contentsOf: [2.0, 3.0, 5.0].filter { $0 <= Double(device.maxAvailableVideoZoomFactor) })
            }
            
            let lens = LensOption(
                id: device.uniqueID,
                kind: kind,
                zoomFactors: zoomFactors,
                displayName: device.localizedName
            )
            lenses.append(lens)
            
            if device.isAppleProRAWSupported {
                hasProRAW = true
            }
        }
        
        // Non-Pro phones have no telephoto — still usable as a second angle.
        capabilities = LensCapabilities(
            lenses: lenses,
            proRAW: hasProRAW,
            proRes: hasProRes,
            maxVideo: hasProRes ? .proRes422 : (hasProRAW ? .hevc4K30 : .hevc1080p30)
        )
    }
    
    private func setupSession() async throws {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        let preferredType: AVCaptureDevice.DeviceType = capabilities.hasTelephoto
            ? .builtInTelephotoCamera
            : .builtInWideAngleCamera
        guard let device = AVCaptureDevice.default(preferredType, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.deviceNotAvailable
        }
        
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraError.configurationFailed("Cannot add camera input")
        }
        session.addInput(input)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(VideoOutputDelegate(source: self), queue: outputQueue)
        guard session.canAddOutput(videoOutput) else {
            throw CameraError.configurationFailed("Cannot add video output")
        }
        session.addOutput(videoOutput)
        self.videoOutput = videoOutput
        
        let photoOutput = AVCapturePhotoOutput()
        guard session.canAddOutput(photoOutput) else {
            throw CameraError.configurationFailed("Cannot add photo output")
        }
        session.addOutput(photoOutput)
        self.photoOutput = photoOutput
        
        let movieOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(movieOutput) else {
            throw CameraError.configurationFailed("Cannot add movie output")
        }
        session.addOutput(movieOutput)
        self.movieOutput = movieOutput
        
        self.captureSession = session
        self.currentDevice = device
        self.currentLensID = device.uniqueID
    }
    
    private func switchToDevice(_ device: AVCaptureDevice) async throws {
        guard let session = captureSession else { return }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        for input in session.inputs {
            session.removeInput(input)
        }
        
        let newInput = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(newInput) else {
            throw CameraError.configurationFailed("Cannot add new camera input")
        }
        session.addInput(newInput)
        
        currentDevice = device
    }
    
    private func createPhotoCaptureSettings(from settings: PhotoSettings) -> AVCapturePhotoSettings {
        var captureSettings: AVCapturePhotoSettings
        
        switch settings.format {
        case .heif:
            captureSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        case .jpeg:
            captureSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        case .proRAW:
            if #available(iOS 14.3, *), let photoOutput = photoOutput {
                if !photoOutput.availableRawPhotoPixelFormatTypes.isEmpty {
                    captureSettings = AVCapturePhotoSettings(rawPixelFormatType: photoOutput.availableRawPhotoPixelFormatTypes.first!)
                } else {
                    captureSettings = AVCapturePhotoSettings()
                }
            } else {
                captureSettings = AVCapturePhotoSettings()
            }
        }
        
        captureSettings.flashMode = settings.flash ? .on : .off
        
        return captureSettings
    }
    
    private func generateOutputURL(for type: CaptureType) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let ext = type == .photo ? "jpg" : "mov"
        let fileName = "\(UUID().uuidString).\(ext)"
        return documentsPath.appendingPathComponent(fileName)
    }
    
    private func normalizeGains(_ gains: AVCaptureDevice.WhiteBalanceGains, for device: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
        var normalized = gains
        let maxGain = device.maxWhiteBalanceGain
        
        normalized.redGain = max(1.0, min(gains.redGain, maxGain))
        normalized.greenGain = max(1.0, min(gains.greenGain, maxGain))
        normalized.blueGain = max(1.0, min(gains.blueGain, maxGain))
        
        return normalized
    }
    
    enum CaptureType {
        case photo, video
    }
    
    // MARK: - Delegate Callbacks
    
    nonisolated func handleVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampNs = UInt64(CMTimeGetSeconds(timestamp) * 1_000_000_000)
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        
        let data = Data(bytes: baseAddress, count: bytesPerRow * height)
        
        let frame = VideoFrame(
            data: data,
            width: width,
            height: height,
            timestamp: timestampNs,
            orientation: 0
        )
        
        Task { await deliverFrame(frame) }
    }
    
    private func deliverFrame(_ frame: VideoFrame) {
        frameContinuation?.yield(frame)
    }
    
    nonisolated func handlePhotoCaptured(_ photo: AVCapturePhoto) {
        Task { await processPhoto(photo) }
    }
    
    private func processPhoto(_ photo: AVCapturePhoto) {
        guard let data = photo.fileDataRepresentation() else {
            pendingPhotoCapture?.resume(throwing: CameraError.configurationFailed("No photo data"))
            pendingPhotoCapture = nil
            return
        }
        
        let captured = CapturedPhoto(
            data: data,
            format: .jpeg,
            width: Int(photo.resolvedSettings.photoDimensions.width),
            height: Int(photo.resolvedSettings.photoDimensions.height),
            timestamp: Date(),
            thumbnail: nil
        )
        
        pendingPhotoCapture?.resume(returning: captured)
        pendingPhotoCapture = nil
    }
    
    nonisolated func handleRecordingFinished(outputURL: URL, error: Error?) {
        Task { await processRecordingFinished(outputURL: outputURL, error: error) }
    }
    
    private func processRecordingFinished(outputURL: URL, error: Error?) {
        isRecording = false
        
        if let error = error {
            pendingRecording?.continuation?.resume(throwing: error)
            pendingRecording = nil
            return
        }
        
        guard let recordingState = pendingRecording else { return }
        
        let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes?[.size] as? Int64 ?? 0
        
        let duration = Date().timeIntervalSince(recordingState.startTime)
        
        let recorded = RecordedVideo(
            id: recordingState.id,
            filePath: outputURL.path,
            duration: duration,
            startTimestamp: recordingState.startTime,
            fileSize: fileSize,
            thumbnail: nil
        )
        
        pendingRecording?.continuation?.resume(returning: recorded)
        pendingRecording = nil
    }
}

// MARK: - Delegate Classes

@available(iOS 13.0, *)
private class VideoOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var source: AVCameraSource?
    
    init(source: AVCameraSource) {
        self.source = source
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        source?.handleVideoFrame(sampleBuffer)
    }
}

@available(iOS 13.0, *)
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    weak var source: AVCameraSource?
    
    init(source: AVCameraSource) {
        self.source = source
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error == nil {
            source?.handlePhotoCaptured(photo)
        }
    }
}

@available(iOS 13.0, *)
private class MovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    weak var source: AVCameraSource?
    
    init(source: AVCameraSource) {
        self.source = source
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        source?.handleRecordingFinished(outputURL: outputFileURL, error: error)
    }
}
#endif
