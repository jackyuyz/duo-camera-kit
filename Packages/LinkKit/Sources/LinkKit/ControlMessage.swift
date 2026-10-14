import Foundation
import CameraKit

/// Messages sent between Control and Lens devices
public enum ControlMessage: Codable, Sendable {
    /// Initial handshake with peer info
    case hello(PeerInfo)
    
    /// Select a specific camera lens
    case selectLens(String)
    
    /// Set zoom factor
    case zoom(Double)
    
    /// Set focus/exposure point (normalized 0-1)
    case focus(CGPoint)
    
    /// Set exposure bias (-3 to +3)
    case exposureBias(Float)
    
    /// Set white balance preset
    case whiteBalance(WBPreset)
    
    /// Lock or unlock auto-exposure and auto-focus
    case lockAEAF(Bool)
    
    /// Capture a photo with settings
    case capturePhoto(PhotoSettings)
    
    /// Start video recording at a scheduled time (nanoseconds since epoch)
    case startRecording(at: UInt64)
    
    /// Stop video recording
    case stopRecording
    
    /// Request transfer of a specific capture
    case requestTransfer(UUID)
    
    /// Ping for latency measurement (local timestamp in nanoseconds)
    case ping(UInt64)
    
    /// Pong response with local and remote timestamps
    case pong(localTimestamp: UInt64, remoteTimestamp: UInt64)
    
    /// Status update from Lens
    case status(LensStatus)
    
    /// Photo captured notification with thumbnail
    case photoCaptured(id: UUID, thumbnail: Data)
    
    /// Video recording started
    case recordingStarted(id: UUID, startTimestamp: UInt64)
    
    /// Video recording stopped
    case recordingStopped(id: UUID, duration: Double, fileSize: Int64)
    
    /// Error from the Lens
    case error(String)
    
    /// Goodbye message before disconnecting
    case goodbye
    
    /// File transfer request
    case fileTransferRequest(TransferRequest)
    
    /// File transfer data chunk
    case fileTransferChunk(TransferChunk)
    
    /// Transfer completed acknowledgment
    case transferComplete(UUID)
    
    /// Transfer cancelled
    case transferCancelled(UUID)
}

/// Protocol version for compatibility checking
public struct ProtocolVersion: Codable, Sendable, Equatable, Comparable {
    public let major: Int
    public let minor: Int
    
    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }
    
    public static let current = ProtocolVersion(major: 1, minor: 0)
    
    public static func < (lhs: ProtocolVersion, rhs: ProtocolVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        return lhs.minor < rhs.minor
    }
    
    /// Check if this version is compatible with another
    public func isCompatible(with other: ProtocolVersion) -> Bool {
        major == other.major
    }
    
    public var description: String {
        "\(major).\(minor)"
    }
}
