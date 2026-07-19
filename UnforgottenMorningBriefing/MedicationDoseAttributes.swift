import ActivityKit
import Foundation

/// Defines the data model for the Medication Dose Live Activity.
/// Shown on the Lock Screen while one or more doses are due and not yet taken.
/// This file must be included in BOTH the main app target and the widget extension target.
struct MedicationDoseAttributes: ActivityAttributes {
    /// Dynamic state that can be updated while the Live Activity is running.
    public struct ContentState: Codable, Hashable {
        /// Doses that are due now (or overdue) and not yet taken, oldest first.
        var doses: [DoseItem]
        /// How many of today's doses have been taken so far.
        var takenTodayCount: Int
        /// Total number of doses scheduled today.
        var totalTodayCount: Int
        var lastUpdated: Date
    }

    /// A single due dose shown in the Live Activity.
    struct DoseItem: Codable, Hashable {
        let medicationName: String
        /// e.g. medication strength ("50mg"), if known.
        let doseDescription: String?
        /// Formatted scheduled time, e.g. "8:00 AM".
        let time: String
        /// True when the dose is more than an hour past its scheduled time.
        let isOverdue: Bool
    }

    // Static data set when the activity starts (doesn't change).
    // Uses String (ISO8601) instead of Date for APNs payload compatibility.
    var date: String
}
