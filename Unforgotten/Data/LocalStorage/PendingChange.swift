import SwiftUI
import SwiftData

// MARK: - Pending Change Model
/// Tracks offline changes that need to be synced to Supabase
@Model
final class PendingChange {
    // MARK: - Properties
    var id: UUID
    var entityType: String       // "account", "profile", "medication", etc.
    var entityId: UUID
    var accountId: UUID
    var changeType: String       // "create", "update", "delete"
    var payload: Data?           // JSON-encoded change data for complex changes
    var createdAt: Date
    var retryCount: Int
    var lastError: String?
    var lastAttemptAt: Date?

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        entityType: String,
        entityId: UUID,
        accountId: UUID,
        changeType: String,
        payload: Data? = nil,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        lastError: String? = nil,
        lastAttemptAt: Date? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.accountId = accountId
        self.changeType = changeType
        self.payload = payload
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastError = lastError
        self.lastAttemptAt = lastAttemptAt
    }

    // MARK: - Computed Properties

    /// Whether this change should be retried
    var shouldRetry: Bool {
        retryCount < PendingChange.maxRetries
    }

    /// Maximum number of retry attempts
    static let maxRetries = 5

    // MARK: - Change Types
    enum ChangeType: String {
        case create
        case update
        case delete
    }

    // MARK: - Entity Types
    enum EntityType: String {
        case account
        case accountMember
        case profile
        case profileDetail
        case profileConnection
        case medication
        case medicationSchedule
        case medicationLog
        case appointment
        case usefulContact
        case toDoList
        case toDoItem
        case countdown
        case stickyReminder
        case moodEntry
        case importantAccount
    }

    // MARK: - Convenience Methods

    /// Create a pending change for entity creation
    static func create(
        entityType: String,
        entityId: UUID,
        accountId: UUID,
        payload: Data? = nil
    ) -> PendingChange {
        PendingChange(
            entityType: entityType,
            entityId: entityId,
            accountId: accountId,
            changeType: ChangeType.create.rawValue,
            payload: payload
        )
    }

    /// Create a pending change for entity update
    static func update(
        entityType: String,
        entityId: UUID,
        accountId: UUID,
        payload: Data? = nil
    ) -> PendingChange {
        PendingChange(
            entityType: entityType,
            entityId: entityId,
            accountId: accountId,
            changeType: ChangeType.update.rawValue,
            payload: payload
        )
    }

    /// Create a pending change for entity deletion
    static func delete(
        entityType: String,
        entityId: UUID,
        accountId: UUID
    ) -> PendingChange {
        PendingChange(
            entityType: entityType,
            entityId: entityId,
            accountId: accountId,
            changeType: ChangeType.delete.rawValue
        )
    }

    /// Record a failed attempt
    func recordFailure(error: String) {
        retryCount += 1
        lastError = error
        lastAttemptAt = Date()
    }
}
