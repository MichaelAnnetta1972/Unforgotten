import SwiftUI

// MARK: - Birthdays View
struct BirthdaysView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.iPadAddCountdownAction) private var iPadAddCountdownAction
    @Environment(\.iPadEditCountdownAction) private var iPadEditCountdownAction
    @Environment(\.appAccentColor) private var appAccentColor
    @StateObject private var viewModel = BirthdaysViewModel()
    @State private var showSettings = false
    @State private var showAddCountdown = false
    @State private var showEditCountdown = false
    @State private var showUpgradeSheet = false
    @State private var countdownToEdit: Countdown?
    @State private var countdownToDelete: Countdown?
    @State private var showDeleteConfirmation = false

    /// Whether the current user can add/edit items
    private var canEdit: Bool {
        appState.canEdit
    }

    /// Check if user can create another countdown
    private var canCreateCountdown: Bool {
        PremiumLimitsManager.shared.canCreateCountdown(appState: appState, currentCount: viewModel.countdowns.count)
    }

    /// Check if user has premium access
    private var hasPremiumAccess: Bool {
        PremiumLimitsManager.shared.hasPremiumAccess(appState: appState)
    }

    /// Check if user has reached the free tier countdown limit
    private var hasReachedCountdownLimit: Bool {
        !hasPremiumAccess && viewModel.countdowns.count >= PremiumLimitsManager.FreeTierLimits.countdowns
    }

    /// Whether we're on iPad (using full-screen overlay)
    private var isiPad: Bool {
        iPadAddCountdownAction != nil
    }

    /// Open the add countdown modal (uses iPad overlay or local sheet)
    private func openAddCountdown() {
        // Check limit before opening
        guard canCreateCountdown else {
            showUpgradeSheet = true
            return
        }

        if let iPadAction = iPadAddCountdownAction {
            iPadAction()
        } else {
            showAddCountdown = true
        }
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header scrolls with content - uses style-based assets from HeaderStyleManager
                    CustomizableHeaderView(
                        pageIdentifier: .birthdays,
                        title: "Birthdays & Countdowns",
                        showBackButton: iPadHomeAction == nil,
                        backAction: { dismiss() },
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction,
                        showAddButton: canEdit,
                        addAction: canEdit ? openAddCountdown : nil
                    )

                    // Content
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Premium limit reached card - show at top when countdown limit reached
                        if hasReachedCountdownLimit {
                            PremiumFeatureLockBanner(
                                feature: .countdowns,
                                onUpgrade: { showUpgradeSheet = true }
                            )
                        }

                        // Combined event list
                        LazyVStack(spacing: AppDimensions.cardSpacing) {
                            ForEach(viewModel.upcomingEvents) { event in
                                switch event {
                                case .birthday(let birthday):
                                    NavigationLink(destination: ProfileDetailView(profile: birthday.profile)) {
                                        BirthdayCard(birthday: birthday)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                case .countdown(let countdown):
                                    CountdownCard(
                                        countdown: countdown,
                                        onEdit: {
                                            // Use iPad side panel if available
                                            if let iPadEditAction = iPadEditCountdownAction {
                                                iPadEditAction(countdown)
                                            } else {
                                                countdownToEdit = countdown
                                                showEditCountdown = true
                                            }
                                        },
                                        onDelete: {
                                            countdownToDelete = countdown
                                            showDeleteConfirmation = true
                                        }
                                    )
                                }
                            }
                        }

                        // Loading state
                        if viewModel.isLoading && viewModel.upcomingEvents.isEmpty {
                            LoadingView(message: "Loading...")
                                .padding(.top, 40)
                        }

                        // Empty state
                        if viewModel.upcomingEvents.isEmpty && !viewModel.isLoading {
                            VStack(spacing: 16) {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.textSecondary)

                                Text("No Upcoming Events")
                                    .font(.appTitle)
                                    .foregroundColor(.textPrimary)

                                Text("Add birthdays to profiles or create countdown events")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)

                                if canEdit {
                                    PrimaryButton(
                                        title: "Add Countdown",
                                        backgroundColor: appAccentColor
                                    ) {
                                        openAddCountdown()
                                    }
                                    .padding(.horizontal, 32)
                                    .padding(.top, 8)
                                }
                            }
                            .padding(.top, 40)
                        }

                        // Bottom spacing for nav bar
                        Spacer()
                            .frame(height: 120)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showSettings) {
            SettingsPanelView(onDismiss: { showSettings = false })
        }
        .conditionalSidePanel(isPresented: $showAddCountdown, showPanel: !isiPad) {
            AddCountdownView(
                onDismiss: { showAddCountdown = false }
            ) { _ in
                Task {
                    await viewModel.loadData(appState: appState)
                }
            }
        }
        .conditionalSidePanel(isPresented: $showEditCountdown, showPanel: !isiPad) {
            if let countdown = countdownToEdit {
                EditCountdownView(
                    countdown: countdown,
                    onDismiss: {
                        showEditCountdown = false
                        countdownToEdit = nil
                    }
                ) { _ in
                    Task {
                        await viewModel.loadData(appState: appState)
                    }
                    showEditCountdown = false
                    countdownToEdit = nil
                }
            }
        }
        .task {
            await viewModel.loadData(appState: appState)
        }
        .refreshable {
            await viewModel.loadData(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            Task {
                await viewModel.loadData(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .countdownsDidChange)) { _ in
            Task {
                await viewModel.loadData(appState: appState)
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .alert("Delete Countdown", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                countdownToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let countdown = countdownToDelete {
                    Task {
                        await viewModel.deleteCountdown(id: countdown.id, appState: appState)
                        countdownToDelete = nil
                    }
                }
            }
        } message: {
            if let countdown = countdownToDelete {
                Text("Are you sure you want to delete \"\(countdown.title)\"? This action cannot be undone.")
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
        }
    }
}

// MARK: - Birthday Card
struct BirthdayCard: View {
    let birthday: UpcomingBirthday
    @Environment(\.appAccentColor) private var appAccentColor

    private var countdownText: String {
        if birthday.daysUntil == 0 {
            return "Today!"
        } else if birthday.daysUntil == 1 {
            return "1 day"
        } else {
            return "\(birthday.daysUntil) days"
        }
    }

    private var turningAge: Int? {
        guard let age = birthday.profile.age else { return nil }
        return age + 1
    }

    var body: some View {
        HStack(alignment: .center) {
            // Left side - Birthday icon
            Image(systemName: "gift.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(8)

            // Middle - Name with days badge, and date below
            VStack(alignment: .leading, spacing: 4) {
                // Name and days badge on same line
                HStack(spacing: 12) {
                    Text(birthday.profile.displayName)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)

                    // Memorial heart icon if deceased
                    if birthday.profile.isDeceased {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.textMuted)
                    }

                    // Days countdown pill
                    Text(countdownText)
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cardBackgroundLight)
                        .cornerRadius(16)
                }

                // Type label and date below
                HStack(spacing: 8) {
                    Text("Birthday")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    if let bday = birthday.profile.birthday {
                        Text(bday.formattedBirthdayWithOrdinal())
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }
            }

            Spacer()

            // Right side - Age badge (show "Would be" for deceased)
            if let age = turningAge {
                VStack(spacing: 1) {
                    Text(birthday.profile.isDeceased ? "Would be" : "Turns")
                        .font(.appCaption)
                        .foregroundColor(appAccentColor)

                    Text("\(age)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cardBackgroundLight.opacity(0.4))
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Countdown Card
struct CountdownCard: View {
    let countdown: Countdown
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var countdownText: String {
        let days = countdown.daysUntilNextOccurrence
        if days == 0 {
            return "Today!"
        } else if days == 1 {
            return "1 day"
        } else {
            return "\(days) days"
        }
    }

    /// Adaptive button size for iPad
    private var buttonSize: CGFloat {
        horizontalSizeClass == .regular ? 52 : 44
    }

    var body: some View {
        HStack(alignment: .center) {
            // Left side - Type icon
            Image(systemName: countdown.type.icon)
                .font(.system(size: 20))
                .foregroundColor(countdown.type.color)
                .frame(width: 40, height: 40)
                .background(countdown.type.color.opacity(0.15))
                .cornerRadius(8)

            // Middle - Title and type/date info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text(countdown.title)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)

                    // Recurring indicator
                    if countdown.isRecurring {
                        Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                            .font(.system(size: 12))
                            .foregroundColor(.textMuted)
                    }

                    // Days countdown pill
                    Text(countdownText)
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cardBackgroundLight)
                        .cornerRadius(16)
                }

                HStack(spacing: 8) {
                    Text(countdown.displayTypeName)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    Text(countdown.date.formattedBirthdayWithOrdinal())
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            // Edit button
            Button {
                onEdit()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
                    .foregroundColor(.textMuted)
                    .frame(width: buttonSize, height: buttonSize)
                    .cornerRadius(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
                    .foregroundColor(.medicalRed)
                    .frame(width: buttonSize, height: buttonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Birthdays View Model
@MainActor
class BirthdaysViewModel: ObservableObject {
    @Published var upcomingBirthdays: [UpcomingBirthday] = []
    @Published var countdowns: [Countdown] = []
    @Published var upcomingEvents: [UpcomingEvent] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadData(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            // Load birthdays
            let profiles = try await appState.profileRepository.getUpcomingBirthdays(accountId: account.id, days: 365)
            upcomingBirthdays = profiles.compactMap { profile in
                guard let birthday = profile.birthday else { return nil }
                let daysUntil = birthday.daysUntilNextOccurrence()
                return UpcomingBirthday(profile: profile, daysUntil: daysUntil)
            }

            // Load countdowns
            countdowns = try await appState.countdownRepository.getUpcomingCountdowns(accountId: account.id, days: 365)

            // Combine into unified events list
            var events: [UpcomingEvent] = []
            events.append(contentsOf: upcomingBirthdays.map { .birthday($0) })
            events.append(contentsOf: countdowns.map { .countdown($0) })

            // Sort by days until occurrence
            upcomingEvents = events.sorted { $0.daysUntil < $1.daysUntil }

        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    func loadBirthdays(appState: AppState) async {
        await loadData(appState: appState)
    }

    func deleteCountdown(id: UUID, appState: AppState) async {
        do {
            try await appState.countdownRepository.deleteCountdown(id: id)
            // Cancel any scheduled notification
            await NotificationService.shared.cancelCountdownReminder(countdownId: id)
            // Remove from local list
            countdowns.removeAll { $0.id == id }
            upcomingEvents.removeAll { event in
                if case .countdown(let countdown) = event {
                    return countdown.id == id
                }
                return false
            }
        } catch {
            self.error = "Failed to delete countdown: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        BirthdaysView()
            .environmentObject(AppState())
    }
}
