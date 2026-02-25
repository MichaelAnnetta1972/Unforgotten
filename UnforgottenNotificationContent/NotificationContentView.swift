import SwiftUI

// MARK: - Notification Data Model

struct NotificationData {
    let category: String
    let title: String
    let body: String
    let userInfo: [AnyHashable: Any]

    /// Whether the notification preview should be hidden (set by main app's hide previews preference)
    var hidePreview: Bool { userInfo["hidePreview"] as? Bool ?? false }

    // Medication fields
    var medicationName: String? { userInfo["medicationName"] as? String }
    var doseDescription: String? {
        let desc = userInfo["doseDescription"] as? String
        return (desc?.isEmpty == true) ? nil : desc
    }
    var scheduledTime: String? { userInfo["scheduledTime"] as? String }

    // Appointment fields
    var appointmentTitle: String? { userInfo["appointmentTitle"] as? String }
    var appointmentLocation: String? {
        let loc = userInfo["appointmentLocation"] as? String
        return (loc?.isEmpty == true) ? nil : loc
    }
    var appointmentTime: String? {
        let time = userInfo["appointmentTime"] as? String
        return (time?.isEmpty == true) ? nil : time
    }

    // Sticky reminder fields
    var reminderTitle: String? { userInfo["title"] as? String }
    var repeatInterval: String? { userInfo["repeatInterval"] as? String }

    // Category display info
    var categoryDisplayName: String {
        switch category {
        case "MEDICATION_REMINDER": return "Medication Reminder"
        case "APPOINTMENT_REMINDER": return "Appointment"
        case "BIRTHDAY_REMINDER": return "Birthday"
        case "STICKY_REMINDER": return "Reminder"
        default: return "Notification"
        }
    }

    var categoryIcon: String {
        switch category {
        case "MEDICATION_REMINDER": return "pill.fill"
        case "APPOINTMENT_REMINDER": return "calendar"
        case "BIRTHDAY_REMINDER": return "gift.fill"
        case "STICKY_REMINDER": return "pin.fill"
        default: return "bell.fill"
        }
    }

    var categoryColor: Color {
        switch category {
        case "MEDICATION_REMINDER": return NotificationTheme.medicalRed
        case "APPOINTMENT_REMINDER": return NotificationTheme.accentYellow
        case "BIRTHDAY_REMINDER": return NotificationTheme.headerGradientEnd
        case "STICKY_REMINDER": return NotificationTheme.accentYellow
        default: return NotificationTheme.accentYellow
        }
    }
}

// MARK: - Main Notification Content View

struct NotificationContentView: View {
    let data: NotificationData

    var body: some View {
        VStack(spacing: 0) {
            brandingHeader

            if data.hidePreview {
                // Hidden preview mode - show generic message
                hiddenPreviewContent
            } else {
                // Full detail mode
                fullDetailContent
            }
        }
        .frame(maxWidth: 500)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .background(NotificationTheme.headerGradient)
    }

    // MARK: - Hidden Preview Content

    private var hiddenPreviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("You have things to do today. Open the Unforgotten app to get started.")
                .font(NotificationTheme.bodyFont)
                .foregroundColor(NotificationTheme.textPrimary)

            openAppButton
        }
        .padding(NotificationTheme.cardPadding)
    }

    // MARK: - Full Detail Content

    private var fullDetailContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Category label
            HStack(spacing: 8) {
                Image(systemName: data.categoryIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(data.categoryColor)
                Text(data.categoryDisplayName)
                    .font(NotificationTheme.captionFont)
                    .foregroundColor(.white.opacity(0.50))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(data.categoryColor.opacity(0.15))
            .cornerRadius(20)

            // Title
            Text(data.title)
                .font(NotificationTheme.titleFont)
                .foregroundColor(NotificationTheme.textPrimary)

            // Category-specific details
            detailCard

            // Open app button
            openAppButton
        }
        .padding(NotificationTheme.cardPadding)
    }

    // MARK: - Branding Header

    private var brandingHeader: some View {
        HStack(spacing: 8) {
            Image("unforgotten-icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Unforgotten")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(NotificationTheme.textPrimary)

            Spacer()
        }
        .padding(.horizontal, NotificationTheme.cardPadding)
        .padding(.vertical, NotificationTheme.cardPadding)
        //.background(NotificationTheme.cardBackground)
    }

    // MARK: - Detail Card

    @ViewBuilder
    private var detailCard: some View {
        switch data.category {
        case "MEDICATION_REMINDER":
            medicationDetail
        case "APPOINTMENT_REMINDER":
            appointmentDetail
        case "BIRTHDAY_REMINDER":
            birthdayDetail
        case "STICKY_REMINDER":
            stickyReminderDetail
        default:
            genericDetail
        }
    }

    // MARK: - Medication Detail

    private var medicationDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let name = data.medicationName {
                detailRow(label: "Medication", value: name)
            }
            if let dose = data.doseDescription {
                detailRow(label: "Dose", value: dose)
            }
            if let timeStr = data.scheduledTime,
               let formattedTime = formatISO8601Time(timeStr) {
                detailRow(label: "Scheduled", value: formattedTime)
            }
        Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // .padding(NotificationTheme.cardPadding)
        // .background(NotificationTheme.cardBackground)
        // .cornerRadius(NotificationTheme.cardCornerRadius)
    }

    // MARK: - Appointment Detail

    private var appointmentDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = data.appointmentTitle {
                detailRow(label: "Event", value: title)
            }
            if let location = data.appointmentLocation {
                detailRow(label: "Location", value: location)
            }
            if let time = data.appointmentTime {
                detailRow(label: "Time", value: time)
            }
            // Fallback to body if structured fields aren't available
            if data.appointmentTitle == nil {
                Text(data.body)
                    .font(NotificationTheme.bodyFont)
                    .foregroundColor(NotificationTheme.textPrimary)
            }
        Spacer()

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // .padding(NotificationTheme.cardPadding)
        // .background(NotificationTheme.cardBackground)
        // .cornerRadius(NotificationTheme.cardCornerRadius)
    }

    // MARK: - Birthday Detail

    private var birthdayDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(data.body)
                .font(NotificationTheme.bodyFont)
                .foregroundColor(NotificationTheme.textPrimary)
            Spacer()

        }
    
        .frame(maxWidth: .infinity, alignment: .leading)
        // .padding(NotificationTheme.cardPadding)
        // .background(NotificationTheme.cardBackground)
        // .cornerRadius(NotificationTheme.cardCornerRadius)
    }

    // MARK: - Sticky Reminder Detail

    private var stickyReminderDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(data.body)
                .font(NotificationTheme.bodyFont)
                .foregroundColor(NotificationTheme.textPrimary)
            if let interval = data.repeatInterval {
                detailRow(label: "Repeats", value: formatRepeatInterval(interval))
            }
        Spacer()

        }
        .frame(maxWidth: .infinity, alignment: .leading)
         //.padding(NotificationTheme.cardPadding)
        //.background(NotificationTheme.cardBackground)
        //.cornerRadius(NotificationTheme.cardCornerRadius)

    }

    // MARK: - Generic Fallback

    private var genericDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(data.body)
                .font(NotificationTheme.bodyFont)
                .foregroundColor(NotificationTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NotificationTheme.cardPadding)
        //.background(NotificationTheme.cardBackground)
        .cornerRadius(NotificationTheme.cardCornerRadius)
    }

    // MARK: - Open App Button

    private var openAppButton: some View {
        HStack(spacing: 8) {
            Spacer()
            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 16, weight: .semibold))
            Text("Open in Unforgotten")
                .font(NotificationTheme.buttonFont)
            Spacer()
        }
        .foregroundColor(NotificationTheme.accentYellow)
        .padding(.vertical, 14)
        .overlay(
            RoundedRectangle(cornerRadius: NotificationTheme.buttonCornerRadius)
                .stroke(NotificationTheme.accentYellow, lineWidth: 2)
        )
        .background(NotificationTheme.accentYellow.opacity(0.25))
        .cornerRadius(NotificationTheme.buttonCornerRadius)
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(NotificationTheme.captionFont)
                .foregroundColor(NotificationTheme.textSecondary)
            Text(value)
                .font(NotificationTheme.bodyFont)
                .foregroundColor(NotificationTheme.textPrimary)
        }
    }

    private func formatISO8601Time(_ isoString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return nil }
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        return timeFormatter.string(from: date)
    }

    private func formatRepeatInterval(_ interval: String) -> String {
        let parts = interval.split(separator: "_")
        guard parts.count == 2,
              let value = Int(parts[0]) else { return interval }
        let unit = String(parts[1])
        if value == 1 {
            let singular = unit.hasSuffix("s") ? String(unit.dropLast()) : unit
            return "Every \(singular)"
        }
        return "Every \(value) \(unit)"
    }
}
