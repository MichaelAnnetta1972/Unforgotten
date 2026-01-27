import SwiftUI
import SwiftData

// MARK: - Local Medication Schedule Model
/// SwiftData model for MedicationSchedule, stored locally for offline support
@Model
final class LocalMedicationSchedule {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var medicationId: UUID
    var scheduleType: String  // Store as raw value
    var startDate: Date
    var endDate: Date?
    var daysOfWeek: Data?  // Store as JSON data [Int]
    var scheduleEntries: Data?  // Store as JSON data [ScheduleEntry]
    var legacyTimes: Data?  // Store as JSON data [String]
    var doseDescription: String?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        medicationId: UUID,
        scheduleType: String,
        startDate: Date = Date(),
        endDate: Date? = nil,
        daysOfWeek: Data? = nil,
        scheduleEntries: Data? = nil,
        legacyTimes: Data? = nil,
        doseDescription: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.medicationId = medicationId
        self.scheduleType = scheduleType
        self.startDate = startDate
        self.endDate = endDate
        self.daysOfWeek = daysOfWeek
        self.scheduleEntries = scheduleEntries
        self.legacyTimes = legacyTimes
        self.doseDescription = doseDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: MedicationSchedule) {
        let daysData: Data?
        if let days = remote.daysOfWeek {
            daysData = try? JSONEncoder().encode(days)
        } else {
            daysData = nil
        }

        let entriesData: Data?
        if let entries = remote.scheduleEntries {
            entriesData = try? JSONEncoder().encode(entries)
        } else {
            entriesData = nil
        }

        let timesData: Data?
        if let times = remote.legacyTimes {
            timesData = try? JSONEncoder().encode(times)
        } else {
            timesData = nil
        }

        self.init(
            id: remote.id,
            accountId: remote.accountId,
            medicationId: remote.medicationId,
            scheduleType: remote.scheduleType.rawValue,
            startDate: remote.startDate,
            endDate: remote.endDate,
            daysOfWeek: daysData,
            scheduleEntries: entriesData,
            legacyTimes: timesData,
            doseDescription: remote.doseDescription,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> MedicationSchedule {
        var days: [Int]?
        if let daysData = daysOfWeek {
            days = try? JSONDecoder().decode([Int].self, from: daysData)
        }

        var entries: [ScheduleEntry]?
        if let entriesData = scheduleEntries {
            entries = try? JSONDecoder().decode([ScheduleEntry].self, from: entriesData)
        }

        var times: [String]?
        if let timesData = legacyTimes {
            times = try? JSONDecoder().decode([String].self, from: timesData)
        }

        return MedicationSchedule(
            id: id,
            accountId: accountId,
            medicationId: medicationId,
            scheduleType: ScheduleType(rawValue: scheduleType) ?? .scheduled,
            startDate: startDate,
            endDate: endDate,
            daysOfWeek: days,
            scheduleEntries: entries,
            legacyTimes: times,
            doseDescription: doseDescription,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: MedicationSchedule) {
        self.accountId = remote.accountId
        self.medicationId = remote.medicationId
        self.scheduleType = remote.scheduleType.rawValue
        self.startDate = remote.startDate
        self.endDate = remote.endDate

        if let days = remote.daysOfWeek {
            self.daysOfWeek = try? JSONEncoder().encode(days)
        } else {
            self.daysOfWeek = nil
        }

        if let entries = remote.scheduleEntries {
            self.scheduleEntries = try? JSONEncoder().encode(entries)
        } else {
            self.scheduleEntries = nil
        }

        if let times = remote.legacyTimes {
            self.legacyTimes = try? JSONEncoder().encode(times)
        } else {
            self.legacyTimes = nil
        }

        self.doseDescription = remote.doseDescription
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
    var schedule: ScheduleType {
        get { ScheduleType(rawValue: scheduleType) ?? .scheduled }
        set { scheduleType = newValue.rawValue }
    }

    /// Decoded schedule entries
    var decodedScheduleEntries: [ScheduleEntry]? {
        guard let data = scheduleEntries else { return nil }
        return try? JSONDecoder().decode([ScheduleEntry].self, from: data)
    }

    /// Decoded days of week
    var decodedDaysOfWeek: [Int]? {
        guard let data = daysOfWeek else { return nil }
        return try? JSONDecoder().decode([Int].self, from: data)
    }
}
