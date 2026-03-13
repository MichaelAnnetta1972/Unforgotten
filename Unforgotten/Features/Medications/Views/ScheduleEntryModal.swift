import SwiftUI

// MARK: - Schedule Data
/// Holds the data for a single medication schedule in the Add/Edit medication flow
struct ScheduleData: Identifiable, Equatable {
    var id = UUID()
    var entries: [ScheduleEntry] = [ScheduleEntry(time: "08:00")]
    var startDate: Date = Date()
    var endDate: Date? = nil
    var hasEndDate: Bool = false
    var existingScheduleId: UUID? = nil
}

// MARK: - Medication Schedule Modal
struct MedicationScheduleModal: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    @Binding var scheduleData: ScheduleData
    let isEditing: Bool
    let onSave: () -> Void
    let onDelete: (() -> Void)?

    // Internal state
    @State private var selectedDays: [Int]
    @State private var dosage: String
    @State private var timeSlots: [Date]
    @State private var internalStartDate: Date
    @State private var showEndDate: Bool
    @State private var internalEndDate: Date
    @State private var useDuration: Bool
    @State private var durationValue: Int
    @State private var durationUnit: DurationUnit

    init(
        scheduleData: Binding<ScheduleData>,
        isEditing: Bool = false,
        onSave: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self._scheduleData = scheduleData
        self.isEditing = isEditing
        self.onSave = onSave
        self.onDelete = onDelete

        let data = scheduleData.wrappedValue
        let entries = data.entries
        let firstEntry = entries.first

        _selectedDays = State(initialValue: firstEntry?.daysOfWeek ?? [0, 1, 2, 3, 4, 5, 6])
        _dosage = State(initialValue: firstEntry?.dosage ?? "")

        // Parse time strings into Date values for time pickers
        let parsedTimes: [Date] = entries.map { entry in
            let components = entry.time.split(separator: ":").compactMap { Int($0) }
            var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            dateComponents.hour = components.first ?? 8
            dateComponents.minute = components.count > 1 ? components[1] : 0
            return Calendar.current.date(from: dateComponents) ?? Date()
        }
        _timeSlots = State(initialValue: parsedTimes.isEmpty ? [{
            var dc = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            dc.hour = 8
            dc.minute = 0
            return Calendar.current.date(from: dc) ?? Date()
        }()] : parsedTimes)

        _internalStartDate = State(initialValue: data.startDate)

        let endDateVal = data.endDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        _showEndDate = State(initialValue: data.hasEndDate)
        _internalEndDate = State(initialValue: endDateVal)
        _useDuration = State(initialValue: false)
        _durationValue = State(initialValue: 7)
        _durationUnit = State(initialValue: .days)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with X and checkmark
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.5))
                        )
                }

                Spacer()

                Text(isEditing ? "Edit Schedule" : "Add Schedule")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    saveSchedule()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(selectedDays.isEmpty || timeSlots.isEmpty ? Color.gray.opacity(0.3) : appAccentColor)
                        )
                }
                .disabled(selectedDays.isEmpty || timeSlots.isEmpty)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)

            ScrollView {
                VStack(spacing: 24) {
                    // 1. Days
                    daysSection

                    // 2. Dosage
                    dosageSection

                    // 3. Times (Frequency)
                    timesSection

                    // 4. Start Date
                    startDateSection

                    // 5. End Date / Duration (combined)
                    endDateDurationSection

                    // Delete button (only for editing existing schedules)
                    if isEditing, let onDelete = onDelete {
                        Button {
                            onDelete()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Schedule")
                            }
                            .font(.appBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.medicalRed)
                            .cornerRadius(AppDimensions.buttonCornerRadius)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(AppDimensions.screenPadding)
            }
        }
        .background(Color.appBackgroundLight)
    }

    // MARK: - Days Section

    /// Days ordered Monday-first: [1, 2, 3, 4, 5, 6, 0]
    private let mondayFirstDays = [1, 2, 3, 4, 5, 6, 0]

    private var daysSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(mondayFirstDays, id: \.self) { day in
                    Button {
                        if selectedDays.contains(day) {
                            selectedDays.removeAll { $0 == day }
                        } else {
                            selectedDays.append(day)
                        }
                    } label: {
                        Text(Calendar.shortDaysOfWeek[day])
                            .font(.appCaptionSmall)
                            .foregroundColor(selectedDays.contains(day) ? .black : .textPrimary)
                            .frame(width: 40, height: 40)
                            .background(selectedDays.contains(day) ? appAccentColor : Color.cardBackground)
                            .cornerRadius(20)
                    }
                }
            }

            HStack(spacing: 24) {
                Button("Every Day") {
                    selectedDays = [0, 1, 2, 3, 4, 5, 6]
                }
                .font(.appCaption)
                .foregroundColor(appAccentColor)

                Button("Weekdays") {
                    selectedDays = [1, 2, 3, 4, 5]
                }
                .font(.appCaption)
                .foregroundColor(appAccentColor)

                Button("Weekends") {
                    selectedDays = [0, 6]
                }
                .font(.appCaption)
                .foregroundColor(appAccentColor)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Dosage Section

    private var dosageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DOSAGE")
                .font(.appCaption)
                .foregroundColor(appAccentColor)

            AppTextField(placeholder: "e.g., 2 tablets, 10ml", text: $dosage)
        }
    }

    // MARK: - Times Section (Inline)

    private var timesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TIMES")
                    .font(.appCaption)
                    .foregroundColor(appAccentColor)

                Spacer()

                // Add time button
                Button {
                    let lastTime = timeSlots.last ?? Date()
                    let nextTime = Calendar.current.date(byAdding: .hour, value: 1, to: lastTime) ?? Date()
                    timeSlots.append(nextTime)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Add")
                            .font(.appCaption)
                    }
                    .foregroundColor(appAccentColor)
                }
            }

            // Inline time slots
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                ForEach(timeSlots.indices, id: \.self) { index in
                    HStack(spacing: 4) {
                        DatePicker(
                            "",
                            selection: $timeSlots[index],
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(appAccentColor)

                        if timeSlots.count > 1 {
                            Button {
                                timeSlots.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.medicalRed)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Start Date Section

    private var startDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("START DATE")
                .font(.appCaption)
                .foregroundColor(appAccentColor)

            DatePicker(
                "Start Date",
                selection: $internalStartDate,
                displayedComponents: .date
            )
            .font(.appBody)
            .foregroundColor(.textPrimary)
            .tint(appAccentColor)
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                    .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Combined End Date / Duration Section

    private var endDateDurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("END DATE")
                .font(.appCaption)
                .foregroundColor(appAccentColor)

            VStack(alignment: .leading, spacing: 12) {
                // Duration toggle — first row
                Toggle(isOn: $useDuration) {
                    Text("Use Duration")
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                }
                .tint(appAccentColor)

                if useDuration {
                    // Duration details
                    HStack {
                        Text("Take for")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        Stepper("\(durationValue)", value: $durationValue, in: 1...maxDurationValue)
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                            .fixedSize()

                        Picker("", selection: $durationUnit) {
                            ForEach(DurationUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(appAccentColor)
                    }

                    // Computed end date preview
                    Text(durationExplanationText)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                } else {
                    // End date picker
                    Toggle(isOn: $showEndDate) {
                        Text("Set End Date")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                    }
                    .tint(appAccentColor)

                    if showEndDate {
                        DatePicker(
                            "End Date",
                            selection: $internalEndDate,
                            in: internalStartDate...,
                            displayedComponents: .date
                        )
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                        .tint(appAccentColor)
                    }
                }
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                    .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private var maxDurationValue: Int {
        switch durationUnit {
        case .days: return 365
        case .weeks: return 52
        case .months: return 12
        }
    }

    private var computedEndDate: Date? {
        let calendar = Calendar.current
        switch durationUnit {
        case .days:
            return calendar.date(byAdding: .day, value: durationValue, to: internalStartDate)
        case .weeks:
            return calendar.date(byAdding: .day, value: durationValue * 7, to: internalStartDate)
        case .months:
            return calendar.date(byAdding: .month, value: durationValue, to: internalStartDate)
        }
    }

    private var durationExplanationText: String {
        let unitName = durationValue == 1 ? durationUnit.singularName : durationUnit.displayName.lowercased()
        if let end = computedEndDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Ending \(formatter.string(from: end))"
        }
        return "Schedule will be active for \(durationValue) \(unitName)."
    }

    // MARK: - Save

    private func saveSchedule() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let sortedDays = selectedDays.sorted()
        let dosageValue = dosage.isBlank ? nil : dosage

        // Build schedule entries from time slots
        let newEntries = timeSlots.enumerated().map { index, time in
            ScheduleEntry(
                time: formatter.string(from: time),
                dosage: dosageValue,
                daysOfWeek: sortedDays,
                durationValue: nil,
                durationUnit: .days,
                sortOrder: index
            )
        }

        scheduleData.entries = newEntries
        scheduleData.startDate = internalStartDate

        if useDuration {
            scheduleData.hasEndDate = true
            scheduleData.endDate = computedEndDate
        } else if showEndDate {
            scheduleData.hasEndDate = true
            scheduleData.endDate = internalEndDate
        } else {
            scheduleData.hasEndDate = false
            scheduleData.endDate = nil
        }

        onSave()
        dismiss()
    }
}

// MARK: - Schedule Summary Card

struct ScheduleSummaryCard: View {
    let scheduleData: ScheduleData
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    // Days
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(appAccentColor)
                            .font(.system(size: 12))
                        Text(daysText)
                            .font(.appCaption)
                            .foregroundColor(.textPrimary)
                    }

                    // Dosage
                    if let dosage = scheduleData.entries.first?.dosage, !dosage.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "pills")
                                .foregroundColor(appAccentColor)
                                .font(.system(size: 12))
                            Text(dosage)
                                .font(.appCaption)
                                .foregroundColor(.textPrimary)
                        }
                    }

                    // Times
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundColor(appAccentColor)
                            .font(.system(size: 12))
                        Text(timesText)
                            .font(.appCaption)
                            .foregroundColor(.textPrimary)
                    }

                    // Date range
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(appAccentColor)
                            .font(.system(size: 12))
                        Text(dateRangeText)
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.textMuted)
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                    .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var daysText: String {
        guard let days = scheduleData.entries.first?.daysOfWeek else { return "Every day" }
        let sorted = days.sorted()
        if sorted.count == 7 { return "Every day" }
        if sorted == [1, 2, 3, 4, 5] { return "Weekdays" }
        if sorted == [0, 6] { return "Weekends" }
        return sorted.compactMap { $0 < Calendar.daysOfWeek.count ? Calendar.daysOfWeek[$0] : nil }.joined(separator: ", ")
    }

    private var timesText: String {
        let times = scheduleData.entries.map { $0.time }
        if times.isEmpty { return "No times set" }
        if times.count == 1 { return times[0] }
        return "\(times.count)x daily (\(times.joined(separator: ", ")))"
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let start = formatter.string(from: scheduleData.startDate)

        if scheduleData.hasEndDate, let end = scheduleData.endDate {
            return "\(start) – \(formatter.string(from: end))"
        }
        return "From \(start), ongoing"
    }
}

// MARK: - Calendar Extension (Short Day Names)
extension Calendar {
    /// Single letter day abbreviations for compact display
    static let shortDaysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
}

// MARK: - Preview
#Preview {
    MedicationScheduleModal(
        scheduleData: .constant(ScheduleData()),
        isEditing: false,
        onSave: {}
    )
}
