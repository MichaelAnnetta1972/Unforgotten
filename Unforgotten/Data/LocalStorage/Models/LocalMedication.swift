import SwiftUI
import SwiftData

// MARK: - Local Medication Model
/// SwiftData model for Medication, stored locally for offline support
@Model
final class LocalMedication {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var profileId: UUID
    var name: String
    var strength: String?
    var form: String?
    var reason: String?
    var prescribingDoctorId: UUID?
    var notes: String?
    var imageUrl: String?
    var localImagePath: String?
    var intakeInstruction: String?  // Store as raw value
    var isPaused: Bool
    var pausedAt: Date?
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
        profileId: UUID,
        name: String,
        strength: String? = nil,
        form: String? = nil,
        reason: String? = nil,
        prescribingDoctorId: UUID? = nil,
        notes: String? = nil,
        imageUrl: String? = nil,
        localImagePath: String? = nil,
        intakeInstruction: String? = nil,
        isPaused: Bool = false,
        pausedAt: Date? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.profileId = profileId
        self.name = name
        self.strength = strength
        self.form = form
        self.reason = reason
        self.prescribingDoctorId = prescribingDoctorId
        self.notes = notes
        self.imageUrl = imageUrl
        self.localImagePath = localImagePath
        self.intakeInstruction = intakeInstruction
        self.isPaused = isPaused
        self.pausedAt = pausedAt
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: Medication) {
        self.init(
            id: remote.id,
            accountId: remote.accountId,
            profileId: remote.profileId,
            name: remote.name,
            strength: remote.strength,
            form: remote.form,
            reason: remote.reason,
            prescribingDoctorId: remote.prescribingDoctorId,
            notes: remote.notes,
            imageUrl: remote.imageUrl,
            localImagePath: remote.localImagePath,
            intakeInstruction: remote.intakeInstruction?.rawValue,
            isPaused: remote.isPaused,
            pausedAt: remote.pausedAt,
            sortOrder: remote.sortOrder,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> Medication {
        Medication(
            id: id,
            accountId: accountId,
            profileId: profileId,
            name: name,
            strength: strength,
            form: form,
            reason: reason,
            prescribingDoctorId: prescribingDoctorId,
            notes: notes,
            imageUrl: imageUrl,
            localImagePath: localImagePath,
            intakeInstruction: intakeInstruction.flatMap { IntakeInstruction(rawValue: $0) },
            isPaused: isPaused,
            pausedAt: pausedAt,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: Medication) {
        self.accountId = remote.accountId
        self.profileId = remote.profileId
        self.name = remote.name
        self.strength = remote.strength
        self.form = remote.form
        self.reason = remote.reason
        self.prescribingDoctorId = remote.prescribingDoctorId
        self.notes = remote.notes
        self.imageUrl = remote.imageUrl
        self.localImagePath = remote.localImagePath
        self.intakeInstruction = remote.intakeInstruction?.rawValue
        self.isPaused = remote.isPaused
        self.pausedAt = remote.pausedAt
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
    var displayName: String {
        if let strength = strength {
            return "\(name) \(strength)"
        }
        return name
    }
}
