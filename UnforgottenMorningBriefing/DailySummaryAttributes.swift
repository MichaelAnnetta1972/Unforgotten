import ActivityKit
import Foundation

/// Defines the data model for the Daily Summary Live Activity.
/// This file must be included in BOTH the main app target and the widget extension target.
struct DailySummaryAttributes: ActivityAttributes {
    /// Dynamic state that can be updated while the Live Activity is running.
    public struct ContentState: Codable, Hashable {
        var medicationCount: Int
        var appointments: [AppointmentItem]
        var birthdays: [String]
        var countdowns: [CountdownItem]
        var taskCount: Int
        /// ISO8601 string instead of Date: ActivityKit's push payload decoder
        /// rejects date strings with fractional seconds (as produced by both the
        /// Supabase encoder and JS toISOString), silently dropping push-to-start
        /// events. A plain String always decodes. Same reason `date` is a String.
        var lastUpdated: String

        /// Current timestamp in a push-safe format.
        static func timestampNow() -> String {
            ISO8601DateFormatter().string(from: Date())
        }
    }

    /// A single appointment shown in the Live Activity.
    struct AppointmentItem: Codable, Hashable {
        let title: String
        let time: String
    }

    /// A single countdown event shown in the Live Activity.
    struct CountdownItem: Codable, Hashable {
        let title: String
        let typeName: String
    }

    // Static data set when the activity starts (doesn't change).
    // Uses String (ISO8601) instead of Date for push-to-start APNs payload compatibility.
    var date: String
}
