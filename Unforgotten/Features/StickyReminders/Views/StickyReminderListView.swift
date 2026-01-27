import SwiftUI

// MARK: - Sticky Reminder List View
struct StickyReminderListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var reminders: [StickyReminder] = []
    @State private var isLoading = true
    @State private var showAddReminder = false
    @State private var showUpgradePrompt = false
    @State private var errorMessage: String?

    /// Check if we're in iPad mode (regular size class)
    private var isiPad: Bool {
        horizontalSizeClass == .regular
    }

    /// Whether the current user can add/edit sticky reminders
    private var canEdit: Bool {
        appState.canEdit
    }

    /// Check if user can add more sticky reminders
    private var canAddReminder: Bool {
        PremiumLimitsManager.shared.canCreateStickyReminder(
            appState: appState,
            currentCount: reminders.count
        )
    }

    /// Check if user has premium access
    private var hasPremiumAccess: Bool {
        PremiumLimitsManager.shared.hasPremiumAccess(appState: appState)
    }

    /// Check if user has reached the free tier limit (exactly 5 reminders on free plan)
    private var hasReachedFreeLimit: Bool {
        !hasPremiumAccess && reminders.count >= PremiumLimitsManager.FreeTierLimits.stickyReminders
    }

    private var activeReminders: [StickyReminder] {
        reminders.filter { !$0.isDismissed && $0.isActive }
    }

    private var dismissedReminders: [StickyReminder] {
        reminders.filter { $0.isDismissed || !$0.isActive }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                CustomizableHeaderView(
                    pageIdentifier: .stickyReminders,
                    title: "Sticky Reminders",
                    showBackButton: true,
                    backAction: { dismiss() },
                    showAddButton: canEdit,
                    addAction: canEdit ? {
                        if canAddReminder {
                            showAddReminder = true
                        } else {
                            showUpgradePrompt = true
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
                        // Premium limit reached card - show at top when limit reached
                        if hasReachedFreeLimit {
                            PremiumFeatureLockBanner(
                                feature: .stickyReminders,
                                onUpgrade: { showUpgradePrompt = true }
                            )
                        }

                        // Active Reminders Section
                        if !activeReminders.isEmpty {
                            sectionHeader("Active Reminders", count: activeReminders.count)
                            ForEach(activeReminders) { reminder in
                                NavigationLink(destination: StickyReminderDetailView(reminder: reminder)) {
                                    StickyReminderCard(reminder: reminder)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        // Dismissed Reminders Section
                        if !dismissedReminders.isEmpty {
                            sectionHeader("Dismissed", count: dismissedReminders.count)
                            ForEach(dismissedReminders) { reminder in
                                NavigationLink(destination: StickyReminderDetailView(reminder: reminder)) {
                                    StickyReminderCard(reminder: reminder)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Bottom spacing
                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.top, AppDimensions.cardSpacing)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackgroundLight)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showAddReminder) {
            AddStickyReminderView(
                onSave: { newReminder in
                    reminders.insert(newReminder, at: 0)
                    NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
                    showAddReminder = false
                },
                onDismiss: { showAddReminder = false }
            )
            .environmentObject(appState)
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
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
            infoCard
                .padding(.horizontal, 16)

            Button {
                if canAddReminder {
                    showAddReminder = true
                } else {
                    showUpgradePrompt = true
                }
            } label: {
                Text("Add Reminder")
                    .font(.appBodyMedium)
                    .foregroundColor(.black)
                    .frame(width: isiPad ? 200 : nil)
                    .padding(.horizontal, isiPad ? 0 : 24)
                    .padding(.vertical, 14)
                    .background(appAccentColor)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: isiPad ? 400 : .infinity)
        .padding(.vertical, 60)
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
        .padding()
        .background(appAccentColor.opacity(0.2))
        .cornerRadius(AppDimensions.cardCornerRadius)
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
}

// MARK: - Sticky Reminder Card
struct StickyReminderCard: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let reminder: StickyReminder

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

                // Info details (frequency and status)
                HStack(spacing: 8) {
                    // Repeat interval
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
                    } else {
                        Text("Scheduled")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(appAccentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(appAccentColor.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Chevron indicator for navigation
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textSecondary.opacity(0.5))
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StickyReminderListView()
            .environmentObject(AppState.forPreview())
    }
}
