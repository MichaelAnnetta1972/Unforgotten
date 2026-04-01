import WidgetKit
import ActivityKit
import SwiftUI

/// Live Activity widget primarily for the Lock Screen.
/// The Dynamic Island presentation is kept minimal.
struct DailySummaryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailySummaryAttributes.self) { context in
            DailySummaryLockScreenView(context: context)
                .activityBackgroundTint(LiveActivityTheme.background.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "unforgotten://home"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                EmptyView()
            }
        }
    }
}

// MARK: - Lock Screen View

struct DailySummaryLockScreenView: View {
    let context: ActivityViewContext<DailySummaryAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(alignment: .center, spacing: 8) {
                Image("unforgotten-icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 45)
                    .cornerRadius(8)

                Spacer()

                Text("Today's Overview")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(LiveActivityTheme.textPrimary)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Natural language summary
            if hasAnyItems {
                Text(summaryText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(LiveActivityTheme.textPrimary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Nothing scheduled for today. Enjoy your day!")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(LiveActivityTheme.textSecondary)
            }
        }
        .padding(14)
        .widgetURL(URL(string: "unforgotten://home"))
    }

    // MARK: - Helpers

    private var hasAnyItems: Bool {
        context.state.medicationCount > 0
        || !context.state.appointments.isEmpty
        || !context.state.birthdays.isEmpty
        || !context.state.countdowns.isEmpty
        || context.state.taskCount > 0
    }

    /// Build a natural-language summary of today's items.
    /// e.g. "Today you have 2 medications to take, 1 appointment and 2 events (Gisele with Michael, Charlie's Party)."
    private var summaryText: String {
        var parts: [String] = []

        if context.state.medicationCount > 0 {
            parts.append(
                context.state.medicationCount == 1
                    ? "1 medication to take"
                    : "\(context.state.medicationCount) medications to take"
            )
        }

        if !context.state.appointments.isEmpty {
            let count = context.state.appointments.count
            if count == 1 {
                parts.append("1 appointment (\(context.state.appointments[0].title))")
            } else {
                parts.append("\(count) appointments")
            }
        }

        if !context.state.birthdays.isEmpty {
            let names = context.state.birthdays.joined(separator: " & ")
            if context.state.birthdays.count == 1 {
                parts.append("\(names)'s birthday")
            } else {
                parts.append("\(context.state.birthdays.count) birthdays (\(names))")
            }
        }

        if !context.state.countdowns.isEmpty {
            let titles = context.state.countdowns.map(\.title).joined(separator: ", ")
            if context.state.countdowns.count == 1 {
                parts.append("1 event (\(titles))")
            } else {
                parts.append("\(context.state.countdowns.count) events (\(titles))")
            }
        }

        if context.state.taskCount > 0 {
            parts.append(
                context.state.taskCount == 1
                    ? "1 task pending"
                    : "\(context.state.taskCount) tasks pending"
            )
        }

        // Join with commas and "and" before the last item
        let joined: String
        if parts.count == 1 {
            joined = parts[0]
        } else if parts.count == 2 {
            joined = "\(parts[0]) and \(parts[1])"
        } else {
            joined = parts.dropLast().joined(separator: ", ") + " and " + parts.last!
        }

        return "Today you have \(joined)."
    }
}
