// FoldKit: Unified fold state handling for iOS foldable devices
// This package abstracts hinge state from device-specific APIs.

@_exported import Foundation

/// Parse launch arguments for fold mock configuration.
/// Values: `nohinge`, `closed`, `open`, `half:<deg>`, `sweep:<from>-<to>:<seconds>`, `script:<bundled-json-name>`
public func parseFoldMockArgument(_ value: String) -> FoldMockConfiguration? {
    let lowercased = value.lowercased()
    
    if lowercased == "nohinge" {
        return .fixed(.noHinge, angle: nil)
    } else if lowercased == "closed" {
        return .fixed(.closed, angle: 0)
    } else if lowercased == "open" {
        return .fixed(.fullyOpen, angle: 180)
    } else if lowercased.hasPrefix("half:") {
        let angleStr = String(lowercased.dropFirst(5))
        if let angle = Double(angleStr) {
            return .fixed(.partiallyOpen, angle: angle)
        }
    } else if lowercased.hasPrefix("sweep:") {
        let params = String(lowercased.dropFirst(6))
        let parts = params.split(separator: ":")
        if parts.count == 2,
           let duration = Double(parts[1]) {
            let range = parts[0].split(separator: "-")
            if range.count == 2,
               let from = Double(range[0]),
               let to = Double(range[1]) {
                return .sweep(from: from, to: to, duration: duration)
            }
        }
    } else if lowercased.hasPrefix("script:") {
        let scriptName = String(value.dropFirst(7))
        return .script(name: scriptName)
    }
    
    return nil
}

/// Configuration for mock fold state
public enum FoldMockConfiguration: Sendable {
    case fixed(FoldPosture, angle: Double?)
    case sweep(from: Double, to: Double, duration: Double)
    case script(name: String)
}

/// Check if we should use mock fold state based on launch arguments
public func shouldUseMockFoldState() -> FoldMockConfiguration? {
    let args = ProcessInfo.processInfo.arguments
    
    guard let mockIndex = args.firstIndex(of: "-FoldMock"),
          mockIndex + 1 < args.count else {
        return nil
    }
    
    let value = args[mockIndex + 1]
    
    #if DEBUG
    return parseFoldMockArgument(value)
    #else
    if args.contains("-UITestMode") {
        return parseFoldMockArgument(value)
    }
    return nil
    #endif
}
