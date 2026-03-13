import Foundation

// MARK: - Shared Data Store (Main App Copy)

/// Reads/writes morning briefing data via a shared App Group UserDefaults.
/// This is the main app's copy — a matching copy exists in the widget extension.
enum WidgetDataStore {
    static let appGroupId = "group.com.bbad.michael.Unforgotten"
    private static let briefingKey = "morningBriefingData"
    private static let tomorrowBriefingKey = "tomorrowBriefingData"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    // MARK: - Today's Data

    static func saveBriefingData(_ data: WidgetBriefingData) {
        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: briefingKey)
        }
    }

    /// Load the most recent briefing data (used by background task to populate Live Activity).
    static func loadBriefingData() -> WidgetBriefingData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: briefingKey),
              let briefing = try? JSONDecoder().decode(WidgetBriefingData.self, from: data) else {
            return nil
        }
        return briefing
    }

    // MARK: - Tomorrow's Pre-cached Data

    static func saveTomorrowBriefingData(_ data: WidgetBriefingData) {
        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: tomorrowBriefingKey)
        }
    }

    static func loadTomorrowBriefingData() -> WidgetBriefingData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: tomorrowBriefingKey),
              let briefing = try? JSONDecoder().decode(WidgetBriefingData.self, from: data) else {
            return nil
        }
        return briefing
    }

    /// Promote pre-cached tomorrow data to today's slot.
    /// Called by the background task at ~2 AM when the new day starts.
    static func promoteTomorrowToToday() {
        guard let tomorrowData = loadTomorrowBriefingData() else { return }

        // Re-date the data to now so the widget's isDateInToday check passes
        let promoted = WidgetBriefingData(
            date: Date(),
            items: tomorrowData.items,
            totalCount: tomorrowData.totalCount
        )
        saveBriefingData(promoted)

        // Clear the tomorrow slot
        sharedDefaults?.removeObject(forKey: tomorrowBriefingKey)

        #if DEBUG
        print("📋 Promoted tomorrow's briefing data to today (\(promoted.totalCount) items)")
        #endif
    }
}

// MARK: - Shared Codable Models

struct WidgetBriefingData: Codable {
    let date: Date
    let items: [WidgetBriefingItemData]
    let totalCount: Int
}

struct WidgetBriefingItemData: Codable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String?
    let colorHex: String
}
