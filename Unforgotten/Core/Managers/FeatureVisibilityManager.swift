import SwiftUI
import UniformTypeIdentifiers

// MARK: - Feature
/// Represents toggleable features in the app
enum Feature: String, CaseIterable, Identifiable, Codable {
    case aboutMe = "about_me"
    case calendar = "calendar"
    case familyAndFriends = "family_and_friends"
    case medications = "medications"
    case appointments = "appointments"
    case countdownEvents = "countdown_events"
    case todoLists = "todo_lists"
    case notes = "notes"
    case stickyReminders = "sticky_reminders"
    case birthdays = "birthdays"
    case usefulContacts = "useful_contacts"
    case moodTracker = "mood_tracker"
    case mealPlanner = "meal_planner"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aboutMe: return "About Me"
        case .calendar: return "Calendar"
        case .familyAndFriends: return "Family & Friends"
        case .medications: return "Medications"
        case .appointments: return "Appointments"
        case .countdownEvents: return "Countdown Events"
        case .todoLists: return "To Do Lists"
        case .notes: return "Notes"
        case .stickyReminders: return "Sticky Reminders"
        case .birthdays: return "Birthdays"
        case .usefulContacts: return "Useful Contacts"
        case .moodTracker: return "Mood Tracker"
        case .mealPlanner: return "Meal Planner"
        }
    }

    var icon: String {
        switch self {
        case .aboutMe: return "person.crop.rectangle"
        case .calendar: return "calendar.badge.clock"
        case .familyAndFriends: return "person.2"
        case .medications: return "pills"
        case .appointments: return "calendar"
        case .countdownEvents: return "timer"
        case .todoLists: return "checklist"
        case .notes: return "note.text"
        case .stickyReminders: return "bell.badge"
        case .birthdays: return "gift"
        case .usefulContacts: return "phone"
        case .moodTracker: return "face.smiling"
        case .mealPlanner: return "fork.knife"
        }
    }

    /// Features that cannot be hidden (core features)
    static var requiredFeatures: [Feature] {
        [.aboutMe, .calendar, .familyAndFriends]
    }

    var canBeHidden: Bool {
        !Feature.requiredFeatures.contains(self)
    }
}

// MARK: - Feature + Transferable
extension Feature: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .text)
    }
}

// MARK: - Feature Visibility Manager
@Observable
class FeatureVisibilityManager {
    private let userDefaultsKey = "feature_visibility"
    private let orderKey = "feature_order"

    /// Current user ID for sync (set by AppState)
    var currentUserId: UUID?
    /// Current account ID for sync (set by AppState)
    var currentAccountId: UUID?

    /// Dictionary of feature visibility states (true = visible)
    private(set) var visibilityStates: [String: Bool] = [:]

    /// Ordered list of feature raw values
    private(set) var featureOrder: [String] = []

    init() {
        loadVisibilityStates()
        loadFeatureOrder()
    }

    /// Trigger async sync to Supabase
    private func triggerSync() {
        guard let userId = currentUserId, let accountId = currentAccountId else { return }
        Task { @MainActor in
            await PreferencesSyncService.shared.syncFeatureVisibility(userId: userId, accountId: accountId)
        }
    }

    // MARK: - Public Methods

    /// Check if a feature is visible
    func isVisible(_ feature: Feature) -> Bool {
        // Required features are always visible
        if Feature.requiredFeatures.contains(feature) {
            return true
        }
        // Default to visible if not explicitly set
        return visibilityStates[feature.rawValue] ?? true
    }

    /// Set visibility for a feature
    func setVisibility(_ feature: Feature, isVisible: Bool) {
        // Don't allow hiding required features
        guard feature.canBeHidden else { return }

        visibilityStates[feature.rawValue] = isVisible
        saveVisibilityStates()
    }

    /// Toggle visibility for a feature
    func toggleVisibility(_ feature: Feature) {
        guard feature.canBeHidden else { return }

        let currentState = isVisible(feature)
        setVisibility(feature, isVisible: !currentState)
    }

    /// Get all visible features
    var visibleFeatures: [Feature] {
        Feature.allCases.filter { isVisible($0) }
    }

    /// Get all visible features in the user's custom order
    var orderedVisibleFeatures: [Feature] {
        let visible = Set(Feature.allCases.filter { isVisible($0) }.map { $0.rawValue })

        // Start with features in saved order that are still visible
        var ordered = featureOrder.compactMap { rawValue -> Feature? in
            guard visible.contains(rawValue), let feature = Feature(rawValue: rawValue) else { return nil }
            return feature
        }

        // Append any visible features not in the saved order (new features)
        let orderedSet = Set(ordered.map { $0.rawValue })
        let missing = Feature.allCases.filter { visible.contains($0.rawValue) && !orderedSet.contains($0.rawValue) }
        ordered.append(contentsOf: missing)

        return ordered
    }

    /// Get all hidden features
    var hiddenFeatures: [Feature] {
        Feature.allCases.filter { !isVisible($0) }
    }

    /// Move a feature from one index to another in the ordered list
    func moveFeature(fromIndex: Int, toIndex: Int) {
        var current = orderedVisibleFeatures.map { $0.rawValue }
        guard fromIndex >= 0, fromIndex < current.count,
              toIndex >= 0, toIndex < current.count,
              fromIndex != toIndex else { return }

        let item = current.remove(at: fromIndex)
        current.insert(item, at: toIndex)
        featureOrder = current
        saveFeatureOrder()
    }

    /// Apply order from remote sync (does NOT trigger sync back)
    func applyRemoteOrder(_ order: [String]) {
        featureOrder = order
        if let data = try? JSONEncoder().encode(featureOrder) {
            UserDefaults.standard.set(data, forKey: orderKey)
        }
    }

    /// Reset all features to visible and default order
    func resetToDefaults() {
        visibilityStates = [:]
        featureOrder = []
        saveVisibilityStates()
        saveFeatureOrder()
    }

    // MARK: - Private Methods

    private func loadVisibilityStates() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let states = try? JSONDecoder().decode([String: Bool].self, from: data) {
            visibilityStates = states
        }
    }

    private func saveVisibilityStates() {
        if let data = try? JSONEncoder().encode(visibilityStates) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        triggerSync()
    }

    private func loadFeatureOrder() {
        if let data = UserDefaults.standard.data(forKey: orderKey),
           let order = try? JSONDecoder().decode([String].self, from: data) {
            featureOrder = order
        }
    }

    private func saveFeatureOrder() {
        if let data = try? JSONEncoder().encode(featureOrder) {
            UserDefaults.standard.set(data, forKey: orderKey)
        }
        triggerSync()
    }
}
