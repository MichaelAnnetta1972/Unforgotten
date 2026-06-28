import SwiftUI

// MARK: - Add Sticky Reminder View
struct AddStickyReminderView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.dismiss) private var dismiss

    // Edit mode
    var editingReminder: StickyReminder?
    var onSave: ((StickyReminder) -> Void)?
    var onDismiss: (() -> Void)?

    // Form state
    @State private var title: String = ""
    @State private var message: String = ""
    @State private var intervalValue: Int = 1
    @State private var intervalUnit: StickyReminderTimeUnit = .hours

    // Date & Time state
    @State private var startImmediately: Bool = false
    @State private var dateEnabled: Bool = false
    @State private var timeEnabled: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var selectedTime: Date = Date()

    // Picker expansion state
    @State private var showDatePicker: Bool = false
    @State private var showTimePicker: Bool = false

    // UI state
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case message
    }

    private var isEditing: Bool {
        editingReminder != nil
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var repeatInterval: StickyReminderInterval {
        StickyReminderInterval(value: intervalValue, unit: intervalUnit)
    }

    /// Combines the selected date and (optional) time into a single trigger Date.
    private var resolvedTriggerTime: Date {
        if startImmediately {
            return Date()
        }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)

        if timeEnabled {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
        } else {
            components.hour = 0
            components.minute = 0
        }

        return calendar.date(from: components) ?? selectedDate
    }

    /// Dismisses the view, calling onDismiss callback if provided
    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 28) {
                        titleNotesCard
                        dateTimeSection
                        repeatIntervalSection

                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                                .multilineTextAlignment(.center)
                        }

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, 24)
                }
            }
            .background(Color.appBackgroundLight)
            .navigationTitle(isEditing ? "Edit Reminder" : "New Sticky Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveReminder()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(!isValid || isSaving ? .textSecondary : appAccentColor)
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .onAppear {
                if let reminder = editingReminder {
                    title = reminder.title
                    message = reminder.message ?? ""
                    intervalValue = reminder.repeatInterval.value
                    intervalUnit = reminder.repeatInterval.unit

                    // Seed the Date & Time fields from the reminder's next
                    // notification time rather than its (possibly historical)
                    // original trigger time — there's no need to edit a date in
                    // the past. Falls back to triggerTime if no next time exists.
                    let seedTime = reminder.nextNotificationTime ?? reminder.triggerTime
                    startImmediately = false
                    dateEnabled = true
                    selectedDate = seedTime
                    selectedTime = seedTime
                    showDatePicker = false

                    // Treat a non-midnight time as an explicitly chosen time
                    let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: seedTime)
                    timeEnabled = (timeComponents.hour ?? 0) != 0 || (timeComponents.minute ?? 0) != 0
                    showTimePicker = false
                } else {
                    focusedField = .title
                }
            }
        }
        .padding(.top, 8)
        .background(Color.appBackground)
        .clipShape(RoundedCorner(radius: 36, corners: [.topLeft, .topRight]))
    }

    // MARK: - Title & Notes Card
    private var titleNotesCard: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $title)
                .font(.appBody)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, AppDimensions.cardPadding)
                .frame(height: AppDimensions.textFieldHeight)
                .focused($focusedField, equals: .title)

            Divider()
                .overlay(Color.textSecondary.opacity(0.3))
                .padding(.horizontal, AppDimensions.cardPadding)

            TextField("Notes", text: $message, axis: .vertical)
                .font(.appBody)
                .foregroundColor(.textPrimary)
                .lineLimit(3...6)
                .padding(AppDimensions.cardPadding)
                .focused($focusedField, equals: .message)
        }
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Date & Time Section
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date & Time")
                .font(.appBody)
                .foregroundColor(.textSecondary)

            VStack(spacing: 0) {
                // Start Now
                Toggle(isOn: $startImmediately.animation()) {
                    HStack(spacing: 12) {
                        Image(systemName: "alarm")
                            .font(.system(size: 20))
                            .foregroundColor(.textSecondary)
                            .frame(width: 26)

                        Text("Start Now")
                            .font(.appBodyMedium)
                            .foregroundColor(.textPrimary)
                    }
                }
                .tint(appAccentColor)
                .padding(.horizontal, AppDimensions.cardPadding)
                .padding(.vertical, 14)

                if !startImmediately {
                    rowDivider

                    // Date
                    dateRow

                    if dateEnabled && showDatePicker {
                        datePickerView
                    }

                    rowDivider

                    // Add Time
                    timeRow

                    if timeEnabled && showTimePicker {
                        timePickerView
                    }
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(Color.textSecondary.opacity(0.3))
            .padding(.horizontal, AppDimensions.cardPadding)
    }

    // MARK: - Date Row
    private var dateRow: some View {
        Toggle(isOn: dateToggleBinding) {
            Button {
                guard dateEnabled else { return }
                withAnimation { showDatePicker.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 20))
                        .foregroundColor(.textSecondary)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Date")
                            .font(.appBodyMedium)
                            .foregroundColor(.textPrimary)

                        if dateEnabled {
                            Text(selectedDate.formatted(.dateTime.day().month(.wide).year()))
                                .font(.appCaption)
                                .foregroundColor(appAccentColor)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .tint(appAccentColor)
        .padding(.horizontal, AppDimensions.cardPadding)
        .padding(.vertical, 12)
    }

    private var dateToggleBinding: Binding<Bool> {
        Binding(
            get: { dateEnabled },
            set: { newValue in
                withAnimation {
                    dateEnabled = newValue
                    showDatePicker = newValue
                    if !newValue {
                        // Time depends on a date, so disable it alongside
                        timeEnabled = false
                        showTimePicker = false
                    }
                }
            }
        )
    }

    /// Lower bound for the date picker. Defaults to today, but allows an
    /// existing reminder's original (possibly past) date when editing.
    private var datePickerLowerBound: Date {
        let today = Calendar.current.startOfDay(for: Date())
        return min(today, Calendar.current.startOfDay(for: selectedDate))
    }

    private var datePickerView: some View {
        DatePicker(
            "",
            selection: $selectedDate,
            in: datePickerLowerBound...,
            displayedComponents: [.date]
        )
        .datePickerStyle(.graphical)
        .tint(appAccentColor)
        .padding(.horizontal, AppDimensions.cardPadding)
        .padding(.bottom, AppDimensions.cardPadding)
    }

    // MARK: - Time Row
    private var timeRow: some View {
        Toggle(isOn: timeToggleBinding) {
            Button {
                guard timeEnabled else { return }
                withAnimation { showTimePicker.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 20))
                        .foregroundColor(.textSecondary)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Time")
                            .font(.appBodyMedium)
                            .foregroundColor(.textPrimary)

                        if timeEnabled {
                            Text(selectedTime.formatted(date: .omitted, time: .shortened))
                                .font(.appCaption)
                                .foregroundColor(appAccentColor)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .tint(appAccentColor)
        .disabled(!dateEnabled)
        .padding(.horizontal, AppDimensions.cardPadding)
        .padding(.vertical, 12)
    }

    private var timeToggleBinding: Binding<Bool> {
        Binding(
            get: { timeEnabled },
            set: { newValue in
                withAnimation {
                    timeEnabled = newValue
                    showTimePicker = newValue
                }
            }
        )
    }

    private var timePickerView: some View {
        DatePicker(
            "",
            selection: $selectedTime,
            displayedComponents: [.hourAndMinute]
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .tint(appAccentColor)
        .frame(maxWidth: .infinity)
        .padding(.bottom, AppDimensions.cardPadding)
    }

    // MARK: - Repeat Interval Section
    private var repeatIntervalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Text("Repeat Frequency")
            //     .font(.appBody)
            //     .foregroundColor(.textSecondary)

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Text("Repeat Every")
                        .font(.appBody)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    numberPickerMenu
                    unitPickerMenu

                    //Spacer()

                    //quickPresetsMenu
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }

    private var numberPickerMenu: some View {
        Menu {
            ForEach(Array(intervalUnit.validRange), id: \.self) { num in
                Button {
                    intervalValue = num
                } label: {
                    if num == intervalValue {
                        Label("\(num)", systemImage: "checkmark")
                    } else {
                        Text("\(num)")
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text("\(intervalValue)")
                    .font(.appBodyMedium)
                    .foregroundColor(appAccentColor)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(appAccentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.cardBackground)
            .cornerRadius(8)
        }
    }

    private var unitPickerMenu: some View {
        Menu {
            ForEach(StickyReminderTimeUnit.allCases) { unit in
                Button {
                    intervalUnit = unit
                    if !unit.validRange.contains(intervalValue) {
                        intervalValue = unit.validRange.lowerBound
                    }
                } label: {
                    if unit == intervalUnit {
                        Label(unit.displayName, systemImage: "checkmark")
                    } else {
                        Text(unit.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(intervalValue == 1 ? intervalUnit.singularName : intervalUnit.displayName)
                    .font(.appBodyMedium)
                    .foregroundColor(appAccentColor)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(appAccentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.cardBackground)
            .cornerRadius(8)
        }
    }

    private var quickPresetsMenu: some View {
        Menu {
            ForEach(StickyReminderInterval.presets, id: \.displayName) { preset in
                Button {
                    intervalValue = preset.value
                    intervalUnit = preset.unit
                } label: {
                    if repeatInterval == preset {
                        Label(preset.displayName, systemImage: "checkmark")
                    } else {
                        Label(preset.displayName, systemImage: preset.unit.icon)
                    }
                }
            }
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 20))
                .foregroundColor(appAccentColor)
                .frame(width: 44, height: 44)
                .background(Color.cardBackground)
                .cornerRadius(8)
        }
    }

    // MARK: - Save Reminder
    private func saveReminder() {
        guard isValid else { return }
        guard let account = appState.currentAccount else {
            errorMessage = "No account found"
            return
        }

        isSaving = true
        errorMessage = nil

        let finalTriggerTime = resolvedTriggerTime

        Task {
            do {
                let savedReminder: StickyReminder

                if let existing = editingReminder {
                    // Update existing
                    var updated = existing
                    updated.title = title.trimmingCharacters(in: .whitespaces)
                    updated.message = message.isEmpty ? nil : message
                    updated.triggerTime = finalTriggerTime
                    updated.repeatInterval = repeatInterval

                    savedReminder = try await appState.stickyReminderRepository.updateReminder(updated)
                } else {
                    // Create new
                    let insert = StickyReminderInsert(
                        accountId: account.id,
                        title: title.trimmingCharacters(in: .whitespaces),
                        message: message.isEmpty ? nil : message,
                        triggerTime: finalTriggerTime,
                        repeatInterval: repeatInterval
                    )

                    savedReminder = try await appState.stickyReminderRepository.createReminder(insert)
                }

                // Schedule notification
                await NotificationService.shared.scheduleStickyReminder(reminder: savedReminder)

                await MainActor.run {
                    onSave?(savedReminder)
                    dismissView()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save reminder: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}


// MARK: - Preview
#Preview {
    AddStickyReminderView()
        .environmentObject(AppState.forPreview())
}

#Preview("Edit Mode") {
    AddStickyReminderView(
        editingReminder: StickyReminder(
            accountId: UUID(),
            title: "Take vitamins",
            message: "Don't forget your morning vitamins",
            triggerTime: Date(),
            repeatInterval: StickyReminderInterval(value: 2, unit: .hours)
        )
    )
    .environmentObject(AppState.forPreview())
}
