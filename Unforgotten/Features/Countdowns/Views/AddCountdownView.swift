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
    @State private var selectedImage: UIImage?

    @State private var isLoading = false
    @State private var errorMessage: String?

    // Date picker modal state
    @State private var showDatePicker = false
    @State private var showEndDatePicker = false

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
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(appAccentColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.cardCornerRadius)

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
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.cardCornerRadius)

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
    }

    // MARK: - Family Sharing Section
    @ViewBuilder
    private var familySharingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Family Calendar")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
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
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.cardCornerRadius)
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
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.cardCornerRadius)
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
                        do {
                            _ = try await appState.familyCalendarRepository.createShare(
                                accountId: account.id,
                                eventType: .countdown,
                                eventId: countdown.id,
                                memberUserIds: Array(selectedMemberIds)
                            )
                        } catch {
                            #if DEBUG
                            print("Failed to create family share for day: \(error)")
                            #endif
                        }
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
                    isRecurring: isRecurring
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
                    do {
                        _ = try await appState.familyCalendarRepository.createShare(
                            accountId: account.id,
                            eventType: .countdown,
                            eventId: countdown.id,
                            memberUserIds: Array(selectedMemberIds)
                        )
                    } catch {
                        #if DEBUG
                        print("Failed to create family share: \(error)")
                        #endif
                    }
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
    @State private var selectedImage: UIImage?
    @State private var removePhoto = false

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEditGroupSheet = false
    @State private var showDeleteGroupConfirmation = false

    // Date picker modal state
    @State private var showDatePicker = false
    @State private var showEndDatePicker = false

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
                        .cornerRadius(AppDimensions.cardCornerRadius)
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
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(appAccentColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.cardCornerRadius)

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
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.cardCornerRadius)

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
                                .background(Color.cardBackgroundSoft)
                                .cornerRadius(AppDimensions.cardCornerRadius)
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
                                .background(Color.cardBackgroundSoft)
                                .cornerRadius(AppDimensions.cardCornerRadius)
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
            await loadExistingFamilyShare()
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
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.cardCornerRadius)
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

                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentYellow)
            }
            .padding()
            .background(Color.cardBackgroundSoft)
            .cornerRadius(AppDimensions.cardCornerRadius)
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

    private func updateFamilyCalendarSharing(accountId: UUID, countdownId: UUID) async {
        do {
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
            }
        } catch {
            #if DEBUG
            print("Failed to update family calendar sharing: \(error)")
            #endif
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
                await updateFamilyCalendarSharing(accountId: account.id, countdownId: saved.id)
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
    @State private var selectedImage: UIImage?
    @State private var removePhoto = false

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
                        Text("Changes will apply to all days of this event. Individual dates and subtitles are not affected.")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                    .padding()
                    .background(appAccentColor.opacity(0.1))
                    .cornerRadius(AppDimensions.cardCornerRadius)

                    AppTextField(placeholder: "Title *", text: $title)

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
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.cardCornerRadius)

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
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.cardCornerRadius)

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
            await loadExistingFamilyShare()
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
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.cardCornerRadius)
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

                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentYellow)
            }
            .padding()
            .background(Color.cardBackgroundSoft)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .opacity(0.7)
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
            isRecurring: isRecurring
        )

        do {
            let updated = try await appState.countdownRepository.updateCountdownGroupFields(groupId, update: update)

            // Re-schedule notification for earliest day
            if let earliestDay = updated.sorted(by: { $0.date < $1.date }).first {
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
            if let account = appState.currentAccount {
                await updateFamilyCalendarSharingForGroup(
                    accountId: account.id,
                    countdownIds: updated.map { $0.id }
                )
            }

            NotificationCenter.default.post(name: .countdownsDidChange, object: nil)

            if let first = updated.first {
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
                .foregroundColor(.accentYellow)
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
