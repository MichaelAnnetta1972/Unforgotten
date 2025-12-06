import Foundation

// MARK: - Account
struct Account: Codable, Identifiable, Equatable {
    let id: UUID
    let ownerUserId: UUID
    let displayName: String
    let timezone: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserId = "owner_user_id"
        case displayName = "display_name"
        case timezone
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
        case .helper: return "Can update medications & appointments"
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
struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let type: ProfileType
    var fullName: String
    var preferredName: String?
    var relationship: String?
    var birthday: Date?
    var address: String?
    var phone: String?
    var email: String?
    var notes: String?
    var isFavourite: Bool
    var linkedUserId: UUID?
    var photoUrl: String?
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case type
        case fullName = "full_name"
        case preferredName = "preferred_name"
        case relationship
        case birthday
        case address
        case phone
        case email
        case notes
        case isFavourite = "is_favourite"
        case linkedUserId = "linked_user_id"
        case photoUrl = "photo_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var displayName: String {
        preferredName ?? fullName
    }
    
    var age: Int? {
        birthday?.age()
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
    
    var displayName: String {
        switch self {
        case .clothing: return "Clothing"
        case .giftIdea: return "Gift"
        case .medicalCondition: return "Medical Condition"
        case .allergy: return "Allergy"
        case .like: return "Like"
        case .dislike: return "Dislike"
        case .note: return "Note"
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
        }
    }
}

// MARK: - Medication
struct Medication: Codable, Identifiable, Equatable {
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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

// MARK: - Appointment
struct Appointment: Codable, Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let profileId: UUID
    var withProfileId: UUID?
    var title: String
    var date: Date
    var time: Date?
    var location: String?
    var notes: String?
    var reminderOffsetMinutes: Int?
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case profileId = "profile_id"
        case withProfileId = "with_profile_id"
        case title
        case date
        case time
        case location
        case notes
        case reminderOffsetMinutes = "reminder_offset_minutes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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
        case .mother, .father, .son, .daughter, .brother, .sister,
             .grandmother, .grandfather, .grandson, .granddaughter,
             .aunt, .uncle, .nephew, .niece, .cousin, .spouse, .partner:
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
        [.mother, .father, .son, .daughter, .brother, .sister,
         .grandmother, .grandfather, .grandson, .granddaughter,
         .aunt, .uncle, .nephew, .niece, .cousin, .spouse, .partner]
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
