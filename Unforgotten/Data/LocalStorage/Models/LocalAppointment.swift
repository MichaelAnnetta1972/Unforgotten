import SwiftUI
import SwiftData

// MARK: - Local Appointment Model
/// SwiftData model for Appointment, stored locally for offline support
@Model
final class LocalAppointment {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var profileId: UUID
    var withProfileId: UUID?
    var type: String  // Store as raw value
    var title: String
    var date: Date
    var time: Date?
    var location: String?
    var notes: String?
    var reminderOffsetMinutes: Int?
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        profileId: UUID,
        withProfileId: UUID? = nil,
        type: String = "general",
        title: String,
        date: Date,
        time: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        reminderOffsetMinutes: Int? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.profileId = profileId
        self.withProfileId = withProfileId
        self.type = type
        self.title = title
        self.date = date
        self.time = time
        self.location = location
        self.notes = notes
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: Appointment) {
        self.init(
            id: remote.id,
            accountId: remote.accountId,
            profileId: remote.profileId,
            withProfileId: remote.withProfileId,
            type: remote.type.rawValue,
            title: remote.title,
            date: remote.date,
            time: remote.time,
            location: remote.location,
            notes: remote.notes,
            reminderOffsetMinutes: remote.reminderOffsetMinutes,
            isCompleted: remote.isCompleted,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> Appointment {
        Appointment(
            id: id,
            accountId: accountId,
            profileId: profileId,
            withProfileId: withProfileId,
            type: AppointmentType(rawValue: type) ?? .general,
            title: title,
            date: date,
            time: time,
            location: location,
            notes: notes,
            reminderOffsetMinutes: reminderOffsetMinutes,
            isCompleted: isCompleted,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: Appointment) {
        self.accountId = remote.accountId
        self.profileId = remote.profileId
        self.withProfileId = remote.withProfileId
        self.type = remote.type.rawValue
        self.title = remote.title
        self.date = remote.date
        self.time = remote.time
        self.location = remote.location
        self.notes = remote.notes
        self.reminderOffsetMinutes = remote.reminderOffsetMinutes
        self.isCompleted = remote.isCompleted
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
    var appointmentType: AppointmentType {
        get { AppointmentType(rawValue: type) ?? .general }
        set { type = newValue.rawValue }
    }

    var dateTime: Date {
        guard let time = time else { return date }
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? date
    }
}
