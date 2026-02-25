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
    @State private var triggerTime: Date = Date()
    @State private var intervalValue: Int = 1
    @State private var intervalUnit: StickyReminderTimeUnit = .hours
    @State private var startImmediately: Bool = true

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
                    // Form content
                    VStack(spacing: 24) {
                        // Title field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        TextField("What do you need to remember?", text: $title)
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                            .padding()
                            .frame(height: AppDimensions.textFieldHeight)
                            .background(Color.cardBackgroundSoft)
                            .cornerRadius(AppDimensions.buttonCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                                    .stroke(focusedField == .title ? appAccentColor : Color.textSecondary.opacity(0.6), lineWidth: 1)
                            )
                            .focused($focusedField, equals: .title)
                    }

                    // Message field (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Message")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            Text("(optional)")
                                .font(.appCaption)
                                .foregroundColor(.textMuted)
                        }

                        TextField("Add more details...", text: $message, axis: .vertical)
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                            .lineLimit(3...6)
                            .padding()
                            .background(Color.cardBackgroundSoft)
                            .cornerRadius(AppDimensions.buttonCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                                    .stroke(focusedField == .message ? appAccentColor : Color.textSecondary.opacity(0.3), lineWidth: 1)
                            )
                            .focused($focusedField, equals: .message)
                    }

                    // Start time toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text("When to Start")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        Toggle(isOn: $startImmediately) {
                            HStack(spacing: 12) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(appAccentColor)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Start Immediately")
                                        .font(.appBodyMedium)
                                        .foregroundColor(.textPrimary)

                                    Text("Begin reminding right away")
                                        .font(.appCaption)
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }
                        .tint(appAccentColor)
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.buttonCornerRadius)

                        if !startImmediately {
                            VStack {
                                Text("Start Time")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                DatePicker(
                                    "",
                                    selection: $triggerTime,
                                    in: Date()...,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.wheel)
                                .tint(appAccentColor)

                            }
                            .padding()
                            .background(Color.cardBackgroundSoft)
                            .cornerRadius(AppDimensions.buttonCornerRadius)
                        }
                    }

                    // Repeat interval
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How Often to Remind")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        // Dynamic interval picker
                        VStack(spacing: 16) {
                            // Number + Unit picker row
                            HStack(spacing: 12) {
                                Text("Every")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                // Number picker
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
                                            .foregroundColor(.textPrimary)

                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.textSecondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.cardBackground)
                                    .cornerRadius(8)
                                }

                                // Unit picker
                                Menu {
                                    ForEach(StickyReminderTimeUnit.allCases) { unit in
                                        Button {
                                            intervalUnit = unit
                                            // Clamp value to valid range for new unit
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
                                            .foregroundColor(.textPrimary)

                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.textSecondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.cardBackground)
                                    .cornerRadius(8)
                                }

                                Spacer()

                                // Quick options button
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
                        }
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.buttonCornerRadius)
                    }

                    // Info card
                    infoCard

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                            .multilineTextAlignment(.center)
                    }

                        // Bottom spacing
                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, 24)
                }
            }
            .background(Color.appBackground)
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
                    triggerTime = reminder.triggerTime
                    intervalValue = reminder.repeatInterval.value
                    intervalUnit = reminder.repeatInterval.unit
                    startImmediately = reminder.triggerTime <= Date()
                } else {
                    // Focus title field for new reminders
                    focusedField = .title
                }
            }
        }
        .padding(.top, 8)
        .background(Color.appBackground)
    }

    // MARK: - Info Card
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(appAccentColor)

                Text("How Sticky Reminders Work")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "bell.badge", text: "You'll receive notifications at your chosen frequency")
                infoRow(icon: "repeat", text: "Reminders repeat until you dismiss them in the app")
                infoRow(icon: "hand.tap", text: "Open the app and tap 'Dismiss' to stop notifications")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(appAccentColor.opacity(0.15))
        .cornerRadius(AppDimensions.buttonCornerRadius)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
                .frame(width: 18)

            Text(text)
                .font(.appCaption)
                .foregroundColor(.textSecondary)
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

        let finalTriggerTime = startImmediately ? Date() : triggerTime

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
