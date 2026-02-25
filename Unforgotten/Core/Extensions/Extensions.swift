import SwiftUI
import SwiftData

// MARK: - View Extensions
extension View {
    /// Apply app background color
    func appBackground() -> some View {
        self.background(Color.appBackground.ignoresSafeArea())
    }
    
    /// Hide keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// Conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply floating add button overlay
    func floatingButton(action: @escaping () -> Void) -> some View {
        self.overlay(alignment: .bottom) {
            FloatingAddButton(action: action)
                .padding(.bottom, 20)
        }
    }
}

// MARK: - Date Extensions
extension Date {
    /// Format date for display
    func formatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: self)
    }
    
    /// Format as "15th April, 1972"
    func formattedBirthday() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM, yyyy"
        let day = Calendar.current.component(.day, from: self)
        let suffix = daySuffix(for: day)
        formatter.dateFormat = "MMMM, yyyy"
        return "\(day)\(suffix) \(formatter.string(from: self))"
    }

    /// Format as "17th December, 2002" with ordinal day
    func formattedBirthdayWithOrdinal() -> String {
        let day = Calendar.current.component(.day, from: self)
        let suffix = daySuffix(for: day)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM, yyyy"
        return "\(day)\(suffix) \(formatter.string(from: self))"
    }

    /// Format as "17th December" with ordinal day (no year)
    func formattedDayMonth() -> String {
        let day = Calendar.current.component(.day, from: self)
        let suffix = daySuffix(for: day)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return "\(day)\(suffix) \(formatter.string(from: self))"
    }

    /// Calculate age from birthday
    func age() -> Int {
        Calendar.current.dateComponents([.year], from: self, to: Date()).year ?? 0
    }
    
    /// Days until this date (for birthdays)
    func daysUntilNextOccurrence() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var components = calendar.dateComponents([.month, .day], from: self)
        components.year = calendar.component(.year, from: today)

        guard var nextDate = calendar.date(from: components) else { return 0 }

        if nextDate < today {
            components.year = (components.year ?? 0) + 1
            nextDate = calendar.date(from: components) ?? nextDate
        }

        return calendar.dateComponents([.day], from: today, to: nextDate).day ?? 0
    }

    /// Returns the next occurrence of this date (same month/day in the current or next year)
    func nextOccurrenceDate() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var components = calendar.dateComponents([.month, .day], from: self)
        components.year = calendar.component(.year, from: today)

        guard var nextDate = calendar.date(from: components) else { return self }

        if nextDate < today {
            components.year = (components.year ?? 0) + 1
            nextDate = calendar.date(from: components) ?? nextDate
        }

        return nextDate
    }
    
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Check if date is in the past
    var isPast: Bool {
        self < Date()
    }
    
    /// Start of day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// End of day
    var endOfDay: Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: self) ?? self
    }
    
    private func daySuffix(for day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
}

// MARK: - String Extensions
extension String {
    /// Validate email format
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    /// Trim whitespace
    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if string is empty or whitespace only
    var isBlank: Bool {
        self.trimmed.isEmpty
    }
}

// MARK: - Optional Extensions
extension Optional where Wrapped == String {
    /// Return empty string if nil
    var orEmpty: String {
        self ?? ""
    }
    
    /// Check if nil or empty
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}

// MARK: - Array Extensions
extension Array {
    /// Safe subscript access
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Collection Extensions
extension Collection {
    /// Check if collection is not empty
    var isNotEmpty: Bool {
        !isEmpty
    }
}

// MARK: - TimeInterval Extensions
extension TimeInterval {
    /// Minutes in seconds
    static func minutes(_ value: Double) -> TimeInterval {
        value * 60
    }
    
    /// Hours in seconds
    static func hours(_ value: Double) -> TimeInterval {
        value * 3600
    }
    
    /// Days in seconds
    static func days(_ value: Double) -> TimeInterval {
        value * 86400
    }
}

// MARK: - Calendar Extensions
extension Calendar {
    /// Days of the week (Sunday = 0)
    static let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    /// Full day names
    static let fullDaysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
}

// MARK: - Binding Extensions
extension Binding {
    /// Create a binding with a default value for optionals
    func defaultValue<T>(_ defaultValue: T) -> Binding<T> where Value == T? {
        Binding<T>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

// MARK: - UUID Extensions
extension UUID {
    /// Generate a deterministic UUID from a string (for preview purposes)
    static func from(_ string: String) -> UUID {
        let hash = string.hashValue
        let uuidString = String(format: "%08X-%04X-%04X-%04X-%012X",
                               abs(hash) & 0xFFFFFFFF,
                               abs(hash >> 32) & 0xFFFF,
                               abs(hash >> 48) & 0xFFFF,
                               abs(hash >> 64) & 0xFFFF,
                               abs(hash >> 80) & 0xFFFFFFFFFFFF)
        return UUID(uuidString: uuidString) ?? UUID()
    }
}

// MARK: - Error Extensions
extension Error {
    /// Check if this error is a cancellation error (Swift CancellationError, URLError.cancelled, or NSURLErrorCancelled)
    var isCancellation: Bool {
        // Check Swift's CancellationError
        if self is CancellationError {
            return true
        }

        // Check URLError.cancelled
        if let urlError = self as? URLError, urlError.code == .cancelled {
            return true
        }

        // Check NSError domain and code for cancellation
        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }

        // Check if the localized description contains "cancelled" (fallback)
        if localizedDescription.lowercased() == "cancelled" {
            return true
        }

        return false
    }
}

// MARK: - Notification Names for Data Refresh
extension Notification.Name {
    /// Posted when profiles data has changed and lists should refresh
    static let profilesDidChange = Notification.Name("profilesDidChange")

    /// Posted when medications data has changed and lists should refresh
    static let medicationsDidChange = Notification.Name("medicationsDidChange")

    /// Posted when appointments data has changed and lists should refresh
    /// userInfo keys: "appointmentId" (UUID), "action" (AppointmentChangeAction), "appointment" (Appointment, optional)
    static let appointmentsDidChange = Notification.Name("appointmentsDidChange")

    /// Posted when contacts data has changed and lists should refresh
    static let contactsDidChange = Notification.Name("contactsDidChange")

    /// Posted when sticky reminders data has changed and lists should refresh
    static let stickyRemindersDidChange = Notification.Name("stickyRemindersDidChange")

    /// Posted when the current account has changed (e.g., user switched accounts)
    static let accountDidChange = Notification.Name("accountDidChange")

    /// Posted when profile details (medical conditions, gift ideas, clothing sizes) have changed
    static let profileDetailsDidChange = Notification.Name("profileDetailsDidChange")

    /// Posted when important accounts have changed
    static let importantAccountsDidChange = Notification.Name("importantAccountsDidChange")

    /// Posted when the app should open the edit sheet for the primary profile (My Card)
    static let editPrimaryProfileRequested = Notification.Name("editPrimaryProfileRequested")

    /// Posted when countdowns data has changed and lists should refresh
    static let countdownsDidChange = Notification.Name("countdownsDidChange")

    /// Posted when a profile sync connection has changed (created or severed)
    /// userInfo keys: "syncId" (UUID), "action" (String: "created" or "severed")
    static let profileSyncDidChange = Notification.Name("profileSyncDidChange")

    /// Posted when profile sharing preferences have changed
    static let profileSharingPreferencesDidChange = Notification.Name("profileSharingPreferencesDidChange")

    /// Posted at midnight when the morning briefing should refresh for the new day
    static let morningBriefingShouldRefresh = Notification.Name("morningBriefingShouldRefresh")

    /// Posted when meal planner data (recipes or planned meals) has changed
    static let mealsDidChange = Notification.Name("mealsDidChange")

    /// Posted when to-do lists or items have changed
    static let todosDidChange = Notification.Name("todosDidChange")

    /// Posted when notes data has changed
    static let notesDidChange = Notification.Name("notesDidChange")

    /// Posted when mood entries have changed
    static let moodEntriesDidChange = Notification.Name("moodEntriesDidChange")
}

// MARK: - Appointment Change Action
enum AppointmentChangeAction: String {
    case created
    case updated
    case deleted
    case completionToggled
}

// MARK: - Notification UserInfo Keys
enum NotificationUserInfoKey {
    static let appointmentId = "appointmentId"
    static let appointment = "appointment"
    static let action = "action"
}

// MARK: - Generic Data Change Action
enum DataChangeAction: String {
    case created
    case updated
    case deleted
}

// MARK: - Bottom Nav Bar Visibility Environment Key
private struct BottomNavBarVisibleKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var isBottomNavBarVisible: Bool {
        get { self[BottomNavBarVisibleKey.self] }
        set { self[BottomNavBarVisibleKey.self] = newValue }
    }
}

// MARK: - Bottom Nav Bar Visibility Preference Key
struct BottomNavBarVisibilityPreference: PreferenceKey {
    static var defaultValue: Bool = true

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

extension View {
    /// Hide the bottom navigation bar for this view
    func hideBottomNavBar(_ hide: Bool = true) -> some View {
        self.preference(key: BottomNavBarVisibilityPreference.self, value: !hide)
    }
}

// MARK: - iPad Floating Add Button Visibility Environment Key
private struct HideFloatingAddButtonKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}

extension EnvironmentValues {
    /// Binding to hide the iPad floating add button
    var hideFloatingAddButton: Binding<Bool>? {
        get { self[HideFloatingAddButtonKey.self] }
        set { self[HideFloatingAddButtonKey.self] = newValue }
    }
}

// MARK: - iPad Home Action Environment Key
private struct iPadHomeActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to navigate back to iPad home (deselect all content)
    var iPadHomeAction: (() -> Void)? {
        get { self[iPadHomeActionKey.self] }
        set { self[iPadHomeActionKey.self] = newValue }
    }
}

// MARK: - Navigate to Home Tab Action Environment Key
private struct NavigateToHomeTabActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to navigate to the Home tab (for iPhone bottom nav)
    var navigateToHomeTab: (() -> Void)? {
        get { self[NavigateToHomeTabActionKey.self] }
        set { self[NavigateToHomeTabActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Note Action Environment Key
private struct iPadAddNoteActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to trigger the Add Note panel on iPad
    var iPadAddNoteAction: (() -> Void)? {
        get { self[iPadAddNoteActionKey.self] }
        set { self[iPadAddNoteActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Contact Action Environment Key
private struct iPadAddContactActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to trigger the Add Contact panel on iPad
    var iPadAddContactAction: (() -> Void)? {
        get { self[iPadAddContactActionKey.self] }
        set { self[iPadAddContactActionKey.self] = newValue }
    }
}

// MARK: - iPad Edit Note Action Environment Key
private struct iPadEditNoteActionKey: EnvironmentKey {
    static let defaultValue: ((LocalNote) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to trigger the Edit Note panel on iPad with an existing note
    var iPadEditNoteAction: ((LocalNote) -> Void)? {
        get { self[iPadEditNoteActionKey.self] }
        set { self[iPadEditNoteActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Profile Action Environment Key
private struct iPadAddProfileActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to trigger the Add Profile panel on iPad
    var iPadAddProfileAction: (() -> Void)? {
        get { self[iPadAddProfileActionKey.self] }
        set { self[iPadAddProfileActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Medication Action Environment Key
private struct iPadAddMedicationActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to trigger the Add Medication panel on iPad
    var iPadAddMedicationAction: (() -> Void)? {
        get { self[iPadAddMedicationActionKey.self] }
        set { self[iPadAddMedicationActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Appointment Action Environment Key
private struct iPadAddAppointmentActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to trigger the Add Appointment panel on iPad
    var iPadAddAppointmentAction: (() -> Void)? {
        get { self[iPadAddAppointmentActionKey.self] }
        set { self[iPadAddAppointmentActionKey.self] = newValue }
    }
}

// MARK: - iPad Appointment Filter Action Environment Key
private struct iPadAppointmentFilterActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to trigger the Appointment Filter overlay on iPad
    var iPadAppointmentFilterAction: (() -> Void)? {
        get { self[iPadAppointmentFilterActionKey.self] }
        set { self[iPadAppointmentFilterActionKey.self] = newValue }
    }
}

// MARK: - iPad Appointment Filter Binding Environment Key
private struct iPadAppointmentFilterBindingKey: EnvironmentKey {
    static let defaultValue: Binding<AppointmentType?>? = nil
}

extension EnvironmentValues {
    /// Binding to the selected appointment type filter on iPad
    var iPadAppointmentFilterBinding: Binding<AppointmentType?>? {
        get { self[iPadAppointmentFilterBindingKey.self] }
        set { self[iPadAppointmentFilterBindingKey.self] = newValue }
    }
}

// MARK: - iPad Add To Do List Action Environment Key
private struct iPadAddToDoListActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to trigger the Add To Do List panel on iPad
    var iPadAddToDoListAction: (() -> Void)? {
        get { self[iPadAddToDoListActionKey.self] }
        set { self[iPadAddToDoListActionKey.self] = newValue }
    }
}

// MARK: - iPad To Do List Filter Binding Environment Key
private struct iPadToDoListFilterBindingKey: EnvironmentKey {
    static let defaultValue: Binding<String?>? = nil
}

extension EnvironmentValues {
    /// Binding to the selected to do list type filter on iPad
    var iPadToDoListFilterBinding: Binding<String?>? {
        get { self[iPadToDoListFilterBindingKey.self] }
        set { self[iPadToDoListFilterBindingKey.self] = newValue }
    }
}

// MARK: - iPad Calendar Filter Binding Environment Key
private struct iPadCalendarFilterBindingKey: EnvironmentKey {
    static let defaultValue: Binding<Set<CalendarEventFilter>>? = nil
}

extension EnvironmentValues {
    /// Binding to the selected calendar event filters on iPad
    var iPadCalendarFilterBinding: Binding<Set<CalendarEventFilter>>? {
        get { self[iPadCalendarFilterBindingKey.self] }
        set { self[iPadCalendarFilterBindingKey.self] = newValue }
    }
}

// MARK: - iPad Calendar Countdown Type Filter Binding Environment Key
private struct iPadCalendarCountdownTypeFilterBindingKey: EnvironmentKey {
    static let defaultValue: Binding<Set<CountdownType>>? = nil
}

extension EnvironmentValues {
    /// Binding to the selected countdown type sub-filters on iPad
    var iPadCalendarCountdownTypeFilterBinding: Binding<Set<CountdownType>>? {
        get { self[iPadCalendarCountdownTypeFilterBindingKey.self] }
        set { self[iPadCalendarCountdownTypeFilterBindingKey.self] = newValue }
    }
}

// MARK: - iPad Calendar Custom Type Name Filter Binding Environment Key
private struct iPadCalendarCustomTypeNameFilterBindingKey: EnvironmentKey {
    static let defaultValue: Binding<Set<String>>? = nil
}

extension EnvironmentValues {
    /// Binding to the selected custom countdown type name sub-filters on iPad
    var iPadCalendarCustomTypeNameFilterBinding: Binding<Set<String>>? {
        get { self[iPadCalendarCustomTypeNameFilterBindingKey.self] }
        set { self[iPadCalendarCustomTypeNameFilterBindingKey.self] = newValue }
    }
}

// MARK: - iPad Calendar Member Filter Binding Environment Key
private struct iPadCalendarMemberFilterBindingKey: EnvironmentKey {
    static let defaultValue: Binding<Set<UUID>>? = nil
}

extension EnvironmentValues {
    /// Binding to the selected calendar member filters on iPad
    var iPadCalendarMemberFilterBinding: Binding<Set<UUID>>? {
        get { self[iPadCalendarMemberFilterBindingKey.self] }
        set { self[iPadCalendarMemberFilterBindingKey.self] = newValue }
    }
}

// MARK: - iPad Calendar Members With Events Binding Environment Key
private struct iPadCalendarMembersWithEventsBindingKey: EnvironmentKey {
    static let defaultValue: Binding<[AccountMemberWithUser]>? = nil
}

extension EnvironmentValues {
    /// Binding to the account members with events for calendar filtering on iPad
    var iPadCalendarMembersWithEventsBinding: Binding<[AccountMemberWithUser]>? {
        get { self[iPadCalendarMembersWithEventsBindingKey.self] }
        set { self[iPadCalendarMembersWithEventsBindingKey.self] = newValue }
    }
}

// MARK: - iPad Add Sticky Reminder Action Environment Key
private struct iPadAddStickyReminderActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to trigger the Add Sticky Reminder panel on iPad
    var iPadAddStickyReminderAction: (() -> Void)? {
        get { self[iPadAddStickyReminderActionKey.self] }
        set { self[iPadAddStickyReminderActionKey.self] = newValue }
    }
}

// MARK: - iPad Edit Sticky Reminder Action Environment Key
private struct iPadEditStickyReminderActionKey: EnvironmentKey {
    static let defaultValue: ((StickyReminder) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to trigger the Edit Sticky Reminder panel on iPad with an existing reminder
    var iPadEditStickyReminderAction: ((StickyReminder) -> Void)? {
        get { self[iPadEditStickyReminderActionKey.self] }
        set { self[iPadEditStickyReminderActionKey.self] = newValue }
    }
}

// MARK: - iPad View Sticky Reminder Action Environment Key
private struct iPadViewStickyReminderActionKey: EnvironmentKey {
    static let defaultValue: ((StickyReminder) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to view a Sticky Reminder in the full-screen side panel on iPad
    var iPadViewStickyReminderAction: ((StickyReminder) -> Void)? {
        get { self[iPadViewStickyReminderActionKey.self] }
        set { self[iPadViewStickyReminderActionKey.self] = newValue }
    }
}

// MARK: - iPad View ToDo List Action Environment Key
private struct iPadViewToDoListActionKey: EnvironmentKey {
    static let defaultValue: ((ToDoList) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to view a ToDo List in the full-screen side panel on iPad
    var iPadViewToDoListAction: ((ToDoList) -> Void)? {
        get { self[iPadViewToDoListActionKey.self] }
        set { self[iPadViewToDoListActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Countdown Action Environment Key
private struct iPadAddCountdownActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to trigger the Add Countdown panel on iPad
    var iPadAddCountdownAction: (() -> Void)? {
        get { self[iPadAddCountdownActionKey.self] }
        set { self[iPadAddCountdownActionKey.self] = newValue }
    }
}

// MARK: - iPad Edit Countdown Action Environment Key
private struct iPadEditCountdownActionKey: EnvironmentKey {
    static let defaultValue: ((Countdown) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to edit a Countdown in the full-screen side panel on iPad
    var iPadEditCountdownAction: ((Countdown) -> Void)? {
        get { self[iPadEditCountdownActionKey.self] }
        set { self[iPadEditCountdownActionKey.self] = newValue }
    }
}

// MARK: - iPad Edit Profile Action Environment Key
private struct iPadEditProfileActionKey: EnvironmentKey {
    static let defaultValue: ((Profile) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to edit a Profile in the full-screen side panel on iPad
    var iPadEditProfileAction: ((Profile) -> Void)? {
        get { self[iPadEditProfileActionKey.self] }
        set { self[iPadEditProfileActionKey.self] = newValue }
    }
}

// MARK: - iPad Edit Medication Action Environment Key
private struct iPadEditMedicationActionKey: EnvironmentKey {
    static let defaultValue: ((Medication) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to edit a Medication in the full-screen side panel on iPad
    var iPadEditMedicationAction: ((Medication) -> Void)? {
        get { self[iPadEditMedicationActionKey.self] }
        set { self[iPadEditMedicationActionKey.self] = newValue }
    }
}

// MARK: - iPad Edit Appointment Action Environment Key
private struct iPadEditAppointmentActionKey: EnvironmentKey {
    static let defaultValue: ((Appointment) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to edit an Appointment in the full-screen side panel on iPad
    var iPadEditAppointmentAction: ((Appointment) -> Void)? {
        get { self[iPadEditAppointmentActionKey.self] }
        set { self[iPadEditAppointmentActionKey.self] = newValue }
    }
}

// MARK: - iPad Edit Useful Contact Action Environment Key
private struct iPadEditUsefulContactActionKey: EnvironmentKey {
    static let defaultValue: ((UsefulContact) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to edit a Useful Contact in the full-screen side panel on iPad
    var iPadEditUsefulContactAction: ((UsefulContact) -> Void)? {
        get { self[iPadEditUsefulContactActionKey.self] }
        set { self[iPadEditUsefulContactActionKey.self] = newValue }
    }
}

// MARK: - iPad Edit Important Account Action Environment Key
private struct iPadEditImportantAccountActionKey: EnvironmentKey {
    static let defaultValue: ((ImportantAccount, Profile) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to edit an Important Account in the full-screen side panel on iPad
    var iPadEditImportantAccountAction: ((ImportantAccount, Profile) -> Void)? {
        get { self[iPadEditImportantAccountActionKey.self] }
        set { self[iPadEditImportantAccountActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Important Account Action Environment Key
private struct iPadAddImportantAccountActionKey: EnvironmentKey {
    static let defaultValue: ((Profile) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to add an Important Account in the full-screen side panel on iPad
    var iPadAddImportantAccountAction: ((Profile) -> Void)? {
        get { self[iPadAddImportantAccountActionKey.self] }
        set { self[iPadAddImportantAccountActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Medical Condition Action Environment Key
private struct iPadAddMedicalConditionActionKey: EnvironmentKey {
    static let defaultValue: ((Profile) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to add a Medical Condition in the full-screen side panel on iPad
    var iPadAddMedicalConditionAction: ((Profile) -> Void)? {
        get { self[iPadAddMedicalConditionActionKey.self] }
        set { self[iPadAddMedicalConditionActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Gift Idea Action Environment Key
private struct iPadAddGiftIdeaActionKey: EnvironmentKey {
    static let defaultValue: ((Profile) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to add a Gift Idea in the full-screen side panel on iPad
    var iPadAddGiftIdeaAction: ((Profile) -> Void)? {
        get { self[iPadAddGiftIdeaActionKey.self] }
        set { self[iPadAddGiftIdeaActionKey.self] = newValue }
    }
}

// MARK: - iPad Edit Gift Idea Action Environment Key
private struct iPadEditGiftIdeaActionKey: EnvironmentKey {
    static let defaultValue: ((ProfileDetail) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to edit a Gift Idea in the full-screen side panel on iPad
    var iPadEditGiftIdeaAction: ((ProfileDetail) -> Void)? {
        get { self[iPadEditGiftIdeaActionKey.self] }
        set { self[iPadEditGiftIdeaActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Clothing Size Action Environment Key
private struct iPadAddClothingSizeActionKey: EnvironmentKey {
    static let defaultValue: ((Profile) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to add a Clothing Size in the full-screen side panel on iPad
    var iPadAddClothingSizeAction: ((Profile) -> Void)? {
        get { self[iPadAddClothingSizeActionKey.self] }
        set { self[iPadAddClothingSizeActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Hobby Section Action Environment Key
private struct iPadAddHobbySectionActionKey: EnvironmentKey {
    static let defaultValue: ((Profile) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to add a Hobby section in the full-screen side panel on iPad
    var iPadAddHobbySectionAction: ((Profile) -> Void)? {
        get { self[iPadAddHobbySectionActionKey.self] }
        set { self[iPadAddHobbySectionActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Activity Section Action Environment Key
private struct iPadAddActivitySectionActionKey: EnvironmentKey {
    static let defaultValue: ((Profile) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to add an Activity section in the full-screen side panel on iPad
    var iPadAddActivitySectionAction: ((Profile) -> Void)? {
        get { self[iPadAddActivitySectionActionKey.self] }
        set { self[iPadAddActivitySectionActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Hobby Item Action Environment Key
private struct iPadAddHobbyItemActionKey: EnvironmentKey {
    static let defaultValue: ((Profile, String) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to add a Hobby item in the full-screen side panel on iPad (profile, sectionName)
    var iPadAddHobbyItemAction: ((Profile, String) -> Void)? {
        get { self[iPadAddHobbyItemActionKey.self] }
        set { self[iPadAddHobbyItemActionKey.self] = newValue }
    }
}

// MARK: - iPad Add Activity Item Action Environment Key
private struct iPadAddActivityItemActionKey: EnvironmentKey {
    static let defaultValue: ((Profile, String) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to add an Activity item in the full-screen side panel on iPad (profile, sectionName)
    var iPadAddActivityItemAction: ((Profile, String) -> Void)? {
        get { self[iPadAddActivityItemActionKey.self] }
        set { self[iPadAddActivityItemActionKey.self] = newValue }
    }
}

// MARK: - iPad Edit Clothing Size Action Environment Key
private struct iPadEditClothingSizeActionKey: EnvironmentKey {
    static let defaultValue: ((ProfileDetail) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to edit a Clothing Size in the full-screen side panel on iPad
    var iPadEditClothingSizeAction: ((ProfileDetail) -> Void)? {
        get { self[iPadEditClothingSizeActionKey.self] }
        set { self[iPadEditClothingSizeActionKey.self] = newValue }
    }
}

// MARK: - iPad Settings Panel Actions

private struct iPadShowInviteMemberActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct iPadShowManageMembersActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct iPadShowMoodHistoryActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct iPadShowAppearanceSettingsActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct iPadShowFeatureVisibilityActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct iPadShowSwitchAccountActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct iPadShowEditAccountNameActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct iPadShowAdminPanelActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct iPadShowUpgradeActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var iPadShowInviteMemberAction: (() -> Void)? {
        get { self[iPadShowInviteMemberActionKey.self] }
        set { self[iPadShowInviteMemberActionKey.self] = newValue }
    }

    var iPadShowManageMembersAction: (() -> Void)? {
        get { self[iPadShowManageMembersActionKey.self] }
        set { self[iPadShowManageMembersActionKey.self] = newValue }
    }

    var iPadShowMoodHistoryAction: (() -> Void)? {
        get { self[iPadShowMoodHistoryActionKey.self] }
        set { self[iPadShowMoodHistoryActionKey.self] = newValue }
    }

    var iPadShowAppearanceSettingsAction: (() -> Void)? {
        get { self[iPadShowAppearanceSettingsActionKey.self] }
        set { self[iPadShowAppearanceSettingsActionKey.self] = newValue }
    }

    var iPadShowFeatureVisibilityAction: (() -> Void)? {
        get { self[iPadShowFeatureVisibilityActionKey.self] }
        set { self[iPadShowFeatureVisibilityActionKey.self] = newValue }
    }

    var iPadShowSwitchAccountAction: (() -> Void)? {
        get { self[iPadShowSwitchAccountActionKey.self] }
        set { self[iPadShowSwitchAccountActionKey.self] = newValue }
    }

    var iPadShowEditAccountNameAction: (() -> Void)? {
        get { self[iPadShowEditAccountNameActionKey.self] }
        set { self[iPadShowEditAccountNameActionKey.self] = newValue }
    }

    var iPadShowAdminPanelAction: (() -> Void)? {
        get { self[iPadShowAdminPanelActionKey.self] }
        set { self[iPadShowAdminPanelActionKey.self] = newValue }
    }

    var iPadShowUpgradeAction: (() -> Void)? {
        get { self[iPadShowUpgradeActionKey.self] }
        set { self[iPadShowUpgradeActionKey.self] = newValue }
    }
}

// MARK: - iPad Calendar Day Detail Action Environment Key
private struct iPadCalendarDayDetailActionKey: EnvironmentKey {
    static let defaultValue: ((Date, [CalendarEvent], @escaping () -> Void) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to show the Calendar Day Detail overlay on iPad (date, events, and onDismiss callback)
    var iPadCalendarDayDetailAction: ((Date, [CalendarEvent], @escaping () -> Void) -> Void)? {
        get { self[iPadCalendarDayDetailActionKey.self] }
        set { self[iPadCalendarDayDetailActionKey.self] = newValue }
    }
}

// MARK: - iPad Calendar Day Detail Dismiss Action Environment Key
private struct iPadCalendarDayDetailDismissActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to dismiss the Calendar Day Detail overlay on iPad
    var iPadCalendarDayDetailDismissAction: (() -> Void)? {
        get { self[iPadCalendarDayDetailDismissActionKey.self] }
        set { self[iPadCalendarDayDetailDismissActionKey.self] = newValue }
    }
}

// MARK: - iPad Calendar Event Selected Action Environment Key
private struct iPadCalendarEventSelectedActionKey: EnvironmentKey {
    static let defaultValue: ((CalendarEvent) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to handle when a calendar event is selected on iPad (for navigation)
    var iPadCalendarEventSelectedAction: ((CalendarEvent) -> Void)? {
        get { self[iPadCalendarEventSelectedActionKey.self] }
        set { self[iPadCalendarEventSelectedActionKey.self] = newValue }
    }
}

// MARK: - iPad Today Item Navigation Actions

private struct iPadTodayMedicationActionKey: EnvironmentKey {
    static let defaultValue: ((Medication) -> Void)? = nil
}

private struct iPadTodayAppointmentActionKey: EnvironmentKey {
    static let defaultValue: ((Appointment) -> Void)? = nil
}

private struct iPadTodayProfileActionKey: EnvironmentKey {
    static let defaultValue: ((Profile) -> Void)? = nil
}

private struct iPadTodayCountdownActionKey: EnvironmentKey {
    static let defaultValue: ((Countdown) -> Void)? = nil
}

extension EnvironmentValues {
    /// Action to navigate to medication detail from Today card on iPad
    var iPadTodayMedicationAction: ((Medication) -> Void)? {
        get { self[iPadTodayMedicationActionKey.self] }
        set { self[iPadTodayMedicationActionKey.self] = newValue }
    }

    /// Action to navigate to appointment detail from Today card on iPad
    var iPadTodayAppointmentAction: ((Appointment) -> Void)? {
        get { self[iPadTodayAppointmentActionKey.self] }
        set { self[iPadTodayAppointmentActionKey.self] = newValue }
    }

    /// Action to navigate to profile detail from Today card on iPad
    var iPadTodayProfileAction: ((Profile) -> Void)? {
        get { self[iPadTodayProfileActionKey.self] }
        set { self[iPadTodayProfileActionKey.self] = newValue }
    }

    /// Action to navigate to countdown detail from Today card on iPad
    var iPadTodayCountdownAction: ((Countdown) -> Void)? {
        get { self[iPadTodayCountdownActionKey.self] }
        set { self[iPadTodayCountdownActionKey.self] = newValue }
    }
}

