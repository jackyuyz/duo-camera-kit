import Foundation

/// Represents a video frame from the camera
public struct VideoFrame: Sendable {
    /// Raw pixel data
    public let data: Data
    
    /// Frame width in pixels
    public let width: Int
    
    /// Frame height in pixels
    public let height: Int
    
    /// Presentation timestamp
    public let timestamp: UInt64
    
    /// Frame orientation in degrees (0, 90, 180, 270)
    public let orientation: Int
    
    public init(data: Data, width: Int, height: Int, timestamp: UInt64, orientation: Int = 0) {
        self.data = data
        self.width = width
        self.height = height
        self.timestamp = timestamp
        self.orientation = orientation
    }
}

/// Result of a photo capture
public struct CapturedPhoto: Sendable {
    /// Unique identifier
    public let id: UUID
    
    /// Photo data
    public let data: Data
    
    /// Format of the photo
    public let format: PhotoFormatOption
    
    /// Width in pixels
    public let width: Int
    
    /// Height in pixels
    public let height: Int
    
    /// Capture timestamp
    public let timestamp: Date
    
    /// Thumbnail data (JPEG)
    public let thumbnail: Data?
    
    /// Optional metadata
    public let metadata: [String: String]
    
    public init(
        id: UUID = UUID(),
        data: Data,
        format: PhotoFormatOption,
        width: Int,
        height: Int,
        timestamp: Date = .now,
        thumbnail: Data? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.data = data
        self.format = format
        self.width = width
        self.height = height
        self.timestamp = timestamp
        self.thumbnail = thumbnail
        self.metadata = metadata
    }
}

/// Result of a video recording
public struct RecordedVideo: Sendable {
    /// Unique identifier
    public let id: UUID
    
    /// Path to the video file (in app container)
    public let filePath: String
    
    /// Duration in seconds
    public let duration: Double
    
    /// Start timestamp
    public let startTimestamp: Date
    
    /// File size in bytes
    public let fileSize: Int64
    
    /// Thumbnail data (JPEG)
    public let thumbnail: Data?
    
    public init(
        id: UUID = UUID(),
        filePath: String,
        duration: Double,
        startTimestamp: Date,
        fileSize: Int64,
        thumbnail: Data? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.duration = duration
        self.startTimestamp = startTimestamp
        self.fileSize = fileSize
        self.thumbnail = thumbnail
    }
}

/// Protocol for camera sources (real AVFoundation or mock)
/// Platform-independent for testing on Linux
public protocol CameraSource: AnyObject, Sendable {
    /// Available lenses on this camera source
    var capabilities: LensCapabilities { get }
    
    /// Currently selected lens ID
    var currentLensID: String? { get }
    
    /// Current camera state (zoom, exposure, etc.)
    var state: CameraState { get }
    
    /// Whether currently recording video
    var isRecording: Bool { get }
    
    /// Stream of video frames for preview
    func frames() -> AsyncStream<VideoFrame>
    
    /// Select a specific lens
    func selectLens(_ lensID: String) async throws
    
    /// Set zoom factor
    func setZoom(_ factor: Double) async throws
    
    /// Set focus/exposure point (normalized 0-1)
    func setFocusPoint(_ point: CGPoint) async throws
    
    /// Set exposure bias
    func setExposureBias(_ bias: Float) async throws
    
    /// Set white balance preset
    func setWhiteBalance(_ preset: WBPreset) async throws
    
    /// Lock auto-exposure and auto-focus
    func lockAEAF(_ locked: Bool) async throws
    
    /// Capture a photo
    func capturePhoto(settings: PhotoSettings) async throws -> CapturedPhoto
    
    /// Start video recording
    func startRecording(settings: VideoSettings, at scheduledTime: UInt64?) async throws
    
    /// Stop video recording
    func stopRecording() async throws -> RecordedVideo
    
    /// Start the camera session
    func start() async throws
    
    /// Stop the camera session
    func stop() async
}

/// Errors from camera operations
public enum CameraError: Error, Sendable, Equatable {
    case notAuthorized
    case deviceNotAvailable
    case lensNotFound(String)
    case captureInProgress
    case noRecordingInProgress
    case sessionNotRunning
    case configurationFailed(String)
}
