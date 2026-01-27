import SwiftUI
import SwiftData

// MARK: - Local Countdown Model
/// SwiftData model for Countdown, stored locally for offline support
@Model
final class LocalCountdown {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var title: String
    var date: Date
    var type: String  // Store as raw value
    var customType: String?
    var notes: String?
    var reminderOffsetMinutes: Int?
    var isRecurring: Bool
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
        date: Date,
        type: String = "countdown",
        customType: String? = nil,
        notes: String? = nil,
        reminderOffsetMinutes: Int? = nil,
        isRecurring: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.title = title
        self.date = date
        self.type = type
        self.customType = customType
        self.notes = notes
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.isRecurring = isRecurring
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: Countdown) {
        self.init(
            id: remote.id,
            accountId: remote.accountId,
            title: remote.title,
            date: remote.date,
            type: remote.type.rawValue,
            customType: remote.customType,
            notes: remote.notes,
            reminderOffsetMinutes: remote.reminderOffsetMinutes,
            isRecurring: remote.isRecurring,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> Countdown {
        Countdown(
            id: id,
            accountId: accountId,
            title: title,
            date: date,
            type: CountdownType(rawValue: type) ?? .countdown,
            customType: customType,
            notes: notes,
            reminderOffsetMinutes: reminderOffsetMinutes,
            isRecurring: isRecurring,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: Countdown) {
        self.accountId = remote.accountId
        self.title = remote.title
        self.date = remote.date
        self.type = remote.type.rawValue
        self.customType = remote.customType
        self.notes = remote.notes
        self.reminderOffsetMinutes = remote.reminderOffsetMinutes
        self.isRecurring = remote.isRecurring
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
    var countdownType: CountdownType {
        get { CountdownType(rawValue: type) ?? .countdown }
        set { type = newValue.rawValue }
    }

    var displayTypeName: String {
        if countdownType == .custom, let customName = customType, !customName.isEmpty {
            return customName
        }
        return countdownType.displayName
    }

    var daysUntilNextOccurrence: Int {
        if isRecurring {
            return date.daysUntilNextOccurrence()
        } else {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let eventDate = calendar.startOfDay(for: date)
            let components = calendar.dateComponents([.day], from: today, to: eventDate)
            return max(0, components.day ?? 0)
        }
    }

    var hasPassed: Bool {
        if isRecurring { return false }
        return date < Date()
    }
}
