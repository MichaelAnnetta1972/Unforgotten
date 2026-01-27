//
//  CountdownEventsView.swift
//  Unforgotten
//
//  Standalone view for managing countdown events
//

import SwiftUI

// MARK: - Countdown Events View
struct CountdownEventsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.iPadAddCountdownAction) private var iPadAddCountdownAction
    @Environment(\.iPadEditCountdownAction) private var iPadEditCountdownAction
    @Environment(\.appAccentColor) private var appAccentColor
    @StateObject private var viewModel = CountdownEventsViewModel()
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
                    // Header scrolls with content
                    CustomizableHeaderView(
                        pageIdentifier: .countdownEvents,
                        title: "Events",
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

                        // Countdown list
                        LazyVStack(spacing: AppDimensions.cardSpacing) {
                            ForEach(viewModel.countdowns) { countdown in
                                CountdownEventCard(
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

                        // Loading state
                        if viewModel.isLoading && viewModel.countdowns.isEmpty {
                            LoadingView(message: "Loading...")
                                .padding(.top, 40)
                        }

                        // Empty state
                        if viewModel.countdowns.isEmpty && !viewModel.isLoading {
                            VStack(spacing: 16) {
                                Image(systemName: "timer")
                                    .font(.system(size: 60))
                                    .foregroundColor(.textSecondary)

                                Text("No Events")
                                    .font(.appTitle)
                                    .foregroundColor(.textPrimary)

                                Text("Create events to track important dates like anniversaries, holidays, and more")
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
                // Use refreshFromRemote to fetch latest data from server
                await viewModel.refreshFromRemote(appState: appState)
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

// MARK: - Countdown Event Card
struct CountdownEventCard: View {
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

    /// Whether to show the type icon (iPad only)
    private var showIcon: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left side - Type icon (iPad only)
            if showIcon {
                Image(systemName: countdown.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(countdown.type.color)
                    .frame(width: 40, height: 40)
                    .background(countdown.type.color.opacity(0.15))
                    .cornerRadius(8)
            }

            // Middle - Title and type/date info
            VStack(alignment: .leading, spacing: 6) {
                // Title with recurring indicator (wraps to multiple lines)
                HStack(alignment: .top, spacing: 6) {
                    Text(countdown.title)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Recurring indicator
                    if countdown.isRecurring {
                        Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                            .font(.system(size: 12))
                            .foregroundColor(.textMuted)
                    }
                }



                // Type and date info
                HStack(spacing: 8) {
                //    Text(countdown.displayTypeName)
                //        .font(.appCaption)
                //        .foregroundColor(.textSecondary)
                
                // Days countdown pill
                Text(countdownText)
                    .font(.appCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cardBackgroundLight)
                    .cornerRadius(16)                    
                Text(countdown.date.formattedBirthdayWithOrdinal())
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            // Action buttons (side by side)
            HStack(spacing: 4) {
                // Edit button
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
                        .foregroundColor(.textMuted)
                        .frame(width: buttonSize, height: buttonSize)
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Countdown Events View Model
@MainActor
class CountdownEventsViewModel: ObservableObject {
    @Published var countdowns: [Countdown] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadData(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            // Load all countdowns sorted by days until next occurrence
            countdowns = try await appState.countdownRepository.getUpcomingCountdowns(accountId: account.id, days: 365)
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    /// Refresh data from the remote server (called when realtime notification received)
    func refreshFromRemote(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        do {
            // Force refresh from server to get latest changes
            _ = try await appState.countdownRepository.refreshFromRemote(accountId: account.id)
            // Then load the updated data
            countdowns = try await appState.countdownRepository.getUpcomingCountdowns(accountId: account.id, days: 365)
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }
    }

    func deleteCountdown(id: UUID, appState: AppState) async {
        do {
            try await appState.countdownRepository.deleteCountdown(id: id)
            // Cancel any scheduled notification
            await NotificationService.shared.cancelCountdownReminder(countdownId: id)
            // Remove from local list
            countdowns.removeAll { $0.id == id }
        } catch {
            self.error = "Failed to delete countdown: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        CountdownEventsView()
            .environmentObject(AppState.forPreview())
    }
}
