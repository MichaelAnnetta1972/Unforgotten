import SwiftUI
import SwiftData

// MARK: - Local Sticky Reminder Model
/// SwiftData model for StickyReminder, stored locally for offline support
@Model
final class LocalStickyReminder {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var title: String
    var message: String?
    var triggerTime: Date
    var repeatInterval: String  // Store as encoded string like "30_minutes"
    var isActive: Bool
    var isDismissed: Bool
    var lastNotifiedAt: Date?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        title: String,
        message: String? = nil,
        triggerTime: Date,
        repeatInterval: String = "1_hours",
        isActive: Bool = true,
        isDismissed: Bool = false,
        lastNotifiedAt: Date? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.title = title
        self.message = message
        self.triggerTime = triggerTime
        self.repeatInterval = repeatInterval
        self.isActive = isActive
        self.isDismissed = isDismissed
        self.lastNotifiedAt = lastNotifiedAt
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: StickyReminder) {
        // Encode the repeat interval to string format "value_unit"
        let intervalString = "\(remote.repeatInterval.value)_\(remote.repeatInterval.unit.rawValue)"

        self.init(
            id: remote.id,
            accountId: remote.accountId,
            title: remote.title,
            message: remote.message,
            triggerTime: remote.triggerTime,
            repeatInterval: intervalString,
            isActive: remote.isActive,
            isDismissed: remote.isDismissed,
            lastNotifiedAt: remote.lastNotifiedAt,
            sortOrder: remote.sortOrder,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> StickyReminder {
        StickyReminder(
            id: id,
            accountId: accountId,
            title: title,
            message: message,
            triggerTime: triggerTime,
            repeatInterval: decodedRepeatInterval,
            isActive: isActive,
            isDismissed: isDismissed,
            lastNotifiedAt: lastNotifiedAt,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: StickyReminder) {
        self.accountId = remote.accountId
        self.title = remote.title
        self.message = remote.message
        self.triggerTime = remote.triggerTime
        self.repeatInterval = "\(remote.repeatInterval.value)_\(remote.repeatInterval.unit.rawValue)"
        self.isActive = remote.isActive
        self.isDismissed = remote.isDismissed
        self.lastNotifiedAt = remote.lastNotifiedAt
        self.sortOrder = remote.sortOrder
        self.createdAt = remote.createdAt
        self.updatedAt = remote.updatedAt
        self.isSynced = true
    }

    // MARK: - Sync Helpers
    func markAsModified() {
        self.updatedAt = Date()
        self.isSynced = false
    }

    // MARK: - Computed Properties
    var decodedRepeatInterval: StickyReminderInterval {
        let components = repeatInterval.split(separator: "_", maxSplits: 1)
        if components.count == 2,
           let value = Int(components[0]),
           let unit = StickyReminderTimeUnit(rawValue: String(components[1])) {
            return StickyReminderInterval(value: value, unit: unit)
        }
        return .everyHour
    }

    var shouldNotify: Bool {
        isActive && !isDismissed && triggerTime <= Date()
    }
}
