import SwiftUI

// MARK: - Home Destinations
enum HomeDestination: Hashable {
    case myCard
    case profiles
    case medications
    case appointments
    case appointmentDetail(Appointment)
    case birthdays
    case contacts
    case notes
    case mood
    case todoLists
    case stickyReminders
    case stickyReminderDetail(StickyReminder)
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @State private var showSettings = false
    @State private var showAccountSwitcher = false
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
                        showSettingsButton: true,
                        settingsAction: { showSettings = true },
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
                            if shouldShowFeature(.aboutMe) {
                                NavigationLink(value: HomeDestination.myCard) {
                                    NavigationCardContent(title: "About Me", icon: "person.crop.circle")
                                }
                                .matchedTransitionSource(id: HomeDestination.myCard, in: namespace)
                            }

                            if shouldShowFeature(.familyAndFriends) {
                                NavigationLink(value: HomeDestination.profiles) {
                                    NavigationCardContent(title: "Family and Friends", icon: "person.2")
                                }
                                .matchedTransitionSource(id: HomeDestination.profiles, in: namespace)
                            }

                            if shouldShowFeature(.medications) {
                                NavigationLink(value: HomeDestination.medications) {
                                    NavigationCardContent(title: "Medications", icon: "pill")
                                }
                                .matchedTransitionSource(id: HomeDestination.medications, in: namespace)
                            }

                            if shouldShowFeature(.appointments) {
                                NavigationLink(value: HomeDestination.appointments) {
                                    NavigationCardContent(title: "Appointments", icon: "calendar")
                                }
                                .matchedTransitionSource(id: HomeDestination.appointments, in: namespace)
                            }

                            if shouldShowFeature(.stickyReminders) {
                                NavigationLink(value: HomeDestination.stickyReminders) {
                                    NavigationCardContent(title: "Sticky Reminders", icon: "pin.fill")
                                }
                                .matchedTransitionSource(id: HomeDestination.stickyReminders, in: namespace)
                            }
                            
                            if shouldShowFeature(.todoLists) {
                                NavigationLink(value: HomeDestination.todoLists) {
                                    NavigationCardContent(title: "To Do Lists", icon: "checklist")
                                }
                                .matchedTransitionSource(id: HomeDestination.todoLists, in: namespace)
                            }

                            if shouldShowFeature(.notes) {
                                NavigationLink(value: HomeDestination.notes) {
                                    NavigationCardContent(title: "Notes", icon: "note.text")
                                }
                                .matchedTransitionSource(id: HomeDestination.notes, in: namespace)
                            }


                            if shouldShowFeature(.usefulContacts) {
                                NavigationLink(value: HomeDestination.contacts) {
                                    NavigationCardContent(title: "Useful Contacts", icon: "phone")
                                }
                                .matchedTransitionSource(id: HomeDestination.contacts, in: namespace)
                            }

                            if shouldShowFeature(.birthdays) {
                                NavigationLink(value: HomeDestination.birthdays) {
                                    NavigationCardContent(title: "Birthdays", icon: "gift")
                                }
                                .matchedTransitionSource(id: HomeDestination.birthdays, in: namespace)
                            }


                            if shouldShowFeature(.moodTracker) {
                                NavigationLink(value: HomeDestination.mood) {
                                    NavigationCardContent(title: "Mood Tracker", icon: "face.smiling")
                                }
                                .matchedTransitionSource(id: HomeDestination.mood, in: namespace)
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
            print("🏠 HomeView: Loading data...")
            await viewModel.loadData(appState: appState)
            print("🏠 HomeView: Initial load - medications count: \(viewModel.todayMedications.count)")
            // Generate today's medication logs if needed
            print("🏠 HomeView: Generating today's medication logs...")
            await appState.generateTodaysMedicationLogs()
            // Reload after generating
            print("🏠 HomeView: Reloading after generation...")
            await viewModel.loadData(appState: appState)
            print("🏠 HomeView: Final load - medications count: \(viewModel.todayMedications.count)")
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
        .onChange(of: appState.currentAccount?.id) { _, _ in
            // Reload data when account changes
            Task {
                await viewModel.loadData(appState: appState)
                await appState.generateTodaysMedicationLogs()
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

    var id: String {
        switch self {
        case .medication(let log): return "med-\(log.id)"
        case .appointment(let apt): return "apt-\(apt.id)"
        case .birthday(let profile): return "bday-\(profile.id)"
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
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "pill.fill")
                .font(.system(size: 18))
                .foregroundColor(.medicalRed)
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

            // Action button
            if log.status == .scheduled {
                Button {
                    Task {
                        isUpdating = true
                        await viewModel.markMedicationTaken(log: log, appState: appState)
                        isUpdating = false
                    }
                } label: {
                    if isUpdating {
                        ProgressView()
                            .tint(.appBackground)
                            .frame(width: 60, height: 32)
                            .background(appAccentColor)
                            .cornerRadius(8)
                    } else {
                        Text("Take")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appBackground)
                            .frame(width: 60, height: 32)
                            .background(appAccentColor)
                            .cornerRadius(8)
                    }
                }
                .disabled(isUpdating)
            } else {
                Text("Taken")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(appAccentColor)
                    .frame(width: 60, height: 32)
            }

            // Options button (vertical dots)
            Button {
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppDimensions.cardPadding)
        .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
            if log.status == .scheduled {
                Button("Skip medication") {
                    Task {
                        await viewModel.skipMedication(log: log, appState: appState)
                    }
                }
            } else if log.status == .taken {
                Button("Mark as not taken") {
                    Task {
                        await viewModel.markMedicationNotTaken(log: log, appState: appState)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Today Appointment Row
struct TodayAppointmentRow: View {
    let appointment: Appointment
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var showOptions = false
    @State private var navigateToDetail = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "calendar")
                .font(.system(size: 18))
                .foregroundColor(.calendarBlue)
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

            // Options button (vertical dots)
            Button {
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppDimensions.cardPadding)
        .background(
            NavigationLink(value: HomeDestination.appointmentDetail(appointment), label: { EmptyView() })
                .opacity(0)
                .disabled(!navigateToDetail)
        )
        .navigationDestination(isPresented: $navigateToDetail) {
            AppointmentDetailView(appointment: appointment)
        }
        .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
            Button("View details") {
                navigateToDetail = true
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Today Birthday Row
struct TodayBirthdayRow: View {
    let profile: Profile
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "gift.fill")
                .font(.system(size: 18))
                .foregroundColor(.calendarPink)
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

            // Options button (vertical dots)
            Button {
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppDimensions.cardPadding)
        .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
            Button("View profile") {
                // Navigate to profile
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Home View Model
@MainActor
class HomeViewModel: ObservableObject {
    @Published var todayMedications: [MedicationLog] = []
    @Published var todayAppointments: [Appointment] = []
    @Published var todayBirthdays: [Profile] = []
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
        !todayMedications.isEmpty || !todayAppointments.isEmpty || !todayBirthdays.isEmpty
    }

    /// Check if there are today items, optionally excluding birthdays
    func hasTodayItems(showBirthdays: Bool) -> Bool {
        if showBirthdays {
            return hasTodayItems
        }
        return !todayMedications.isEmpty || !todayAppointments.isEmpty
    }

    var allTodayItems: [TodayItem] {
        allTodayItems(includeBirthdays: true)
    }

    /// Get all today items, optionally filtering out birthdays (for Helper/Viewer roles)
    func allTodayItems(includeBirthdays: Bool) -> [TodayItem] {
        var items: [TodayItem] = []
        items.append(contentsOf: todayMedications.map { .medication($0) })
        items.append(contentsOf: todayAppointments.map { .appointment($0) })
        if includeBirthdays {
            items.append(contentsOf: todayBirthdays.map { .birthday($0) })
        }
        return items
    }

    func medicationName(for log: MedicationLog) -> String {
        medications.first { $0.id == log.medicationId }?.name ?? "Medication"
    }

    func loadData(appState: AppState) async {
        guard let accountId = appState.currentAccount?.id else {
            print("🏠 HomeViewModel: No account ID, skipping load")
            return
        }

        print("🏠 HomeViewModel: Loading data for account \(accountId)")
        isLoading = true

        do {
            // Load medications for name lookup
            medications = try await appState.medicationRepository.getMedications(accountId: accountId)
            print("🏠 HomeViewModel: Loaded \(medications.count) medications")

            // Load today's medication logs
            let allLogs = try await appState.medicationRepository.getTodaysLogs(accountId: accountId)
            print("🏠 HomeViewModel: Got \(allLogs.count) total logs for today")
            for log in allLogs {
                print("🏠   - log id: \(log.id), medicationId: \(log.medicationId), status: \(log.status), scheduledAt: \(log.scheduledAt)")
            }
            todayMedications = allLogs.filter { $0.status == .scheduled || $0.status == .taken }
            print("🏠 HomeViewModel: Filtered to \(todayMedications.count) scheduled/taken medications")

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

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
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
            // Remove from list
            todayMedications.removeAll { $0.id == log.id }
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
