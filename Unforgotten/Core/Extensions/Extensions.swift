import SwiftUI

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
