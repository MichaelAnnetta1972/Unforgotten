//
//  iPadStickyReminderViews.swift
//  Unforgotten
//
//  iPad-specific views for Sticky Reminders feature
//

import SwiftUI

// MARK: - iPad Sticky Reminders View (Uses full-screen overlay for detail)
struct iPadStickyRemindersView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedReminder: StickyReminder?
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadViewStickyReminderAction) private var iPadViewStickyReminderAction

    var body: some View {
        iPadStickyRemindersListView(
            selectedReminder: $selectedReminder,
            useNavigationLinks: false,
            onReminderSelected: { reminder in
                // Use the full-screen overlay action if available
                if let viewAction = iPadViewStickyReminderAction {
                    viewAction(reminder)
                } else {
                    selectedReminder = reminder
                }
            }
        )
        .background(Color.appBackground)
        .navigationBarHidden(true)
    }
}

// MARK: - iPad Sticky Reminders List View
struct iPadStickyRemindersListView: View {
    @Binding var selectedReminder: StickyReminder?
    var useNavigationLinks: Bool = false
    var onReminderSelected: ((StickyReminder) -> Void)? = nil
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.iPadAddStickyReminderAction) private var iPadAddStickyReminderAction

    @State private var reminders: [StickyReminder] = []
    @State private var isLoading = true
    @State private var showAddReminder = false
    @State private var errorMessage: String?

    /// Whether the current user can add/edit sticky reminders
    private var canEdit: Bool {
        appState.canEdit
    }

    private var activeReminders: [StickyReminder] {
        reminders.filter { !$0.isDismissed && $0.isActive }
    }

    private var dismissedReminders: [StickyReminder] {
        reminders.filter { $0.isDismissed || !$0.isActive }
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    CustomizableHeaderView(
                        pageIdentifier: .stickyReminders,
                        title: "Sticky Reminders",
                        showBackButton: false,
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction,
                        showAddButton: canEdit,
                        addAction: canEdit ? {
                            // Use centralized iPad action if available (shows side panel)
                            if let addAction = iPadAddStickyReminderAction {
                                addAction()
                            } else {
                                showAddReminder = true
                            }
                        } : nil
                    )

                    // Content
                    VStack(spacing: AppDimensions.cardSpacing) {
                        if isLoading {
                            LoadingView()
                                .frame(height: 200)
                        } else if reminders.isEmpty {
                            emptyStateView
                        } else {
                            // Active Reminders Section
                            if !activeReminders.isEmpty {
                                sectionHeader("Active Reminders", count: activeReminders.count)
                                ForEach(activeReminders) { reminder in
                                    if useNavigationLinks {
                                        // Portrait mode: Use NavigationLink for standard push transition
                                        NavigationLink(destination: NavigationStickyReminderDetailView(reminder: reminder)) {
                                            iPadStickyReminderListCard(
                                                reminder: reminder,
                                                isSelected: false,
                                                onDismiss: { dismissReminder(reminder) },
                                                onDelete: { deleteReminder(reminder) }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        // Use button to show in floating panel
                                        Button {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                selectedReminder = reminder
                                                onReminderSelected?(reminder)
                                            }
                                        } label: {
                                            iPadStickyReminderListCard(
                                                reminder: reminder,
                                                isSelected: selectedReminder?.id == reminder.id,
                                                onDismiss: { dismissReminder(reminder) },
                                                onDelete: { deleteReminder(reminder) }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            // Dismissed Reminders Section
                            if !dismissedReminders.isEmpty {
                                sectionHeader("Dismissed", count: dismissedReminders.count)
                                ForEach(dismissedReminders) { reminder in
                                    if useNavigationLinks {
                                        // Portrait mode: Use NavigationLink for standard push transition
                                        NavigationLink(destination: NavigationStickyReminderDetailView(reminder: reminder)) {
                                            iPadStickyReminderListCard(
                                                reminder: reminder,
                                                isSelected: false,
                                                onReactivate: { reactivateReminder(reminder) },
                                                onDelete: { deleteReminder(reminder) }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        // Use button to show in floating panel
                                        Button {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                selectedReminder = reminder
                                                onReminderSelected?(reminder)
                                            }
                                        } label: {
                                            iPadStickyReminderListCard(
                                                reminder: reminder,
                                                isSelected: selectedReminder?.id == reminder.id,
                                                onReactivate: { reactivateReminder(reminder) },
                                                onDelete: { deleteReminder(reminder) }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Bottom spacing
                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .fullScreenCover(isPresented: $showAddReminder) {
            AddStickyReminderView(
                onSave: { newReminder in
                    reminders.insert(newReminder, at: 0)
                    if !useNavigationLinks {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedReminder = newReminder
                        }
                    }
                    NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
                    showAddReminder = false
                },
                onDismiss: { showAddReminder = false }
            )
            .environmentObject(appState)
        }
        .task {
            await loadReminders()
        }
        .refreshable {
            await loadReminders()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stickyRemindersDidChange)) { _ in
            Task {
                await loadReminders()
            }
        }
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.appCaption)
                .fontWeight(.semibold)
                .foregroundColor(appAccentColor)

            Spacer()

            Text("\(count)")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge")
                .font(.system(size: 60))
                .foregroundColor(.textSecondary)

            Text("No Sticky Reminders")
                .font(.appTitle)
                .foregroundColor(.textPrimary)

            // Info card
            stickyReminderInfoCard
                .padding(.horizontal, 16)

            Button {
                // Use centralized iPad action if available (shows side panel)
                if let addAction = iPadAddStickyReminderAction {
                    addAction()
                } else {
                    showAddReminder = true
                }
            } label: {
                Text("Add Reminder")
                    .font(.appBodyMedium)
                    .foregroundColor(.black)
                    .frame(width: 200)
                    .padding(.vertical, 14)
                    .background(appAccentColor)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: 400)
        .padding(.vertical, 60)
    }

    // MARK: - Info Card
    private var stickyReminderInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(appAccentColor)

                Text("How Sticky Reminders Work")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                stickyReminderInfoRow(icon: "bell.badge", text: "You'll receive notifications at your chosen frequency")
                stickyReminderInfoRow(icon: "repeat", text: "Reminders repeat until you dismiss them in the app")
                stickyReminderInfoRow(icon: "hand.tap", text: "Open the app and tap 'Dismiss' to stop notifications")
            }
        }
        .padding()
        .background(appAccentColor.opacity(0.2))
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    private func stickyReminderInfoRow(icon: String, text: String) -> some View {
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

    // MARK: - Actions
    private func loadReminders() async {
        guard let account = appState.currentAccount else { return }
        isLoading = true

        do {
            reminders = try await appState.stickyReminderRepository.getReminders(accountId: account.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func dismissReminder(_ reminder: StickyReminder) {
        Task {
            do {
                let updated = try await appState.stickyReminderRepository.dismissReminder(id: reminder.id)
                if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                    reminders[index] = updated
                }
                if selectedReminder?.id == reminder.id {
                    selectedReminder = updated
                }
                await NotificationService.shared.cancelStickyReminder(reminderId: reminder.id)
                NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reactivateReminder(_ reminder: StickyReminder) {
        Task {
            do {
                let updated = try await appState.stickyReminderRepository.reactivateReminder(id: reminder.id)
                if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                    reminders[index] = updated
                }
                if selectedReminder?.id == reminder.id {
                    selectedReminder = updated
                }
                await NotificationService.shared.scheduleStickyReminder(reminder: updated)
                NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteReminder(_ reminder: StickyReminder) {
        Task {
            do {
                try await appState.stickyReminderRepository.deleteReminder(id: reminder.id)
                reminders.removeAll { $0.id == reminder.id }
                if selectedReminder?.id == reminder.id {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedReminder = nil
                    }
                }
                await NotificationService.shared.cancelStickyReminder(reminderId: reminder.id)
                NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - iPad Sticky Reminder List Card
struct iPadStickyReminderListCard: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let reminder: StickyReminder
    let isSelected: Bool
    var onDismiss: (() -> Void)?
    var onReactivate: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(reminder.isDismissed ? Color.textSecondary.opacity(0.2) : appAccentColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: reminder.isDismissed ? "bell.slash" : "bell.badge.fill")
                    .font(.system(size: 20))
                    .foregroundColor(reminder.isDismissed ? .textSecondary : appAccentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.appBodyMedium)
                    .foregroundColor(reminder.isDismissed ? .textSecondary : .textPrimary)

                // Info details
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: reminder.repeatInterval.icon)
                            .font(.system(size: 11))
                        Text(reminder.repeatInterval.displayName)
                            .font(.appCaption)
                    }
                    .foregroundColor(.textSecondary)

                    // Status badge
                    if reminder.isDismissed {
                        Text("Dismissed")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.textSecondary.opacity(0.2))
                            .clipShape(Capsule())
                    } else if reminder.shouldNotify {
                        Text("Active")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(appAccentColor)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Chevron
            if !isSelected {
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(isSelected ? appAccentColor.opacity(0.1) : Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                .stroke(isSelected ? appAccentColor : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - iPad Sticky Reminder Detail View
struct iPadStickyReminderDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadEditStickyReminderAction) private var iPadEditStickyReminderAction

    let reminder: StickyReminder
    let onClose: () -> Void
    var onUpdate: ((StickyReminder) -> Void)?
    var onEdit: ((StickyReminder) -> Void)?

    @State private var showEditReminder = false
    @State private var showDeleteConfirmation = false

    /// Whether the current user can edit
    private var canEdit: Bool {
        appState.canEdit
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

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
                            .frame(height: 40)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
        }
        .fullScreenCover(isPresented: $showEditReminder) {
            AddStickyReminderView(
                editingReminder: reminder,
                onSave: { updatedReminder in
                    onUpdate?(updatedReminder)
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
            Button(action: onClose) {
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
        .background(Color.appBackgroundLight)
        .clipShape(
            RoundedCorner(radius: 24, corners: [.topLeft])
        )
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
                // Use the onEdit callback if provided (for full-screen overlay context)
                if let onEdit = onEdit {
                    onEdit(reminder)
                } else if let editAction = iPadEditStickyReminderAction {
                    // Fallback to environment action
                    editAction(reminder)
                } else {
                    showEditReminder = true
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
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
                onUpdate?(updated)
                await NotificationService.shared.cancelStickyReminder(reminderId: reminder.id)
                NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
            } catch {
                // Handle error
            }
        }
    }

    private func reactivateReminder() {
        Task {
            do {
                let updated = try await appState.stickyReminderRepository.reactivateReminder(id: reminder.id)
                onUpdate?(updated)
                await NotificationService.shared.scheduleStickyReminder(reminder: updated)
                NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
            } catch {
                // Handle error
            }
        }
    }

    private func deleteReminder() {
        Task {
            do {
                try await appState.stickyReminderRepository.deleteReminder(id: reminder.id)
                await NotificationService.shared.cancelStickyReminder(reminderId: reminder.id)
                NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
                onClose()
            } catch {
                // Handle error
            }
        }
    }
}

// MARK: - Navigation Sticky Reminder Detail View
/// A navigation-compatible wrapper for iPadStickyReminderDetailView that uses dismiss() for back navigation
struct NavigationStickyReminderDetailView: View {
    let reminder: StickyReminder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        iPadStickyReminderDetailView(
            reminder: reminder,
            onClose: { dismiss() },
            onUpdate: nil // Updates will be picked up via notification
        )
        .navigationBarHidden(true)
    }
}
