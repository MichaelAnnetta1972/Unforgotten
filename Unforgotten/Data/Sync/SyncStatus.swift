import SwiftUI

// MARK: - Global Sync Status
/// Represents the overall sync status of the application
enum GlobalSyncStatus: Equatable {
    case idle
    case syncing(entity: String, progress: Double)
    case completed(changesCount: Int)
    case offline
    case failed(error: String)

    // MARK: - Computed Properties

    var isActive: Bool {
        if case .syncing = self { return true }
        return false
    }

    var isOffline: Bool {
        if case .offline = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .idle:
            return "Synced"
        case .syncing(let entity, let progress):
            if progress > 0 {
                return "Syncing \(entity)... \(Int(progress * 100))%"
            }
            return "Syncing \(entity)..."
        case .completed(let count):
            if count == 0 {
                return "Up to date"
            }
            return "\(count) change\(count == 1 ? "" : "s") synced"
        case .offline:
            return "Offline"
        case .failed(let error):
            return "Sync failed: \(error)"
        }
    }

    var icon: String {
        switch self {
        case .idle:
            return "checkmark.icloud"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .completed:
            return "checkmark.icloud.fill"
        case .offline:
            return "icloud.slash"
        case .failed:
            return "exclamationmark.icloud"
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .syncing:
            return .blue
        case .completed:
            return .green
        case .offline:
            return .orange
        case .failed:
            return .red
        }
    }
}

// MARK: - Entity Sync Status
/// Represents the sync status for a specific entity type
enum EntitySyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(error: String)

    var isActive: Bool {
        if case .syncing = self { return true }
        return false
    }
}

// MARK: - Sync Direction
/// Direction of sync operation
enum SyncDirection {
    case push    // Local -> Remote
    case pull    // Remote -> Local
    case bidirectional

    var displayName: String {
        switch self {
        case .push: return "Uploading"
        case .pull: return "Downloading"
        case .bidirectional: return "Syncing"
        }
    }
}

// MARK: - Sync Result
/// Result of a sync operation
struct SyncResult {
    let success: Bool
    let changesCount: Int
    let errors: [String]
    let timestamp: Date

    init(success: Bool, changesCount: Int = 0, errors: [String] = []) {
        self.success = success
        self.changesCount = changesCount
        self.errors = errors
        self.timestamp = Date()
    }

    static let empty = SyncResult(success: true)

    static func failure(_ error: String) -> SyncResult {
        SyncResult(success: false, errors: [error])
    }
}

// MARK: - Sync Error
/// Errors that can occur during sync
enum SyncError: LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case serverError(String)
    case conflictDetected(entityId: UUID)
    case dataCorruption(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to sync"
        case .networkUnavailable:
            return "No internet connection"
        case .serverError(let message):
            return "Server error: \(message)"
        case .conflictDetected(let id):
            return "Conflict detected for item \(id.uuidString.prefix(8))"
        case .dataCorruption(let message):
            return "Data error: \(message)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
