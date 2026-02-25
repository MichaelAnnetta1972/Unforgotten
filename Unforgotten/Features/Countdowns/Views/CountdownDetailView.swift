import SwiftUI

// MARK: - Countdown Detail View
struct CountdownDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.dismiss) private var dismiss

    @State var countdown: Countdown
    @State private var showEditCountdown = false
    @State private var showDeleteConfirmation = false
    @State private var showFullscreenPhoto = false
    @State private var sharedByName: String?
    @State private var isSharedByMe = false
    @State private var showRemoveSharedConfirmation = false
    @State private var isDeleting = false
    @State private var showEditGroupSheet = false
    @State private var showDeleteGroupConfirmation = false
    @State private var groupDayInfo: (current: Int, total: Int)?

    /// Whether this countdown belongs to another account (shared via family calendar)
    private var isSharedFromOtherAccount: Bool {
        guard let currentAccountId = appState.currentAccount?.id else { return false }
        return countdown.accountId != currentAccountId
    }

    /// Whether the current user can edit
    private var canEdit: Bool {
        appState.canEdit && !isSharedFromOtherAccount
    }

    private var daysUntilText: String {
        let days = countdown.daysUntilNextOccurrence
        if days == 0 {
            return "Today!"
        } else if days == 1 {
            return "Tomorrow"
        } else {
            return "In \(days) days"
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title bar with close button
                titleBar

                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Shared event banner
                        if isSharedFromOtherAccount {
                            sharedEventBanner
                        }

                        // Countdown Card
                        countdownCard

                        // Details Card
                        detailsCard

                        // Notes Card (if notes exist)
                        if let notes = countdown.notes, !notes.isEmpty {
                            notesCard(notes: notes)
                        }

                        // Photo Card (if photo exists)
                        if let imageUrl = countdown.imageUrl, let url = URL(string: imageUrl) {
                            photoCard(url: url)
                        }

                        // Action Buttons
                        if canEdit {
                            actionButtons
                        }

                        // Remove button for shared events
                        if isSharedFromOtherAccount {
                            Button {
                                showRemoveSharedConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "eye.slash")
                                    Text("Remove from My Events")
                                }
                                .font(.appBodyMedium)
                                .foregroundColor(.medicalRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.medicalRed.opacity(0.1))
                                .cornerRadius(AppDimensions.cardCornerRadius)
                            }
                            .disabled(isDeleting)
                        }

                        // Bottom spacing
                        Spacer()
                            .frame(height: 120)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
        }
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showEditCountdown) {
            EditCountdownView(
                countdown: countdown,
                onDismiss: { showEditCountdown = false }
            ) { updatedCountdown in
                countdown = updatedCountdown
                NotificationCenter.default.post(name: .countdownsDidChange, object: nil)
                showEditCountdown = false
            }
            .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showFullscreenPhoto) {
            if let imageUrl = countdown.imageUrl {
                RemoteFullscreenImageView(imageUrl: imageUrl, title: countdown.title)
            }
        }
        .task {
            if isSharedFromOtherAccount {
                await loadSharedByName()
            } else {
                // Check if this countdown has been shared by the current user
                if let _ = try? await appState.familyCalendarRepository.getShareForEvent(
                    eventType: .countdown, eventId: countdown.id
                ) {
                    isSharedByMe = true
                }
            }

            // Load group day info
            if let groupId = countdown.groupId {
                await loadGroupDayInfo(groupId: groupId)
            }
        }
        .sidePanel(isPresented: $showEditGroupSheet) {
            if let groupId = countdown.groupId {
                EditGroupCountdownView(
                    groupId: groupId,
                    countdown: countdown,
                    onDismiss: { showEditGroupSheet = false },
                    onSave: { updated in
                        countdown = updated
                        showEditGroupSheet = false
                    }
                )
                .environmentObject(appState)
            }
        }
        .confirmationDialog(
            countdown.groupId != nil ? "Delete This Day" : "Delete Event",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteCountdown()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(countdown.groupId != nil
                ? "This will delete only this day of the multi-day event. Other days will remain."
                : "Are you sure you want to delete this event? This cannot be undone.")
        }
        .confirmationDialog("Delete All Days", isPresented: $showDeleteGroupConfirmation, titleVisibility: .visible) {
            Button("Delete All Days", role: .destructive) {
                deleteAllGroupDays()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all days of this multi-day event. This action cannot be undone.")
        }
        .alert("Remove Shared Event", isPresented: $showRemoveSharedConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    await removeSharedCountdown()
                }
            }
        } message: {
            Text("Remove \"\(countdown.title)\" from your events? The original owner will still have this event.")
        }
    }

    // MARK: - Title Bar
    private var titleBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.cardBackgroundSoft)
                    .clipShape(Circle())
            }

            Spacer()

            if isSharedFromOtherAccount {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Color.cardBackgroundSoft)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, AppDimensions.screenPadding)
        .padding(.vertical, 12)
        .background(Color.appBackground)
    }

    // MARK: - Shared Event Banner
    private var sharedEventBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 14))
                .foregroundColor(appAccentColor)

            Text("Shared by \(sharedByName ?? "a family member")")
                .font(.appBodyMedium)
                .foregroundColor(.textPrimary)

            Spacer()

            Text("View Only")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.cardBackgroundSoft)
                .cornerRadius(12)
        }
        .padding(AppDimensions.cardPadding)
        .background(appAccentColor.opacity(0.1))
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Countdown Card
    private var countdownCard: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(appAccentColor.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: countdown.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(appAccentColor)
            }

            VStack(alignment: .leading, spacing: 4) {

                Text(countdown.title)
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                if let subtitle = countdown.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }

                if let dayInfo = groupDayInfo {
                    Text("Day \(dayInfo.current) of \(dayInfo.total)")
                        .font(.appCaption)
                        .foregroundColor(appAccentColor)
                }

                Text(daysUntilText)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                Text(countdown.formattedDateShort)
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            VStack(spacing: 8) {
                // Recurring badge
                if countdown.isRecurring {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                            .font(.system(size: 12))
                        Text("Recurring")
                            .font(.appCaption)
                    }
                    .foregroundColor(.textSecondary)
                }

                // Shared badge
                if isSharedByMe || isSharedFromOtherAccount {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("Shared")
                            .font(.appCaption)
                    }
                    .foregroundColor(appAccentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(appAccentColor.opacity(0.15))
                    .cornerRadius(12)
                }
            }
        }
        .padding(AppDimensions.cardPaddingLarge)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Details Card
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            // Type
            HStack {
                Image(systemName: "tag.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .frame(width: 24)

                Text("Type")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)

                Spacer()

                Text(countdown.displayTypeName)
                    .font(.appBodyMedium)
                    .foregroundColor(appAccentColor)
            }

            Divider()

            // Date
            if let endDate = countdown.endDate {
                // Multi-day event
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                            .frame(width: 24)

                        Text("From")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)

                        Spacer()

                        if countdown.hasTime {
                            Text(countdown.date.formattedDayMonth() + ", " + countdown.date.formatted(date: .omitted, time: .shortened))
                                .font(.appBodyMedium)
                                .foregroundColor(.textPrimary)
                        } else {
                            Text(countdown.date.formattedDayMonth())
                                .font(.appBodyMedium)
                                .foregroundColor(.textPrimary)
                        }
                    }

                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                            .frame(width: 24)

                        Text("To")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)

                        Spacer()

                        if countdown.hasTime {
                            Text(endDate.formattedDayMonth() + ", " + endDate.formatted(date: .omitted, time: .shortened))
                                .font(.appBodyMedium)
                                .foregroundColor(.textPrimary)
                        } else {
                            Text(endDate.formattedDayMonth())
                                .font(.appBodyMedium)
                                .foregroundColor(.textPrimary)
                        }
                    }
                }
            } else {
                // Single day event
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .frame(width: 24)

                    Text("Date")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)

                    Spacer()

                    Text(countdown.date.formattedDayMonth())
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)
                }

                // Time (if set, single-day only)
                if countdown.hasTime {
                    Divider()

                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                            .frame(width: 24)

                        Text("Time")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)

                        Spacer()

                        Text(countdown.date.formatted(date: .omitted, time: .shortened))
                            .font(.appBodyMedium)
                            .foregroundColor(.textPrimary)
                    }
                }
            }

            // Reminder (if set)
            if let reminderMinutes = countdown.reminderOffsetMinutes {
                Divider()

                HStack {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .frame(width: 24)

                    Text("Reminder")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)

                    Spacer()

                    Text(reminderText(minutes: reminderMinutes))
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)
                }
            }
        }
        .padding(AppDimensions.cardPaddingLarge)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Notes Card
    private func notesCard(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Text(notes)
                .font(.appBody)
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppDimensions.cardPaddingLarge)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Photo Card
    private func photoCard(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo")
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Button {
                showFullscreenPhoto = true
            } label: {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.textSecondary)
                            Text("Failed to load image")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color.cardBackgroundSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(AppDimensions.cardPaddingLarge)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Edit button
            Button {
                showEditCountdown = true
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text(countdown.groupId != nil ? "Edit This Day" : "Edit Event")
                }
                .font(.appBodyMedium)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(appAccentColor)
                .cornerRadius(AppDimensions.cardCornerRadius)
            }

            // Group actions for multi-day events
            if countdown.groupId != nil {
                Button {
                    showEditGroupSheet = true
                } label: {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                        Text("Edit All Days")
                    }
                    .font(.appBodyMedium)
                    .foregroundColor(appAccentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.cardCornerRadius)
                }
            }

            // Delete button
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(countdown.groupId != nil ? "Delete This Day" : "Delete Event")
                }
                .font(.appBodyMedium)
                .foregroundColor(.medicalRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
            }

            // Delete all days button for grouped events
            if countdown.groupId != nil {
                Button {
                    showDeleteGroupConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete All Days")
                    }
                    .font(.appBodyMedium)
                    .foregroundColor(.medicalRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.medicalRed.opacity(0.1))
                    .cornerRadius(AppDimensions.cardCornerRadius)
                }
            }
        }
    }

    // MARK: - Helper Methods
    private func reminderText(minutes: Int) -> String {
        if minutes == 0 {
            return "At time of event"
        } else if minutes < 60 {
            return "\(minutes) minutes before"
        } else if minutes < 1440 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour before" : "\(hours) hours before"
        } else {
            let days = minutes / 1440
            return days == 1 ? "1 day before" : "\(days) days before"
        }
    }

    private func loadSharedByName() async {
        guard let accountId = appState.currentAccount?.id else { return }
        do {
            // Find the share record for this countdown to get the sharedByUserId
            let share = try await appState.familyCalendarRepository.getShareForEvent(
                eventType: .countdown, eventId: countdown.id
            )
            guard let sharerUserId = share?.sharedByUserId else { return }

            // Look up profiles in current account - find synced profile whose sourceUserId matches the sharer
            let profiles = try await appState.profileRepository.getProfiles(accountId: accountId)
            if let sharerProfile = profiles.first(where: { $0.sourceUserId == sharerUserId }) {
                sharedByName = sharerProfile.displayName
            }
        } catch {
            #if DEBUG
            print("Failed to load shared-by name: \(error)")
            #endif
        }
    }

    private func deleteCountdown() {
        Task {
            do {
                // Clean up photo from storage if exists
                if countdown.imageUrl != nil {
                    try? await ImageUploadService.shared.deleteImage(
                        bucket: SupabaseConfig.countdownPhotosBucket,
                        path: "countdowns/\(countdown.id.uuidString)/photo.jpg"
                    )
                }

                try await appState.countdownRepository.deleteCountdown(id: countdown.id)
                NotificationCenter.default.post(name: .countdownsDidChange, object: nil)
                dismiss()
            } catch {
                print("Error deleting countdown: \(error)")
            }
        }
    }

    private func loadGroupDayInfo(groupId: UUID) async {
        do {
            let groupCountdowns = try await appState.countdownRepository.getCountdownsByGroupId(groupId)
            let sorted = groupCountdowns.sorted { $0.date < $1.date }
            if let index = sorted.firstIndex(where: { $0.id == countdown.id }) {
                groupDayInfo = (current: index + 1, total: sorted.count)
            }
        } catch {
            #if DEBUG
            print("Failed to load group day info: \(error)")
            #endif
        }
    }

    private func deleteAllGroupDays() {
        guard let groupId = countdown.groupId else { return }
        Task {
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
                    try? await appState.familyCalendarRepository.deleteShareForEvent(
                        eventType: .countdown,
                        eventId: cd.id
                    )
                }
                try await appState.countdownRepository.deleteCountdownsByGroupId(groupId)
                NotificationCenter.default.post(name: .countdownsDidChange, object: nil)
                dismiss()
            } catch {
                print("Error deleting countdown group: \(error)")
            }
        }
    }

    private func removeSharedCountdown() async {
        isDeleting = true
        do {
            try await appState.familyCalendarRepository.removeSelfFromShare(
                eventType: .countdown, eventId: countdown.id
            )
            NotificationCenter.default.post(name: .countdownsDidChange, object: nil)
            dismiss()
        } catch {
            isDeleting = false
        }
    }
}

// MARK: - Preview
#Preview {
    CountdownDetailView(
        countdown: Countdown(
            id: UUID(),
            accountId: UUID(),
            title: "Wedding Anniversary",
            date: Date().addingTimeInterval(86400 * 30),
            type: .anniversary,
            notes: "Remember to book a restaurant!",
            reminderOffsetMinutes: 1440,
            isRecurring: true
        )
    )
    .environmentObject(AppState.forPreview())
}
