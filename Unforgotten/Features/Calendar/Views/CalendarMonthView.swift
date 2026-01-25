import SwiftUI

// MARK: - Calendar Month View
struct CalendarMonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.appAccentColor) private var appAccentColor

    let onDaySelected: () -> Void

    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 16) {
            // Month Navigation
            monthNavigationHeader

            // Days of Week Header
            daysOfWeekHeader

            // Calendar Grid
            calendarGrid
        }
        .padding(AppDimensions.cardPaddingLarge)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Month Navigation Header

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(monthYearString)
                .font(.appTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            Button {
                viewModel.goToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 44, height: 44)
            }
        }
    }

    // MARK: - Days of Week Header

    private var daysOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.appCaption)
                    .fontWeight(.medium)
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let weeks = weeksInMonth
        return VStack(spacing: 8) {
            ForEach(0..<weeks.count, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let date = weeks[weekIndex][dayIndex]
                        CalendarMonthDayCell(
                            date: date,
                            isCurrentMonth: isCurrentMonth(date),
                            isSelected: isSelected(date),
                            isToday: isToday(date),
                            eventColors: viewModel.eventColors(for: date),
                            accentColor: appAccentColor
                        ) {
                            viewModel.selectedDate = date
                            onDaySelected()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Properties

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: viewModel.currentMonth)
    }

    private var weeksInMonth: [[Date]] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: viewModel.currentMonth))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!

        // Find the first day of the week containing the first of the month
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = firstWeekday - 1

        // Calculate total cells needed (leading days + days in month)
        let totalDays = leadingDays + range.count
        let weeksNeeded = Int(ceil(Double(totalDays) / 7.0))

        var weeks: [[Date]] = []
        var currentDate = calendar.date(byAdding: .day, value: -leadingDays, to: startOfMonth)!

        for _ in 0..<weeksNeeded {
            var week: [Date] = []
            for _ in 0..<7 {
                week.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            weeks.append(week)
        }

        return weeks
    }

    private func isCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: viewModel.currentMonth, toGranularity: .month)
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let selectedDate = viewModel.selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
}

// MARK: - Calendar Month Day Cell
private struct CalendarMonthDayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let eventColors: [Color]
    let accentColor: Color
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Day number
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isToday ? .bold : .regular))
                    .foregroundColor(dayTextColor)

                // Event indicators
                if !eventColors.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(Array(eventColors.prefix(3).enumerated()), id: \.offset) { _, color in
                            Circle()
                                .fill(color)
                                .frame(width: 5, height: 5)
                        }
                    }
                } else {
                    // Spacer to maintain consistent cell height
                    Spacer()
                        .frame(height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(backgroundColor)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var dayTextColor: Color {
        if isSelected {
            return .black
        } else if !isCurrentMonth {
            return .textSecondary.opacity(0.4)
        } else if isToday {
            return accentColor
        } else {
            return .textPrimary
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return accentColor
        } else if isToday {
            return accentColor.opacity(0.2)
        } else {
            return .clear
        }
    }
}

// MARK: - Preview
#Preview {
    CalendarMonthView(viewModel: CalendarViewModel()) {}
        .padding()
        .background(Color.appBackgroundLight)
}
