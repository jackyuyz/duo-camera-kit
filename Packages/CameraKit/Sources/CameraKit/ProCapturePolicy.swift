import Foundation

/// Capture limits for the free tier vs Camera Kit Pro.
/// Control applies this before sending capture commands. Lens does not re-check.
public struct ProCapturePolicy: Sendable, Equatable {
    public var isProUnlocked: Bool
    
    public init(isProUnlocked: Bool) {
        self.isProUnlocked = isProUnlocked
    }
    
    public static let free = ProCapturePolicy(isProUnlocked: false)
    public static let pro = ProCapturePolicy(isProUnlocked: true)
    
    /// Free: photos up to 12 MP (spec A: Lens free tier)
    public static let freeMaxMegapixels = 12
    
    public var allowsFullResolution: Bool { isProUnlocked }
    public var allowsProRAW: Bool { isProUnlocked }
    public var allowsProRes: Bool { isProUnlocked }
    public var allowsAutoTransfer: Bool { isProUnlocked }
    public var allows4K: Bool { isProUnlocked }
    
    public func gatedPhotoSettings(_ settings: PhotoSettings) -> PhotoSettings {
        var result = settings
        if !allowsProRAW, result.format == .proRAW {
            result.format = .heif
        }
        return result
    }
    
    public func gatedVideoSettings(_ settings: VideoSettings) -> VideoSettings {
        var result = settings
        if !allowsProRes, result.format.isProRes {
            result.format = .hevc1080p30
        }
        if !allows4K, result.format.is4K {
            result.format = .hevc1080p30
        }
        return result
    }
    
    /// Cap pixel dimensions to 12 MP when Pro is locked.
    public func photoPixelSize(width: Int, height: Int) -> (width: Int, height: Int) {
        guard !allowsFullResolution else { return (width, height) }
        let megapixels = Double(width * height) / 1_000_000.0
        guard megapixels > Double(Self.freeMaxMegapixels) else { return (width, height) }
        let scale = sqrt(Double(Self.freeMaxMegapixels) / megapixels)
        return (max(1, Int(Double(width) * scale)), max(1, Int(Double(height) * scale)))
    }
}
