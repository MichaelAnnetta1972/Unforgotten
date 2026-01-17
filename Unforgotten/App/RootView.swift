import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var minimumSplashTimeElapsed = false

    var body: some View {
        Group {
            if appState.isLoading || !minimumSplashTimeElapsed {
                LoadingScreen()
                    .onAppear {
                        // Ensure splash screen shows for at least 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                minimumSplashTimeElapsed = true
                            }
                        }
                    }
            } else if !appState.isAuthenticated {
                AuthView()
            } else if !appState.hasCompletedOnboarding {
                OnboardingContainerView()
            } else {
                MainAppView()
                    .sheet(isPresented: $appState.showMoodPrompt) {
                        MoodPromptView()
                    }
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
        .animation(.easeInOut, value: appState.hasCompletedOnboarding)
        .animation(.easeInOut, value: minimumSplashTimeElapsed)
    }
}

// MARK: - Loading Screen
struct LoadingScreen: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background image with reduced opacity
            Image("splash-background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.4)
                .ignoresSafeArea()

            // Dark overlay for better text readability
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // App icon with entrance animation
                Image("unforgotten-logo-stacked")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                // Tagline
                Text("Because the important things in life\nshould stay Unforgotten.")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(logoOpacity)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: appAccentColor))
                    .scaleEffect(1.2)
                    .opacity(logoOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}

// MARK: - Main App View (Adaptive)
struct MainAppView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadRootView()
        } else {
            IPhoneMainView()
        }
    }
}

// MARK: - iPad Sidebar Item
enum iPadSidebarItem: String, CaseIterable, Identifiable {
    case home
    case profiles
    case medications
    case appointments
    case todoLists
    case notes
    case birthdays
    case contacts
    case mood
    case stickyReminders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .profiles: return "Family & Friends"
        case .medications: return "Medicines"
        case .appointments: return "Appointments"
        case .todoLists: return "To Do Lists"
        case .notes: return "Notes"
        case .birthdays: return "Birthdays"
        case .contacts: return "Useful Contacts"
        case .mood: return "Mood Tracker"
        case .stickyReminders: return "Sticky Reminders"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .profiles: return "person.2.fill"
        case .medications: return "pill.fill"
        case .appointments: return "calendar"
        case .todoLists: return "checklist"
        case .notes: return "note.text"
        case .birthdays: return "gift.fill"
        case .contacts: return "phone.fill"
        case .mood: return "face.smiling.fill"
        case .stickyReminders: return "pin.fill"
        }
    }
}

// MARK: - iPad Main View
struct iPadMainView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var selectedSidebarItem: iPadSidebarItem? = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSettings = false
    @State private var showAddProfile = false
    @State private var showAddMedication = false
    @State private var showAddAppointment = false
    @State private var showAddContact = false
    @State private var showAddNote = false
    @State private var showAddToDoList = false
    @State private var showAddStickyReminder = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            List(selection: $selectedSidebarItem) {
                Section {
                    ForEach(iPadSidebarItem.allCases) { item in
                        NavigationLink(value: item) {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        MyCardView()
                    } label: {
                        Label("My Card", systemImage: "person.crop.circle.fill")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Unforgotten")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showAddProfile = true
                        } label: {
                            Label("Family or Friend", systemImage: "person.2")
                        }

                        Button {
                            showAddMedication = true
                        } label: {
                            Label("Medication", systemImage: "pill")
                        }

                        Button {
                            showAddAppointment = true
                        } label: {
                            Label("Appointment", systemImage: "calendar")
                        }

                        Button {
                            showAddContact = true
                        } label: {
                            Label("Contact", systemImage: "phone")
                        }

                        Button {
                            showAddToDoList = true
                        } label: {
                            Label("To Do List", systemImage: "checklist")
                        }

                        Button {
                            showAddNote = true
                        } label: {
                            Label("Note", systemImage: "note.text")
                        }

                        Button {
                            showAddStickyReminder = true
                        } label: {
                            Label("Sticky Reminder", systemImage: "pin.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .tint(appAccentColor)
        } detail: {
            // Detail content based on selection
            NavigationStack {
                Group {
                    switch selectedSidebarItem {
                    case .home:
                        iPadHomeView()
                    case .profiles:
                        ProfileListContainerView()
                    case .medications:
                        MedicationListContainerView()
                    case .appointments:
                        AppointmentListContainerView()
                    case .todoLists:
                        ToDoListsContainerView()
                    case .notes:
                        NotesFeatureView()
                    case .birthdays:
                        BirthdaysContainerView()
                    case .contacts:
                        UsefulContactsContainerView()
                    case .mood:
                        MoodDashboardView()
                    case .stickyReminders:
                        StickyReminderListView()
                    case .none:
                        ContentUnavailableView(
                            "Select an Item",
                            systemImage: "sidebar.left",
                            description: Text("Choose a section from the sidebar")
                        )
                    }
                }
                .navigationDestination(for: HomeDestination.self) { destination in
                    iPadDestinationView(for: destination)
                }
            }
            .tint(appAccentColor)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(appAccentColor)
        .sidePanel(isPresented: $showSettings) {
            SettingsPanelView(onDismiss: { showSettings = false })
        }
        .sheet(isPresented: $showAddProfile, onDismiss: {
            NotificationCenter.default.post(name: .profilesDidChange, object: nil)
        }) {
            AddProfileView { _ in }
        }
        .sheet(isPresented: $showAddMedication, onDismiss: {
            NotificationCenter.default.post(name: .medicationsDidChange, object: nil)
        }) {
            AddMedicationView { _ in }
        }
        .sheet(isPresented: $showAddAppointment, onDismiss: {
            NotificationCenter.default.post(name: .appointmentsDidChange, object: nil)
        }) {
            AddAppointmentView { _ in }
        }
        .sheet(isPresented: $showAddContact, onDismiss: {
            NotificationCenter.default.post(name: .contactsDidChange, object: nil)
        }) {
            AddUsefulContactView { _ in }
        }
        .sheet(isPresented: $showAddNote) {
            AddNoteSheet(accountId: appState.currentAccount?.id)
        }
        .sheet(isPresented: $showAddToDoList) {
            NavigationStack {
                AddToDoListSheet(viewModel: ToDoListsViewModel()) { _ in }
            }
        }
        .sheet(isPresented: $showAddStickyReminder, onDismiss: {
            NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
        }) {
            AddStickyReminderView()
        }
    }

    @ViewBuilder
    private func iPadDestinationView(for destination: HomeDestination) -> some View {
        switch destination {
        case .myCard:
            MyCardView()
        case .profiles:
            ProfileListContainerView()
        case .medications:
            MedicationListContainerView()
        case .appointments:
            AppointmentListContainerView()
        case .appointmentDetail(let appointment):
            AppointmentDetailView(appointment: appointment)
        case .birthdays:
            BirthdaysContainerView()
        case .contacts:
            UsefulContactsContainerView()
        case .notes:
            NotesFeatureView()
        case .mood:
            MoodDashboardView()
        case .todoLists:
            ToDoListsContainerView()
        case .stickyReminders:
            StickyReminderListView()
        case .stickyReminderDetail(let reminder):
            StickyReminderDetailView(reminder: reminder)
        }
    }
}

// MARK: - iPad Home View (Simplified for sidebar navigation)
struct iPadHomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.appAccentColor) private var appAccentColor

    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back")
                        .font(.appTitle2)
                        .foregroundColor(.textSecondary)

                    Text(appState.currentAccount?.displayName ?? "")
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Today Card (if there are items)
                if viewModel.hasTodayItems {
                    iPadTodayCard(viewModel: viewModel)
                        .padding(.horizontal, 24)
                }

                // Quick Navigation Grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(iPadSidebarItem.allCases.filter { $0 != .home }) { item in
                        NavigationLink(value: item.toHomeDestination) {
                            iPadQuickNavCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadData(appState: appState)
            await appState.generateTodaysMedicationLogs()
            await viewModel.loadData(appState: appState)
        }
        .refreshable {
            await viewModel.loadData(appState: appState)
        }
    }
}

// MARK: - iPad Quick Nav Card
struct iPadQuickNavCard: View {
    let item: iPadSidebarItem
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: item.icon)
                .font(.system(size: 24))
                .foregroundColor(appAccentColor)
                .frame(width: 48, height: 48)
                .background(appAccentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(item.title)
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(.textSecondary)
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .hoverEffect(.lift)
    }
}

// MARK: - iPad Today Card
struct iPadTodayCard: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            if !viewModel.todayMedications.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Medications", systemImage: "pill.fill")
                        .font(.appBodyMedium)
                        .foregroundColor(appAccentColor)

                    ForEach(viewModel.todayMedications.prefix(3)) { log in
                        HStack {
                            Text(viewModel.medicationName(for: log))
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Text(log.scheduledAt.formatted(date: .omitted, time: .shortened))
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if viewModel.todayMedications.count > 3 {
                        Text("+ \(viewModel.todayMedications.count - 3) more")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }
            }

            if !viewModel.todayAppointments.isEmpty {
                Divider()
                    .background(Color.cardBackgroundLight)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Appointments", systemImage: "calendar")
                        .font(.appBodyMedium)
                        .foregroundColor(appAccentColor)

                    ForEach(viewModel.todayAppointments.prefix(3)) { apt in
                        HStack {
                            Text(apt.title)
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                            Spacer()
                            if let appointmentTime = apt.time {
                                Text(appointmentTime.formatted(date: .omitted, time: .shortened))
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !viewModel.todayBirthdays.isEmpty {
                Divider()
                    .background(Color.cardBackgroundLight)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Birthdays", systemImage: "gift.fill")
                        .font(.appBodyMedium)
                        .foregroundColor(appAccentColor)

                    ForEach(viewModel.todayBirthdays.prefix(3)) { profile in
                        Text(profile.displayName)
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - iPadSidebarItem to HomeDestination
extension iPadSidebarItem {
    var toHomeDestination: HomeDestination? {
        switch self {
        case .home: return nil
        case .profiles: return .profiles
        case .medications: return .medications
        case .appointments: return .appointments
        case .todoLists: return .todoLists
        case .notes: return .notes
        case .birthdays: return .birthdays
        case .contacts: return .contacts
        case .mood: return .mood
        case .stickyReminders: return .stickyReminders
        }
    }
}

// MARK: - iPhone Main View
struct IPhoneMainView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: NavDestination = .home
    @State private var slideDirection: SlideDirection = .none
    @State private var showAddProfile = false
    @State private var showAddMedication = false
    @State private var showAddAppointment = false
    @State private var showAddContact = false
    @State private var navigateToToDoLists = false
    @State private var shouldShowToDoAddSheet = false
    @State private var showAddNote = false
    @State private var showAddStickyReminder = false
    @State private var showAddCountdown = false
    @State private var homePath = NavigationPath()
    @State private var profilesPath = NavigationPath()
    @State private var appointmentsPath = NavigationPath()
    @State private var medicationsPath = NavigationPath()
    @State private var myCardPath = NavigationPath()
    @State private var currentHomeDestination: HomeDestination? = nil
    @State private var isBottomNavBarVisible = true
    @State private var hasHandledOnboardingAction = false
    @Namespace private var navNamespace

    // Premium limit state
    @State private var showUpgradePrompt = false
    @State private var profileCount = 0
    @State private var medicationCount = 0
    @State private var appointmentCount = 0
    @State private var contactCount = 0
    @State private var noteCount = 0
    @State private var stickyReminderCount = 0

    // Notes model container for counting notes
    @State private var notesModelContainer: ModelContainer = {
        do {
            return try NotesContainerConfiguration.createContainer()
        } catch {
            fatalError("Failed to create notes model container: \(error)")
        }
    }()

    /// Helper/Viewer roles have limited access
    private var isLimitedAccess: Bool {
        appState.currentUserRole == .helper || appState.currentUserRole == .viewer
    }

    // Determine if we're at the root of the current tab
    private var isAtHomeRoot: Bool {
        homePath.isEmpty
    }

    // Determine which nav icon should be active based on current destination
    private var activeNavDestination: NavDestination {
        // If we're on home tab and navigated to a page with a matching nav icon, highlight that icon
        if selectedTab == .home, let destination = currentHomeDestination {
            switch destination {
            case .profiles:
                return isLimitedAccess ? .home : .profiles
            case .myCard:
                return isLimitedAccess ? .myCard : .home
            case .medications:
                return .medications
            case .appointments:
                return .appointments
            default:
                return .home
            }
        }
        return selectedTab
    }

    var body: some View {
        ZStack {
            // Tab content with slide transition
            TabContentView(
                selectedTab: selectedTab,
                slideDirection: slideDirection,
                navNamespace: navNamespace,
                homePath: $homePath,
                profilesPath: $profilesPath,
                appointmentsPath: $appointmentsPath,
                medicationsPath: $medicationsPath,
                currentHomeDestination: $currentHomeDestination,
                shouldShowToDoAddSheet: shouldShowToDoAddSheet
            )
            .environment(\.navNamespace, navNamespace)
            .environment(\.isBottomNavBarVisible, isBottomNavBarVisible)
            .onPreferenceChange(BottomNavBarVisibilityPreference.self) { visible in
                isBottomNavBarVisible = visible
            }

            // Persistent bottom nav bar (conditionally shown)
            if isBottomNavBarVisible {
                BottomNavBar(
                    currentPage: activeNavDestination,
                    isAtHomeRoot: isAtHomeRoot,
                    isLimitedAccess: isLimitedAccess,
                    onNavigate: { newTab in
                        navigateToTab(newTab)
                    },
                    onAddProfile: {
                        if PremiumLimitsManager.shared.canCreateFriendProfile(appState: appState, currentCount: profileCount) {
                            showAddProfile = true
                        } else {
                            showUpgradePrompt = true
                        }
                    },
                    onAddMedication: {
                        if PremiumLimitsManager.shared.canCreateMedication(appState: appState, currentCount: medicationCount) {
                            showAddMedication = true
                        } else {
                            showUpgradePrompt = true
                        }
                    },
                    onAddAppointment: {
                        // Appointments use date-based limit (30 days), not count-based
                        showAddAppointment = true
                    },
                    onAddContact: {
                        if PremiumLimitsManager.shared.canCreateUsefulContact(appState: appState, currentCount: contactCount) {
                            showAddContact = true
                        } else {
                            showUpgradePrompt = true
                        }
                    },
                    onAddToDoList: { navigateToToDoLists = true },
                    onAddNote: {
                        if PremiumLimitsManager.shared.canCreateNote(appState: appState, currentCount: noteCount) {
                            showAddNote = true
                        } else {
                            showUpgradePrompt = true
                        }
                    },
                    onAddStickyReminder: {
                        if PremiumLimitsManager.shared.canCreateStickyReminder(appState: appState, currentCount: stickyReminderCount) {
                            showAddStickyReminder = true
                        } else {
                            showUpgradePrompt = true
                        }
                    },
                    onAddCountdown: {
                        showAddCountdown = true
                    }
                )
            }
        }
        .sheet(isPresented: $showAddProfile, onDismiss: {
            // Post notification to refresh profiles list
            NotificationCenter.default.post(name: .profilesDidChange, object: nil)
        }) {
            AddProfileView { _ in }
        }
        .sheet(isPresented: $showAddMedication, onDismiss: {
            // Post notification to refresh medications list
            NotificationCenter.default.post(name: .medicationsDidChange, object: nil)
        }) {
            AddMedicationView { _ in }
        }
        .sheet(isPresented: $showAddAppointment, onDismiss: {
            // Post notification to refresh appointments list
            NotificationCenter.default.post(name: .appointmentsDidChange, object: nil)
        }) {
            AddAppointmentView { _ in }
        }
        .sheet(isPresented: $showAddContact, onDismiss: {
            // Post notification to refresh contacts list
            NotificationCenter.default.post(name: .contactsDidChange, object: nil)
        }) {
            AddUsefulContactView { _ in }
        }
        .sheet(isPresented: $showAddNote) {
            AddNoteSheet(accountId: appState.currentAccount?.id)
        }
        .sheet(isPresented: $showAddStickyReminder, onDismiss: {
            NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
        }) {
            AddStickyReminderView()
        }
        .sheet(isPresented: $showAddCountdown, onDismiss: {
            NotificationCenter.default.post(name: .countdownsDidChange, object: nil)
        }) {
            AddCountdownView { _ in }
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
        }
        .task {
            await loadFeatureCounts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilesDidChange)) { _ in
            Task { await loadFeatureCounts() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationsDidChange)) { _ in
            Task { await loadFeatureCounts() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appointmentsDidChange)) { _ in
            Task { await loadFeatureCounts() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsDidChange)) { _ in
            Task { await loadFeatureCounts() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stickyRemindersDidChange)) { _ in
            Task { await loadFeatureCounts() }
        }
        .onChange(of: navigateToToDoLists) { _, shouldNavigate in
            if shouldNavigate {
                // Set flag to show add sheet
                shouldShowToDoAddSheet = true
                // Navigate to To Do Lists on home tab
                selectedTab = .home
                homePath.append(HomeDestination.todoLists)
                // Reset the navigation flag
                navigateToToDoLists = false
                // Reset the add sheet flag after navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    shouldShowToDoAddSheet = false
                }
            }
        }
        .onAppear {
            handlePendingOnboardingAction()
            // Check for any pending notification navigation on appear
            checkPendingNotifications()
        }
        .onChange(of: appState.pendingAppointmentId) { _, appointmentId in
            guard appointmentId != nil,
                  appState.isAuthenticated,
                  appState.hasCompletedOnboarding else { return }
            handlePendingAppointmentNavigation()
        }
        .onChange(of: appState.pendingProfileId) { _, profileId in
            guard profileId != nil,
                  appState.isAuthenticated,
                  appState.hasCompletedOnboarding else { return }
            handlePendingProfileNavigation()
        }
        .onChange(of: appState.pendingStickyReminderId) { _, reminderId in
            guard reminderId != nil,
                  appState.isAuthenticated,
                  appState.hasCompletedOnboarding else { return }
            handlePendingStickyReminderNavigation()
        }
    }

    // MARK: - Check Pending Notifications on Appear
    private func checkPendingNotifications() {
        guard appState.isAuthenticated, appState.hasCompletedOnboarding else { return }

        // Small delay to ensure view is fully ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if appState.pendingAppointmentId != nil {
                handlePendingAppointmentNavigation()
            } else if appState.pendingProfileId != nil {
                handlePendingProfileNavigation()
            } else if appState.pendingStickyReminderId != nil {
                handlePendingStickyReminderNavigation()
            }
        }
    }

    // MARK: - Handle Pending Notification Navigation
    private func handlePendingAppointmentNavigation() {
        guard let appointmentId = appState.pendingAppointmentId else { return }
        appState.pendingAppointmentId = nil

        Task {
            guard let appointment = try? await appState.appointmentRepository.getAppointment(id: appointmentId) else { return }
            await MainActor.run {
                selectedTab = .home
                homePath = NavigationPath()
                homePath.append(HomeDestination.appointments)
                homePath.append(HomeDestination.appointmentDetail(appointment))
            }
        }
    }

    private func handlePendingProfileNavigation() {
        guard appState.pendingProfileId != nil else { return }
        appState.pendingProfileId = nil

        selectedTab = .home
        homePath = NavigationPath()
        homePath.append(HomeDestination.birthdays)
    }

    private func handlePendingStickyReminderNavigation() {
        guard let reminderId = appState.pendingStickyReminderId else { return }
        appState.pendingStickyReminderId = nil

        Task {
            guard let account = appState.currentAccount,
                  let reminders = try? await appState.stickyReminderRepository.getReminders(accountId: account.id),
                  let reminder = reminders.first(where: { $0.id == reminderId }) else {
                // If reminder not found, just go to the list
                await MainActor.run {
                    selectedTab = .home
                    homePath = NavigationPath()
                    homePath.append(HomeDestination.stickyReminders)
                }
                return
            }
            await MainActor.run {
                selectedTab = .home
                homePath = NavigationPath()
                homePath.append(HomeDestination.stickyReminders)
                homePath.append(HomeDestination.stickyReminderDetail(reminder))
            }
        }
    }

    // MARK: - Handle Pending Onboarding Action
    private func handlePendingOnboardingAction() {
        guard !hasHandledOnboardingAction,
              let action = appState.pendingOnboardingAction else { return }

        hasHandledOnboardingAction = true
        appState.pendingOnboardingAction = nil

        // Delay slightly to ensure view is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch action {
            case .addFriend:
                // Navigate to Profiles and show Add Profile sheet
                selectedTab = .home
                homePath.append(HomeDestination.profiles)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showAddProfile = true
                }

            case .createReminder:
                // Show Add Sticky Reminder sheet
                showAddStickyReminder = true

            case .updateDetails:
                // Navigate to My Card and trigger edit sheet
                selectedTab = .home
                homePath.append(HomeDestination.myCard)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: .editPrimaryProfileRequested, object: nil)
                }

            case .exploreApp:
                // Just stay on home - no action needed
                break
            }
        }
    }

    private func navigateToTab(_ newTab: NavDestination) {
        // If tapping home while on home tab but not at root, go back to root
        if newTab == .home && selectedTab == .home && !isAtHomeRoot {
            withAnimation(.easeInOut(duration: 0.3)) {
                homePath = NavigationPath()
            }
            return
        }

        // Handle My Card navigation - navigate within home tab to My Card
        if newTab == .myCard {
            // If already on My Card, do nothing
            if currentHomeDestination == .myCard { return }

            // Navigate to My Card on home tab
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = .home
                homePath = NavigationPath()
                homePath.append(HomeDestination.myCard)
            }
            return
        }

        guard newTab != selectedTab else { return }

        // Determine slide direction based on tab order
        let tabOrder: [NavDestination] = [.home, .profiles, .myCard, .appointments, .medications]
        let currentIndex = tabOrder.firstIndex(of: selectedTab) ?? 0
        let newIndex = tabOrder.firstIndex(of: newTab) ?? 0

        slideDirection = newIndex > currentIndex ? .left : .right

        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = newTab
        }
    }

    // MARK: - Load Feature Counts for Premium Limits
    private func loadFeatureCounts() async {
        guard let account = appState.currentAccount else { return }

        do {
            // Load profile count (friend/family profiles, excluding primary)
            let profiles = try await appState.profileRepository.getProfiles(accountId: account.id)
            profileCount = profiles.filter { $0.type != .primary }.count

            // Load medication count
            let medications = try await appState.medicationRepository.getMedications(accountId: account.id)
            medicationCount = medications.count

            // Load appointment count
            let appointments = try await appState.appointmentRepository.getAppointments(accountId: account.id)
            appointmentCount = appointments.count

            // Load contact count
            let contacts = try await appState.usefulContactRepository.getContacts(accountId: account.id)
            contactCount = contacts.count

            // Load sticky reminder count
            let reminders = try await appState.stickyReminderRepository.getReminders(accountId: account.id)
            stickyReminderCount = reminders.count

            // Load note count from SwiftData
            await loadNoteCount(accountId: account.id)
        } catch {
            #if DEBUG
            print("Error loading feature counts: \(error)")
            #endif
        }
    }

    /// Load note count from SwiftData model container
    @MainActor
    private func loadNoteCount(accountId: UUID) async {
        let context = notesModelContainer.mainContext
        let descriptor = FetchDescriptor<LocalNote>(
            predicate: #Predicate<LocalNote> { note in
                note.accountId == accountId
            }
        )
        do {
            let notes = try context.fetch(descriptor)
            noteCount = notes.count
        } catch {
            #if DEBUG
            print("Error loading note count: \(error)")
            #endif
            noteCount = 0
        }
    }
}

// MARK: - Slide Direction
enum SlideDirection {
    case left
    case right
    case none
}

// MARK: - Tab Content View
struct TabContentView: View {
    let selectedTab: NavDestination
    let slideDirection: SlideDirection
    let navNamespace: Namespace.ID
    @Binding var homePath: NavigationPath
    @Binding var profilesPath: NavigationPath
    @Binding var appointmentsPath: NavigationPath
    @Binding var medicationsPath: NavigationPath
    @Binding var currentHomeDestination: HomeDestination?
    let shouldShowToDoAddSheet: Bool

    var body: some View {
        ZStack {
            // Each tab has its own NavigationStack for internal navigation
            switch selectedTab {
            case .home:
                NavigationStack(path: $homePath) {
                    HomeView()
                        .onAppear { currentHomeDestination = nil }
                        .navigationDestination(for: HomeDestination.self) { destination in
                            destinationView(for: destination)
                                .onAppear { currentHomeDestination = destination }
                                .onDisappear {
                                    // Only clear if we're going back (path is shorter)
                                    if homePath.isEmpty {
                                        currentHomeDestination = nil
                                    }
                                }
                        }
                }
                .tint(.accentYellow)
                .transition(slideTransition)

            case .profiles:
                NavigationStack(path: $profilesPath) {
                    ProfileListView()
                        .navigationDestination(for: HomeDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tint(.accentYellow)
                .transition(slideTransition)

            case .appointments:
                NavigationStack(path: $appointmentsPath) {
                    AppointmentListView()
                        .navigationDestination(for: HomeDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tint(.accentYellow)
                .transition(slideTransition)

            case .medications:
                NavigationStack(path: $medicationsPath) {
                    MedicationListView()
                        .navigationDestination(for: HomeDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tint(.accentYellow)
                .transition(slideTransition)

            case .myCard:
                // My Card is handled via home tab navigation, not as a separate tab
                EmptyView()

            case .other:
                EmptyView()
            }
        }
    }

    private var slideTransition: AnyTransition {
        switch slideDirection {
        case .left:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .right:
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
        case .none:
            return .opacity
        }
    }

    @ViewBuilder
    private func destinationView(for destination: HomeDestination) -> some View {
        switch destination {
        case .myCard:
            MyCardView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .profiles:
            ProfileListView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .medications:
            MedicationListView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .appointments:
            AppointmentListView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .appointmentDetail(let appointment):
            AppointmentDetailView(appointment: appointment)
        case .birthdays:
            BirthdaysView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .contacts:
            UsefulContactsListView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .notes:
            NotesFeatureView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .mood:
            MoodDashboardView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .todoLists:
            ToDoListsView(openAddSheetOnAppear: shouldShowToDoAddSheet)
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .stickyReminders:
            StickyReminderListView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .stickyReminderDetail(let reminder):
            StickyReminderDetailView(reminder: reminder)
        }
    }
}

// MARK: - Navigate to Root Environment Key
private struct NavigateToRootKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var navigateToRoot: () -> Void {
        get { self[NavigateToRootKey.self] }
        set { self[NavigateToRootKey.self] = newValue }
    }
}

// MARK: - Nav Namespace Environment Key
private struct NavNamespaceKey: EnvironmentKey {
    @Namespace static var defaultNamespace
    static let defaultValue: Namespace.ID = defaultNamespace
}

extension EnvironmentValues {
    var navNamespace: Namespace.ID {
        get { self[NavNamespaceKey.self] }
        set { self[NavNamespaceKey.self] = newValue }
    }
}

// MARK: - Preview
#Preview {
    RootView()
        .environmentObject(AppState())
}
