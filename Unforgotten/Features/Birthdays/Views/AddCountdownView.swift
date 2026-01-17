import SwiftUI

// MARK: - Add Countdown View
struct AddCountdownView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    var onDismiss: (() -> Void)? = nil
    let onSave: (Countdown) -> Void

    @State private var title = ""
    @State private var date = Date()
    @State private var selectedType: CountdownType = .countdown
    @State private var customTypeName = ""
    @State private var notes = ""
    @State private var reminderMinutes: Int? = 1440  // Default: 1 day before
    @State private var isRecurring = false

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let reminderOptions: [(Int?, String)] = [
        (nil, "No reminder"),
        (0, "On the day"),
        (1440, "1 day before"),
        (2880, "2 days before"),
        (10080, "1 week before"),
        (20160, "2 weeks before")
    ]

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header with icons
                HStack {
                    Button {
                        dismissView()
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

                    Text("Add Countdown")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        Task { await saveCountdown() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(title.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                            )
                    }
                    .disabled(title.isBlank || isLoading)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        AppTextField(placeholder: "Title *", text: $title)

                        // Type selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            CountdownTypePicker(selectedType: $selectedType)
                        }

                        // Custom type name (shown only when "Custom" is selected)
                        if selectedType == .custom {
                            AppTextField(placeholder: "Custom type name", text: $customTypeName)
                        }

                        // Date picker row
                        HStack {
                            Text("Date")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)

                            Spacer()

                            DatePicker(
                                "",
                                selection: $date,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .tint(appAccentColor)
                            .labelsHidden()
                        }
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)

                        // Recurring toggle
                        HStack {
                            Toggle("Repeats every year", isOn: $isRecurring)
                                .tint(appAccentColor)
                        }
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)

                        // Reminder picker row
                        HStack {
                            Text("Reminder")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)

                            Spacer()

                            Picker("Reminder", selection: $reminderMinutes) {
                                ForEach(reminderOptions, id: \.0) { option in
                                    Text(option.1).tag(option.0)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(appAccentColor)
                        }
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)

                        AppTextField(placeholder: "Notes (optional)", text: $notes)

                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackgroundLight)
            .navigationBarHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollContentBackground(.hidden)
        .background(Color.appBackgroundLight)
        .toolbarBackground(.hidden, for: .navigationBar)
        .presentationDetents([.fraction(0.9)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    private func saveCountdown() async {
        guard let account = appState.currentAccount else {
            errorMessage = "No account found"
            return
        }

        isLoading = true
        errorMessage = nil

        let insert = CountdownInsert(
            accountId: account.id,
            title: title,
            date: date,
            type: selectedType,
            customType: selectedType == .custom ? customTypeName : nil,
            notes: notes.isBlank ? nil : notes,
            reminderOffsetMinutes: reminderMinutes,
            isRecurring: isRecurring
        )

        do {
            let countdown = try await appState.countdownRepository.createCountdown(insert)

            // Schedule notification reminder if reminder is set
            if let reminderMinutes = reminderMinutes {
                await NotificationService.shared.scheduleCountdownReminder(
                    countdownId: countdown.id,
                    title: countdown.title,
                    countdownDate: countdown.date,
                    reminderMinutesBefore: reminderMinutes,
                    isRecurring: countdown.isRecurring
                )
            }

            onSave(countdown)
            dismissView()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Countdown Type Picker
struct CountdownTypePicker: View {
    @Binding var selectedType: CountdownType
    @Environment(\.appAccentColor) private var appAccentColor

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(CountdownType.allCases) { type in
                CountdownTypeBadge(
                    type: type,
                    isSelected: selectedType == type,
                    onTap: { selectedType = type }
                )
            }
        }
    }
}

// MARK: - Countdown Type Badge
struct CountdownTypeBadge: View {
    let type: CountdownType
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.caption)
                Text(type.displayName)
                    .font(.appCaption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? appAccentColor.opacity(0.3) : Color.cardBackgroundSoft)
            .foregroundColor(isSelected ? appAccentColor : .textSecondary)
            .cornerRadius(AppDimensions.pillCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.pillCornerRadius)
                    .stroke(isSelected ? appAccentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Edit Countdown View
struct EditCountdownView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let countdown: Countdown
    var onDismiss: (() -> Void)? = nil
    let onSave: (Countdown) -> Void

    @State private var title: String
    @State private var date: Date
    @State private var selectedType: CountdownType
    @State private var customTypeName: String
    @State private var notes: String
    @State private var reminderMinutes: Int?
    @State private var isRecurring: Bool

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let reminderOptions: [(Int?, String)] = [
        (nil, "No reminder"),
        (0, "On the day"),
        (1440, "1 day before"),
        (2880, "2 days before"),
        (10080, "1 week before"),
        (20160, "2 weeks before")
    ]

    init(countdown: Countdown, onDismiss: (() -> Void)? = nil, onSave: @escaping (Countdown) -> Void) {
        self.countdown = countdown
        self.onDismiss = onDismiss
        self.onSave = onSave
        self._title = State(initialValue: countdown.title)
        self._date = State(initialValue: countdown.date)
        self._selectedType = State(initialValue: countdown.type)
        self._customTypeName = State(initialValue: countdown.customType ?? "")
        self._notes = State(initialValue: countdown.notes ?? "")
        self._reminderMinutes = State(initialValue: countdown.reminderOffsetMinutes)
        self._isRecurring = State(initialValue: countdown.isRecurring)
    }

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header with icons
                HStack {
                    Button {
                        dismissView()
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

                    Text("Edit Countdown")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        Task { await updateCountdown() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(title.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                            )
                    }
                    .disabled(title.isBlank || isLoading)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        AppTextField(placeholder: "Title *", text: $title)

                        // Type selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            CountdownTypePicker(selectedType: $selectedType)
                        }

                        // Custom type name (shown only when "Custom" is selected)
                        if selectedType == .custom {
                            AppTextField(placeholder: "Custom type name", text: $customTypeName)
                        }

                        // Date picker row
                        HStack {
                            Text("Date")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)

                            Spacer()

                            DatePicker(
                                "",
                                selection: $date,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .tint(appAccentColor)
                            .labelsHidden()
                        }
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)

                        // Recurring toggle
                        HStack {
                            Toggle("Repeats every year", isOn: $isRecurring)
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .tint(appAccentColor)
                        }
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)

                        // Reminder picker row
                        HStack {
                            Text("Reminder")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)

                            Spacer()

                            Picker("Reminder", selection: $reminderMinutes) {
                                ForEach(reminderOptions, id: \.0) { option in
                                    Text(option.1).tag(option.0)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(appAccentColor)
                        }
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)

                        AppTextField(placeholder: "Notes", text: $notes)

                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackgroundLight)
            .navigationBarHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollContentBackground(.hidden)
        .background(Color.appBackgroundLight)
        .toolbarBackground(.hidden, for: .navigationBar)
        .presentationDetents([.fraction(0.9)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    private func updateCountdown() async {
        isLoading = true
        errorMessage = nil

        var updatedCountdown = countdown
        updatedCountdown.title = title
        updatedCountdown.date = date
        updatedCountdown.type = selectedType
        updatedCountdown.customType = selectedType == .custom ? customTypeName : nil
        updatedCountdown.notes = notes.isBlank ? nil : notes
        updatedCountdown.reminderOffsetMinutes = reminderMinutes
        updatedCountdown.isRecurring = isRecurring

        do {
            let saved = try await appState.countdownRepository.updateCountdown(updatedCountdown)

            // Update notification reminder
            await NotificationService.shared.cancelCountdownReminder(countdownId: countdown.id)
            if let reminderMinutes = reminderMinutes {
                await NotificationService.shared.scheduleCountdownReminder(
                    countdownId: saved.id,
                    title: saved.title,
                    countdownDate: saved.date,
                    reminderMinutesBefore: reminderMinutes,
                    isRecurring: saved.isRecurring
                )
            }

            onSave(saved)
            dismissView()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    AddCountdownView { _ in }
        .environmentObject(AppState())
}
