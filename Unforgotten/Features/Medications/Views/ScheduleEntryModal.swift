import SwiftUI

// MARK: - Schedule Entry Modal
struct ScheduleEntryModal: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    @Binding var entry: ScheduleEntry
    let isEditing: Bool
    let onSave: (ScheduleEntry) -> Void
    let onDelete: (() -> Void)?

    @State private var selectedTime: Date
    @State private var dosage: String
    @State private var selectedDays: [Int]
    @State private var hasDuration: Bool
    @State private var durationValue: Int
    @State private var durationUnit: DurationUnit

    init(
        entry: Binding<ScheduleEntry>,
        isEditing: Bool = false,
        onSave: @escaping (ScheduleEntry) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self._entry = entry
        self.isEditing = isEditing
        self.onSave = onSave
        self.onDelete = onDelete

        // Parse time string to Date
        let timeComponents = entry.wrappedValue.time.split(separator: ":").compactMap { Int($0) }
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = timeComponents.first ?? 8
        dateComponents.minute = timeComponents.count > 1 ? timeComponents[1] : 0
        let initialTime = Calendar.current.date(from: dateComponents) ?? Date()

        _selectedTime = State(initialValue: initialTime)
        _dosage = State(initialValue: entry.wrappedValue.dosage ?? "")
        _selectedDays = State(initialValue: entry.wrappedValue.daysOfWeek)
        _hasDuration = State(initialValue: entry.wrappedValue.durationValue != nil)
        _durationValue = State(initialValue: entry.wrappedValue.durationValue ?? 7)
        _durationUnit = State(initialValue: entry.wrappedValue.durationUnit)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Time picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TIME")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                                .background(Color.cardBackgroundSoft)
                                .cornerRadius(AppDimensions.buttonCornerRadius)
                        }

                        // Dosage
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DOSAGE")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            AppTextField(placeholder: "e.g., 2 tablets, 10ml", text: $dosage)
                        }

                        // Days
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DAYS")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            HStack(spacing: 8) {
                                ForEach(0..<7) { day in
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
                                            .background(selectedDays.contains(day) ? appAccentColor : Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }

                            // Quick select buttons
                            HStack(spacing: 12) {
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

                        // Duration
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DURATION")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            Toggle("Limit duration", isOn: $hasDuration)
                                .tint(appAccentColor)
                                .padding()
                                .background(Color.cardBackgroundSoft)
                                .cornerRadius(AppDimensions.buttonCornerRadius)

                            if hasDuration {
                                // Duration value stepper
                                HStack {
                                    Text("Take for")
                                        .font(.appBody)
                                        .foregroundColor(.textPrimary)

                                    Spacer()

                                    Stepper("\(durationValue)", value: $durationValue, in: 1...maxDurationValue)
                                        .font(.appBody)
                                        .foregroundColor(.textPrimary)
                                }
                                .padding()
                                .background(Color.cardBackgroundSoft)
                                .cornerRadius(AppDimensions.buttonCornerRadius)

                                // Duration unit picker (segmented)
                                Picker("Duration Unit", selection: $durationUnit) {
                                    ForEach(DurationUnit.allCases, id: \.self) { unit in
                                        Text(unit.displayName).tag(unit)
                                    }
                                }
                                .pickerStyle(.segmented)

                                // Explanation text
                                Text(durationExplanationText)
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                            }
                        }

                        // Delete button (only for editing)
                        if isEditing, let onDelete = onDelete {
                            Button {
                                onDelete()
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Schedule Entry")
                                }
                                .font(.appBodyMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.medicalRed)
                                .cornerRadius(AppDimensions.buttonCornerRadius)
                            }
                            .padding(.top, 16)
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .navigationTitle(isEditing ? "Edit Schedule" : "Add Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .foregroundColor(appAccentColor)
                    .disabled(selectedDays.isEmpty)
                }
            }
        }
    }

    private func saveEntry() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: selectedTime)

        var updatedEntry = entry
        updatedEntry.time = timeString
        updatedEntry.dosage = dosage.isBlank ? nil : dosage
        updatedEntry.daysOfWeek = selectedDays.sorted()
        updatedEntry.durationValue = hasDuration ? durationValue : nil
        updatedEntry.durationUnit = durationUnit

        onSave(updatedEntry)
        dismiss()
    }

    /// Maximum value allowed based on selected unit
    private var maxDurationValue: Int {
        switch durationUnit {
        case .days: return 365
        case .weeks: return 52
        case .months: return 12
        }
    }

    /// Generate explanation text based on selected days and duration
    private var durationExplanationText: String {
        let unitName = durationValue == 1 ? durationUnit.singularName : durationUnit.displayName.lowercased()

        if selectedDays.count == 7 {
            return "This schedule will be active for \(durationValue) \(unitName) from the start date."
        } else if selectedDays.isEmpty {
            return "Please select at least one day."
        } else {
            let dayNames = selectedDays.sorted().map { Calendar.fullDaysOfWeek[$0] }
            let daysDescription: String
            if dayNames.count == 1 {
                daysDescription = dayNames[0] + "s"
            } else if dayNames.count == 2 {
                daysDescription = dayNames.joined(separator: " and ")
            } else {
                daysDescription = dayNames.dropLast().joined(separator: ", ") + ", and " + (dayNames.last ?? "")
            }

            return "This schedule will be active on \(daysDescription) for \(durationValue) \(unitName)."
        }
    }
}

// MARK: - Schedule Entries List View
struct ScheduleEntriesListView: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var entries: [ScheduleEntry]

    @State private var showAddModal = false
    @State private var editingEntry: ScheduleEntry?
    @State private var newEntry = ScheduleEntry(time: "08:00")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SCHEDULE")
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            // Existing entries
            ForEach(entries.indices, id: \.self) { index in
                ScheduleEntryRow(entry: entries[index]) {
                    editingEntry = entries[index]
                }
            }

            // Add button
            Button {
                newEntry = ScheduleEntry(
                    time: "08:00",
                    sortOrder: entries.count
                )
                showAddModal = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Schedule")
                }
                .font(.appCaption)
                .foregroundColor(appAccentColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.buttonCornerRadius)
            }
        }
        .sheet(isPresented: $showAddModal) {
            ScheduleEntryModal(
                entry: $newEntry,
                isEditing: false,
                onSave: { entry in
                    var newEntry = entry
                    newEntry.sortOrder = entries.count
                    entries.append(newEntry)
                }
            )
        }
        .sheet(item: $editingEntry) { entry in
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                ScheduleEntryModal(
                    entry: $entries[index],
                    isEditing: true,
                    onSave: { updatedEntry in
                        entries[index] = updatedEntry
                    },
                    onDelete: {
                        entries.remove(at: index)
                    }
                )
            }
        }
    }
}

// MARK: - Schedule Entry Row
struct ScheduleEntryRow: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let entry: ScheduleEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Time with clock icon
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(appAccentColor)
                        .font(.system(size: 12))
                    Text(entry.time)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                }

                // Dosage (if present)
                if let dosage = entry.dosage {
                    Text("•")
                        .foregroundColor(.textMuted)
                    Text(dosage)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                // Days
                Text("•")
                    .foregroundColor(.textMuted)
                Text(daysText)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                // Duration (if present)
                if let duration = durationText {
                    Text("•")
                        .foregroundColor(.textMuted)
                    Text(duration)
                        .font(.appCaption)
                        .foregroundColor(appAccentColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }
            .padding()
            .background(Color.cardBackgroundSoft)
            .cornerRadius(AppDimensions.buttonCornerRadius)
        }
    }

    private var durationText: String? {
        guard let value = entry.durationValue else { return nil }
        let unit = entry.durationUnit
        let unitName = value == 1 ? unit.singularName : unit.displayName.lowercased()
        return "\(value) \(unitName)"
    }

    private var daysText: String {
        let days = entry.daysOfWeek
        if days.count == 7 {
            return "Daily"
        } else if days == [1, 2, 3, 4, 5] {
            return "Weekdays"
        } else if days == [0, 6] {
            return "Weekends"
        } else {
            return days.map { Calendar.shortDaysOfWeek[$0] }.joined(separator: ", ")
        }
    }
}

// MARK: - Calendar Extension (Short Day Names)
extension Calendar {
    /// Single letter day abbreviations for compact display
    static let shortDaysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
}

// MARK: - Preview
#Preview {
    ScheduleEntryModal(
        entry: .constant(ScheduleEntry(time: "08:00")),
        isEditing: false,
        onSave: { _ in }
    )
}
