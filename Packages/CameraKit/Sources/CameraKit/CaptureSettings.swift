import Foundation

/// Settings for capturing a photo
public struct PhotoSettings: Codable, Sendable, Equatable {
    /// Photo format to use
    public var format: PhotoFormatOption
    
    /// Whether flash is enabled
    public var flashEnabled: Bool
    
    /// Whether to use HDR
    public var hdrEnabled: Bool
    
    public init(format: PhotoFormatOption = .heif, flashEnabled: Bool = false, hdrEnabled: Bool = true) {
        self.format = format
        self.flashEnabled = flashEnabled
        self.hdrEnabled = hdrEnabled
    }
    
    public static let `default` = PhotoSettings()
}

/// Settings for video recording
public struct VideoSettings: Codable, Sendable, Equatable {
    /// Video format to use
    public var format: VideoFormatOption
    
    /// Whether to record audio
    public var audioEnabled: Bool
    
    /// Whether stabilization is enabled
    public var stabilizationEnabled: Bool
    
    public init(format: VideoFormatOption = .hevc1080p30, audioEnabled: Bool = true, stabilizationEnabled: Bool = true) {
        self.format = format
        self.audioEnabled = audioEnabled
        self.stabilizationEnabled = stabilizationEnabled
    }
    
    public static let `default` = VideoSettings()
}

/// White balance presets
public enum WBPreset: String, Codable, Sendable, Equatable, CaseIterable {
    case auto
    case sunny
    case cloudy
    case shade
    case tungsten
    case fluorescent
    case flash
    case custom
    
    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .sunny: return "Sunny"
        case .cloudy: return "Cloudy"
        case .shade: return "Shade"
        case .tungsten: return "Tungsten"
        case .fluorescent: return "Fluorescent"
        case .flash: return "Flash"
        case .custom: return "Custom"
        }
    }
    
    /// Approximate color temperature in Kelvin
    public var temperatureKelvin: Int {
        switch self {
        case .auto: return 5500
        case .sunny: return 5500
        case .cloudy: return 6500
        case .shade: return 7500
        case .tungsten: return 3200
        case .fluorescent: return 4000
        case .flash: return 5500
        case .custom: return 5500
        }
    }
}

/// Current camera exposure/focus state
public struct CameraState: Codable, Sendable, Equatable {
    /// Current zoom factor
    public var zoomFactor: Double
    
    /// Exposure bias (-3 to +3 typically)
    public var exposureBias: Float
    
    /// Current white balance preset
    public var whiteBalance: WBPreset
    
    /// Whether auto-exposure is locked
    public var aeLocked: Bool
    
    /// Whether auto-focus is locked
    public var afLocked: Bool
    
    /// Focus/exposure point (normalized 0-1)
    public var focusPoint: CGPoint?
    
    public init(
        zoomFactor: Double = 1.0,
        exposureBias: Float = 0.0,
        whiteBalance: WBPreset = .auto,
        aeLocked: Bool = false,
        afLocked: Bool = false,
        focusPoint: CGPoint? = nil
    ) {
        self.zoomFactor = zoomFactor
        self.exposureBias = exposureBias
        self.whiteBalance = whiteBalance
        self.aeLocked = aeLocked
        self.afLocked = afLocked
        self.focusPoint = focusPoint
    }
    
    public static let `default` = CameraState()
}
