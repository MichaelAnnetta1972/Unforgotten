import SwiftUI

// MARK: - Feature
/// Represents toggleable features in the app
enum Feature: String, CaseIterable, Identifiable {
    case aboutMe = "about_me"
    case familyAndFriends = "family_and_friends"
    case medications = "medications"
    case appointments = "appointments"
    case calendar = "calendar"
    case todoLists = "todo_lists"
    case notes = "notes"
    case stickyReminders = "sticky_reminders"
    case birthdays = "birthdays"
    case usefulContacts = "useful_contacts"
    case moodTracker = "mood_tracker"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aboutMe: return "About Me"
        case .familyAndFriends: return "Family & Friends"
        case .medications: return "Medications"
        case .appointments: return "Appointments"
        case .calendar: return "Calendar"
        case .todoLists: return "To Do Lists"
        case .notes: return "Notes"
        case .stickyReminders: return "Sticky Reminders"
        case .birthdays: return "Birthdays"
        case .usefulContacts: return "Useful Contacts"
        case .moodTracker: return "Mood Tracker"
        }
    }

    var icon: String {
        switch self {
        case .aboutMe: return "person.crop.rectangle"
        case .familyAndFriends: return "person.2"
        case .medications: return "pills"
        case .appointments: return "calendar"
        case .calendar: return "calendar.badge.clock"
        case .todoLists: return "checklist"
        case .notes: return "note.text"
        case .stickyReminders: return "bell.badge"
        case .birthdays: return "gift"
        case .usefulContacts: return "phone"
        case .moodTracker: return "face.smiling"
        }
    }

    /// Features that cannot be hidden (core features)
    static var requiredFeatures: [Feature] {
        [.aboutMe]
    }

    var canBeHidden: Bool {
        !Feature.requiredFeatures.contains(self)
    }
}

// MARK: - Feature Visibility Manager
@Observable
class FeatureVisibilityManager {
    private let userDefaultsKey = "feature_visibility"

    /// Current user ID for sync (set by AppState)
    var currentUserId: UUID?
    /// Current account ID for sync (set by AppState)
    var currentAccountId: UUID?

    /// Dictionary of feature visibility states (true = visible)
    private(set) var visibilityStates: [String: Bool] = [:]

    init() {
        loadVisibilityStates()
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

    /// Get all hidden features
    var hiddenFeatures: [Feature] {
        Feature.allCases.filter { !isVisible($0) }
    }

    /// Reset all features to visible
    func resetToDefaults() {
        visibilityStates = [:]
        saveVisibilityStates()
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
}
