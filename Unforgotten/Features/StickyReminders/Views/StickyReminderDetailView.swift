import SwiftUI

// MARK: - Sticky Reminder Detail View (iPhone)
struct StickyReminderDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.dismiss) private var dismiss

    @State var reminder: StickyReminder
    @State private var showEditReminder = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    /// Whether the current user can edit
    private var canEdit: Bool {
        appState.canEdit
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title bar with close button
                titleBar

                ScrollView {
                    // Content
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Status Card
                        statusCard

                        // Details Card
                        detailsCard

                        // Schedule Card
                        scheduleCard

                        // Action Buttons
                        if canEdit {
                            actionButtons
                        }

                        // Bottom spacing
                        Spacer()
                            .frame(height: 80)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showEditReminder) {
            AddStickyReminderView(
                editingReminder: reminder,
                onSave: { updatedReminder in
                    reminder = updatedReminder
                    NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
                    showEditReminder = false
                },
                onDismiss: { showEditReminder = false }
            )
            .environmentObject(appState)
        }
        .confirmationDialog("Delete Reminder", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteReminder()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this reminder? This cannot be undone.")
        }
    }

    // MARK: - Title Bar
    private var titleBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.cardBackgroundSoft)
                    .clipShape(Circle())
            }

            Text(reminder.title)
                .font(.appTitle)
                .foregroundColor(.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, AppDimensions.screenPadding)
        .padding(.vertical, 12)
        .background(Color.appBackground)
    }

    // MARK: - Status Card
    private var statusCard: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(reminder.isDismissed ? Color.textSecondary.opacity(0.2) : appAccentColor.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: reminder.isDismissed ? "bell.slash.fill" : "bell.badge.fill")
                    .font(.system(size: 24))
                    .foregroundColor(reminder.isDismissed ? .textSecondary : appAccentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                Text(reminder.isDismissed ? "Dismissed" : (reminder.shouldNotify ? "Active" : "Scheduled"))
                    .font(.appTitle)
                    .foregroundColor(reminder.isDismissed ? .textSecondary : .textPrimary)
            }

            Spacer()

            // Quick action button
            if canEdit {
                if reminder.isDismissed {
                    Button {
                        reactivateReminder()
                    } label: {
                        Text("Activate")
                            .font(.appBodyMedium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(appAccentColor)
                            .cornerRadius(8)
                    }
                } else {
                    Button {
                        dismissReminder()
                    } label: {
                        Text("Dismiss")
                            .font(.appBodyMedium)
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.cardBackgroundSoft)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Details Card
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DETAILS")
                .font(.appCaption)
                .fontWeight(.semibold)
                .foregroundColor(appAccentColor)

            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                Text(reminder.title)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)
            }

            // Message (if present)
            if let message = reminder.message, !message.isEmpty {
                Divider()
                    .background(Color.textSecondary.opacity(0.2))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Message")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    Text(message)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Schedule Card
    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SCHEDULE")
                .font(.appCaption)
                .fontWeight(.semibold)
                .foregroundColor(appAccentColor)

            // Next notification (only show if active)
            if let nextTime = reminder.nextNotificationTime {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 20))
                        .foregroundColor(appAccentColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Notification")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        Text(nextTime.formatted(date: .abbreviated, time: .shortened))
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                    }
                }

                Divider()
                    .background(Color.textSecondary.opacity(0.2))
            }

            // Repeat interval
            HStack(spacing: 12) {
                Image(systemName: reminder.repeatInterval.icon)
                    .font(.system(size: 20))
                    .foregroundColor(appAccentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Repeat Interval")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    Text(reminder.repeatInterval.displayName)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                }
            }

            Divider()
                .background(Color.textSecondary.opacity(0.2))

            // Start time
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 20))
                    .foregroundColor(appAccentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Started")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    Text(reminder.triggerTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                }
            }

            // Created date
            Divider()
                .background(Color.textSecondary.opacity(0.2))

            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 20))
                    .foregroundColor(appAccentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Created")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    Text(reminder.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Edit button
            Button {
                showEditReminder = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                    Text("Edit Reminder")
                        .font(.appBodyMedium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(appAccentColor)
                .cornerRadius(AppDimensions.buttonCornerRadius)
            }

            // Delete button
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                    Text("Delete Reminder")
                        .font(.appBodyMedium)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.buttonCornerRadius)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions
    private func dismissReminder() {
        Task {
            do {
                let updated = try await appState.stickyReminderRepository.dismissReminder(id: reminder.id)
                reminder = updated
                await NotificationService.shared.cancelStickyReminder(reminderId: reminder.id)
                NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reactivateReminder() {
        Task {
            do {
                let updated = try await appState.stickyReminderRepository.reactivateReminder(id: reminder.id)
                reminder = updated
                await NotificationService.shared.scheduleStickyReminder(reminder: updated)
                NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteReminder() {
        Task {
            do {
                try await appState.stickyReminderRepository.deleteReminder(id: reminder.id)
                await NotificationService.shared.cancelStickyReminder(reminderId: reminder.id)
                NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StickyReminderDetailView(
            reminder: StickyReminder(
                accountId: UUID(),
                title: "Take vitamins",
                message: "Don't forget your morning vitamins with breakfast",
                triggerTime: Date(),
                repeatInterval: StickyReminderInterval(value: 2, unit: .hours)
            )
        )
        .environmentObject(AppState.forPreview())
    }
}
