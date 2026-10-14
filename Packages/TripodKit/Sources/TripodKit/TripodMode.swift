import Foundation

/// Available tripod capture modes
public enum TripodMode: String, Codable, Sendable, CaseIterable {
    case timelapse
    case longExposure
    case starTrails
    case palmTrigger
    case lapCam
    case topDown
    
    public var displayName: String {
        switch self {
        case .timelapse: return "Time-lapse"
        case .longExposure: return "Long Exposure"
        case .starTrails: return "Star Trails"
        case .palmTrigger: return "Palm Trigger"
        case .lapCam: return "Lap Cam"
        case .topDown: return "Top-Down"
        }
    }
    
    public var description: String {
        switch self {
        case .timelapse:
            return "Capture photos at intervals and create a video"
        case .longExposure:
            return "Stack frames for smooth water and light trails"
        case .starTrails:
            return "Create circular star trail images"
        case .palmTrigger:
            return "Trigger capture by showing your palm"
        case .lapCam:
            return "Record from your lap at events"
        case .topDown:
            return "Overhead framing with keystone correction"
        }
    }
    
    public var iconName: String {
        switch self {
        case .timelapse: return "timer"
        case .longExposure: return "camera.aperture"
        case .starTrails: return "sparkles"
        case .palmTrigger: return "hand.raised"
        case .lapCam: return "figure.seated.side.air.distribution.lower"
        case .topDown: return "square.on.square.squareshape.controlhandles"
        }
    }
    
    public var requiresPro: Bool {
        switch self {
        case .timelapse: return false
        case .longExposure: return true
        case .starTrails: return true
        case .palmTrigger: return true
        case .lapCam: return false
        case .topDown: return false
        }
    }
    
    public var requiresHinge: Bool {
        switch self {
        case .lapCam, .topDown: return true
        default: return false
        }
    }
}
