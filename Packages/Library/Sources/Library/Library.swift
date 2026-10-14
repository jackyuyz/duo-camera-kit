// Library: Local capture storage using SwiftData
// Platform-agnostic interfaces for testing

import Foundation
import LinkKit

/// Protocol for capture library operations
public protocol CaptureLibrary: AnyObject, Sendable {
    /// All captures, newest first
    func allCaptures() async -> [CaptureItem]
    
    /// Get a specific capture
    func capture(id: UUID) async -> CaptureItem?
    
    /// Add a new capture
    func addCapture(_ item: CaptureItem) async throws
    
    /// Update a capture (e.g., mark as transferred)
    func updateCapture(_ item: CaptureItem) async throws
    
    /// Delete a capture
    func deleteCapture(id: UUID) async throws
    
    /// Get captures by kind
    func captures(kind: CaptureKind) async -> [CaptureItem]
    
    /// Get untransferred captures
    func untransferredCaptures() async -> [CaptureItem]
}

/// In-memory capture library for testing
public actor MockCaptureLibrary: CaptureLibrary {
    private var captures: [UUID: CaptureItem] = [:]
    
    public init() {}
    
    public func allCaptures() async -> [CaptureItem] {
        captures.values.sorted { $0.createdAt > $1.createdAt }
    }
    
    public func capture(id: UUID) async -> CaptureItem? {
        captures[id]
    }
    
    public func addCapture(_ item: CaptureItem) async throws {
        captures[item.id] = item
    }
    
    public func updateCapture(_ item: CaptureItem) async throws {
        guard captures[item.id] != nil else {
            throw LibraryError.notFound
        }
        captures[item.id] = item
    }
    
    public func deleteCapture(id: UUID) async throws {
        guard captures.removeValue(forKey: id) != nil else {
            throw LibraryError.notFound
        }
    }
    
    public func captures(kind: CaptureKind) async -> [CaptureItem] {
        captures.values
            .filter { $0.kind == kind }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    public func untransferredCaptures() async -> [CaptureItem] {
        captures.values
            .filter { !$0.transferred }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

/// Library errors
public enum LibraryError: Error, Sendable {
    case notFound
    case saveFailed
    case deleteFailed
}
