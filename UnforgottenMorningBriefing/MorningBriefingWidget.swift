import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct MorningBriefingProvider: TimelineProvider {
    func placeholder(in context: Context) -> MorningBriefingEntry {
        MorningBriefingEntry.sample
    }

    func getSnapshot(in context: Context, completion: @escaping (MorningBriefingEntry) -> Void) {
        completion(MorningBriefingEntry.sample)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MorningBriefingEntry>) -> Void) {
        let entry: MorningBriefingEntry
        if let briefingData = WidgetDataStore.loadBriefingData() {
            entry = briefingData.toEntry()
        } else {
            // No data yet — show empty state
            entry = MorningBriefingEntry(date: Date(), items: [], totalCount: 0)
        }

        // Refresh at the start of the next day
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct MorningBriefingEntry: TimelineEntry {
    let date: Date
    let items: [WidgetBriefingItem]
    let totalCount: Int

    static var sample: MorningBriefingEntry {
        MorningBriefingEntry(
            date: Date(),
            items: [
                .init(icon: "pill.fill", title: "Paracetamol", subtitle: "8:00 AM", color: LiveActivityTheme.medicalRed),
                .init(icon: "pill.fill", title: "Vitamin D", subtitle: "8:00 AM", color: LiveActivityTheme.medicalRed),
                .init(icon: "calendar", title: "Dr. Smith", subtitle: "2:00 PM", color: LiveActivityTheme.calendarBlue),
                .init(icon: "gift.fill", title: "Mum's Birthday", subtitle: "Turning 75", color: LiveActivityTheme.birthdayPink),
                .init(icon: "clock.fill", title: "Anniversary", subtitle: nil, color: LiveActivityTheme.countdownPurple)
            ],
            totalCount: 5
        )
    }
}

struct WidgetBriefingItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color
}

// MARK: - Widget View

struct MorningBriefingWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: MorningBriefingEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        case .systemSmall:
            smallView
        case .accessoryRectangular:
            rectangularView
        case .accessoryCircular:
            circularView
        case .accessoryInline:
            inlineView
        default:
            mediumView
        }
    }

    // MARK: - System Medium (Home Screen full-width widget)
    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(alignment: .center, spacing: 8) {
                Image("unforgotten-icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 32)


            }

            Divider()
                .background(Color.white.opacity(0.15))

            if entry.totalCount == 0 {
                Spacer()
                HStack {
                    Spacer()
                    Text("Nothing scheduled today")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(LiveActivityTheme.textSecondary)
                    Spacer()
                }
                Spacer()
            } else {
                // Item rows
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(entry.items.prefix(3)) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(item.color)
                                .frame(width: 16)

                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(LiveActivityTheme.textPrimary)
                                .lineLimit(1)

                            if let subtitle = item.subtitle {
                                Text(subtitle)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(LiveActivityTheme.textSecondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(3)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                    }

                    if entry.totalCount > 3 {
                        Text("+\(entry.totalCount - 3) more")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(LiveActivityTheme.textSecondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .widgetURL(URL(string: "unforgotten://home"))
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    LiveActivityTheme.cardBackground,
                    LiveActivityTheme.cardBackground.opacity(0.7),
                    LiveActivityTheme.background.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - System Small (Home Screen square widget)
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack(spacing: 6) {
                Image("unforgotten-icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 32)

            }

            Divider()
                .background(Color.white.opacity(0.1))

            if entry.totalCount == 0 {
                Spacer()
                Text("Nothing scheduled")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LiveActivityTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.items.prefix(3)) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(item.color)
                                .frame(width: 14)

                            Text(item.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(LiveActivityTheme.textPrimary)
                                .lineLimit(1)
                        }
                    }

                    if entry.totalCount > 3 {
                        Text("+\(entry.totalCount - 3) more")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(LiveActivityTheme.textSecondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(10 )
        .widgetURL(URL(string: "unforgotten://home"))
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    LiveActivityTheme.cardBackground,
                    LiveActivityTheme.cardBackground.opacity(0.9),
                    LiveActivityTheme.background.opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Rectangular (Lock Screen widget)
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: LiveActivityTheme.headerSystemImageName)
                    .font(.system(size: 10, weight: .semibold))
                Text("Today")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                if entry.totalCount > 3 {
                    Text("+\(entry.totalCount - 3)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(entry.items.prefix(3)) { item in
                HStack(spacing: 4) {
                    Image(systemName: item.icon)
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 12)
                    Text(item.title)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            }
        }
        .widgetURL(URL(string: "unforgotten://home"))
    }

    // MARK: - Circular
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: LiveActivityTheme.headerSystemImageName)
                    .font(.system(size: 12, weight: .semibold))
                Text("\(entry.totalCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
        }
        .widgetURL(URL(string: "unforgotten://home"))
    }

    // MARK: - Inline (single line above the clock)
    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: LiveActivityTheme.headerSystemImageName)
            if entry.totalCount == 0 {
                Text("Nothing scheduled")
            } else {
                Text("\(entry.totalCount) item\(entry.totalCount == 1 ? "" : "s") today")
            }
        }
        .widgetURL(URL(string: "unforgotten://home"))
    }
}

// MARK: - Widget Configuration

struct MorningBriefingWidget: Widget {
    let kind: String = "MorningBriefingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MorningBriefingProvider()) { entry in
            MorningBriefingWidgetView(entry: entry)
        }
        .configurationDisplayName("Morning Briefing")
        .description("See today's medications, appointments, and birthdays at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}
