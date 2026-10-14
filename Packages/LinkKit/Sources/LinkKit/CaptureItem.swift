import Foundation

/// Kind of capture
public enum CaptureKind: String, Codable, Sendable, Equatable {
    case photo
    case video
    case timelapse
    case longExposure
    case starTrails
}

/// A captured item (photo or video)
public struct CaptureItem: Codable, Sendable, Identifiable, Equatable {
    /// Unique identifier
    public var id: UUID
    
    /// Kind of capture
    public var kind: CaptureKind
    
    /// Which device captured this
    public var source: DeviceRole
    
    /// Local file name
    public var fileName: String
    
    /// When it was created
    public var createdAt: Date
    
    /// Whether it has been transferred to the Control device
    public var transferred: Bool
    
    /// File size in bytes
    public var fileSize: Int64
    
    /// Thumbnail data (JPEG)
    public var thumbnail: Data?
    
    /// Duration in seconds (for video)
    public var duration: Double?
    
    /// Related capture (e.g., sync recording partner)
    public var relatedCaptureId: UUID?
    
    public init(
        id: UUID = UUID(),
        kind: CaptureKind,
        source: DeviceRole,
        fileName: String,
        createdAt: Date = .now,
        transferred: Bool = false,
        fileSize: Int64 = 0,
        thumbnail: Data? = nil,
        duration: Double? = nil,
        relatedCaptureId: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.source = source
        self.fileName = fileName
        self.createdAt = createdAt
        self.transferred = transferred
        self.fileSize = fileSize
        self.thumbnail = thumbnail
        self.duration = duration
        self.relatedCaptureId = relatedCaptureId
    }
    
    /// Human-readable file size
    public var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    /// Human-readable duration
    public var durationFormatted: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }
}

/// Sidecar file for sync recordings
public struct SyncRecordingSidecar: Codable, Sendable {
    /// ID of the control (Duo) recording
    public var controlCaptureId: UUID
    
    /// ID of the lens (Pro) recording
    public var lensCaptureId: UUID
    
    /// Scheduled start time (nanoseconds since epoch)
    public var scheduledStartNs: UInt64
    
    /// Actual start time on control (nanoseconds)
    public var controlActualStartNs: UInt64?
    
    /// Actual start time on lens (nanoseconds)
    public var lensActualStartNs: UInt64?
    
    /// Clock offset at recording time
    public var clockOffsetNs: Int64
    
    /// Whether sync clap was used
    public var syncClapUsed: Bool
    
    public init(
        controlCaptureId: UUID,
        lensCaptureId: UUID,
        scheduledStartNs: UInt64,
        clockOffsetNs: Int64,
        syncClapUsed: Bool = true
    ) {
        self.controlCaptureId = controlCaptureId
        self.lensCaptureId = lensCaptureId
        self.scheduledStartNs = scheduledStartNs
        self.clockOffsetNs = clockOffsetNs
        self.syncClapUsed = syncClapUsed
    }
    
    /// Estimated sync offset between recordings in milliseconds
    public var estimatedOffsetMs: Double? {
        guard let controlStart = controlActualStartNs,
              let lensStart = lensActualStartNs else {
            return nil
        }
        return Double(Int64(controlStart) - Int64(lensStart) - clockOffsetNs) / 1_000_000
    }
}
