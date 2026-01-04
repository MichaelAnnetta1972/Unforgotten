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

// MARK: - iPad Settings Panel Actions

private struct iPadShowInviteMemberActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct iPadShowManageMembersActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct iPadShowJoinAccountActionKey: EnvironmentKey {
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

    var iPadShowJoinAccountAction: (() -> Void)? {
        get { self[iPadShowJoinAccountActionKey.self] }
        set { self[iPadShowJoinAccountActionKey.self] = newValue }
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
