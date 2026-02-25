import Foundation
import SwiftUI

// MARK: - Shared Data Store

/// Reads/writes morning briefing data via a shared App Group UserDefaults.
/// Both the main app and widget extension use this to share data.
enum WidgetDataStore {
    static let appGroupId = "group.com.bbad.michael.Unforgotten"
    private static let briefingKey = "morningBriefingData"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    // MARK: - Write (called from main app)

    static func saveBriefingData(_ data: WidgetBriefingData) {
        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: briefingKey)
        }
    }

    // MARK: - Read (called from widget)

    static func loadBriefingData() -> WidgetBriefingData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: briefingKey),
              let briefing = try? JSONDecoder().decode(WidgetBriefingData.self, from: data) else {
            return nil
        }
        // Only return data if it's from today
        if Calendar.current.isDateInToday(briefing.date) {
            return briefing
        }
        return nil
    }
}

// MARK: - Shared Codable Model

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

// MARK: - Conversion to Widget Display Model

extension WidgetBriefingData {
    func toEntry() -> MorningBriefingEntry {
        MorningBriefingEntry(
            date: date,
            items: items.map { item in
                WidgetBriefingItem(
                    icon: item.icon,
                    title: item.title,
                    subtitle: item.subtitle,
                    color: Color(hex: item.colorHex)
                )
            },
            totalCount: totalCount
        )
    }
}
