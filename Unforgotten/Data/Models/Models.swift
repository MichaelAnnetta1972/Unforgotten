import Foundation
import SwiftUI

// MARK: - Account
struct Account: Codable, Identifiable, Equatable {
    let id: UUID
    let ownerUserId: UUID
    let displayName: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserId = "owner_user_id"
        case displayName = "display_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Account Member
struct AccountMember: Codable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let userId: UUID
    let role: MemberRole
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case userId = "user_id"
        case role
        case createdAt = "created_at"
    }
}

enum MemberRole: String, Codable, CaseIterable {
    case owner
    case admin
    case helper
    case viewer
    
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .helper: return "Helper"
        case .viewer: return "Viewer"
        }
    }
    
    var description: String {
        switch self {
        case .owner: return "Full access, manage members"
        case .admin: return "Full access to data"
        case .helper: return "Can update medications, appointments, contacts, and sticky reminders."
        case .viewer: return "Read-only access"
        }
    }
    
    var canWrite: Bool {
        self != .viewer
    }
    
    var canManageMembers: Bool {
        self == .owner || self == .admin
    }
}

// MARK: - Account Invitation
struct AccountInvitation: Codable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let email: String
    let role: MemberRole
    let inviteCode: String
    let invitedBy: UUID
    var status: InvitationStatus
    let createdAt: Date
    let expiresAt: Date
    var acceptedAt: Date?
    var acceptedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case email
        case role
        case inviteCode = "invite_code"
        case invitedBy = "invited_by"
        case status
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case acceptedAt = "accepted_at"
        case acceptedBy = "accepted_by"
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    var isActive: Bool {
        status == .pending && !isExpired
    }
}

enum InvitationStatus: String, Codable {
    case pending
    case accepted
    case expired
    case revoked
}

// MARK: - Profile
struct Profile: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let accountId: UUID
    let type: ProfileType
    var fullName: String
    var preferredName: String?
    var relationship: String?
    var connectedToProfileId: UUID?  // Links to another profile for family tree relationships
    var includeInFamilyTree: Bool  // Whether to show this profile in the family tree
    var birthday: Date?
    var isDeceased: Bool  // Whether this person has passed away
    var dateOfDeath: Date?  // Date of death if deceased
    var address: String?
    var phone: String?
    var email: String?
    var notes: String?
    var isFavourite: Bool
    var linkedUserId: UUID?
    var photoUrl: String?
    var sortOrder: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case type
        case fullName = "full_name"
        case preferredName = "preferred_name"
        case relationship
        case connectedToProfileId = "connected_to_profile_id"
        case includeInFamilyTree = "include_in_family_tree"
        case birthday
        case isDeceased = "is_deceased"
        case dateOfDeath = "date_of_death"
        case address
        case phone
        case email
        case notes
        case isFavourite = "is_favourite"
        case linkedUserId = "linked_user_id"
        case photoUrl = "photo_url"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Memberwise initializer
    init(
        id: UUID,
        accountId: UUID,
        type: ProfileType,
        fullName: String,
        preferredName: String? = nil,
        relationship: String? = nil,
        connectedToProfileId: UUID? = nil,
        includeInFamilyTree: Bool = true,
        birthday: Date? = nil,
        isDeceased: Bool = false,
        dateOfDeath: Date? = nil,
        address: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        notes: String? = nil,
        isFavourite: Bool = false,
        linkedUserId: UUID? = nil,
        photoUrl: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.accountId = accountId
        self.type = type
        self.fullName = fullName
        self.preferredName = preferredName
        self.relationship = relationship
        self.connectedToProfileId = connectedToProfileId
        self.includeInFamilyTree = includeInFamilyTree
        self.birthday = birthday
        self.isDeceased = isDeceased
        self.dateOfDeath = dateOfDeath
        self.address = address
        self.phone = phone
        self.email = email
        self.notes = notes
        self.isFavourite = isFavourite
        self.linkedUserId = linkedUserId
        self.photoUrl = photoUrl
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Custom decoder to provide default for sort_order, includeInFamilyTree, and isDeceased
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        accountId = try container.decode(UUID.self, forKey: .accountId)
        type = try container.decode(ProfileType.self, forKey: .type)
        fullName = try container.decode(String.self, forKey: .fullName)
        preferredName = try container.decodeIfPresent(String.self, forKey: .preferredName)
        relationship = try container.decodeIfPresent(String.self, forKey: .relationship)
        connectedToProfileId = try container.decodeIfPresent(UUID.self, forKey: .connectedToProfileId)
        includeInFamilyTree = try container.decodeIfPresent(Bool.self, forKey: .includeInFamilyTree) ?? true
        birthday = try container.decodeIfPresent(Date.self, forKey: .birthday)
        isDeceased = try container.decodeIfPresent(Bool.self, forKey: .isDeceased) ?? false
        dateOfDeath = try container.decodeIfPresent(Date.self, forKey: .dateOfDeath)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isFavourite = try container.decodeIfPresent(Bool.self, forKey: .isFavourite) ?? false
        linkedUserId = try container.decodeIfPresent(UUID.self, forKey: .linkedUserId)
        photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    var displayName: String {
        preferredName ?? fullName
    }

    var age: Int? {
        birthday?.age()
    }

    /// Age at death if person is deceased and has both birthday and date of death
    var ageAtDeath: Int? {
        guard isDeceased, let birthday = birthday, let deathDate = dateOfDeath else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthday, to: deathDate)
        return components.year
    }
}

enum ProfileType: String, Codable, CaseIterable {
    case primary
    case relative
    case friend
    case doctor
    case carer
    case other
    
    var displayName: String {
        switch self {
        case .primary: return "Primary User"
        case .relative: return "Relative"
        case .friend: return "Friend"
        case .doctor: return "Doctor"
        case .carer: return "Carer"
        case .other: return "Other"
        }
    }
}

// MARK: - Profile Detail
struct ProfileDetail: Codable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let profileId: UUID
    let category: DetailCategory
    var label: String
    var value: String
    var status: String?
    var occasion: String?
    var metadata: [String: String]?
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case profileId = "profile_id"
        case category
        case label
        case value
        case status
        case occasion
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum DetailCategory: String, Codable, CaseIterable {
    case clothing
    case giftIdea = "gift_idea"
    case medicalCondition = "medical_condition"
    case allergy
    case like
    case dislike
    case note
    case hobby
    case activityIdea = "activity_idea"

    var displayName: String {
        switch self {
        case .clothing: return "Clothing"
        case .giftIdea: return "Gift"
        case .medicalCondition: return "Medical Condition"
        case .allergy: return "Allergy"
        case .like: return "Like"
        case .dislike: return "Dislike"
        case .note: return "Note"
        case .hobby: return "Hobby"
        case .activityIdea: return "Activity"
        }
    }

    var icon: String {
        switch self {
        case .clothing: return "tshirt.fill"
        case .giftIdea: return "gift.fill"
        case .medicalCondition: return "cross.fill"
        case .allergy: return "exclamationmark.triangle.fill"
        case .like: return "heart.fill"
        case .dislike: return "hand.thumbsdown.fill"
        case .note: return "note.text"
        case .hobby: return "heart.circle.fill"
        case .activityIdea: return "figure.walk"
        }
    }
}

// MARK: - Medication
struct Medication: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let accountId: UUID
    let profileId: UUID
    var name: String
    var strength: String?
    var form: String?
    var reason: String?
    var prescribingDoctorId: UUID?
    var notes: String?
    var imageUrl: String?
    var localImagePath: String?
    var intakeInstruction: IntakeInstruction?
    var isPaused: Bool
    var pausedAt: Date?
    var sortOrder: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case profileId = "profile_id"
        case name
        case strength
        case form
        case reason
        case prescribingDoctorId = "prescribing_doctor_id"
        case notes
        case imageUrl = "image_url"
        case localImagePath = "local_image_path"
        case intakeInstruction = "intake_instruction"
        case isPaused = "is_paused"
        case pausedAt = "paused_at"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Memberwise initializer
    init(
        id: UUID,
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
        intakeInstruction: IntakeInstruction? = nil,
        isPaused: Bool = false,
        pausedAt: Date? = nil,
        sortOrder: Int = 0,
        createdAt: Date,
        updatedAt: Date
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
    }

    // Custom decoder to provide defaults for new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        accountId = try container.decode(UUID.self, forKey: .accountId)
        profileId = try container.decode(UUID.self, forKey: .profileId)
        name = try container.decode(String.self, forKey: .name)
        strength = try container.decodeIfPresent(String.self, forKey: .strength)
        form = try container.decodeIfPresent(String.self, forKey: .form)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        prescribingDoctorId = try container.decodeIfPresent(UUID.self, forKey: .prescribingDoctorId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        localImagePath = try container.decodeIfPresent(String.self, forKey: .localImagePath)
        intakeInstruction = try container.decodeIfPresent(IntakeInstruction.self, forKey: .intakeInstruction)
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        pausedAt = try container.decodeIfPresent(Date.self, forKey: .pausedAt)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    var displayName: String {
        if let strength = strength {
            return "\(name) \(strength)"
        }
        return name
    }
}

// MARK: - Intake Instruction
enum IntakeInstruction: String, Codable, CaseIterable {
    case withMeals = "with_meals"
    case emptyStomach = "empty_stomach"
    case beforeMeals = "before_meals"
    case afterMeals = "after_meals"
    case withWater = "with_water"
    case withFood = "with_food"

    var displayName: String {
        switch self {
        case .withMeals: return "With Meals"
        case .emptyStomach: return "Empty Stomach"
        case .beforeMeals: return "Before Meals"
        case .afterMeals: return "After Meals"
        case .withWater: return "With Water"
        case .withFood: return "With Food"
        }
    }
}

enum MedicationForm: String, Codable, CaseIterable {
    case tablet
    case capsule
    case liquid
    case injection
    case inhaler
    case patch
    case cream
    case drops
    case spray
    case other
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Medication Schedule
struct MedicationSchedule: Codable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let medicationId: UUID
    var scheduleType: ScheduleType
    var startDate: Date
    var endDate: Date?
    var daysOfWeek: [Int]?
    var scheduleEntries: [ScheduleEntry]?
    var legacyTimes: [String]?  // For backwards compatibility with old 'times' field
    var doseDescription: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case medicationId = "medication_id"
        case scheduleType = "schedule_type"
        case startDate = "start_date"
        case endDate = "end_date"
        case daysOfWeek = "days_of_week"
        case scheduleEntries = "schedule_entries"
        case legacyTimes = "times"
        case doseDescription = "dose_description"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Returns times from schedule entries, or falls back to legacy times field
    var times: [String]? {
        if let entries = scheduleEntries, !entries.isEmpty {
            return entries.map { $0.time }
        }
        return legacyTimes
    }
}

// MARK: - Duration Unit
enum DurationUnit: String, Codable, CaseIterable {
    case days
    case weeks
    case months

    var displayName: String {
        switch self {
        case .days: return "Days"
        case .weeks: return "Weeks"
        case .months: return "Months"
        }
    }

    var singularName: String {
        switch self {
        case .days: return "day"
        case .weeks: return "week"
        case .months: return "month"
        }
    }
}

// MARK: - Schedule Entry
struct ScheduleEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var time: String  // HH:mm format
    var dosage: String?
    var daysOfWeek: [Int]  // 0-6 (Sunday-Saturday)
    var durationValue: Int?  // Duration value in the selected unit
    var durationUnit: DurationUnit  // Unit for duration (days, weeks, months)
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        time: String,
        dosage: String? = nil,
        daysOfWeek: [Int] = [0, 1, 2, 3, 4, 5, 6],
        durationValue: Int? = nil,
        durationUnit: DurationUnit = .days,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.time = time
        self.dosage = dosage
        self.daysOfWeek = daysOfWeek
        self.durationValue = durationValue
        self.durationUnit = durationUnit
        self.sortOrder = sortOrder
    }

    /// Calculate the total number of active days based on selected days and duration
    /// If specific days are selected (not all 7), only those days count toward duration
    var effectiveDurationDays: Int? {
        guard let value = durationValue else { return nil }

        // Convert to total calendar days based on unit
        let calendarDays: Int
        switch durationUnit {
        case .days:
            calendarDays = value
        case .weeks:
            calendarDays = value * 7
        case .months:
            calendarDays = value * 30  // Approximate
        }

        // If all days are selected, return calendar days directly
        if daysOfWeek.count == 7 {
            return calendarDays
        }

        // If specific days selected, calculate how many calendar days needed
        // to get the required number of dose days
        // e.g., 1 month of Mondays = ~4 doses, but spans ~30 calendar days
        return calendarDays
    }

    /// Legacy support for durationDays
    var durationDays: Int? {
        return effectiveDurationDays
    }

    enum CodingKeys: String, CodingKey {
        case id
        case time
        case dosage
        case daysOfWeek = "days_of_week"
        case durationValue = "duration_value"
        case durationUnit = "duration_unit"
        case sortOrder = "sort_order"
    }

    // Custom decoder for backwards compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        time = try container.decode(String.self, forKey: .time)
        dosage = try container.decodeIfPresent(String.self, forKey: .dosage)
        daysOfWeek = try container.decodeIfPresent([Int].self, forKey: .daysOfWeek) ?? [0, 1, 2, 3, 4, 5, 6]
        durationValue = try container.decodeIfPresent(Int.self, forKey: .durationValue)
        durationUnit = try container.decodeIfPresent(DurationUnit.self, forKey: .durationUnit) ?? .days
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

enum ScheduleType: String, Codable, CaseIterable {
    case scheduled
    case asNeeded = "as_needed"

    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .asNeeded: return "As Needed"
        }
    }
}

// MARK: - Medication Log
struct MedicationLog: Codable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let medicationId: UUID
    let scheduledAt: Date
    var status: MedicationLogStatus
    var takenAt: Date?
    var note: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case medicationId = "medication_id"
        case scheduledAt = "scheduled_at"
        case status
        case takenAt = "taken_at"
        case note
        case createdAt = "created_at"
    }
}

enum MedicationLogStatus: String, Codable, CaseIterable {
    case scheduled
    case taken
    case missed
    case skipped
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .scheduled: return "textSecondary"
        case .taken: return "badgeGreen"
        case .missed: return "badgeRed"
        case .skipped: return "badgeGrey"
        }
    }
}

// MARK: - Appointment Type
enum AppointmentType: String, Codable, CaseIterable {
    case general
    case doctor
    case dentist
    case hospital
    case gym
    case work
    case school
    case friends
    case family
    case shopping
    case travel
    case other

    var displayName: String {
        switch self {
        case .general: return "General"
        case .doctor: return "Doctor"
        case .dentist: return "Dentist"
        case .hospital: return "Hospital"
        case .gym: return "Gym"
        case .work: return "Work"
        case .school: return "School"
        case .friends: return "Friends"
        case .family: return "Family"
        case .shopping: return "Shopping"
        case .travel: return "Travel"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .general: return "calendar"
        case .doctor: return "stethoscope"
        case .dentist: return "mouth.fill"
        case .hospital: return "cross.case.fill"
        case .gym: return "dumbbell.fill"
        case .work: return "briefcase.fill"
        case .school: return "graduationcap.fill"
        case .friends: return "person.2.fill"
        case .family: return "house.fill"
        case .shopping: return "cart.fill"
        case .travel: return "airplane"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: return .calendarBlue
        case .doctor: return .medicalRed
        case .dentist: return .cyan
        case .hospital: return .medicalRed
        case .gym: return .orange
        case .work: return .blue
        case .school: return .yellow
        case .friends: return .green
        case .family: return .pink
        case .shopping: return .mint
        case .travel: return .indigo
        case .other: return .gray
        }
    }
}

// MARK: - Appointment
struct Appointment: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let accountId: UUID
    let profileId: UUID
    var withProfileId: UUID?
    var type: AppointmentType
    var title: String
    var date: Date
    var time: Date?
    var location: String?
    var notes: String?
    var reminderOffsetMinutes: Int?
    var isCompleted: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case profileId = "profile_id"
        case withProfileId = "with_profile_id"
        case type
        case title
        case date
        case time
        case location
        case notes
        case reminderOffsetMinutes = "reminder_offset_minutes"
        case isCompleted = "is_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Custom decoder to provide defaults for backwards compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        accountId = try container.decode(UUID.self, forKey: .accountId)
        profileId = try container.decode(UUID.self, forKey: .profileId)
        withProfileId = try container.decodeIfPresent(UUID.self, forKey: .withProfileId)
        type = try container.decodeIfPresent(AppointmentType.self, forKey: .type) ?? .general
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        time = try container.decodeIfPresent(Date.self, forKey: .time)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        reminderOffsetMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderOffsetMinutes)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    // Memberwise initializer
    init(
        id: UUID,
        accountId: UUID,
        profileId: UUID,
        withProfileId: UUID? = nil,
        type: AppointmentType = .general,
        title: String,
        date: Date,
        time: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        reminderOffsetMinutes: Int? = nil,
        isCompleted: Bool = false,
        createdAt: Date,
        updatedAt: Date
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

// MARK: - Useful Contact
struct UsefulContact: Codable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    var name: String
    var category: ContactCategory
    var companyName: String?
    var phone: String?
    var email: String?
    var website: String?
    var address: String?
    var notes: String?
    var isFavourite: Bool
    var sortOrder: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case name
        case category
        case companyName = "company_name"
        case phone
        case email
        case website
        case address
        case notes
        case isFavourite = "is_favourite"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Memberwise initializer
    init(
        id: UUID,
        accountId: UUID,
        name: String,
        category: ContactCategory,
        companyName: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        isFavourite: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.accountId = accountId
        self.name = name
        self.category = category
        self.companyName = companyName
        self.phone = phone
        self.email = email
        self.website = website
        self.address = address
        self.notes = notes
        self.isFavourite = isFavourite
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Custom decoder to provide default for sort_order
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        accountId = try container.decode(UUID.self, forKey: .accountId)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(ContactCategory.self, forKey: .category)
        companyName = try container.decodeIfPresent(String.self, forKey: .companyName)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isFavourite = try container.decodeIfPresent(Bool.self, forKey: .isFavourite) ?? false
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

enum ContactCategory: String, Codable, CaseIterable {
    case doctor
    case dentist
    case specialist
    case pharmacy
    case plumber
    case electrician
    case handyman
    case emergency
    case service
    case other
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .doctor, .dentist, .specialist: return "stethoscope"
        case .pharmacy: return "cross.case.fill"
        case .plumber: return "wrench.fill"
        case .electrician: return "bolt.fill"
        case .handyman: return "hammer.fill"
        case .emergency: return "exclamationmark.triangle.fill"
        case .service: return "phone.fill"
        case .other: return "person.fill"
        }
    }
    
    var color: String {
        switch self {
        case .doctor, .dentist, .specialist, .pharmacy: return "medicalRed"
        case .plumber, .electrician, .handyman: return "clothingBlue"
        case .emergency: return "badgeRed"
        case .service, .other: return "textSecondary"
        }
    }
}

// MARK: - Mood Entry
struct MoodEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let userId: UUID
    let date: Date
    var rating: Int
    var note: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case userId = "user_id"
        case date
        case rating
        case note
        case createdAt = "created_at"
    }
}

// MARK: - Today Summary (View Model helper)
struct TodaySummary {
    let medications: [MedicationWithLog]
    let appointments: [Appointment]
    let birthdays: [Profile]
    
    var hasItems: Bool {
        !medications.isEmpty || !appointments.isEmpty || !birthdays.isEmpty
    }
}

struct MedicationWithLog {
    let medication: Medication
    let log: MedicationLog
    let schedule: MedicationSchedule?
}

// MARK: - Profile with Details (View Model helper)
struct ProfileWithDetails {
    let profile: Profile
    let clothingSizes: [ProfileDetail]
    let giftIdeas: [ProfileDetail]
    let medicalConditions: [ProfileDetail]
    let allergies: [ProfileDetail]
    
    var allMedicalItems: [ProfileDetail] {
        medicalConditions + allergies
    }
}

// MARK: - Upcoming Birthday
struct UpcomingBirthday: Identifiable {
    let profile: Profile
    let daysUntil: Int

    var id: UUID { profile.id }
}

// MARK: - Profile Connection
struct ProfileConnection: Codable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let fromProfileId: UUID
    let toProfileId: UUID
    let relationshipType: ConnectionType
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case fromProfileId = "from_profile_id"
        case toProfileId = "to_profile_id"
        case relationshipType = "relationship_type"
        case createdAt = "created_at"
    }
}

// MARK: - Connection Type
enum ConnectionType: String, Codable, CaseIterable {
    // Family
    case me
    case mother
    case father
    case son
    case daughter
    case brother
    case sister
    case grandmother
    case grandfather
    case grandson
    case granddaughter
    case aunt
    case uncle
    case nephew
    case niece
    case cousin
    case spouse
    case partner
    case exSpouse
    case inlaw

    // Professional
    case doctor
    case dentist
    case lawyer
    case accountant
    case carer

    // Social
    case friend
    case neighbour
    case colleague

    // Generic
    case other

    var displayName: String {
        switch self {
        case .me: return "Me"
        case .mother: return "Mother"
        case .father: return "Father"
        case .son: return "Son"
        case .daughter: return "Daughter"
        case .brother: return "Brother"
        case .sister: return "Sister"
        case .grandmother: return "Grandmother"
        case .grandfather: return "Grandfather"
        case .grandson: return "Grandson"
        case .granddaughter: return "Granddaughter"
        case .aunt: return "Aunt"
        case .uncle: return "Uncle"
        case .nephew: return "Nephew"
        case .niece: return "Niece"
        case .cousin: return "Cousin"
        case .spouse: return "Spouse"
        case .partner: return "Partner"
        case .exSpouse: return "Ex Spouse"
        case .inlaw: return "In Law"
        case .doctor: return "Doctor"
        case .dentist: return "Dentist"
        case .lawyer: return "Lawyer"
        case .accountant: return "Accountant"
        case .carer: return "Carer"
        case .friend: return "Friend"
        case .neighbour: return "Neighbour"
        case .colleague: return "Colleague"
        case .other: return "Other"
        }
    }

    var category: ConnectionCategory {
        switch self {
        case .me, .mother, .father, .son, .daughter, .brother, .sister,
             .grandmother, .grandfather, .grandson, .granddaughter,
             .aunt, .uncle, .nephew, .niece, .cousin, .spouse, .partner, .exSpouse, .inlaw:
            return .family
        case .doctor, .dentist, .lawyer, .accountant, .carer:
            return .professional
        case .friend, .neighbour, .colleague:
            return .social
        case .other:
            return .other
        }
    }

    /// Returns the inverse relationship type for bidirectional connections
    var inverse: ConnectionType {
        switch self {
        case .me: return .me
        case .mother, .father: return .son // Will be adjusted based on context
        case .son: return .father // Will be adjusted based on context
        case .daughter: return .mother // Will be adjusted based on context
        case .brother: return .brother
        case .sister: return .sister
        case .grandmother, .grandfather: return .grandson // Will be adjusted
        case .grandson: return .grandfather // Will be adjusted
        case .granddaughter: return .grandmother // Will be adjusted
        case .aunt: return .nephew // Will be adjusted
        case .uncle: return .niece // Will be adjusted
        case .nephew: return .uncle
        case .niece: return .aunt
        case .cousin: return .cousin
        case .spouse: return .spouse
        case .exSpouse: return .exSpouse
        case .inlaw: return .inlaw
        case .partner: return .partner
        case .doctor: return .other // Patient (not in list)
        case .dentist: return .other
        case .lawyer: return .other
        case .accountant: return .other
        case .carer: return .other
        case .friend: return .friend
        case .neighbour: return .neighbour
        case .colleague: return .colleague
        case .other: return .other
        }
    }

    static var familyTypes: [ConnectionType] {
        [.me, .mother, .father, .son, .daughter, .brother, .sister,
         .grandmother, .grandfather, .grandson, .granddaughter,
         .aunt, .uncle, .nephew, .niece, .cousin, .spouse, .partner, .exSpouse, .inlaw]
    }

    static var professionalTypes: [ConnectionType] {
        [.doctor, .dentist, .lawyer, .accountant, .carer]
    }

    static var socialTypes: [ConnectionType] {
        [.friend, .neighbour, .colleague]
    }
}

enum ConnectionCategory: String {
    case family = "Family"
    case professional = "Professional"
    case social = "Social"
    case other = "Other"
}

// MARK: - Connection with Profile (View Model helper)
struct ConnectionWithProfile: Identifiable {
    let connection: ProfileConnection
    let connectedProfile: Profile

    var id: UUID { connection.id }
}

// MARK: - Note Models
// Note: Notes feature now uses SwiftData with LocalNote model
// See Features/Notes/Storage/Note.swift and Features/Notes/Models/NoteTheme.swift

// MARK: - Sticky Reminder
/// A persistent reminder that keeps notifying until dismissed in-app
struct StickyReminder: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let accountId: UUID
    var title: String
    var message: String?
    var triggerTime: Date
    var repeatInterval: StickyReminderInterval
    var isActive: Bool
    var isDismissed: Bool
    var lastNotifiedAt: Date?
    var sortOrder: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case title
        case message
        case triggerTime = "trigger_time"
        case repeatInterval = "repeat_interval"
        case isActive = "is_active"
        case isDismissed = "is_dismissed"
        case lastNotifiedAt = "last_notified_at"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Memberwise initializer
    init(
        id: UUID = UUID(),
        accountId: UUID,
        title: String,
        message: String? = nil,
        triggerTime: Date,
        repeatInterval: StickyReminderInterval = .everyHour,
        isActive: Bool = true,
        isDismissed: Bool = false,
        lastNotifiedAt: Date? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
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
    }

    // Custom decoder to provide defaults for optional fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        accountId = try container.decode(UUID.self, forKey: .accountId)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        triggerTime = try container.decode(Date.self, forKey: .triggerTime)
        repeatInterval = try container.decodeIfPresent(StickyReminderInterval.self, forKey: .repeatInterval) ?? .everyHour
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        isDismissed = try container.decodeIfPresent(Bool.self, forKey: .isDismissed) ?? false
        lastNotifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastNotifiedAt)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    /// Whether this reminder should currently be sending notifications
    var shouldNotify: Bool {
        isActive && !isDismissed && triggerTime <= Date()
    }

    /// Calculates the next notification time based on the repeat interval
    var nextNotificationTime: Date? {
        guard isActive && !isDismissed else { return nil }

        let now = Date()

        // If trigger time is in the future, that's the next notification
        if triggerTime > now {
            return triggerTime
        }

        // Calculate next notification based on last notified or trigger time
        let baseTime = lastNotifiedAt ?? triggerTime
        let intervalSeconds = repeatInterval.intervalInSeconds

        // Calculate how many intervals have passed since base time
        let timeSinceBase = now.timeIntervalSince(baseTime)
        let intervalsPassed = Int(timeSinceBase / intervalSeconds)

        // Next notification is base time + (intervals passed + 1) * interval
        let nextTime = baseTime.addingTimeInterval(Double(intervalsPassed + 1) * intervalSeconds)

        return nextTime
    }
}

// MARK: - Sticky Reminder Time Unit
enum StickyReminderTimeUnit: String, Codable, CaseIterable, Identifiable {
    case minutes = "minutes"
    case hours = "hours"
    case days = "days"
    case months = "months"
    case years = "years"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minutes: return "Minutes"
        case .hours: return "Hours"
        case .days: return "Days"
        case .months: return "Months"
        case .years: return "Years"
        }
    }

    var singularName: String {
        switch self {
        case .minutes: return "Minute"
        case .hours: return "Hour"
        case .days: return "Day"
        case .months: return "Month"
        case .years: return "Year"
        }
    }

    var icon: String {
        switch self {
        case .minutes: return "clock.badge.exclamationmark"
        case .hours: return "clock"
        case .days: return "sun.max"
        case .months: return "calendar"
        case .years: return "calendar.badge.clock"
        }
    }

    /// Seconds per unit (approximate for months/years)
    var secondsPerUnit: TimeInterval {
        switch self {
        case .minutes: return 60
        case .hours: return 60 * 60
        case .days: return 24 * 60 * 60
        case .months: return 30 * 24 * 60 * 60  // ~30 days
        case .years: return 365 * 24 * 60 * 60  // ~365 days
        }
    }

    /// Valid range of values for this unit
    var validRange: ClosedRange<Int> {
        switch self {
        case .minutes: return 5...59
        case .hours: return 1...23
        case .days: return 1...30
        case .months: return 1...12
        case .years: return 1...10
        }
    }
}

// MARK: - Sticky Reminder Interval
/// Dynamic interval supporting custom number + time unit combinations
/// Stored in database as a string like "30_minutes" or "2_hours"
struct StickyReminderInterval: Codable, Equatable, Hashable {
    var value: Int
    var unit: StickyReminderTimeUnit

    /// Default interval of 1 hour
    static let everyHour = StickyReminderInterval(value: 1, unit: .hours)

    /// Common presets for quick selection
    static let presets: [StickyReminderInterval] = [
        StickyReminderInterval(value: 15, unit: .minutes),
        StickyReminderInterval(value: 30, unit: .minutes),
        StickyReminderInterval(value: 1, unit: .hours),
        StickyReminderInterval(value: 2, unit: .hours),
        StickyReminderInterval(value: 4, unit: .hours),
        StickyReminderInterval(value: 1, unit: .days),
        StickyReminderInterval(value: 1, unit: .months)
    ]

    init(value: Int, unit: StickyReminderTimeUnit) {
        self.value = value
        self.unit = unit
    }

    // Custom encoding to store as "value_unit" string
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("\(value)_\(unit.rawValue)")
    }

    // Custom decoding from "value_unit" string
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)

        // Parse "value_unit" format (e.g., "30_minutes", "2_hours")
        let components = string.split(separator: "_", maxSplits: 1)

        if components.count == 2,
           let parsedValue = Int(components[0]),
           let parsedUnit = StickyReminderTimeUnit(rawValue: String(components[1])) {
            self.value = parsedValue
            self.unit = parsedUnit
        } else {
            // Fallback: try to parse legacy format
            self = Self.parseLegacyFormat(string) ?? .everyHour
        }
    }

    /// Parse legacy enum-style formats for backwards compatibility
    private static func parseLegacyFormat(_ string: String) -> StickyReminderInterval? {
        switch string {
        case "every_15_minutes": return StickyReminderInterval(value: 15, unit: .minutes)
        case "every_30_minutes": return StickyReminderInterval(value: 30, unit: .minutes)
        case "every_hour", "hourly": return StickyReminderInterval(value: 1, unit: .hours)
        case "every_2_hours": return StickyReminderInterval(value: 2, unit: .hours)
        case "every_4_hours": return StickyReminderInterval(value: 4, unit: .hours)
        case "every_8_hours": return StickyReminderInterval(value: 8, unit: .hours)
        case "daily": return StickyReminderInterval(value: 1, unit: .days)
        default: return nil
        }
    }

    var displayName: String {
        if value == 1 {
            return "Every \(unit.singularName.lowercased())"
        } else {
            return "Every \(value) \(unit.displayName.lowercased())"
        }
    }

    var intervalInSeconds: TimeInterval {
        TimeInterval(value) * unit.secondsPerUnit
    }

    var icon: String {
        unit.icon
    }
}

// MARK: - Important Account
/// Model for storing online account references (NOT passwords)
struct ImportantAccount: Codable, Identifiable, Equatable {
    let id: UUID
    let profileId: UUID
    var accountName: String
    var websiteURL: String?
    var username: String?
    var emailAddress: String?
    var phoneNumber: String?
    var securityQuestionHint: String?
    var recoveryHint: String?
    var notes: String?
    var category: AccountCategory?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case accountName = "account_name"
        case websiteURL = "website_url"
        case username
        case emailAddress = "email_address"
        case phoneNumber = "phone_number"
        case securityQuestionHint = "security_question_hint"
        case recoveryHint = "recovery_hint"
        case notes
        case category
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Memberwise initializer
    init(
        id: UUID = UUID(),
        profileId: UUID,
        accountName: String,
        websiteURL: String? = nil,
        username: String? = nil,
        emailAddress: String? = nil,
        phoneNumber: String? = nil,
        securityQuestionHint: String? = nil,
        recoveryHint: String? = nil,
        notes: String? = nil,
        category: AccountCategory? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.profileId = profileId
        self.accountName = accountName
        self.websiteURL = websiteURL
        self.username = username
        self.emailAddress = emailAddress
        self.phoneNumber = phoneNumber
        self.securityQuestionHint = securityQuestionHint
        self.recoveryHint = recoveryHint
        self.notes = notes
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Account Category
enum AccountCategory: String, Codable, CaseIterable {
    case financial = "financial"
    case social = "social"
    case shopping = "shopping"
    case entertainment = "entertainment"
    case utilities = "utilities"
    case healthcare = "healthcare"
    case work = "work"
    case other = "other"

    var displayName: String {
        switch self {
        case .financial: return "Financial"
        case .social: return "Social Media"
        case .shopping: return "Shopping"
        case .entertainment: return "Entertainment"
        case .utilities: return "Utilities"
        case .healthcare: return "Healthcare"
        case .work: return "Work"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .financial: return "dollarsign.circle.fill"
        case .social: return "person.2.fill"
        case .shopping: return "cart.fill"
        case .entertainment: return "tv.fill"
        case .utilities: return "bolt.fill"
        case .healthcare: return "heart.fill"
        case .work: return "briefcase.fill"
        case .other: return "folder.fill"
        }
    }

    var color: Color {
        switch self {
        case .financial: return .green
        case .social: return .blue
        case .shopping: return .orange
        case .entertainment: return .purple
        case .utilities: return .yellow
        case .healthcare: return .red
        case .work: return .gray
        case .other: return Color.textSecondary
        }
    }
}

// MARK: - Countdown Type
enum CountdownType: String, Codable, CaseIterable, Identifiable {
    case anniversary
    case holiday
    case countdown
    case task
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anniversary: return "Anniversary"
        case .holiday: return "Holiday"
        case .countdown: return "Countdown"
        case .task: return "Task"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .anniversary: return "heart.fill"
        case .holiday: return "star.fill"
        case .countdown: return "clock.fill"
        case .task: return "checklist"
        case .custom: return "tag.fill"
        }
    }

    var color: Color {
        switch self {
        case .anniversary: return .pink
        case .holiday: return .yellow
        case .countdown: return .blue
        case .task: return .green
        case .custom: return .purple
        }
    }
}

// MARK: - Countdown
/// A custom countdown event for tracking anniversaries, holidays, tasks, and other important dates
struct Countdown: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let accountId: UUID
    var title: String
    var date: Date
    var type: CountdownType
    var customType: String?
    var notes: String?
    var reminderOffsetMinutes: Int?
    var isRecurring: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case title
        case date
        case type
        case customType = "custom_type"
        case notes
        case reminderOffsetMinutes = "reminder_offset_minutes"
        case isRecurring = "is_recurring"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Memberwise initializer
    init(
        id: UUID = UUID(),
        accountId: UUID,
        title: String,
        date: Date,
        type: CountdownType = .countdown,
        customType: String? = nil,
        notes: String? = nil,
        reminderOffsetMinutes: Int? = nil,
        isRecurring: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
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
    }

    // Custom decoder to provide defaults for optional fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        accountId = try container.decode(UUID.self, forKey: .accountId)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        type = try container.decodeIfPresent(CountdownType.self, forKey: .type) ?? .countdown
        customType = try container.decodeIfPresent(String.self, forKey: .customType)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        reminderOffsetMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderOffsetMinutes)
        isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    /// The display name for the type (uses customType if type is .custom)
    var displayTypeName: String {
        if type == .custom, let customName = customType, !customName.isEmpty {
            return customName
        }
        return type.displayName
    }

    /// Calculate days until the next occurrence of this countdown
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

    /// Whether this countdown has already passed (for non-recurring countdowns)
    var hasPassed: Bool {
        if isRecurring { return false }
        return date < Date()
    }
}

// MARK: - Upcoming Event
/// A unified type for displaying both birthdays and countdowns in a single list
enum UpcomingEvent: Identifiable {
    case birthday(UpcomingBirthday)
    case countdown(Countdown)

    var id: UUID {
        switch self {
        case .birthday(let birthday): return birthday.id
        case .countdown(let countdown): return countdown.id
        }
    }

    var daysUntil: Int {
        switch self {
        case .birthday(let birthday): return birthday.daysUntil
        case .countdown(let countdown): return countdown.daysUntilNextOccurrence
        }
    }

    var title: String {
        switch self {
        case .birthday(let birthday): return birthday.profile.displayName
        case .countdown(let countdown): return countdown.title
        }
    }

    var isBirthday: Bool {
        if case .birthday = self { return true }
        return false
    }

    var isCountdown: Bool {
        if case .countdown = self { return true }
        return false
    }
}

// MARK: - Calendar Event Type
/// Type of event that can be shared to the family calendar
enum CalendarEventType: String, Codable {
    case appointment
    case countdown
}

// MARK: - Family Calendar Share
/// Represents an event shared to the family calendar
struct FamilyCalendarShare: Codable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let eventType: CalendarEventType
    let eventId: UUID
    let sharedByUserId: UUID
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case eventType = "event_type"
        case eventId = "event_id"
        case sharedByUserId = "shared_by_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Family Calendar Share Member
/// Represents a member who can see a shared calendar event
struct FamilyCalendarShareMember: Codable, Identifiable, Equatable {
    let id: UUID
    let shareId: UUID
    let memberUserId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case shareId = "share_id"
        case memberUserId = "member_user_id"
        case createdAt = "created_at"
    }
}

// MARK: - Account Member With User
/// Account member with associated user details for display
struct AccountMemberWithUser: Identifiable, Equatable {
    let member: AccountMember
    let user: AppUser

    var id: UUID { member.id }
    var userId: UUID { member.userId }
    var email: String { user.email }
    var role: MemberRole { member.role }

    /// Display name for the member (uses email since app_users doesn't have display name)
    var displayName: String {
        // Extract name part from email (before @) and capitalize it
        let emailName = user.email.components(separatedBy: "@").first ?? user.email
        return emailName.capitalized
    }
}

// MARK: - Calendar Event Filter
/// Filter options for calendar events
enum CalendarEventFilter: String, CaseIterable, Identifiable {
    case appointments
    case countdowns
    case birthdays
    case medications

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appointments: return "Appointments"
        case .countdowns: return "Events"
        case .birthdays: return "Birthdays"
        case .medications: return "Medications"
        }
    }

    var icon: String {
        switch self {
        case .appointments: return "calendar"
        case .countdowns: return "clock.fill"
        case .birthdays: return "gift.fill"
        case .medications: return "pill.fill"
        }
    }

    var color: Color {
        switch self {
        case .appointments: return .calendarBlue
        case .countdowns: return .blue
        case .birthdays: return .pink
        case .medications: return .badgeGreen
        }
    }
}

// MARK: - Unified Calendar Event
/// A unified type for displaying different event types in the calendar
enum CalendarEvent: Identifiable {
    case appointment(Appointment, isShared: Bool)
    case countdown(Countdown, isShared: Bool)
    case birthday(UpcomingBirthday)
    case medication(Medication, ScheduleEntry, Date)

    var id: String {
        switch self {
        case .appointment(let apt, _): return "apt-\(apt.id)"
        case .countdown(let cd, _): return "cd-\(cd.id)"
        case .birthday(let bday): return "bday-\(bday.id)"
        case .medication(let med, let entry, let date):
            let dateStr = ISO8601DateFormatter().string(from: date)
            return "med-\(med.id)-\(entry.id)-\(dateStr)"
        }
    }

    var date: Date {
        switch self {
        case .appointment(let apt, _): return apt.date
        case .countdown(let cd, _): return cd.date
        case .birthday(let bday): return bday.profile.birthday?.nextOccurrenceDate() ?? Date()
        case .medication(_, _, let date): return date
        }
    }

    var dateTime: Date {
        switch self {
        case .appointment(let apt, _): return apt.dateTime
        case .countdown(let cd, _): return cd.date
        case .birthday(let bday): return bday.profile.birthday?.nextOccurrenceDate() ?? Date()
        case .medication(_, let entry, let date):
            // Combine date with schedule entry time
            let calendar = Calendar.current
            let components = entry.time.split(separator: ":").compactMap { Int($0) }
            if components.count >= 2 {
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
                dateComponents.hour = components[0]
                dateComponents.minute = components[1]
                return calendar.date(from: dateComponents) ?? date
            }
            return date
        }
    }

    var title: String {
        switch self {
        case .appointment(let apt, _): return apt.title
        case .countdown(let cd, _): return cd.title
        case .birthday(let bday): return "\(bday.profile.displayName)'s Birthday"
        case .medication(let med, _, _): return med.name
        }
    }

    var subtitle: String? {
        switch self {
        case .appointment(let apt, _): return apt.location
        case .countdown(let cd, _): return cd.notes
        case .birthday(let bday):
            if let age = bday.profile.age {
                return "Turning \(age + 1)"
            }
            return nil
        case .medication(let med, let entry, _):
            return entry.dosage ?? med.strength
        }
    }

    var time: String? {
        switch self {
        case .appointment(let apt, _):
            guard let time = apt.time else { return nil }
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: time)
        case .countdown: return nil
        case .birthday: return nil
        case .medication(_, let entry, _): return entry.time
        }
    }

    var icon: String {
        switch self {
        case .appointment(let apt, _): return apt.type.icon
        case .countdown(let cd, _): return cd.type.icon
        case .birthday: return "gift.fill"
        case .medication: return "pill.fill"
        }
    }

    var color: Color {
        switch self {
        case .appointment(let apt, _): return apt.type.color
        case .countdown(let cd, _): return cd.type.color
        case .birthday: return .pink
        case .medication: return .badgeGreen
        }
    }

    var filterType: CalendarEventFilter {
        switch self {
        case .appointment: return .appointments
        case .countdown: return .countdowns
        case .birthday: return .birthdays
        case .medication: return .medications
        }
    }

    var isSharedToFamily: Bool {
        switch self {
        case .appointment(_, let isShared): return isShared
        case .countdown(_, let isShared): return isShared
        case .birthday: return false
        case .medication: return false
        }
    }

    var canBeShared: Bool {
        switch self {
        case .appointment, .countdown: return true
        case .birthday, .medication: return false
        }
    }

    /// The profile ID associated with this event (if any)
    /// Note: Countdowns are account-scoped and don't have a specific profile
    var profileId: UUID? {
        switch self {
        case .appointment(let apt, _): return apt.profileId
        case .countdown: return nil // Countdowns are account-wide, not profile-specific
        case .birthday(let bday): return bday.profile.id
        case .medication(let med, _, _): return med.profileId
        }
    }
}
