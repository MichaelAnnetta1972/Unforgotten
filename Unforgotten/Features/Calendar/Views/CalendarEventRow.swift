import SwiftUI

// MARK: - Calendar Event Row Style
enum CalendarEventRowStyle {
    case filled      // Default: solid background
    case outlined    // No background, border instead
}

// MARK: - Calendar Event Row
struct CalendarEventRow: View {
    let event: CalendarEvent
    var showFullDetails: Bool = false
    var showDate: Bool = false
    var style: CalendarEventRowStyle = .filled

    @Environment(\.appAccentColor) private var appAccentColor

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator and icon
            VStack {
                Image(systemName: event.icon)
                    .font(.system(size: 16))
                    .foregroundColor(appAccentColor)
            }
            .frame(width: 40, height: 40)
            .background(appAccentColor.opacity(0.2))
            .cornerRadius(10)

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(event.title)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)
                        .lineLimit(showFullDetails ? nil : 1)

                    // Age badge for birthdays
                    if case .birthday(let bday) = event, let age = birthdayAge(for: bday) {
                        Text("\(age)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(appAccentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(appAccentColor.opacity(0.2))
                            .cornerRadius(AppDimensions.pillCornerRadius)
                    }

                    if event.isSharedToFamily {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                }

                HStack(spacing: 8) {
                    // Date (for list view)
                    if showDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            Text(formattedDate)
                                .font(.appCaption)
                        }
                        .foregroundColor(isToday ? appAccentColor : .textSecondary)
                    }

                    // Time
                    if let time = event.time {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text(time)
                                .font(.appCaption)
                        }
                        .foregroundColor(.textSecondary)
                    }
                }
            }

            Spacer()

            // Chevron for navigation (if in detail view)
            if showFullDetails {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(style == .filled ? Color.cardBackgroundSoft.opacity(0.4) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                .stroke(style == .outlined ? .white.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Date Helpers

    private var isToday: Bool {
        calendar.isDateInToday(event.date)
    }

    private var formattedDate: String {
        if isToday {
            return "Today"
        } else if calendar.isDateInTomorrow(event.date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(event.date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: event.date)
        }
    }

    // MARK: - Helper Properties

    private var subtitleIcon: String {
        switch event {
        case .appointment: return "mappin"
        case .countdown: return "text.alignleft"
        case .birthday: return "gift"
        case .medication: return "pill"
        case .todoList: return "checklist"
        }
    }

    /// Calculate the age the person will be turning on this birthday
    private func birthdayAge(for bday: UpcomingBirthday) -> Int? {
        guard let birthDate = bday.profile.birthday else { return nil }
        let calendar = Calendar.current
        // Use the event's actual date (the birthday occurrence shown on the calendar)
        let eventDate = calendar.startOfDay(for: event.date)
        let birthStart = calendar.startOfDay(for: birthDate)
        let components = calendar.dateComponents([.year], from: birthStart, to: eventDate)
        return components.year
    }

    private var eventTypeName: String {
        switch event {
        case .appointment(let apt, _): return apt.type.displayName
        case .countdown(let cd, _, _): return cd.displayTypeName
        case .birthday: return "Birthday"
        case .medication: return "Medication"
        case .todoList(let list): return list.listType ?? "To Do"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        // Note: These previews won't work without actual model instances
        // This is just for structure reference
        Text("Calendar Event Rows")
            .font(.headline)
    }
    .padding()
    .background(Color.appBackgroundLight)
}
