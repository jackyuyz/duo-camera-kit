import Foundation

/// Kind of camera lens
public enum LensKind: String, Codable, Sendable, Equatable, CaseIterable {
    case ultraWide
    case wide
    case telephoto
}

/// Represents a camera lens option available on a device
public struct LensOption: Codable, Hashable, Sendable, Identifiable {
    /// Unique device identifier (AVCaptureDevice.uniqueID on real device)
    public var id: String
    
    /// Kind of lens
    public var kind: LensKind
    
    /// Available zoom factors for this lens
    public var zoomFactors: [Double]
    
    /// User-facing display name
    public var displayName: String
    
    public init(id: String, kind: LensKind, zoomFactors: [Double], displayName: String) {
        self.id = id
        self.kind = kind
        self.zoomFactors = zoomFactors
        self.displayName = displayName
    }
    
    /// Standard display label (e.g., "0.5×", "1×", "3×")
    public var shortLabel: String {
        switch kind {
        case .ultraWide:
            return "0.5×"
        case .wide:
            return "1×"
        case .telephoto:
            if let maxZoom = zoomFactors.max() {
                return "\(Int(maxZoom))×"
            }
            return "3×"
        }
    }
}

/// Capabilities of a lens device (e.g., an iPhone being used as a remote lens)
public struct LensCapabilities: Codable, Hashable, Sendable {
    /// Available lenses on this device
    public var lenses: [LensOption]
    
    /// Whether ProRAW capture is supported
    public var proRAW: Bool
    
    /// Whether ProRes video is supported
    public var proRes: Bool
    
    /// Maximum video format supported
    public var maxVideo: VideoFormatOption
    
    public init(lenses: [LensOption], proRAW: Bool, proRes: Bool, maxVideo: VideoFormatOption) {
        self.lenses = lenses
        self.proRAW = proRAW
        self.proRes = proRes
        self.maxVideo = maxVideo
    }
    
    /// Mock capabilities for an iPhone Pro with telephoto
    public static let mockIPhonePro = LensCapabilities(
        lenses: [
            LensOption(id: "mock-ultrawide", kind: .ultraWide, zoomFactors: [0.5], displayName: "Ultra Wide"),
            LensOption(id: "mock-wide", kind: .wide, zoomFactors: [1.0, 1.5, 2.0], displayName: "Wide"),
            LensOption(id: "mock-tele", kind: .telephoto, zoomFactors: [3.0, 5.0], displayName: "Telephoto")
        ],
        proRAW: true,
        proRes: true,
        maxVideo: .hevc4K60
    )
    
    /// Mock capabilities for iPhone Duo (no telephoto)
    public static let mockIPhoneDuo = LensCapabilities(
        lenses: [
            LensOption(id: "mock-ultrawide", kind: .ultraWide, zoomFactors: [0.5], displayName: "Ultra Wide"),
            LensOption(id: "mock-wide", kind: .wide, zoomFactors: [1.0, 1.5, 2.0], displayName: "Wide")
        ],
        proRAW: false,
        proRes: false,
        maxVideo: .hevc4K60
    )
}

/// Video format options
public enum VideoFormatOption: String, Codable, Sendable, Equatable, CaseIterable {
    case h264_1080p30
    case h264_1080p60
    case hevc1080p30
    case hevc1080p60
    case hevc4K30
    case hevc4K60
    case proRes422
    case proRes422HQ
    
    public var displayName: String {
        switch self {
        case .h264_1080p30: return "H.264 1080p30"
        case .h264_1080p60: return "H.264 1080p60"
        case .hevc1080p30: return "HEVC 1080p30"
        case .hevc1080p60: return "HEVC 1080p60"
        case .hevc4K30: return "HEVC 4K30"
        case .hevc4K60: return "HEVC 4K60"
        case .proRes422: return "ProRes 422"
        case .proRes422HQ: return "ProRes 422 HQ"
        }
    }
    
    public var isProRes: Bool {
        switch self {
        case .proRes422, .proRes422HQ: return true
        default: return false
        }
    }
}

/// Photo format options
public enum PhotoFormatOption: String, Codable, Sendable, Equatable, CaseIterable {
    case heif
    case jpeg
    case proRAW
    
    public var displayName: String {
        switch self {
        case .heif: return "HEIF"
        case .jpeg: return "JPEG"
        case .proRAW: return "ProRAW"
        }
    }
}
