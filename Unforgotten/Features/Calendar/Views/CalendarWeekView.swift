import SwiftUI

// MARK: - Calendar Week View
struct CalendarWeekView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.appAccentColor) private var appAccentColor

    let onDaySelected: () -> Void

    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    var body: some View {
        VStack(spacing: 16) {
            // Week Navigation
            weekNavigationHeader

            // Week days with events
            VStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { date in
                    CalendarWeekDayRow(
                        date: date,
                        events: viewModel.events(for: date),
                        isToday: calendar.isDateInToday(date),
                        isSelected: isSelected(date),
                        accentColor: appAccentColor
                    ) {
                        viewModel.selectedDate = date
                        onDaySelected()
                    }

                    if !calendar.isDate(date, inSameDayAs: daysOfWeek.last ?? date) {
                        Divider()
                            .background(Color.white.opacity(0.1))
                    }
                }
            }
        }
        .padding(AppDimensions.cardPaddingLarge)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Week Navigation Header

    private var weekNavigationHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousWeek()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(weekRangeString)
                .font(.appTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            Button {
                viewModel.goToNextWeek()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 44, height: 44)
            }
        }
    }

    // MARK: - Helpers

    private var daysOfWeek: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: viewModel.currentWeekStart)
        }
    }

    private var weekRangeString: String {
        let start = viewModel.currentWeekStart
        guard let end = calendar.date(byAdding: .day, value: 6, to: start) else {
            return ""
        }
        let startFormatter = DateFormatter()
        let endFormatter = DateFormatter()

        if calendar.component(.month, from: start) == calendar.component(.month, from: end) {
            startFormatter.dateFormat = "MMM d"
            endFormatter.dateFormat = "d, yyyy"
        } else if calendar.component(.year, from: start) == calendar.component(.year, from: end) {
            startFormatter.dateFormat = "MMM d"
            endFormatter.dateFormat = "MMM d, yyyy"
        } else {
            startFormatter.dateFormat = "MMM d, yyyy"
            endFormatter.dateFormat = "MMM d, yyyy"
        }

        return "\(startFormatter.string(from: start)) - \(endFormatter.string(from: end))"
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let selectedDate = viewModel.selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }
}

// MARK: - Calendar Week Day Row
private struct CalendarWeekDayRow: View {
    let date: Date
    let events: [CalendarEvent]
    let isToday: Bool
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Day column
                VStack(spacing: 2) {
                    Text(dayAbbreviation)
                        .font(.appCaption)
                        .fontWeight(.medium)
                        .foregroundColor(isToday ? accentColor : .textSecondary)

                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 18, weight: isToday ? .bold : .semibold))
                        .foregroundColor(isSelected ? .black : isToday ? accentColor : .textPrimary)
                }
                .frame(width: 44, height: 48)
                .background(isSelected ? accentColor : isToday ? accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(10)

                // Events column
                if events.isEmpty {
                    Text("No events")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(events.prefix(3)) { event in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(event.filterType.color)
                                    .frame(width: 6, height: 6)

                                Text(event.title)
                                    .font(.appCaption)
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(1)

                                if let time = event.time {
                                    Text(time)
                                        .font(.system(size: 11))
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }

                        if events.count > 3 {
                            Text("+\(events.count - 3) more")
                                .font(.system(size: 11))
                                .foregroundColor(accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary.opacity(0.5))
                    .padding(.top, 16)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var dayAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Preview
#Preview {
    CalendarWeekView(viewModel: CalendarViewModel()) {}
        .padding()
        .background(Color.appBackgroundLight)
}
