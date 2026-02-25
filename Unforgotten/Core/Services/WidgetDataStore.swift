import Foundation

// MARK: - Shared Data Store (Main App Copy)

/// Reads/writes morning briefing data via a shared App Group UserDefaults.
/// This is the main app's copy — a matching copy exists in the widget extension.
enum WidgetDataStore {
    static let appGroupId = "group.com.bbad.michael.Unforgotten"
    private static let briefingKey = "morningBriefingData"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func saveBriefingData(_ data: WidgetBriefingData) {
        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: briefingKey)
        }
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
