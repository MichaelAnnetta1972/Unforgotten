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
    @Environment(\.appAccentColor) private var appAccentColor
    @StateObject private var viewModel = CountdownEventsViewModel()
    @State private var showSettings = false
    @State private var showAddCountdown = false
    @State private var showUpgradeSheet = false
    @State private var countdownToDelete: Countdown?
    @State private var groupToDelete: Countdown?
    @State private var sharedCountdownToRemove: Countdown?
    @State private var searchText = ""
    @State private var selectedType: CountdownType?
    @State private var selectedCustomTypeName: String?

    /// Whether the current user can add/edit items
    private var canEdit: Bool {
        appState.canEdit
    }

    /// Count distinct events (grouped multi-day events count as 1)
    private var distinctCountdownCount: Int {
        var seenGroups: Set<UUID> = []
        var count = 0
        for cd in viewModel.countdowns {
            if let groupId = cd.groupId {
                if seenGroups.insert(groupId).inserted { count += 1 }
            } else {
                count += 1
            }
        }
        return count
    }

    /// Check if user can create another countdown
    private var canCreateCountdown: Bool {
        PremiumLimitsManager.shared.canCreateCountdown(appState: appState, currentCount: distinctCountdownCount)
    }

    /// Check if user has premium access
    private var hasPremiumAccess: Bool {
        PremiumLimitsManager.shared.hasPremiumAccess(appState: appState)
    }

    /// Check if user has reached the free tier countdown limit
    private var hasReachedCountdownLimit: Bool {
        !hasPremiumAccess && distinctCountdownCount >= PremiumLimitsManager.FreeTierLimits.countdowns
    }

    /// Whether we're on iPad (using full-screen overlay)
    private var isiPad: Bool {
        iPadAddCountdownAction != nil
    }

    /// Types that are actually used by existing countdowns (excluding .custom which is shown by name)
    private var availableTypes: [CountdownType] {
        let usedTypes = Set(viewModel.countdowns.map { $0.type })
        return CountdownType.allCases.filter { usedTypes.contains($0) && $0 != .custom }
    }

    /// Unique custom type names used by existing countdowns
    private var availableCustomTypeNames: [String] {
        let names = viewModel.countdowns
            .filter { $0.type == .custom }
            .compactMap { $0.customType }
        return Array(Set(names)).sorted()
    }

    /// Whether a filter is active
    private var isFilterActive: Bool {
        selectedType != nil || selectedCustomTypeName != nil
    }

    /// Countdowns filtered by search text and selected type
    private var filteredCountdowns: [Countdown] {
        var results = viewModel.countdowns

        if let customName = selectedCustomTypeName {
            results = results.filter { $0.type == .custom && $0.customType == customName }
        } else if let type = selectedType {
            results = results.filter { $0.type == type }
        }

        if !searchText.isEmpty {
            results = results.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        return results
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

    /// Estimated height for the embedded List (scroll-disabled inside outer ScrollView)
    private var estimatedListHeight: CGFloat {
        let rowHeight: CGFloat = 100
        let spacing: CGFloat = AppDimensions.cardSpacing
        return CGFloat(filteredCountdowns.count) * (rowHeight + spacing)
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
                        // Search and filter row
                        if !viewModel.countdowns.isEmpty {
                            HStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.textSecondary)

                                    TextField("Search events", text: $searchText)
                                        .font(.appBody)
                                        .foregroundColor(.textPrimary)
                                }
                                .padding(AppDimensions.cardPadding)
                                .background(Color.cardBackground)
                                .cornerRadius(AppDimensions.cardCornerRadius)

                                Menu {
                                    Button {
                                        selectedType = nil
                                        selectedCustomTypeName = nil
                                    } label: {
                                        if !isFilterActive {
                                            Label("All", systemImage: "checkmark")
                                        } else {
                                            Text("All")
                                        }
                                    }

                                    ForEach(availableTypes) { type in
                                        Button {
                                            selectedType = type
                                            selectedCustomTypeName = nil
                                        } label: {
                                            if selectedType == type && selectedCustomTypeName == nil {
                                                Label(type.displayName, systemImage: "checkmark")
                                            } else {
                                                Label(type.displayName, systemImage: type.icon)
                                            }
                                        }
                                    }

                                    ForEach(availableCustomTypeNames, id: \.self) { name in
                                        Button {
                                            selectedType = nil
                                            selectedCustomTypeName = name
                                        } label: {
                                            if selectedCustomTypeName == name {
                                                Label(name, systemImage: "checkmark")
                                            } else {
                                                Label(name, systemImage: CountdownType.custom.icon)
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(isFilterActive ? appAccentColor : .textSecondary)
                                        .frame(width: 44, height: 44)
                                        .background(Color.cardBackground)
                                        .cornerRadius(AppDimensions.cardCornerRadius)
                                }
                                .tint(appAccentColor)
                            }
                        }

                        // Premium limit reached card
                        if hasReachedCountdownLimit {
                            PremiumFeatureLockBanner(
                                feature: .countdowns,
                                onUpgrade: { showUpgradeSheet = true }
                            )
                        }

                        // Countdown list with swipe-to-delete
                        if !filteredCountdowns.isEmpty {
                            List {
                                ForEach(filteredCountdowns) { countdown in
                                    ZStack {
                                        NavigationLink(value: countdown) {
                                            EmptyView()
                                        }
                                        .opacity(0)

                                        CountdownEventCard(
                                            countdown: countdown,
                                            isShared: countdown.accountId != appState.currentAccount?.id
                                        )
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        if canEdit && countdown.accountId == appState.currentAccount?.id {
                                            Button(role: .destructive) {
                                                countdownToDelete = countdown
                                            } label: {
                                                Label(countdown.groupId != nil ? "Delete Day" : "Delete", systemImage: "trash")
                                            }
                                            if countdown.groupId != nil {
                                                Button(role: .destructive) {
                                                    groupToDelete = countdown
                                                } label: {
                                                    Label("Delete All", systemImage: "trash.fill")
                                                }
                                                .tint(.orange)
                                            }
                                        } else if countdown.accountId != appState.currentAccount?.id {
                                            // Shared countdown - allow removing from user's view
                                            Button(role: .destructive) {
                                                sharedCountdownToRemove = countdown
                                            } label: {
                                                Label("Remove", systemImage: "eye.slash")
                                            }
                                        }
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: AppDimensions.cardSpacing / 2, leading: 0, bottom: AppDimensions.cardSpacing / 2, trailing: 0))
                                }
                            }
                            .listStyle(.plain)
                            .scrollDisabled(true)
                            .scrollContentBackground(.hidden)
                            .frame(height: estimatedListHeight)
                        }

                        // Loading state
                        if viewModel.isLoading && viewModel.countdowns.isEmpty {
                            LoadingView(message: "Loading...")
                                .padding(.top, 40)
                        }

                        // Empty state - no results from search/filter
                        if !viewModel.countdowns.isEmpty && filteredCountdowns.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.textSecondary)

                                Text("No matching events")
                                    .font(.appCardTitle)
                                    .foregroundColor(.textPrimary)

                                Text("Try adjusting your search or filter")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                            }
                            .padding(.top, 40)
                        }

                        // Empty state - no countdowns at all
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
        .navigationDestination(for: Countdown.self) { countdown in
            CountdownDetailView(countdown: countdown)
        }
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
        .alert("Delete Event", isPresented: .init(
            get: { countdownToDelete != nil },
            set: { if !$0 { countdownToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let countdown = countdownToDelete {
                    Task {
                        await viewModel.deleteCountdown(id: countdown.id, appState: appState)
                    }
                    countdownToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                countdownToDelete = nil
            }
        } message: {
            if let countdown = countdownToDelete {
                Text("Are you sure you want to delete \"\(countdown.title)\"?")
            }
        }
        .alert("Delete All Days", isPresented: .init(
            get: { groupToDelete != nil },
            set: { if !$0 { groupToDelete = nil } }
        )) {
            Button("Delete All Days", role: .destructive) {
                if let countdown = groupToDelete, let groupId = countdown.groupId {
                    Task {
                        await viewModel.deleteCountdownGroup(groupId: groupId, appState: appState)
                    }
                    groupToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                groupToDelete = nil
            }
        } message: {
            if let countdown = groupToDelete {
                Text("This will delete all days of \"\(countdown.title)\". This action cannot be undone.")
            }
        }
        .alert("Remove Shared Event", isPresented: .init(
            get: { sharedCountdownToRemove != nil },
            set: { if !$0 { sharedCountdownToRemove = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let countdown = sharedCountdownToRemove {
                    Task {
                        await viewModel.removeSharedCountdown(id: countdown.id, appState: appState)
                    }
                    sharedCountdownToRemove = nil
                }
            }
            Button("Cancel", role: .cancel) {
                sharedCountdownToRemove = nil
            }
        } message: {
            if let countdown = sharedCountdownToRemove {
                Text("Remove \"\(countdown.title)\" from your events? The original owner will still have this event.")
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
    var isShared: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appAccentColor) private var appAccentColor


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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left side - Type icon
            Image(systemName: countdown.type.icon)
                .font(.system(size: 20))
                .foregroundColor(appAccentColor)
                .frame(width: 40, height: 40)
                .background(appAccentColor.opacity(0.15))
                .cornerRadius(8)

            // Middle - Title and type/date info
            VStack(alignment: .leading, spacing: 6) {
                // Title with recurring indicator (wraps to multiple lines)
                HStack(alignment: .top, spacing: 6) {
                    Text(countdown.title)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Shared indicator
                    if isShared {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.textMuted)
                    }

                    // Recurring indicator
                    if countdown.isRecurring {
                        Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                            .font(.system(size: 12))
                            .foregroundColor(.textMuted)
                    }
                }

                // Subtitle (if present)
                if let subtitle = countdown.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }

                // Type and date info
                HStack(spacing: 8) {
                    // Days countdown pill
                    Text(countdownText)
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cardBackgroundLight)
                        .cornerRadius(16)
                    Text(countdown.formattedDateShort)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
            // Load own countdowns sorted by days until next occurrence
            var allCountdowns = try await appState.countdownRepository.getUpcomingCountdowns(accountId: account.id, days: 365)

            // Also load shared countdowns from other accounts (via RPC to bypass RLS)
            let ownIds = Set(allCountdowns.map { $0.id })
            if let shared = try? await appState.countdownRepository.getSharedCountdowns() {
                let newShared = shared.filter { !ownIds.contains($0.id) }
                if !newShared.isEmpty {
                    allCountdowns.append(contentsOf: newShared)
                    allCountdowns.sort { $0.daysUntilNextOccurrence < $1.daysUntilNextOccurrence }
                }
            }

            countdowns = allCountdowns
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
            // Then load the updated data including shared countdowns
            await loadData(appState: appState)
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }
    }

    func deleteCountdown(id: UUID, appState: AppState) async {
        do {
            // Clean up photo from storage if exists
            if let countdown = countdowns.first(where: { $0.id == id }), countdown.imageUrl != nil {
                try? await ImageUploadService.shared.deleteImage(
                    bucket: SupabaseConfig.countdownPhotosBucket,
                    path: "countdowns/\(id.uuidString)/photo.jpg"
                )
            }

            try await appState.countdownRepository.deleteCountdown(id: id)
            // Cancel any scheduled notification
            await NotificationService.shared.cancelCountdownReminder(countdownId: id)
            // Remove from local list
            countdowns.removeAll { $0.id == id }
        } catch {
            self.error = "Failed to delete countdown: \(error.localizedDescription)"
        }
    }

    /// Delete all countdowns in a group
    func deleteCountdownGroup(groupId: UUID, appState: AppState) async {
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
            countdowns.removeAll { $0.groupId == groupId }
        } catch {
            self.error = "Failed to delete group: \(error.localizedDescription)"
        }
    }

    /// Remove a shared countdown from the current user's view by unsubscribing from the share
    func removeSharedCountdown(id: UUID, appState: AppState) async {
        do {
            try await appState.familyCalendarRepository.removeSelfFromShare(
                eventType: .countdown, eventId: id
            )
            countdowns.removeAll { $0.id == id }
        } catch {
            self.error = "Failed to remove shared event: \(error.localizedDescription)"
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
