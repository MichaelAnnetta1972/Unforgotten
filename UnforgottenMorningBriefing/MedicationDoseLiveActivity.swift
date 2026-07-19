import WidgetKit
import ActivityKit
import SwiftUI

/// Live Activity widget for due medication doses, primarily for the Lock Screen.
/// Stays visible until the doses are marked taken in the app or the user swipes it away.
/// The Dynamic Island presentation is kept minimal.
struct MedicationDoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MedicationDoseAttributes.self) { context in
            MedicationDoseLockScreenView(context: context)
                .activityBackgroundTint(LiveActivityTheme.background.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "unforgotten://home"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "pills.fill")
                        .foregroundColor(LiveActivityTheme.medicalRed)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.doses.count == 1
                         ? "1 medication due"
                         : "\(context.state.doses.count) medications due")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            } compactLeading: {
                Image(systemName: "pills.fill")
                    .foregroundColor(LiveActivityTheme.medicalRed)
            } compactTrailing: {
                Text("\(context.state.doses.count)")
                    .foregroundColor(.white)
            } minimal: {
                Image(systemName: "pills.fill")
                    .foregroundColor(LiveActivityTheme.medicalRed)
            }
        }
    }
}

// MARK: - Lock Screen View

struct MedicationDoseLockScreenView: View {
    let context: ActivityViewContext<MedicationDoseAttributes>

    /// Show at most this many doses; the rest collapse into a "+N more" line.
    private let maxVisibleDoses = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(alignment: .center, spacing: 8) {
                Image("unforgotten-icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 32)
                    .cornerRadius(8)

                Text("Time for your medicine")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(LiveActivityTheme.textPrimary)

                Spacer()

                if context.state.totalTodayCount > 0 {
                    Text("\(context.state.takenTodayCount) of \(context.state.totalTodayCount) taken")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(LiveActivityTheme.textSecondary)
                }
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Due doses
            VStack(alignment: .leading, spacing: 4) {
                ForEach(context.state.doses.prefix(maxVisibleDoses), id: \.self) { dose in
                    HStack(spacing: 6) {
                        Image(systemName: "pills.fill")
                            .font(.system(size: 12))
                            .foregroundColor(LiveActivityTheme.medicalRed)

                        Text(doseLabel(for: dose))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(LiveActivityTheme.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text(dose.isOverdue ? "\(dose.time) — overdue" : dose.time)
                            .font(.system(size: 12, weight: dose.isOverdue ? .semibold : .regular))
                            .foregroundColor(dose.isOverdue ? LiveActivityTheme.medicalRed : LiveActivityTheme.textSecondary)
                    }
                }

                if context.state.doses.count > maxVisibleDoses {
                    Text("+\(context.state.doses.count - maxVisibleDoses) more")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(LiveActivityTheme.textSecondary)
                }
            }

            Text("Tap to open the app and mark as taken")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(LiveActivityTheme.textSecondary)
        }
        .padding(14)
        .widgetURL(URL(string: "unforgotten://home"))
    }

    private func doseLabel(for dose: MedicationDoseAttributes.DoseItem) -> String {
        if let description = dose.doseDescription, !description.isEmpty {
            return "\(dose.medicationName) \(description)"
        }
        return dose.medicationName
    }
}
