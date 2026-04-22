import SwiftUI

// MARK: - Add Countdown View
struct AddCountdownView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    var onDismiss: (() -> Void)? = nil
    let onSave: (Countdown) -> Void

    @State private var title = ""
    @State private var subtitle = ""
    @State private var date = Date()
    @State private var endDate = Date()
    @State private var isMultiDay = false
    @State private var hasTime = false
    @State private var selectedType: CountdownType = .countdown
    @State private var customTypeName = ""
    @State private var notes = ""
    @State private var reminderMinutes: Int? = 1440  // Default: 1 day before
    @State private var isRecurring = false
    @State private var recurrenceUnit: RecurrenceUnit = .year
    @State private var recurrenceInterval: Int = 1
    @State private var hasRecurrenceEndDate = false
    @State private var recurrenceEndDate = Date()
    @State private var selectedImage: UIImage?

    @State private var isLoading = false
    @State private var errorMessage: String?

    // Date picker modal state
    @State private var showDatePicker = false
    @State private var showEndDatePicker = false
    @State private var showRecurrenceEndDatePicker = false

    // Family sharing state
    @State private var shareToFamily = false
    @State private var selectedMemberIds: Set<UUID> = []
    @State private var showFamilySharingSheet = false

    // Check if user has Family Plus access
    private var hasFamilyAccess: Bool {
        appState.hasFamilyAccess
    }

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

                Text("Add an Event")
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

                    AppTextField(placeholder: "Subtitle (optional)", text: $subtitle)

                    // Family sharing section
                    familySharingSection

                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                    }

                    // Type picker row
                    HStack {
                        Text("Type")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        Picker("Type", selection: $selectedType) {
                            ForEach(CountdownType.allCases) { type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(type)
                                    .font(.appBody)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(appAccentColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    // Custom type name (shown only when "Custom" is selected)
                    if selectedType == .custom {
                        AppTextField(placeholder: "Custom type name", text: $customTypeName)
                    }

                    // Date & Time section
                    VStack(spacing: 0) {
                        // From date row
                        Button {
                            showDatePicker = true
                        } label: {
                            HStack {
                                Text(isMultiDay ? "Date From" : "Date")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                Text(hasTime ? date.formatted(date: .abbreviated, time: .shortened) : date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding()

                        // End date row (shown when multi-day is on)
                        if isMultiDay {
                            Divider()
                                .padding(.horizontal, 16)

                            Button {
                                showEndDatePicker = true
                            } label: {
                                HStack {
                                    Text("Date To")
                                        .font(.appBody)
                                        .foregroundColor(.textPrimary)

                                    Spacer()

                                    Text(hasTime ? endDate.formatted(date: .abbreviated, time: .shortened) : endDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.appBody)
                                        .foregroundColor(.textSecondary)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.textSecondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding()
                        }

                        // Multi-day toggle
                        Divider()
                            .padding(.horizontal, 16)

                        HStack {
                            Toggle("Multi-day event", isOn: $isMultiDay.animation())
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .tint(appAccentColor)
                        }
                        .padding()

                        // Time toggle
                        Divider()
                            .padding(.horizontal, 16)

                        HStack {
                            Toggle("Add time", isOn: $hasTime.animation())
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .tint(appAccentColor)
                        }
                        .padding()
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    // Recurring section
                    VStack(spacing: 0) {
                        HStack {
                            Toggle("Repeats", isOn: $isRecurring.animation())
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .tint(appAccentColor)
                        }
                        .padding()

                        if isRecurring {
                            Divider()
                                .padding(.horizontal, 16)

                            HStack {
                                Text("Every")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                Picker("Interval", selection: $recurrenceInterval) {
                                    ForEach(1...30, id: \.self) { num in
                                        Text("\(num)").tag(num)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(appAccentColor)

                                Picker("Unit", selection: $recurrenceUnit) {
                                    ForEach(RecurrenceUnit.allCases) { unit in
                                        Text(recurrenceInterval == 1 ? unit.displayName : unit.pluralName).tag(unit)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(appAccentColor)
                            }
                            .padding()

                            Divider()
                                .padding(.horizontal, 16)

                            HStack {
                                Toggle("End Date", isOn: $hasRecurrenceEndDate.animation())
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                    .tint(appAccentColor)
                            }
                            .padding()

                            if hasRecurrenceEndDate {
                                Divider()
                                    .padding(.horizontal, 16)

                                HStack {
                                    Text("Ends On")
                                        .font(.appBody)
                                        .foregroundColor(.textPrimary)

                                    Spacer()

                                    Button {
                                        showRecurrenceEndDatePicker = true
                                    } label: {
                                        Text(recurrenceEndDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.appBody)
                                            .foregroundColor(appAccentColor)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

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
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    AppTextField(placeholder: "Notes (optional)", text: $notes)


                    // Photo picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photo")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        ImageSourcePicker(
                            selectedImage: $selectedImage,
                            onImageSelected: { _ in }
                        )
                    }

                    Spacer(minLength: 0)
                }
                .padding(AppDimensions.screenPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackgroundLight)
        .onChange(of: date) { _, newDate in
            if endDate < newDate {
                endDate = newDate
            }
        }
        .sheet(isPresented: $showFamilySharingSheet) {
            FamilySharingSheet(
                isEnabled: $shareToFamily,
                selectedMemberIds: $selectedMemberIds,
                onDismiss: { showFamilySharingSheet = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
        .sheet(isPresented: $showDatePicker) {
            CountdownDatePickerSheet(
                title: isMultiDay ? "Date From" : "Date",
                selection: $date,
                hasTime: hasTime
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
        .sheet(isPresented: $showEndDatePicker) {
            CountdownDatePickerSheet(
                title: "Date To",
                selection: $endDate,
                minimumDate: date,
                hasTime: hasTime
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
        .sheet(isPresented: $showRecurrenceEndDatePicker) {
            CountdownDatePickerSheet(
                title: "Repeat End Date",
                selection: $recurrenceEndDate,
                minimumDate: date,
                hasTime: false
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
    }

    // MARK: - Family Sharing Section
    @ViewBuilder
    private var familySharingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FAMILY CALENDAR")
                .font(.appCaption)
                .foregroundColor(appAccentColor)
                .padding(.horizontal, 4)

            if hasFamilyAccess {
                // Full family sharing controls for Family Plus subscribers
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Add to Family Calendar")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)

                            if shareToFamily && !selectedMemberIds.isEmpty {
                                Text("\(selectedMemberIds.count) member\(selectedMemberIds.count == 1 ? "" : "s") selected")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                            } else if shareToFamily {
                                Text("Tap to select members")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                            }
                        }

                        Spacer()

                        Toggle("", isOn: $shareToFamily)
                            .labelsHidden()
                            .tint(appAccentColor)
                    }

                    if shareToFamily {
                        Button {
                            showFamilySharingSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "person.2")
                                    .foregroundColor(appAccentColor)
                                Text("Select Members")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
            } else {
                // Upgrade prompt for non-Family Plus users
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Share to Family Calendar")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        Text("Upgrade to Family Plus to share events")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "lock.fill")
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    private func saveCountdown() async {
        guard let account = appState.currentAccount else {
            errorMessage = "No account found"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            if isMultiDay {
                // Multi-day: create individual records per day linked by groupId
                let useRemoteFirst = shareToFamily && !selectedMemberIds.isEmpty
                let countdowns = try await appState.countdownRepository.createMultiDayCountdowns(
                    accountId: account.id,
                    title: title,
                    startDate: date,
                    endDate: endDate,
                    hasTime: hasTime,
                    type: selectedType,
                    customType: selectedType == .custom ? customTypeName : nil,
                    notes: notes.isBlank ? nil : notes,
                    imageUrl: nil,
                    reminderOffsetMinutes: reminderMinutes,
                    isRecurring: isRecurring,
                    recurrenceUnit: isRecurring ? recurrenceUnit : nil,
                    recurrenceInterval: isRecurring ? recurrenceInterval : nil,
                    recurrenceEndDate: isRecurring && hasRecurrenceEndDate ? recurrenceEndDate : nil,
                    useRemoteFirst: useRemoteFirst
                )

                // Upload photo to first day, then set imageUrl on all
                if let image = selectedImage, let firstDay = countdowns.first {
                    do {
                        let photoURL = try await ImageUploadService.shared.uploadCountdownPhoto(image: image, countdownId: firstDay.id)
                        for var cd in countdowns {
                            cd.imageUrl = photoURL
                            _ = try await appState.countdownRepository.updateCountdown(cd)
                        }
                    } catch {
                        #if DEBUG
                        print("Failed to upload countdown photo: \(error)")
                        #endif
                    }
                }

                // Schedule notification only for the first day
                if let firstDay = countdowns.first, let reminderMinutes = reminderMinutes {
                    await NotificationService.shared.scheduleCountdownReminder(
                        countdownId: firstDay.id,
                        title: firstDay.title,
                        countdownDate: firstDay.date,
                        reminderMinutesBefore: reminderMinutes,
                        isRecurring: firstDay.isRecurring
                    )
                }

                // Create family shares for all days
                if shareToFamily && !selectedMemberIds.isEmpty {
                    for countdown in countdowns {
                        _ = try await appState.familyCalendarRepository.createShare(
                            accountId: account.id,
                            eventType: .countdown,
                            eventId: countdown.id,
                            memberUserIds: Array(selectedMemberIds)
                        )
                    }
                    // Send one push notification for the event (not per-day)
                    if let firstDay = countdowns.first {
                        await PushNotificationService.shared.sendShareNotification(
                            eventType: .countdown,
                            eventId: firstDay.id,
                            eventTitle: title,
                            sharedByName: appState.currentAppUser?.displayName ?? "Someone",
                            memberUserIds: Array(selectedMemberIds)
                        )
                    }
                }

                if let firstDay = countdowns.first {
                    onSave(firstDay)
                }
            } else {
                // Single-day event
                let insert = CountdownInsert(
                    accountId: account.id,
                    title: title,
                    subtitle: subtitle.isBlank ? nil : subtitle,
                    date: date,
                    hasTime: hasTime,
                    type: selectedType,
                    customType: selectedType == .custom ? customTypeName : nil,
                    notes: notes.isBlank ? nil : notes,
                    reminderOffsetMinutes: reminderMinutes,
                    isRecurring: isRecurring,
                    recurrenceUnit: isRecurring ? recurrenceUnit : nil,
                    recurrenceInterval: isRecurring ? recurrenceInterval : nil,
                    recurrenceEndDate: isRecurring && hasRecurrenceEndDate ? recurrenceEndDate : nil
                )

                var countdown: Countdown
                if shareToFamily && !selectedMemberIds.isEmpty {
                    countdown = try await appState.countdownRepository.createCountdownRemoteFirst(insert)
                } else {
                    countdown = try await appState.countdownRepository.createCountdown(insert)
                }

                // Upload photo if selected
                if let image = selectedImage {
                    do {
                        let photoURL = try await ImageUploadService.shared.uploadCountdownPhoto(image: image, countdownId: countdown.id)
                        countdown.imageUrl = photoURL
                        _ = try await appState.countdownRepository.updateCountdown(countdown)
                    } catch {
                        #if DEBUG
                        print("Failed to upload countdown photo: \(error)")
                        #endif
                    }
                }

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

                // Create family calendar share if enabled
                if shareToFamily && !selectedMemberIds.isEmpty {
                    _ = try await appState.familyCalendarRepository.createShare(
                        accountId: account.id,
                        eventType: .countdown,
                        eventId: countdown.id,
                        memberUserIds: Array(selectedMemberIds)
                    )
                    // Send push notification to shared members
                    await PushNotificationService.shared.sendShareNotification(
                        eventType: .countdown,
                        eventId: countdown.id,
                        eventTitle: countdown.title,
                        sharedByName: appState.currentAppUser?.displayName ?? "Someone",
                        memberUserIds: Array(selectedMemberIds)
                    )
                }

                onSave(countdown)
            }

            dismissView()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isLoading = false
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
    @State private var subtitle: String
    @State private var date: Date
    @State private var endDate: Date
    @State private var isMultiDay: Bool
    @State private var hasTime: Bool
    @State private var selectedType: CountdownType
    @State private var customTypeName: String
    @State private var notes: String
    @State private var reminderMinutes: Int?
    @State private var isRecurring: Bool
    @State private var recurrenceUnit: RecurrenceUnit
    @State private var recurrenceInterval: Int
    @State private var hasRecurrenceEndDate: Bool
    @State private var recurrenceEndDate: Date
    @State private var selectedImage: UIImage?
    @State private var removePhoto = false

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEditGroupSheet = false
    @State private var showDeleteGroupConfirmation = false

    // Date picker modal state
    @State private var showDatePicker = false
    @State private var showEndDatePicker = false
    @State private var showRecurrenceEndDatePicker = false

    // Family sharing state
    @State private var shareToFamily = false
    @State private var selectedMemberIds: Set<UUID> = []
    @State private var showFamilySharingSheet = false

    // Check if user has Family Plus access
    private var hasFamilyAccess: Bool {
        appState.hasFamilyAccess
    }

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
        self._subtitle = State(initialValue: countdown.subtitle ?? "")
        self._date = State(initialValue: countdown.date)
        self._endDate = State(initialValue: countdown.endDate ?? countdown.date)
        self._isMultiDay = State(initialValue: countdown.endDate != nil && countdown.groupId == nil)
        self._hasTime = State(initialValue: countdown.hasTime)
        self._selectedType = State(initialValue: countdown.type)
        self._customTypeName = State(initialValue: countdown.customType ?? "")
        self._notes = State(initialValue: countdown.notes ?? "")
        self._reminderMinutes = State(initialValue: countdown.reminderOffsetMinutes)
        self._isRecurring = State(initialValue: countdown.isRecurring)
        self._recurrenceUnit = State(initialValue: countdown.recurrenceUnit ?? .year)
        self._recurrenceInterval = State(initialValue: countdown.recurrenceInterval ?? 1)
        self._hasRecurrenceEndDate = State(initialValue: countdown.recurrenceEndDate != nil)
        self._recurrenceEndDate = State(initialValue: countdown.recurrenceEndDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
    }

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
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
                    // Group info banner for grouped events
                    if countdown.groupId != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 14))
                                .foregroundColor(appAccentColor)
                            Text("Part of a multi-day event")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                            Spacer()
                        }
                        .padding()
                        .background(appAccentColor.opacity(0.1))
                        .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
                    }

                    AppTextField(placeholder: "Title *", text: $title)

                    AppTextField(placeholder: "Subtitle (optional)", text: $subtitle)


                    // Family sharing section
                    editFamilySharingSection

                    // Type picker row
                    HStack {
                        Text("Type")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        Picker("Type", selection: $selectedType) {
                            ForEach(CountdownType.allCases) { type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(type)
                                    .font(.appBody)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(appAccentColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    // Custom type name (shown only when "Custom" is selected)
                    if selectedType == .custom {
                        AppTextField(placeholder: "Custom type name", text: $customTypeName)
                    }

                    // Date & Time section
                    VStack(spacing: 0) {
                        // From date row
                        Button {
                            showDatePicker = true
                        } label: {
                            HStack {
                                Text(isMultiDay ? "From" : "Date")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                Text(hasTime ? date.formatted(date: .abbreviated, time: .shortened) : date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding()

                        // End date row (shown when multi-day is on)
                        if isMultiDay {
                            Divider()
                                .padding(.horizontal, 16)

                            Button {
                                showEndDatePicker = true
                            } label: {
                                HStack {
                                    Text("To")
                                        .font(.appBody)
                                        .foregroundColor(.textPrimary)

                                    Spacer()

                                    Text(hasTime ? endDate.formatted(date: .abbreviated, time: .shortened) : endDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.appBody)
                                        .foregroundColor(.textSecondary)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.textSecondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding()
                        }

                        // Multi-day toggle (hidden for grouped events — each day is already individual)
                        if countdown.groupId == nil {
                            Divider()
                                .padding(.horizontal, 16)

                            HStack {
                                Toggle("Multi-day event", isOn: $isMultiDay.animation())
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                    .tint(appAccentColor)
                            }
                            .padding()
                        }

                        // Time toggle
                        Divider()
                            .padding(.horizontal, 16)

                        HStack {
                            Toggle("Add time", isOn: $hasTime.animation())
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .tint(appAccentColor)
                        }
                        .padding()
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    // Recurring section
                    VStack(spacing: 0) {
                        HStack {
                            Toggle("Repeats", isOn: $isRecurring.animation())
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .tint(appAccentColor)
                        }
                        .padding()

                        if isRecurring {
                            Divider()
                                .padding(.horizontal, 16)

                            HStack {
                                Text("Every")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                Picker("Interval", selection: $recurrenceInterval) {
                                    ForEach(1...30, id: \.self) { num in
                                        Text("\(num)").tag(num)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(appAccentColor)

                                Picker("Unit", selection: $recurrenceUnit) {
                                    ForEach(RecurrenceUnit.allCases) { unit in
                                        Text(recurrenceInterval == 1 ? unit.displayName : unit.pluralName).tag(unit)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(appAccentColor)
                            }
                            .padding()

                            Divider()
                                .padding(.horizontal, 16)

                            HStack {
                                Toggle("End Date", isOn: $hasRecurrenceEndDate.animation())
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                    .tint(appAccentColor)
                            }
                            .padding()

                            if hasRecurrenceEndDate {
                                Divider()
                                    .padding(.horizontal, 16)

                                HStack {
                                    Text("Ends On")
                                        .font(.appBody)
                                        .foregroundColor(.textPrimary)

                                    Spacer()

                                    Button {
                                        showRecurrenceEndDatePicker = true
                                    } label: {
                                        Text(recurrenceEndDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.appBody)
                                            .foregroundColor(appAccentColor)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    // Reminder picker row
                    HStack {
                        Text("Reminder")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        Picker("Reminder", selection: $reminderMinutes) {
                            ForEach(reminderOptions, id: \.0) { option in
                                Text(option.1).tag(option.0)
                                .font(.appBody)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(appAccentColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    AppTextField(placeholder: "Notes", text: $notes)

                    // Photo picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photo")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        ImageSourcePicker(
                            selectedImage: $selectedImage,
                            currentImageUrl: countdown.imageUrl,
                            onImageSelected: { _ in
                                removePhoto = false
                            },
                            onRemove: {
                                removePhoto = true
                            }
                        )
                    }


                    // Group actions for multi-day events
                    if countdown.groupId != nil {
                        VStack(spacing: 12) {
                            Button {
                                showEditGroupSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 16))
                                    Text("Edit All Days")
                                        .font(.appBody)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.textSecondary)
                                }
                                .foregroundColor(appAccentColor)
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button {
                                showDeleteGroupConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 16))
                                    Text("Delete All Days")
                                        .font(.appBody)
                                    Spacer()
                                }
                                .foregroundColor(.medicalRed)
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

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
        .onChange(of: date) { _, newDate in
            if endDate < newDate {
                endDate = newDate
            }
        }
        .sheet(isPresented: $showFamilySharingSheet) {
            FamilySharingSheet(
                isEnabled: $shareToFamily,
                selectedMemberIds: $selectedMemberIds,
                onDismiss: { showFamilySharingSheet = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
        .sheet(isPresented: $showDatePicker) {
            CountdownDatePickerSheet(
                title: isMultiDay ? "From" : "Date",
                selection: $date,
                hasTime: hasTime
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
        .sheet(isPresented: $showEndDatePicker) {
            CountdownDatePickerSheet(
                title: "To",
                selection: $endDate,
                minimumDate: date,
                hasTime: hasTime
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
        .sheet(isPresented: $showRecurrenceEndDatePicker) {
            CountdownDatePickerSheet(
                title: "Repeat End Date",
                selection: $recurrenceEndDate,
                minimumDate: date,
                hasTime: false
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
        .sidePanel(isPresented: $showEditGroupSheet) {
            if let groupId = countdown.groupId {
                EditGroupCountdownView(
                    groupId: groupId,
                    countdown: countdown,
                    onDismiss: { showEditGroupSheet = false },
                    onSave: { updated in
                        onSave(updated)
                        dismissView()
                    }
                )
                .environmentObject(appState)
            }
        }
        .confirmationDialog(
            "Delete All Days",
            isPresented: $showDeleteGroupConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Days", role: .destructive) {
                Task { await deleteAllGroupDays() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete all days of this multi-day event. This action cannot be undone.")
        }
        .task {
            await refreshRecurrenceFields()
            await loadExistingFamilyShare()
        }
    }

    /// Refresh recurrence and reminder fields from the latest data,
    /// in case the local cache had stale/nil values when the view was initialized
    private func refreshRecurrenceFields() async {
        guard let groupId = countdown.groupId else { return }
        do {
            let groupCountdowns = try await appState.countdownRepository.getCountdownsByGroupId(groupId)
            if let representative = groupCountdowns.first {
                isRecurring = representative.isRecurring
                if let unit = representative.recurrenceUnit {
                    recurrenceUnit = unit
                }
                if let interval = representative.recurrenceInterval {
                    recurrenceInterval = interval
                }
                if let endDate = representative.recurrenceEndDate {
                    hasRecurrenceEndDate = true
                    recurrenceEndDate = endDate
                } else if !representative.isRecurring {
                    hasRecurrenceEndDate = false
                }
                if let reminder = representative.reminderOffsetMinutes {
                    reminderMinutes = reminder
                }
            }
        } catch {
            #if DEBUG
            print("Failed to refresh recurrence fields: \(error)")
            #endif
        }
    }

    private func deleteAllGroupDays() async {
        guard let groupId = countdown.groupId else { return }
        do {
            let groupCountdowns = try await appState.countdownRepository.getCountdownsByGroupId(groupId)
            for cd in groupCountdowns {
                if cd.imageUrl != nil {
                    try? await ImageUploadService.shared.deleteImage(
                        bucket: SupabaseConfig.countdownPhotosBucket,
                        path: "countdowns/\(cd.id.uuidString)/photo.jpg"
                    )
                }
                await NotificationService.shared.cancelCountdownReminder(countdownId: cd.id)
                // Delete family shares
                try? await appState.familyCalendarRepository.deleteShareForEvent(
                    eventType: .countdown,
                    eventId: cd.id
                )
            }
            try await appState.countdownRepository.deleteCountdownsByGroupId(groupId)
            NotificationCenter.default.post(name: .countdownsDidChange, object: nil)
            dismissView()
        } catch {
            errorMessage = "Failed to delete group: \(error.localizedDescription)"
        }
    }

    // MARK: - Family Sharing Section
    @ViewBuilder
    private var editFamilySharingSection: some View {
        if hasFamilyAccess {
            Button {
                showFamilySharingSheet = true
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(shareToFamily ? appAccentColor : .textSecondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("FAMILY CALENDAR")
                            .font(.appBody)
                            .foregroundColor(appAccentColor)

                        Text(shareToFamily ? "\(selectedMemberIds.count) member\(selectedMemberIds.count == 1 ? "" : "s") selected" : "Not shared")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Family Calendar")
                        .font(.appBody)
                        .foregroundColor(.textPrimary)

                    Text("Upgrade to Family Plus to share events")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Image(systemName: "crown.fill")
                //     .font(.system(size: 14))
                //     .foregroundColor(.accentYellow)

                    Image("unforgotten-icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 45)
                        .cornerRadius(8)
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
            .opacity(0.7)
        }
    }

    private func loadExistingFamilyShare() async {
        do {
            if let share = try await appState.familyCalendarRepository.getShareForEvent(
                eventType: .countdown,
                eventId: countdown.id
            ) {
                let members = try await appState.familyCalendarRepository.getMembersForShare(shareId: share.id)
                shareToFamily = true
                selectedMemberIds = Set(members.map { $0.memberUserId })
            }
        } catch {
            #if DEBUG
            print("Failed to load existing family share: \(error)")
            #endif
        }
    }

    private func updateFamilyCalendarSharing(accountId: UUID, countdownId: UUID) async throws {
        // First, delete existing share for this countdown
        try await appState.familyCalendarRepository.deleteShareForEvent(
            eventType: .countdown,
            eventId: countdownId
        )

        // Then create new share if sharing is enabled
        if shareToFamily && !selectedMemberIds.isEmpty {
            _ = try await appState.familyCalendarRepository.createShare(
                accountId: accountId,
                eventType: .countdown,
                eventId: countdownId,
                memberUserIds: Array(selectedMemberIds)
            )
            // Send push notification to shared members
            await PushNotificationService.shared.sendShareNotification(
                eventType: .countdown,
                eventId: countdownId,
                eventTitle: title,
                sharedByName: appState.currentAppUser?.displayName ?? "Someone",
                memberUserIds: Array(selectedMemberIds)
            )
        }
    }

    private func updateCountdown() async {
        isLoading = true
        errorMessage = nil

        var updatedCountdown = countdown
        updatedCountdown.title = title
        updatedCountdown.subtitle = subtitle.isBlank ? nil : subtitle
        updatedCountdown.date = date
        updatedCountdown.endDate = isMultiDay ? endDate : nil
        updatedCountdown.hasTime = hasTime
        updatedCountdown.type = selectedType
        updatedCountdown.customType = selectedType == .custom ? customTypeName : nil
        updatedCountdown.notes = notes.isBlank ? nil : notes
        updatedCountdown.reminderOffsetMinutes = reminderMinutes
        updatedCountdown.isRecurring = isRecurring
        updatedCountdown.recurrenceUnit = isRecurring ? recurrenceUnit : nil
        updatedCountdown.recurrenceInterval = isRecurring ? recurrenceInterval : nil
        updatedCountdown.recurrenceEndDate = isRecurring && hasRecurrenceEndDate ? recurrenceEndDate : nil

        // Handle photo upload/removal
        if let image = selectedImage {
            do {
                let photoURL = try await ImageUploadService.shared.uploadCountdownPhoto(image: image, countdownId: countdown.id)
                updatedCountdown.imageUrl = photoURL
            } catch {
                #if DEBUG
                print("Failed to upload countdown photo: \(error)")
                #endif
            }
        } else if removePhoto {
            // Delete from storage if there was a previous photo
            if countdown.imageUrl != nil {
                try? await ImageUploadService.shared.deleteImage(
                    bucket: SupabaseConfig.countdownPhotosBucket,
                    path: "countdowns/\(countdown.id.uuidString)/photo.jpg"
                )
            }
            updatedCountdown.imageUrl = nil
        }

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

            // Update family calendar sharing
            if let account = appState.currentAccount {
                try await updateFamilyCalendarSharing(accountId: account.id, countdownId: saved.id)
            }

            onSave(saved)
            dismissView()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Edit Group Countdown View
/// Edits shared fields across all countdowns in a multi-day group
struct EditGroupCountdownView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let groupId: UUID
    let countdown: Countdown
    var onDismiss: (() -> Void)? = nil
    let onSave: (Countdown) -> Void

    @State private var title: String
    @State private var hasTime: Bool
    @State private var selectedType: CountdownType
    @State private var customTypeName: String
    @State private var notes: String
    @State private var reminderMinutes: Int?
    @State private var isRecurring: Bool
    @State private var recurrenceUnit: RecurrenceUnit
    @State private var recurrenceInterval: Int
    @State private var hasRecurrenceEndDate: Bool
    @State private var recurrenceEndDate: Date
    @State private var selectedImage: UIImage?
    @State private var removePhoto = false
    @State private var showRecurrenceEndDatePicker = false

    // Date range state
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var groupCountdowns: [Countdown] = []

    // Family sharing state
    @State private var shareToFamily = false
    @State private var selectedMemberIds: Set<UUID> = []
    @State private var showFamilySharingSheet = false

    @State private var isLoading = false
    @State private var errorMessage: String?

    private var hasFamilyAccess: Bool {
        appState.hasFamilyAccess
    }

    private let reminderOptions: [(Int?, String)] = [
        (nil, "No reminder"),
        (0, "On the day"),
        (1440, "1 day before"),
        (2880, "2 days before"),
        (10080, "1 week before"),
        (20160, "2 weeks before")
    ]

    init(groupId: UUID, countdown: Countdown, onDismiss: (() -> Void)? = nil, onSave: @escaping (Countdown) -> Void) {
        self.groupId = groupId
        self.countdown = countdown
        self.onDismiss = onDismiss
        self.onSave = onSave
        self._title = State(initialValue: countdown.title)
        self._hasTime = State(initialValue: countdown.hasTime)
        self._selectedType = State(initialValue: countdown.type)
        self._customTypeName = State(initialValue: countdown.customType ?? "")
        self._notes = State(initialValue: countdown.notes ?? "")
        self._reminderMinutes = State(initialValue: countdown.reminderOffsetMinutes)
        self._isRecurring = State(initialValue: countdown.isRecurring)
        self._recurrenceUnit = State(initialValue: countdown.recurrenceUnit ?? .year)
        self._recurrenceInterval = State(initialValue: countdown.recurrenceInterval ?? 1)
        self._hasRecurrenceEndDate = State(initialValue: countdown.recurrenceEndDate != nil)
        self._recurrenceEndDate = State(initialValue: countdown.recurrenceEndDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
        self._startDate = State(initialValue: countdown.date)
        self._endDate = State(initialValue: countdown.date)
    }

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
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

                Text("Edit All Days")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    Task { await saveGroupUpdate() }
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
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(appAccentColor)
                        Text("Changes will apply to all days of this event. Individual subtitles are not affected.")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                    .padding()
                    .background(appAccentColor.opacity(0.1))
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    AppTextField(placeholder: "Title *", text: $title)

                    // Date range section
                    VStack(spacing: 0) {
                        HStack {
                            Text("Start Date")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)

                            Spacer()

                            Button {
                                showStartDatePicker = true
                            } label: {
                                Text(hasTime ? startDate.formatted(date: .abbreviated, time: .shortened) : startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.appBody)
                                    .foregroundColor(appAccentColor)
                            }
                        }
                        .padding()

                        Divider()
                            .padding(.horizontal, 16)

                        HStack {
                            Text("End Date")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)

                            Spacer()

                            Button {
                                showEndDatePicker = true
                            } label: {
                                Text(hasTime ? endDate.formatted(date: .abbreviated, time: .shortened) : endDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.appBody)
                                    .foregroundColor(appAccentColor)
                            }
                        }
                        .padding()
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    // Family sharing section
                    groupFamilySharingSection

                    // Type picker
                    HStack {
                        Text("Type")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        Picker("Type", selection: $selectedType) {
                            ForEach(CountdownType.allCases) { type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(appAccentColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    if selectedType == .custom {
                        AppTextField(placeholder: "Custom type name", text: $customTypeName)
                    }

                    // Time toggle
                    VStack(spacing: 0) {
                        HStack {
                            Toggle("Add time", isOn: $hasTime.animation())
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .tint(appAccentColor)
                        }
                        .padding()
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    // Recurring section
                    VStack(spacing: 0) {
                        HStack {
                            Toggle("Repeats", isOn: $isRecurring.animation())
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .tint(appAccentColor)
                        }
                        .padding()

                        if isRecurring {
                            Divider()
                                .padding(.horizontal, 16)

                            HStack {
                                Text("Every")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                Picker("Interval", selection: $recurrenceInterval) {
                                    ForEach(1...30, id: \.self) { num in
                                        Text("\(num)").tag(num)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(appAccentColor)

                                Picker("Unit", selection: $recurrenceUnit) {
                                    ForEach(RecurrenceUnit.allCases) { unit in
                                        Text(recurrenceInterval == 1 ? unit.displayName : unit.pluralName).tag(unit)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(appAccentColor)
                            }
                            .padding()

                            Divider()
                                .padding(.horizontal, 16)

                            HStack {
                                Toggle("End Date", isOn: $hasRecurrenceEndDate.animation())
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                    .tint(appAccentColor)
                            }
                            .padding()

                            if hasRecurrenceEndDate {
                                Divider()
                                    .padding(.horizontal, 16)

                                HStack {
                                    Text("Ends On")
                                        .font(.appBody)
                                        .foregroundColor(.textPrimary)

                                    Spacer()

                                    Button {
                                        showRecurrenceEndDatePicker = true
                                    } label: {
                                        Text(recurrenceEndDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.appBody)
                                            .foregroundColor(appAccentColor)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    // Reminder picker
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
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )

                    AppTextField(placeholder: "Notes (optional)", text: $notes)

                    // Photo picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photo")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        ImageSourcePicker(
                            selectedImage: $selectedImage,
                            currentImageUrl: countdown.imageUrl,
                            onImageSelected: { _ in
                                removePhoto = false
                            },
                            onRemove: {
                                removePhoto = true
                            }
                        )
                    }

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
        .task {
            await loadGroupCountdowns()
            await loadExistingFamilyShare()
        }
        .onChange(of: startDate) { _, newDate in
            if endDate < newDate {
                endDate = newDate
            }
        }
        .sheet(isPresented: $showStartDatePicker) {
            CountdownDatePickerSheet(
                title: "Start Date",
                selection: $startDate,
                hasTime: hasTime
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
        .sheet(isPresented: $showEndDatePicker) {
            CountdownDatePickerSheet(
                title: "End Date",
                selection: $endDate,
                minimumDate: startDate,
                hasTime: hasTime
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
        .sheet(isPresented: $showFamilySharingSheet) {
            FamilySharingSheet(
                isEnabled: $shareToFamily,
                selectedMemberIds: $selectedMemberIds,
                onDismiss: { showFamilySharingSheet = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
        .sheet(isPresented: $showRecurrenceEndDatePicker) {
            CountdownDatePickerSheet(
                title: "Repeat End Date",
                selection: $recurrenceEndDate,
                minimumDate: startDate,
                hasTime: false
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
    }

    // MARK: - Family Sharing Section
    @ViewBuilder
    private var groupFamilySharingSection: some View {
        if hasFamilyAccess {
            Button {
                showFamilySharingSheet = true
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(shareToFamily ? appAccentColor : .textSecondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Family Calendar")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        Text(shareToFamily ? "\(selectedMemberIds.count) member\(selectedMemberIds.count == 1 ? "" : "s") selected" : "Not shared")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Family Calendar")
                        .font(.appBody)
                        .foregroundColor(.textPrimary)

                    Text("Upgrade to Family Plus to share events")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Image(systemName: "crown.fill")
                //     .font(.system(size: 14))
                //     .foregroundColor(.accentYellow)
                    Image("unforgotten-icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 45)
                        .cornerRadius(8)

            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
            .opacity(0.7)
        }
    }

    private func loadGroupCountdowns() async {
        do {
            let countdowns = try await appState.countdownRepository.getCountdownsByGroupId(groupId)
            let sorted = countdowns.sorted { $0.date < $1.date }
            groupCountdowns = sorted
            if let first = sorted.first, let last = sorted.last {
                startDate = first.date
                endDate = last.date
            }

            // Refresh recurrence and reminder state from the fetched data,
            // in case the local cache had stale/nil values when the view was initialized
            if let representative = sorted.first {
                isRecurring = representative.isRecurring
                if let unit = representative.recurrenceUnit {
                    recurrenceUnit = unit
                }
                if let interval = representative.recurrenceInterval {
                    recurrenceInterval = interval
                }
                if let endDate = representative.recurrenceEndDate {
                    hasRecurrenceEndDate = true
                    recurrenceEndDate = endDate
                } else if !representative.isRecurring {
                    hasRecurrenceEndDate = false
                }
                if let reminder = representative.reminderOffsetMinutes {
                    reminderMinutes = reminder
                }
            }
        } catch {
            #if DEBUG
            print("Failed to load group countdowns: \(error)")
            #endif
        }
    }

    private func loadExistingFamilyShare() async {
        // Load sharing state from the first countdown in the group
        do {
            if let share = try await appState.familyCalendarRepository.getShareForEvent(
                eventType: .countdown,
                eventId: countdown.id
            ) {
                let members = try await appState.familyCalendarRepository.getMembersForShare(shareId: share.id)
                shareToFamily = true
                selectedMemberIds = Set(members.map { $0.memberUserId })
            }
        } catch {
            #if DEBUG
            print("Failed to load existing family share: \(error)")
            #endif
        }
    }

    private func updateFamilyCalendarSharingForGroup(accountId: UUID, countdownIds: [UUID]) async {
        var didSendNotification = false
        for countdownId in countdownIds {
            do {
                try await appState.familyCalendarRepository.deleteShareForEvent(
                    eventType: .countdown,
                    eventId: countdownId
                )

                if shareToFamily && !selectedMemberIds.isEmpty {
                    _ = try await appState.familyCalendarRepository.createShare(
                        accountId: accountId,
                        eventType: .countdown,
                        eventId: countdownId,
                        memberUserIds: Array(selectedMemberIds)
                    )
                    // Send one push notification for the group (not per-day)
                    if !didSendNotification {
                        didSendNotification = true
                        await PushNotificationService.shared.sendShareNotification(
                            eventType: .countdown,
                            eventId: countdownId,
                            eventTitle: countdown.title,
                            sharedByName: appState.currentAppUser?.displayName ?? "Someone",
                            memberUserIds: Array(selectedMemberIds)
                        )
                    }
                }
            } catch {
                #if DEBUG
                print("Failed to update family sharing for countdown \(countdownId): \(error)")
                #endif
            }
        }
    }

    private func saveGroupUpdate() async {
        isLoading = true
        errorMessage = nil

        // Handle photo upload/removal for all group records
        var imageUrl = countdown.imageUrl
        if let image = selectedImage {
            do {
                let photoURL = try await ImageUploadService.shared.uploadCountdownPhoto(image: image, countdownId: countdown.id)
                imageUrl = photoURL
            } catch {
                #if DEBUG
                print("Failed to upload group countdown photo: \(error)")
                #endif
            }
        } else if removePhoto {
            if countdown.imageUrl != nil {
                try? await ImageUploadService.shared.deleteImage(
                    bucket: SupabaseConfig.countdownPhotosBucket,
                    path: "countdowns/\(countdown.id.uuidString)/photo.jpg"
                )
            }
            imageUrl = nil
        }

        let update = CountdownGroupUpdate(
            title: title,
            hasTime: hasTime,
            type: selectedType,
            customType: selectedType == .custom ? customTypeName : nil,
            notes: notes.isBlank ? nil : notes,
            imageUrl: imageUrl,
            reminderOffsetMinutes: reminderMinutes,
            isRecurring: isRecurring,
            recurrenceUnit: isRecurring ? recurrenceUnit : nil,
            recurrenceInterval: isRecurring ? recurrenceInterval : nil,
            recurrenceEndDate: isRecurring && hasRecurrenceEndDate ? recurrenceEndDate : nil
        )

        do {
            // First update shared fields on all existing group records
            _ = try await appState.countdownRepository.updateCountdownGroupFields(groupId, update: update)

            // Reconcile date range: add/remove days as needed
            let calendar = Calendar.current
            let newStartDay = calendar.startOfDay(for: startDate)
            let newEndDay = calendar.startOfDay(for: endDate)

            // Build set of existing days (normalized to start of day)
            var existingByDay: [Date: Countdown] = [:]
            for cd in groupCountdowns {
                let day = calendar.startOfDay(for: cd.date)
                existingByDay[day] = cd
            }

            // Build set of desired days
            var desiredDays: [Date] = []
            var currentDay = newStartDay
            while currentDay <= newEndDay {
                desiredDays.append(currentDay)
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
                currentDay = nextDay
            }
            let desiredDaySet = Set(desiredDays)

            // Delete days that are no longer in range
            for (day, cd) in existingByDay {
                if !desiredDaySet.contains(day) {
                    try await appState.countdownRepository.deleteCountdown(id: cd.id)
                    // Clean up family share for removed day
                    try? await appState.familyCalendarRepository.deleteShareForEvent(
                        eventType: .countdown,
                        eventId: cd.id
                    )
                }
            }

            // Add new days that don't exist yet
            guard let account = appState.currentAccount else {
                errorMessage = "No account found"
                isLoading = false
                return
            }

            for day in desiredDays {
                if existingByDay[day] == nil {
                    var dayDate = day
                    if hasTime {
                        let timeComponents = calendar.dateComponents([.hour, .minute], from: startDate)
                        dayDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: day) ?? day
                    }

                    let insert = CountdownInsert(
                        accountId: account.id,
                        title: title,
                        date: dayDate,
                        hasTime: hasTime,
                        type: selectedType,
                        customType: selectedType == .custom ? customTypeName : nil,
                        notes: update.notes,
                        imageUrl: imageUrl,
                        groupId: groupId,
                        reminderOffsetMinutes: day == newStartDay ? reminderMinutes : nil,
                        isRecurring: isRecurring,
                        recurrenceUnit: isRecurring ? recurrenceUnit : nil,
                        recurrenceInterval: isRecurring ? recurrenceInterval : nil,
                        recurrenceEndDate: isRecurring && hasRecurrenceEndDate ? recurrenceEndDate : nil
                    )
                    _ = try await appState.countdownRepository.createCountdown(insert)
                }
            }

            // Re-fetch the updated group
            let finalCountdowns = try await appState.countdownRepository.getCountdownsByGroupId(groupId)

            // Re-schedule notification for earliest day
            if let earliestDay = finalCountdowns.sorted(by: { $0.date < $1.date }).first {
                await NotificationService.shared.cancelCountdownReminder(countdownId: earliestDay.id)
                if let reminderMinutes = reminderMinutes {
                    await NotificationService.shared.scheduleCountdownReminder(
                        countdownId: earliestDay.id,
                        title: earliestDay.title,
                        countdownDate: earliestDay.date,
                        reminderMinutesBefore: reminderMinutes,
                        isRecurring: earliestDay.isRecurring
                    )
                }
            }

            // Update family calendar sharing for all group records
            await updateFamilyCalendarSharingForGroup(
                accountId: account.id,
                countdownIds: finalCountdowns.map { $0.id }
            )

            NotificationCenter.default.post(name: .countdownsDidChange, object: nil)

            if let first = finalCountdowns.sorted(by: { $0.date < $1.date }).first {
                onSave(first)
            }
            dismissView()
        } catch {
            errorMessage = "Failed to update: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Date Picker Sheet
private struct CountdownDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let title: String
    @Binding var selection: Date
    var minimumDate: Date? = nil
    var hasTime: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.appBodyMedium)
                        .foregroundColor(appAccentColor)
                }
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)

            // Selected day name label
            Text(selection.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                .font(.appBodyMedium)
                .foregroundColor(appAccentColor)
                .padding(.bottom, 8)

            // Date picker
            if let minimumDate {
                DatePicker(
                    "",
                    selection: $selection,
                    in: minimumDate...,
                    displayedComponents: hasTime ? [.date, .hourAndMinute] : .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            } else {
                DatePicker(
                    "",
                    selection: $selection,
                    displayedComponents: hasTime ? [.date, .hourAndMinute] : .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }

            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    AddCountdownView { _ in }
        .environmentObject(AppState.forPreview())
}
