import SwiftUI

// MARK: - Countdown Detail View
struct CountdownDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.dismiss) private var dismiss

    @State var countdown: Countdown
    @State private var showEditCountdown = false
    @State private var showDeleteConfirmation = false

    /// Whether the current user can edit
    private var canEdit: Bool {
        appState.canEdit
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
                        // Countdown Card
                        countdownCard

                        // Details Card
                        detailsCard

                        // Notes Card (if notes exist)
                        if let notes = countdown.notes, !notes.isEmpty {
                            notesCard(notes: notes)
                        }

                        // Action Buttons
                        if canEdit {
                            actionButtons
                        }

                        // Bottom spacing
                        Spacer()
                            .frame(height: 40)
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
        .confirmationDialog("Delete Event", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteCountdown()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this event? This cannot be undone.")
        }
    }

    // MARK: - Title Bar
    private var titleBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.cardBackgroundSoft)
                    .clipShape(Circle())
            }

            Text(countdown.title)
                .font(.appTitle)
                .foregroundColor(.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, AppDimensions.screenPadding)
        .padding(.vertical, 12)
        .background(Color.appBackground)
    }

    // MARK: - Countdown Card
    private var countdownCard: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(countdown.type.color.opacity(0.2))
                    .frame(width: 64, height: 64)

                Image(systemName: countdown.type.icon)
                    .font(.system(size: 28))
                    .foregroundColor(countdown.type.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(daysUntilText)
                    .font(.appLargeTitle)
                    .foregroundColor(.textPrimary)

                Text(countdown.date.formattedBirthdayWithOrdinal())
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Recurring badge
            if countdown.isRecurring {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                    Text("Recurring")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
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
                    .foregroundColor(countdown.type.color)
            }

            Divider()

            // Date
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .frame(width: 24)

                Text("Date")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)

                Spacer()

                Text(countdown.date.formattedBirthdayWithOrdinal())
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
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

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Edit button
            Button {
                showEditCountdown = true
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Edit Event")
                }
                .font(.appBodyMedium)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(appAccentColor)
                .cornerRadius(AppDimensions.cardCornerRadius)
            }

            // Delete button
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Event")
                }
                .font(.appBodyMedium)
                .foregroundColor(.medicalRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
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

    private func deleteCountdown() {
        Task {
            do {
                try await appState.countdownRepository.deleteCountdown(id: countdown.id)
                NotificationCenter.default.post(name: .countdownsDidChange, object: nil)
                dismiss()
            } catch {
                print("Error deleting countdown: \(error)")
            }
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
