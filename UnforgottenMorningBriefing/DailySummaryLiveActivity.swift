import WidgetKit
import ActivityKit
import SwiftUI

/// Live Activity widget primarily for the Lock Screen.
/// The Dynamic Island presentation is kept minimal — just a small item count —
/// so it doesn't feel like a "takeover" of the Dynamic Island.
struct DailySummaryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailySummaryAttributes.self) { context in
            DailySummaryLockScreenView(context: context)
                .activityBackgroundTint(LiveActivityTheme.background.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "unforgotten://home"))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (user long-presses the island)
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

// MARK: - Dynamic Island Expanded View

/// Compact summary shown when the user long-presses the Dynamic Island.
private struct DailySummaryExpandedView: View {
    let context: ActivityViewContext<DailySummaryAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if context.state.medicationCount > 0 {
                Label(
                    context.state.medicationCount == 1
                        ? "1 medication to take"
                        : "\(context.state.medicationCount) medications to take",
                    systemImage: "pill.fill"
                )
                .font(.system(size: 13))
                .foregroundColor(.white)
            }

            ForEach(context.state.appointments.prefix(2), id: \.self) { appointment in
                Label("\(appointment.title) at \(appointment.time)", systemImage: "calendar")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }

            ForEach(context.state.birthdays.prefix(1), id: \.self) { name in
                Label("\(name)'s birthday", systemImage: "birthday.cake.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }

            ForEach(context.state.countdowns.prefix(1), id: \.self) { countdown in
                Label(countdown.title, systemImage: "clock.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }

            if context.state.taskCount > 0 {
                Label(
                    context.state.taskCount == 1
                        ? "1 task pending"
                        : "\(context.state.taskCount) tasks pending",
                    systemImage: "checklist"
                )
                .font(.system(size: 13))
                .foregroundColor(.white)
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

                //VStack(alignment: .leading, spacing: 2) {
                    
                    Image("unforgotten-icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 45)
                        .cornerRadius(8)
                
                    Spacer()

                    Text("Today's Overview")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(LiveActivityTheme.textPrimary)

                    // Text(formattedDate(context.attributes.date))
                    //     .font(.system(size: 12, weight: .regular))
                    //     .foregroundColor(LiveActivityTheme.textSecondary)
                //}

               

            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Content items
            VStack(alignment: .leading, spacing: 6) {
                if context.state.medicationCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "pill.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(LiveActivityTheme.medicalRed)
                            .frame(width: 16)

                        Text(context.state.medicationCount == 1
                             ? "1 medication to take"
                             : "\(context.state.medicationCount) medications to take")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LiveActivityTheme.textPrimary)
                            .lineLimit(1)
                    }
                }

                ForEach(context.state.appointments.prefix(2), id: \.self) { appointment in
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(LiveActivityTheme.calendarBlue)
                            .frame(width: 16)

                        

                        Text(context.state.appointments.count == 1
                             ? "1 appointment"
                             : "\(context.state.appointments.count) appointments")
                        //Text("\(appointment.title) at \(appointment.time)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LiveActivityTheme.textPrimary)
                            .lineLimit(1)
                    }
                }

                ForEach(context.state.birthdays.prefix(1), id: \.self) { name in
                    HStack(spacing: 8) {
                        Image(systemName: "birthday.cake.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(LiveActivityTheme.birthdayPink)
                            .frame(width: 16)


                        Text(context.state.birthdays.count == 1
                             ? "1 birthday"
                             : "\(context.state.birthdays.count) birthdays")
                        //Text("\(name)'s birthday")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LiveActivityTheme.textPrimary)
                            .lineLimit(1)
                    }
                }

                ForEach(context.state.countdowns.prefix(1), id: \.self) { countdown in
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(LiveActivityTheme.countdownPurple)
                            .frame(width: 16)

                        Text(context.state.countdowns.count == 1
                             ? "1 event"
                             : "\(context.state.countdowns.count) events")
                        //Text(countdown.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LiveActivityTheme.textPrimary)
                            .lineLimit(1)
                    }
                }

                if context.state.taskCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(LiveActivityTheme.taskGreen)
                            .frame(width: 16)


                        Text(context.state.taskCount == 1
                             ? "1 task pending"
                             : "\(context.state.taskCount) tasks pending")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LiveActivityTheme.textPrimary)
                            .lineLimit(1)
                    }
                }

                // "...and X more" indicator
                let displayedItems = itemsDisplayed
                let totalItems = totalItemCount
                if totalItems > displayedItems {
                    Text("...and \(totalItems - displayedItems) more")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(LiveActivityTheme.textSecondary)
                }
            }
        }
        .padding(14)
        .widgetURL(URL(string: "unforgotten://home"))
    }

    // MARK: - Helpers

    private var totalItemCount: Int {
        context.state.medicationCount
        + context.state.appointments.count
        + context.state.birthdays.count
        + context.state.countdowns.count
        + context.state.taskCount
    }

    /// Number of rows actually shown in the layout
    private var itemsDisplayed: Int {
        var count = 0
        if context.state.medicationCount > 0 { count += 1 }
        //count += min(context.state.medicationCount, 1)
        count += min(context.state.appointments.count, 1)
        count += min(context.state.birthdays.count, 1)
        count += min(context.state.countdowns.count, 1)
        //count += min(context.state.taskCount, 1)
        if context.state.taskCount > 0 { count += 1 }
        return count
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
}
