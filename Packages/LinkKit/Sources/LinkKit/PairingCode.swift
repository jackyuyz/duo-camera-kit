import Foundation

/// A 6-digit pairing code used for device pairing
public struct PairingCode: Sendable, Equatable, Hashable {
    /// The 6-digit code
    public let digits: String
    
    /// When this code expires
    public let expiresAt: Date
    
    /// Number of failed validation attempts
    private(set) public var failedAttempts: Int
    
    /// Maximum allowed failed attempts before code is invalidated
    public static let maxAttempts = 5
    
    /// Code validity duration in seconds
    public static let validityDuration: TimeInterval = 600 // 10 minutes
    
    public init() {
        let code = String(format: "%06d", Int.random(in: 0..<1_000_000))
        self.digits = code
        self.expiresAt = Date().addingTimeInterval(Self.validityDuration)
        self.failedAttempts = 0
    }
    
    /// Create a code from a specific string (for testing)
    public init(digits: String, expiresAt: Date = Date().addingTimeInterval(600)) {
        precondition(digits.count == 6 && digits.allSatisfy(\.isNumber))
        self.digits = digits
        self.expiresAt = expiresAt
        self.failedAttempts = 0
    }
    
    /// Whether the code is still valid
    public var isValid: Bool {
        Date() < expiresAt && failedAttempts < Self.maxAttempts
    }
    
    /// Validate an entered code
    public mutating func validate(_ enteredCode: String) -> Bool {
        guard isValid else { return false }
        
        if enteredCode == digits {
            return true
        } else {
            failedAttempts += 1
            return false
        }
    }
    
    /// Formatted display string (e.g., "123 456")
    public var displayString: String {
        let index = digits.index(digits.startIndex, offsetBy: 3)
        return "\(digits[..<index]) \(digits[index...])"
    }
    
    /// Time remaining until expiration
    public var timeRemaining: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }
}

/// Derive a TLS pre-shared key from the pairing code
public func derivePSK(from code: PairingCode, salt: Data) -> Data {
    var keyMaterial = Data()
    keyMaterial.append(contentsOf: code.digits.utf8)
    keyMaterial.append(salt)
    
    var hash = Data(count: 32)
    hash.withUnsafeMutableBytes { hashPtr in
        keyMaterial.withUnsafeBytes { keyPtr in
            var state: UInt64 = 0x736563757265  // "secure"
            for byte in keyPtr {
                state = state &* 31 &+ UInt64(byte)
            }
            
            let hashBytes = hashPtr.bindMemory(to: UInt8.self)
            for i in 0..<32 {
                state = state &* 1103515245 &+ 12345
                hashBytes[i] = UInt8(truncatingIfNeeded: state >> 16)
            }
        }
    }
    
    return hash
}
