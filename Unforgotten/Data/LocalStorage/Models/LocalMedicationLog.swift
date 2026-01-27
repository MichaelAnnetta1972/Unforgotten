import SwiftUI
import SwiftData

// MARK: - Local Medication Log Model
/// SwiftData model for MedicationLog, stored locally for offline support
@Model
final class LocalMedicationLog {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var medicationId: UUID
    var scheduledAt: Date
    var status: String  // Store as raw value
    var takenAt: Date?
    var note: String?
    var createdAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        medicationId: UUID,
        scheduledAt: Date,
        status: String = "scheduled",
        takenAt: Date? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.medicationId = medicationId
        self.scheduledAt = scheduledAt
        self.status = status
        self.takenAt = takenAt
        self.note = note
        self.createdAt = createdAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: MedicationLog) {
        self.init(
            id: remote.id,
            accountId: remote.accountId,
            medicationId: remote.medicationId,
            scheduledAt: remote.scheduledAt,
            status: remote.status.rawValue,
            takenAt: remote.takenAt,
            note: remote.note,
            createdAt: remote.createdAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> MedicationLog {
        MedicationLog(
            id: id,
            accountId: accountId,
            medicationId: medicationId,
            scheduledAt: scheduledAt,
            status: MedicationLogStatus(rawValue: status) ?? .scheduled,
            takenAt: takenAt,
            note: note,
            createdAt: createdAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: MedicationLog) {
        self.accountId = remote.accountId
        self.medicationId = remote.medicationId
        self.scheduledAt = remote.scheduledAt
        self.status = remote.status.rawValue
        self.takenAt = remote.takenAt
        self.note = remote.note
        self.createdAt = remote.createdAt
        self.isSynced = true
    }

    // MARK: - Sync Helpers
    func markAsModified() {
        self.isSynced = false
    }

    // MARK: - Computed Properties
    var logStatus: MedicationLogStatus {
        get { MedicationLogStatus(rawValue: status) ?? .scheduled }
        set { status = newValue.rawValue }
    }
}
