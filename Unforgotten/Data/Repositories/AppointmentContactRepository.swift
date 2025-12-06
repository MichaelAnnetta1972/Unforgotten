import Foundation
import Supabase

// MARK: - Appointment Repository Protocol
protocol AppointmentRepositoryProtocol {
    func getAppointments(accountId: UUID) async throws -> [Appointment]
    func getUpcomingAppointments(accountId: UUID, days: Int) async throws -> [Appointment]
    func getAppointmentsInRange(accountId: UUID, startDate: Date, endDate: Date) async throws -> [Appointment]
    func getTodaysAppointments(accountId: UUID) async throws -> [Appointment]
    func getAppointment(id: UUID) async throws -> Appointment
    func createAppointment(_ appointment: AppointmentInsert) async throws -> Appointment
    func updateAppointment(_ appointment: Appointment) async throws -> Appointment
    func deleteAppointment(id: UUID) async throws
}

// MARK: - Appointment Repository Implementation
final class AppointmentRepository: AppointmentRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Get All Appointments
    func getAppointments(accountId: UUID) async throws -> [Appointment] {
        let appointments: [Appointment] = try await supabase
            .from(TableName.appointments)
            .select()
            .eq("account_id", value: accountId)
            .order("date")
            .execute()
            .value
        
        return appointments
    }
    
    // MARK: - Get Upcoming Appointments
    func getUpcomingAppointments(accountId: UUID, days: Int = 30) async throws -> [Appointment] {
        let today = Calendar.current.startOfDay(for: Date())
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: today)!

        // Format dates as yyyy-MM-dd to match PostgreSQL date column format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let todayString = dateFormatter.string(from: today)
        let futureDateString = dateFormatter.string(from: futureDate)

        let appointments: [Appointment] = try await supabase
            .from(TableName.appointments)
            .select()
            .eq("account_id", value: accountId)
            .gte("date", value: todayString)
            .lte("date", value: futureDateString)
            .order("date")
            .execute()
            .value

        return appointments
    }

    // MARK: - Get Appointments in Date Range
    func getAppointmentsInRange(accountId: UUID, startDate: Date, endDate: Date) async throws -> [Appointment] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let startString = dateFormatter.string(from: startDate)
        let endString = dateFormatter.string(from: endDate)

        let appointments: [Appointment] = try await supabase
            .from(TableName.appointments)
            .select()
            .eq("account_id", value: accountId)
            .gte("date", value: startString)
            .lte("date", value: endString)
            .order("date")
            .execute()
            .value

        return appointments
    }

    // MARK: - Get Today's Appointments
    func getTodaysAppointments(accountId: UUID) async throws -> [Appointment] {
        // Format today's date as yyyy-MM-dd to match PostgreSQL date column format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let todayString = dateFormatter.string(from: Date())

        let appointments: [Appointment] = try await supabase
            .from(TableName.appointments)
            .select()
            .eq("account_id", value: accountId)
            .eq("date", value: todayString)
            .order("time")
            .execute()
            .value

        return appointments
    }
    
    // MARK: - Get Single Appointment
    func getAppointment(id: UUID) async throws -> Appointment {
        let appointment: Appointment = try await supabase
            .from(TableName.appointments)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        
        return appointment
    }
    
    // MARK: - Create Appointment
    func createAppointment(_ appointment: AppointmentInsert) async throws -> Appointment {
        let created: Appointment = try await supabase
            .from(TableName.appointments)
            .insert(appointment)
            .select()
            .single()
            .execute()
            .value
        
        return created
    }
    
    // MARK: - Update Appointment
    func updateAppointment(_ appointment: Appointment) async throws -> Appointment {
        let update = AppointmentUpdate(
            withProfileId: appointment.withProfileId,
            title: appointment.title,
            date: appointment.date,
            time: appointment.time,
            location: appointment.location,
            notes: appointment.notes,
            reminderOffsetMinutes: appointment.reminderOffsetMinutes
        )
        
        let updated: Appointment = try await supabase
            .from(TableName.appointments)
            .update(update)
            .eq("id", value: appointment.id)
            .select()
            .single()
            .execute()
            .value
        
        return updated
    }
    
    // MARK: - Delete Appointment
    func deleteAppointment(id: UUID) async throws {
        try await supabase
            .from(TableName.appointments)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Appointment Insert/Update Types
struct AppointmentInsert: Encodable {
    let accountId: UUID
    let profileId: UUID
    let withProfileId: UUID?
    let title: String
    let date: Date
    let time: Date?
    let location: String?
    let notes: String?
    let reminderOffsetMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case profileId = "profile_id"
        case withProfileId = "with_profile_id"
        case title
        case date
        case time
        case location
        case notes
        case reminderOffsetMinutes = "reminder_offset_minutes"
    }

    init(
        accountId: UUID,
        profileId: UUID,
        title: String,
        date: Date,
        withProfileId: UUID? = nil,
        time: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        reminderOffsetMinutes: Int? = 60
    ) {
        self.accountId = accountId
        self.profileId = profileId
        self.withProfileId = withProfileId
        self.title = title
        self.date = date
        self.time = time
        self.location = location
        self.notes = notes
        self.reminderOffsetMinutes = reminderOffsetMinutes
    }

    // Custom encoding to handle time field as time-only string
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(profileId, forKey: .profileId)
        try container.encodeIfPresent(withProfileId, forKey: .withProfileId)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)

        // Encode time as HH:mm:ss string for PostgreSQL time column
        if let time = time {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            let timeString = timeFormatter.string(from: time)
            try container.encode(timeString, forKey: .time)
        } else {
            try container.encodeNil(forKey: .time)
        }

        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(reminderOffsetMinutes, forKey: .reminderOffsetMinutes)
    }
}

private struct AppointmentUpdate: Encodable {
    let withProfileId: UUID?
    let title: String
    let date: Date
    let time: Date?
    let location: String?
    let notes: String?
    let reminderOffsetMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case withProfileId = "with_profile_id"
        case title
        case date
        case time
        case location
        case notes
        case reminderOffsetMinutes = "reminder_offset_minutes"
    }

    // Custom encoding to handle time field as time-only string
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(withProfileId, forKey: .withProfileId)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)

        // Encode time as HH:mm:ss string for PostgreSQL time column
        if let time = time {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            let timeString = timeFormatter.string(from: time)
            try container.encode(timeString, forKey: .time)
        } else {
            try container.encodeNil(forKey: .time)
        }

        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(reminderOffsetMinutes, forKey: .reminderOffsetMinutes)
    }
}

// MARK: - Useful Contact Repository Protocol
protocol UsefulContactRepositoryProtocol {
    func getContacts(accountId: UUID) async throws -> [UsefulContact]
    func getContacts(accountId: UUID, category: ContactCategory) async throws -> [UsefulContact]
    func getContact(id: UUID) async throws -> UsefulContact
    func createContact(_ contact: UsefulContactInsert) async throws -> UsefulContact
    func updateContact(_ contact: UsefulContact) async throws -> UsefulContact
    func deleteContact(id: UUID) async throws
}

// MARK: - Useful Contact Repository Implementation
final class UsefulContactRepository: UsefulContactRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Get All Contacts
    func getContacts(accountId: UUID) async throws -> [UsefulContact] {
        let contacts: [UsefulContact] = try await supabase
            .from(TableName.usefulContacts)
            .select()
            .eq("account_id", value: accountId)
            .order("name")
            .execute()
            .value
        
        return contacts
    }
    
    // MARK: - Get Contacts by Category
    func getContacts(accountId: UUID, category: ContactCategory) async throws -> [UsefulContact] {
        let contacts: [UsefulContact] = try await supabase
            .from(TableName.usefulContacts)
            .select()
            .eq("account_id", value: accountId)
            .eq("category", value: category.rawValue)
            .order("name")
            .execute()
            .value
        
        return contacts
    }
    
    // MARK: - Get Single Contact
    func getContact(id: UUID) async throws -> UsefulContact {
        let contact: UsefulContact = try await supabase
            .from(TableName.usefulContacts)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        
        return contact
    }
    
    // MARK: - Create Contact
    func createContact(_ contact: UsefulContactInsert) async throws -> UsefulContact {
        let created: UsefulContact = try await supabase
            .from(TableName.usefulContacts)
            .insert(contact)
            .select()
            .single()
            .execute()
            .value
        
        return created
    }
    
    // MARK: - Update Contact
    func updateContact(_ contact: UsefulContact) async throws -> UsefulContact {
        let update = UsefulContactUpdate(
            name: contact.name,
            category: contact.category,
            companyName: contact.companyName,
            phone: contact.phone,
            email: contact.email,
            website: contact.website,
            address: contact.address,
            notes: contact.notes,
            isFavourite: contact.isFavourite
        )
        
        let updated: UsefulContact = try await supabase
            .from(TableName.usefulContacts)
            .update(update)
            .eq("id", value: contact.id)
            .select()
            .single()
            .execute()
            .value
        
        return updated
    }
    
    // MARK: - Delete Contact
    func deleteContact(id: UUID) async throws {
        try await supabase
            .from(TableName.usefulContacts)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Useful Contact Insert/Update Types
struct UsefulContactInsert: Encodable {
    let accountId: UUID
    let name: String
    let category: ContactCategory
    let companyName: String?
    let phone: String?
    let email: String?
    let website: String?
    let address: String?
    let notes: String?
    let isFavourite: Bool
    
    enum CodingKeys: String, CodingKey {
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
    }
    
    init(
        accountId: UUID,
        name: String,
        category: ContactCategory,
        companyName: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        isFavourite: Bool = false
    ) {
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
    }
}

private struct UsefulContactUpdate: Encodable {
    let name: String
    let category: ContactCategory
    let companyName: String?
    let phone: String?
    let email: String?
    let website: String?
    let address: String?
    let notes: String?
    let isFavourite: Bool
    
    enum CodingKeys: String, CodingKey {
        case name
        case category
        case companyName = "company_name"
        case phone
        case email
        case website
        case address
        case notes
        case isFavourite = "is_favourite"
    }
}

// MARK: - Mood Entry Repository Protocol
protocol MoodRepositoryProtocol {
    func getEntries(accountId: UUID, from: Date, to: Date) async throws -> [MoodEntry]
    func getTodaysEntry(accountId: UUID, userId: UUID) async throws -> MoodEntry?
    func createEntry(_ entry: MoodEntryInsert) async throws -> MoodEntry
    func updateEntry(id: UUID, rating: Int, note: String?) async throws -> MoodEntry
}

// MARK: - Mood Entry Repository Implementation
final class MoodRepository: MoodRepositoryProtocol {
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Get Entries for Date Range
    func getEntries(accountId: UUID, from: Date, to: Date) async throws -> [MoodEntry] {
        let entries: [MoodEntry] = try await supabase
            .from(TableName.moodEntries)
            .select()
            .eq("account_id", value: accountId)
            .gte("date", value: from.ISO8601Format())
            .lte("date", value: to.ISO8601Format())
            .order("date", ascending: false)
            .execute()
            .value
        
        return entries
    }
    
    // MARK: - Get Today's Entry
    func getTodaysEntry(accountId: UUID, userId: UUID) async throws -> MoodEntry? {
        // Use UTC calendar for consistent date comparison with stored data
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let todayUTC = utcCalendar.startOfDay(for: Date())

        let entries: [MoodEntry] = try await supabase
            .from(TableName.moodEntries)
            .select()
            .eq("account_id", value: accountId)
            .eq("user_id", value: userId)
            .eq("date", value: todayUTC.ISO8601Format())
            .limit(1)
            .execute()
            .value

        return entries.first
    }
    
    // MARK: - Create Entry
    func createEntry(_ entry: MoodEntryInsert) async throws -> MoodEntry {
        let created: MoodEntry = try await supabase
            .from(TableName.moodEntries)
            .insert(entry)
            .select()
            .single()
            .execute()
            .value
        
        return created
    }
    
    // MARK: - Update Entry
    func updateEntry(id: UUID, rating: Int, note: String?) async throws -> MoodEntry {
        let update = MoodEntryUpdate(rating: rating, note: note)
        
        let updated: MoodEntry = try await supabase
            .from(TableName.moodEntries)
            .update(update)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
        
        return updated
    }
}

// MARK: - Mood Entry Insert/Update Types
struct MoodEntryInsert: Encodable {
    let accountId: UUID
    let userId: UUID
    let date: Date
    let rating: Int
    let note: String?
    
    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case userId = "user_id"
        case date
        case rating
        case note
    }
    
    init(
        accountId: UUID,
        userId: UUID,
        date: Date? = nil,
        rating: Int,
        note: String? = nil
    ) {
        self.accountId = accountId
        self.userId = userId
        // Use UTC midnight for consistent date storage
        if let date = date {
            self.date = date
        } else {
            var utcCalendar = Calendar(identifier: .gregorian)
            utcCalendar.timeZone = TimeZone(identifier: "UTC")!
            self.date = utcCalendar.startOfDay(for: Date())
        }
        self.rating = rating
        self.note = note
    }
}

private struct MoodEntryUpdate: Encodable {
    let rating: Int
    let note: String?
}
