import SwiftUI

// MARK: - Home Destinations
enum HomeDestination: Hashable {
    case myCard
    case profiles
    case profileDetail(Profile)
    case medications
    case medicationDetail(Medication)
    case appointments
    case appointmentDetail(Appointment)
    case countdownEvents
    case countdownDetail(Countdown)
    case calendar
    case birthdays
    case contacts
    case notes
    case mood
    case todoLists
    case stickyReminders
    case stickyReminderDetail(StickyReminder)
    case mealPlanner
}

// MARK: - Feature Card Data
/// Maps a Feature enum case to its navigation destination and card display data
private struct FeatureCardData: Identifiable {
    let feature: Feature
    let destination: HomeDestination
    let title: String
    let icon: String

    var id: String { feature.rawValue }
}

/// Build a FeatureCardData from a Feature
private func featureCardData(for feature: Feature) -> FeatureCardData? {
    switch feature {
    case .calendar:         return FeatureCardData(feature: feature, destination: .calendar, title: "Calendar", icon: "calendar.badge.clock")
    case .aboutMe:          return FeatureCardData(feature: feature, destination: .myCard, title: "About Me", icon: "person.crop.circle")
    case .familyAndFriends: return FeatureCardData(feature: feature, destination: .profiles, title: "Family and Friends", icon: "person.2")
    case .medications:      return FeatureCardData(feature: feature, destination: .medications, title: "Medications", icon: "pill")
    case .appointments:     return FeatureCardData(feature: feature, destination: .appointments, title: "Appointments", icon: "calendar")
    case .countdownEvents:  return FeatureCardData(feature: feature, destination: .countdownEvents, title: "Events", icon: "timer")
    case .stickyReminders:  return FeatureCardData(feature: feature, destination: .stickyReminders, title: "Sticky Reminders", icon: "pin.fill")
    case .todoLists:        return FeatureCardData(feature: feature, destination: .todoLists, title: "To Do Lists", icon: "checklist")
    case .notes:            return FeatureCardData(feature: feature, destination: .notes, title: "Notes", icon: "note.text")
    case .usefulContacts:   return FeatureCardData(feature: feature, destination: .contacts, title: "Useful Contacts", icon: "phone")
    case .birthdays:        return FeatureCardData(feature: feature, destination: .birthdays, title: "Birthdays", icon: "gift")
    case .moodTracker:      return FeatureCardData(feature: feature, destination: .mood, title: "Mood Tracker", icon: "face.smiling")
    case .mealPlanner:      return FeatureCardData(feature: feature, destination: .mealPlanner, title: "Meal Planner", icon: "fork.knife")
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @State private var showSettings = false
    @State private var showAccountSwitcher = false
    @State private var isReordering = false
    @Environment(\.navNamespace) private var namespace
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(FeatureVisibilityManager.self) private var featureVisibility
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @Environment(HeaderStyleManager.self) private var headerStyleManager

    /// Helper/Viewer roles only see limited features
    private var isLimitedAccess: Bool {
        appState.currentUserRole == .helper || appState.currentUserRole == .viewer
    }

    /// Check if user has premium access (subscription or complimentary)
    private var isPremiumUser: Bool {
        appState.hasPremiumAccess
    }

    /// Check if a feature should be visible based on role AND user preferences
    private func shouldShowFeature(_ feature: Feature) -> Bool {
        // First check user's feature visibility preferences
        guard featureVisibility.isVisible(feature) else { return false }

        // For limited access roles, only show specific features
        if isLimitedAccess {
            switch feature {
            case .aboutMe, .medications, .appointments, .moodTracker, .usefulContacts, .stickyReminders:
                return true
            default:
                return false
            }
        }

        return true
    }

    /// Ordered list of visible feature cards respecting user's custom order
    private var orderedFeatureCards: [FeatureCardData] {
        featureVisibility.orderedVisibleFeatures
            .filter { shouldShowFeature($0) }
            .compactMap { featureCardData(for: $0) }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header scrolls with content - uses style-based assets from HeaderStyleManager
                    CustomizableHeaderView(
                        pageIdentifier: .home,
                        title: "Unforgotten",
                        showAccountSwitcherButton: appState.allAccounts.count > 1,
                        accountSwitcherAction: { showAccountSwitcher = true },
                        //showSettingsButton: true,
                        settingsAction: { showSettings = true },
                        showReorderButton: true,
                        isReordering: isReordering,
                        reorderAction: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isReordering.toggle()
                            }
                        },
                        useLogo: true,
                        logoImageName: "unforgotten-logo"
                    )

                    // Viewing As Bar (shown when viewing another account)
                    ViewingAsBar()

                    // Content
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Today Card (if there are items)
                        if viewModel.hasTodayItems(showBirthdays: !isLimitedAccess) {
                            TodayCard(viewModel: viewModel, showBirthdays: !isLimitedAccess)
                        }

                        // Navigation Cards
                        VStack(spacing: AppDimensions.cardSpacing) {
                            if isReordering {
                                // REORDER MODE: draggable cards
                                ForEach(orderedFeatureCards) { card in
                                    DraggableHomeCard(
                                        title: card.title,
                                        icon: card.icon,
                                        feature: card.feature,
                                        onDrop: { droppedFeature in
                                            guard let fromIndex = orderedFeatureCards.firstIndex(where: { $0.feature == droppedFeature }),
                                                  let toIndex = orderedFeatureCards.firstIndex(where: { $0.feature == card.feature }),
                                                  fromIndex != toIndex else { return }
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                featureVisibility.moveFeature(fromIndex: fromIndex, toIndex: toIndex)
                                            }
                                        }
                                    )
                                }
                            } else {
                                // NORMAL MODE: NavigationLinks
                                ForEach(orderedFeatureCards) { card in
                                    NavigationLink(value: card.destination) {
                                        NavigationCardContent(title: card.title, icon: card.icon)
                                    }
                                    .matchedTransitionSource(id: card.destination, in: namespace)
                                }
                            }
                        }

                        // Upgrade banner (only show for free users on their own account)
                        if !isPremiumUser && !appState.isViewingOtherAccount {
                            HomeUpgradeBanner()
                        }

                        // Bottom spacing
                        Spacer()
                            .frame(height: 140)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color.appBackgroundLight)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showAccountSwitcher) {
            AccountSwitcherModal(isPresented: $showAccountSwitcher)
                .environmentObject(appState)
        }
        .sidePanel(isPresented: $showSettings) {
            SettingsPanelView(onDismiss: { showSettings = false })
                .environment(userPreferences)
                .environment(headerOverrides)
                .environment(headerStyleManager)
                .environment(featureVisibility)
                .environmentObject(appState)
        }
        .task {
            #if DEBUG
            print("🏠 HomeView: Loading data...")
            #endif
            await viewModel.loadData(appState: appState)
            #if DEBUG
            print("🏠 HomeView: Initial load - medications count: \(viewModel.todayMedications.count)")
            #endif
            // Generate today's medication logs if needed
            #if DEBUG
            print("🏠 HomeView: Generating today's medication logs...")
            #endif
            await appState.generateTodaysMedicationLogs()
            // Reload after generating
            #if DEBUG
            print("🏠 HomeView: Reloading after generation...")
            #endif
            await viewModel.loadData(appState: appState)
            #if DEBUG
            print("🏠 HomeView: Final load - medications count: \(viewModel.todayMedications.count)")
            #endif
        }
        .refreshable {
            await viewModel.loadData(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationsDidChange)) { _ in
            Task {
                await appState.generateTodaysMedicationLogs()
                await viewModel.loadData(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appointmentsDidChange)) { notification in
            // Try to handle locally first for instant updates
            if notification.userInfo != nil {
                viewModel.handleAppointmentChange(notification: notification)
            }
            // Also reload in case appointment was created or we need fresh data
            Task {
                await viewModel.loadData(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .countdownsDidChange)) { _ in
            Task {
                // Use refreshCountdownsFromRemote to fetch latest data from server
                await viewModel.refreshCountdownsFromRemote(appState: appState)
            }
        }
        .onChange(of: appState.currentAccount?.id) { _, _ in
            // Reload data when account changes
            Task { @MainActor in
                guard !Task.isCancelled else { return }
                await appState.generateTodaysMedicationLogs()
                guard !Task.isCancelled else { return }
                await viewModel.loadData(appState: appState)
            }
        }
    }
}

// MARK: - Navigation Card Content
struct NavigationCardContent: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let title: String
    let icon: String?

    var body: some View {
        HStack(spacing: 14) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(appAccentColor)
                    .frame(width: 28)
            }

            Text(title)
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(.textSecondary)
        }
        .padding(AppDimensions.cardPaddingLarge)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Draggable Home Card
/// Card displayed during reorder mode with drag-and-drop support
struct DraggableHomeCard: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let title: String
    let icon: String
    let feature: Feature
    let onDrop: (Feature) -> Void

    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(appAccentColor)
                .frame(width: 28)

            Text(title)
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .padding(AppDimensions.cardPaddingLarge)
        .background(isTargeted ? appAccentColor.opacity(0.15) : Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                .stroke(isTargeted ? appAccentColor : Color.clear, lineWidth: 2)
        )
        .draggable(feature)
        .dropDestination(for: Feature.self) { droppedFeatures, _ in
            guard let dropped = droppedFeatures.first else { return false }
            onDrop(dropped)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.2)) {
                isTargeted = targeted
            }
        }
    }
}

// MARK: - Today Card
struct TodayCard: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @ObservedObject var viewModel: HomeViewModel
    @State private var isExpanded = false

    /// Whether to show birthdays (false for Helper/Viewer roles)
    var showBirthdays: Bool = true

    private var filteredItems: [TodayItem] {
        viewModel.allTodayItems(includeBirthdays: showBirthdays)
    }

    private var visibleItems: [TodayItem] {
        let allItems = filteredItems
        if isExpanded {
            return allItems
        } else {
            return Array(allItems.prefix(1))
        }
    }

    private var hasMoreItems: Bool {
        filteredItems.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TODAY")
                    .font(.appCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(appAccentColor)

                Spacer()
            }
            .padding(.horizontal, AppDimensions.cardPadding)
            .padding(.top, AppDimensions.cardPadding)
            .padding(.bottom, 12)

            // Items
            ForEach(visibleItems) { item in
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    switch item {
                    case .medication(let log):
                        TodayMedicationRow(log: log, viewModel: viewModel)
                    case .appointment(let appointment):
                        TodayAppointmentRow(appointment: appointment, viewModel: viewModel)
                    case .birthday(let profile):
                        TodayBirthdayRow(profile: profile)
                    case .countdown(let countdown):
                        TodayCountdownRow(countdown: countdown)
                    }
                }
            }

            // See all button
            if hasMoreItems {
                Divider()
                    .background(Color.white.opacity(0.1))

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(isExpanded ? "Show less" : "See all \(filteredItems.count) items")
                            .font(.appBody)
                            .foregroundColor(appAccentColor)

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(appAccentColor)
                    }
                    .padding(AppDimensions.cardPadding)
                }
            }
        }
        .background(Color.cardBackgroundLight.opacity(0.8))
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Today Item Enum
enum TodayItem: Identifiable {
    case medication(MedicationLog)
    case appointment(Appointment)
    case birthday(Profile)
    case countdown(Countdown)

    var id: String {
        switch self {
        case .medication(let log): return "med-\(log.id)"
        case .appointment(let apt): return "apt-\(apt.id)"
        case .birthday(let profile): return "bday-\(profile.id)"
        case .countdown(let countdown): return "countdown-\(countdown.id)"
        }
    }
}

// MARK: - Today Medication Row
struct TodayMedicationRow: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    let log: MedicationLog
    @ObservedObject var viewModel: HomeViewModel
    @State private var isUpdating = false
    @State private var navigateToDetail = false

    private var medication: Medication? {
        viewModel.medications.first { $0.id == log.medicationId }
    }

    /// Status button text based on current status
    private var statusText: String {
        switch log.status {
        case .scheduled: return "Take"
        case .taken: return "Taken"
        case .skipped: return "Skipped"
        case .missed: return "Missed"
        }
    }

    /// Status button colors based on current status
    private var statusColors: (foreground: Color, background: Color) {
        switch log.status {
        case .scheduled:
            return (.appBackground, appAccentColor)
        case .taken:
            return (appAccentColor, appAccentColor.opacity(0.15))
        case .skipped:
            return (.textSecondary, Color.textSecondary.opacity(0.15))
        case .missed:
            return (.medicalRed, Color.medicalRed.opacity(0.15))
        }
    }

    /// Cycle to the next status when tapped
    private func cycleStatus() async {
        isUpdating = true
        switch log.status {
        case .scheduled:
            await viewModel.markMedicationTaken(log: log, appState: appState)
        case .taken:
            await viewModel.skipMedication(log: log, appState: appState)
        case .skipped:
            await viewModel.markMedicationNotTaken(log: log, appState: appState)
        case .missed:
            await viewModel.markMedicationTaken(log: log, appState: appState)
        }
        isUpdating = false
    }

    var body: some View {
        HStack(spacing: 12) {
            // Tappable area for navigation
            Button {
                navigateToDetail = true
            } label: {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: "pill.fill")
                        .font(.system(size: 18))
                        .foregroundColor(appAccentColor)
                        .frame(width: 32, height: 32)

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.medicationName(for: log))
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)

                        Text(log.scheduledAt.formatted(date: .omitted, time: .shortened))
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Cyclable status button
            Button {
                Task {
                    await cycleStatus()
                }
            } label: {
                if isUpdating {
                    ProgressView()
                        .tint(statusColors.foreground)
                        .frame(width: 70, height: 32)
                        .background(statusColors.background)
                        .cornerRadius(8)
                } else {
                    Text(statusText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(statusColors.foreground)
                        .frame(width: 70, height: 32)
                        .background(statusColors.background)
                        .cornerRadius(8)
                }
            }
            .disabled(isUpdating)
        }
        .padding(AppDimensions.cardPadding)
        .navigationDestination(isPresented: $navigateToDetail) {
            if let medication = medication {
                MedicationDetailView(medication: medication)
            }
        }
    }
}

// MARK: - Today Appointment Row
struct TodayAppointmentRow: View {
    let appointment: Appointment
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var navigateToDetail = false

    var body: some View {
        HStack(spacing: 12) {
            // Tappable area for navigation
            Button {
                navigateToDetail = true
            } label: {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(appAccentColor)
                        .frame(width: 32, height: 32)

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appointment.title)
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)

                        if let time = appointment.time {
                            Text(time.formatted(date: .omitted, time: .shortened))
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        } else {
                            Text("All day")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Toggleable check icon
            Button {
                viewModel.toggleAppointmentCompleted(appointmentId: appointment.id, appState: appState)
            } label: {
                Image(systemName: appointment.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 24))
                    .foregroundColor(appointment.isCompleted ? appAccentColor : .textSecondary.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppDimensions.cardPadding)
        .navigationDestination(isPresented: $navigateToDetail) {
            AppointmentDetailView(appointment: appointment)
        }
    }
}

// MARK: - Today Birthday Row
struct TodayBirthdayRow: View {
    let profile: Profile
    @State private var navigateToDetail = false
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        HStack(spacing: 12) {
            // Tappable area for navigation
            Button {
                navigateToDetail = true
            } label: {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: "gift.fill")
                        .font(.system(size: 18))
                        .foregroundColor(appAccentColor)
                        .frame(width: 32, height: 32)

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(profile.displayName)'s Birthday")
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)

                        if let age = profile.age {
                            Text("Turning \(age + 1)")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppDimensions.cardPadding)
        .navigationDestination(isPresented: $navigateToDetail) {
            ProfileDetailView(profile: profile)
        }
    }
}

// MARK: - Today Countdown Row
struct TodayCountdownRow: View {
    let countdown: Countdown
    @State private var navigateToDetail = false
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button {
            navigateToDetail = true
        } label: {
            HStack(spacing: 12) {
                // Icon - use the countdown type's icon and color
                Image(systemName: countdown.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(appAccentColor)
                    .frame(width: 32, height: 32)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(countdown.title)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)

                    Text(countdown.displayTypeName)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(AppDimensions.cardPadding)
        .navigationDestination(isPresented: $navigateToDetail) {
            CountdownDetailView(countdown: countdown)
        }
    }
}

// MARK: - Home View Model
@MainActor
class HomeViewModel: ObservableObject {
    @Published var todayMedications: [MedicationLog] = []
    @Published var todayAppointments: [Appointment] = []
    @Published var todayBirthdays: [Profile] = []
    @Published var todayCountdowns: [Countdown] = []
    @Published var medications: [Medication] = []
    @Published var isLoading = false
    @Published var error: String?

    func toggleAppointmentCompleted(appointmentId: UUID, appState: AppState) {
        guard let index = todayAppointments.firstIndex(where: { $0.id == appointmentId }) else { return }
        let newStatus = !todayAppointments[index].isCompleted

        // Update locally first for immediate UI feedback
        todayAppointments[index].isCompleted = newStatus
        let updatedAppointment = todayAppointments[index]

        // Persist to database and update notification
        Task {
            do {
                let saved = try await appState.appointmentRepository.toggleAppointmentCompletion(id: appointmentId, isCompleted: newStatus)

                // Cancel or reschedule notification based on completion status
                if newStatus {
                    // Completed - cancel the notification
                    await NotificationService.shared.cancelAppointmentReminder(appointmentId: appointmentId)
                } else {
                    // Uncompleted - reschedule the notification if in the future
                    if updatedAppointment.dateTime > Date() {
                        await NotificationService.shared.scheduleAppointmentReminder(
                            appointmentId: appointmentId,
                            title: updatedAppointment.title,
                            appointmentDate: updatedAppointment.date,
                            appointmentTime: updatedAppointment.time,
                            location: updatedAppointment.location,
                            reminderMinutesBefore: updatedAppointment.reminderOffsetMinutes ?? 60
                        )
                    }
                }

                // Post notification with appointment data so other views can update locally
                NotificationCenter.default.post(
                    name: .appointmentsDidChange,
                    object: nil,
                    userInfo: [
                        NotificationUserInfoKey.appointmentId: appointmentId,
                        NotificationUserInfoKey.action: AppointmentChangeAction.completionToggled,
                        NotificationUserInfoKey.appointment: saved
                    ]
                )
            } catch {
                // Revert on error
                if let idx = todayAppointments.firstIndex(where: { $0.id == appointmentId }) {
                    todayAppointments[idx].isCompleted = !newStatus
                }
                self.error = "Failed to update: \(error.localizedDescription)"
            }
        }
    }

    /// Handle appointment change notifications from other views
    func handleAppointmentChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let appointmentId = userInfo[NotificationUserInfoKey.appointmentId] as? UUID,
              let action = userInfo[NotificationUserInfoKey.action] as? AppointmentChangeAction else {
            return
        }

        switch action {
        case .completionToggled, .updated:
            if let appointment = userInfo[NotificationUserInfoKey.appointment] as? Appointment {
                // Update locally if we have this appointment
                if let index = todayAppointments.firstIndex(where: { $0.id == appointmentId }) {
                    todayAppointments[index] = appointment
                }
            }
        case .deleted:
            // Remove from local list
            todayAppointments.removeAll { $0.id == appointmentId }
        case .created:
            // For new appointments, we need to reload to check if it's for today
            break
        }
    }

    func isAppointmentCompleted(appointmentId: UUID) -> Bool {
        todayAppointments.first(where: { $0.id == appointmentId })?.isCompleted ?? false
    }

    var hasTodayItems: Bool {
        !todayMedications.isEmpty || !todayAppointments.isEmpty || !todayBirthdays.isEmpty || !todayCountdowns.isEmpty
    }

    /// Check if there are today items, optionally excluding birthdays/countdowns
    func hasTodayItems(showBirthdays: Bool) -> Bool {
        if showBirthdays {
            return hasTodayItems
        }
        return !todayMedications.isEmpty || !todayAppointments.isEmpty
    }

    var allTodayItems: [TodayItem] {
        allTodayItems(includeBirthdays: true)
    }

    /// Get all today items, optionally filtering out birthdays/countdowns (for Helper/Viewer roles)
    func allTodayItems(includeBirthdays: Bool) -> [TodayItem] {
        var items: [TodayItem] = []
        items.append(contentsOf: todayMedications.map { .medication($0) })
        items.append(contentsOf: todayAppointments.map { .appointment($0) })
        if includeBirthdays {
            items.append(contentsOf: todayBirthdays.map { .birthday($0) })
            items.append(contentsOf: todayCountdowns.map { .countdown($0) })
        }
        return items
    }

    func medicationName(for log: MedicationLog) -> String {
        medications.first { $0.id == log.medicationId }?.name ?? "Medication"
    }

    func loadData(appState: AppState) async {
        guard let accountId = appState.currentAccount?.id else {
            #if DEBUG
            print("🏠 HomeViewModel: No account ID, skipping load")
            #endif
            return
        }

        #if DEBUG
        print("🏠 HomeViewModel: Loading data for account \(accountId)")
        #endif
        isLoading = true

        do {
            // Load medications for name lookup
            medications = try await appState.medicationRepository.getMedications(accountId: accountId)
            #if DEBUG
            print("🏠 HomeViewModel: Loaded \(medications.count) medications")
            #endif

            // Load today's medication logs
            let allLogs = try await appState.medicationRepository.getTodaysLogs(accountId: accountId)
            #if DEBUG
            print("🏠 HomeViewModel: Got \(allLogs.count) total logs for today")
            for log in allLogs {
                print("🏠   - log id: \(log.id), medicationId: \(log.medicationId), status: \(log.status), scheduledAt: \(log.scheduledAt)")
            }
            #endif
            todayMedications = allLogs.filter { $0.status == .scheduled || $0.status == .taken || $0.status == .skipped }
            #if DEBUG
            print("🏠 HomeViewModel: Filtered to \(todayMedications.count) scheduled/taken/skipped medications")
            #endif

            // Load today's appointments
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            todayAppointments = try await appState.appointmentRepository.getAppointments(accountId: accountId)
                .filter { $0.date >= startOfDay && $0.date < endOfDay }

            // Load today's birthdays
            let allProfiles = try await appState.profileRepository.getProfiles(accountId: accountId)
            todayBirthdays = allProfiles.filter { profile in
                guard let birthday = profile.birthday else { return false }
                return birthday.daysUntilNextOccurrence() == 0
            }

            // Load today's countdowns
            let allCountdowns = try await appState.countdownRepository.getUpcomingCountdowns(accountId: accountId, days: 365)
            todayCountdowns = allCountdowns.filter { $0.daysUntilNextOccurrence == 0 }

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Refresh countdowns from remote server (called when realtime notification received)
    func refreshCountdownsFromRemote(appState: AppState) async {
        guard let accountId = appState.currentAccount?.id else { return }

        do {
            // Force refresh from server
            _ = try await appState.countdownRepository.refreshFromRemote(accountId: accountId)
            // Then load the updated data
            let allCountdowns = try await appState.countdownRepository.getUpcomingCountdowns(accountId: accountId, days: 365)
            todayCountdowns = allCountdowns.filter { $0.daysUntilNextOccurrence == 0 }
        } catch {
            // Silently fail - not critical for home view
            #if DEBUG
            print("🏠 HomeViewModel: Failed to refresh countdowns: \(error)")
            #endif
        }
    }

    func markMedicationTaken(log: MedicationLog, appState: AppState) async {
        do {
            try await appState.medicationRepository.updateLogStatus(logId: log.id, status: .taken)
            // Update local state
            if let index = todayMedications.firstIndex(where: { $0.id == log.id }) {
                todayMedications[index].status = .taken
                todayMedications[index].takenAt = Date()
            }
        } catch {
            self.error = "Failed to update medication: \(error.localizedDescription)"
        }
    }

    func skipMedication(log: MedicationLog, appState: AppState) async {
        do {
            try await appState.medicationRepository.updateLogStatus(logId: log.id, status: .skipped)
            // Update local state
            if let index = todayMedications.firstIndex(where: { $0.id == log.id }) {
                todayMedications[index].status = .skipped
                todayMedications[index].takenAt = nil
            }
        } catch {
            self.error = "Failed to skip medication: \(error.localizedDescription)"
        }
    }

    func markMedicationNotTaken(log: MedicationLog, appState: AppState) async {
        do {
            try await appState.medicationRepository.updateLogStatus(logId: log.id, status: .scheduled)
            // Update local state
            if let index = todayMedications.firstIndex(where: { $0.id == log.id }) {
                todayMedications[index].status = .scheduled
                todayMedications[index].takenAt = nil
            }
        } catch {
            self.error = "Failed to update medication: \(error.localizedDescription)"
        }
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Home Upgrade Banner
struct HomeUpgradeBanner: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var showUpgradeSheet = false

    var body: some View {
        Button {
            showUpgradeSheet = true
        } label: {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24))
                        .foregroundColor(appAccentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("You're on the Free Plan")
                            .font(.appBodyMedium)
                            .foregroundColor(.textPrimary)

                        Text("Upgrade to unlock unlimited features")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }

                // CTA
                HStack {
                    Text("Upgrade to Premium")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appBackground)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appBackground)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(appAccentColor)
                .cornerRadius(20)
            }
            .padding(AppDimensions.cardPadding)
            .background(
                LinearGradient(
                    colors: [
                        appAccentColor.opacity(0.15),
                        appAccentColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(appAccentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
        }
    }
}
