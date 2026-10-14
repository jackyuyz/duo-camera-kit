import Foundation
import CameraKit

/// Role of a device in the Duo Camera Kit system
public enum DeviceRole: String, Codable, Sendable, Equatable {
    /// Control device (typically the Duo) - monitors and controls the Lens
    case control
    /// Lens device (typically an older iPhone Pro) - provides camera feed
    case lens
}

/// Information about a peer device
public struct PeerInfo: Codable, Hashable, Sendable, Identifiable {
    /// Unique identifier for this peer
    public let id: UUID
    
    /// Display name of the device
    public var name: String
    
    /// Device model (e.g., "iPhone 15 Pro")
    public var model: String
    
    /// App version string
    public var appVersion: String
    
    /// Camera capabilities (for Lens devices)
    public var capabilities: LensCapabilities?
    
    public init(
        id: UUID = UUID(),
        name: String,
        model: String,
        appVersion: String,
        capabilities: LensCapabilities? = nil
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.appVersion = appVersion
        self.capabilities = capabilities
    }
    
    /// Create a mock peer for testing
    public static func mock(
        name: String = "Test Device",
        model: String = "iPhone 15 Pro",
        role: DeviceRole = .lens
    ) -> PeerInfo {
        PeerInfo(
            name: name,
            model: model,
            appVersion: "1.0.0",
            capabilities: role == .lens ? .mockIPhonePro : nil
        )
    }
}

/// Status of the Lens device
public struct LensStatus: Codable, Sendable, Equatable {
    /// Battery level (0.0 - 1.0)
    public var battery: Float
    
    /// Thermal state (0 = nominal, 1 = fair, 2 = serious, 3 = critical)
    public var thermal: Int
    
    /// Whether currently recording video
    public var isRecording: Bool
    
    /// Available storage in bytes
    public var freeBytes: Int64
    
    public init(battery: Float, thermal: Int, isRecording: Bool, freeBytes: Int64) {
        self.battery = battery
        self.thermal = thermal
        self.isRecording = isRecording
        self.freeBytes = freeBytes
    }
    
    public static let mock = LensStatus(
        battery: 0.85,
        thermal: 0,
        isRecording: false,
        freeBytes: 50_000_000_000
    )
    
    /// Human-readable thermal state
    public var thermalDescription: String {
        switch thermal {
        case 0: return "Normal"
        case 1: return "Fair"
        case 2: return "Serious"
        case 3: return "Critical"
        default: return "Unknown"
        }
    }
    
    /// Whether thermal state requires action
    public var isThermalWarning: Bool {
        thermal >= 2
    }
    
    /// Free storage in human-readable format
    public var freeStorageFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: freeBytes)
    }
}
