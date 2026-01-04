//
//  iPadRootView.swift
//  Unforgotten
//
//  iPad layout with persistent Home sidebar and content area
//

import SwiftUI
import SwiftData

// MARK: - iPad Navigation Selection
enum iPadContentSelection: Hashable {
    case none
    case myCard
    case profiles
    case medications
    case appointments
    case todoLists
    case notes
    case stickyReminders
    case birthdays
    case contacts
    case mood
    case settings
}

// MARK: - iPad Root View
/// iPad layout with the iPhone HomeView as a persistent sidebar
/// and feature content displayed in the right pane
struct iPadRootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    @State private var selectedContent: iPadContentSelection = .none
    @State private var navigationPath = NavigationPath()
    @Namespace private var navNamespace

    // Add menu and sheet states
    @State private var showAddMenu = false
    @State private var showAddProfile = false
    @State private var showAddMedication = false
    @State private var showAddAppointment = false
    @State private var showAddContact = false
    @State private var showAddNote = false
    @State private var showEditNote = false
    @State private var noteToEdit: LocalNote?
    @State private var showAddToDoList = false
    @State private var showAddStickyReminder = false
    @State private var showEditStickyReminder = false
    @State private var stickyReminderToEdit: StickyReminder?
    @State private var showViewStickyReminder = false
    @State private var stickyReminderToView: StickyReminder?
    @State private var showViewToDoList = false
    @State private var toDoListToView: ToDoList?

    // Edit overlays for various features
    @State private var showEditProfile = false
    @State private var profileToEdit: Profile?
    @State private var showEditMedication = false
    @State private var medicationToEdit: Medication?
    @State private var showEditAppointment = false
    @State private var appointmentToEdit: Appointment?
    @State private var showEditUsefulContact = false
    @State private var usefulContactToEdit: UsefulContact?
    @State private var showEditImportantAccount = false
    @State private var importantAccountToEdit: ImportantAccount?
    @State private var importantAccountProfile: Profile?
    @State private var showAddImportantAccount = false
    @State private var addImportantAccountProfile: Profile?
    @State private var showAddMedicalCondition = false
    @State private var addMedicalConditionProfile: Profile?
    @State private var showAddGiftIdea = false
    @State private var addGiftIdeaProfile: Profile?
    @State private var showAddClothingSize = false
    @State private var addClothingSizeProfile: Profile?

    // Settings panel overlays
    @State private var showSettingsInviteMember = false
    @State private var showSettingsManageMembers = false
    @State private var showSettingsJoinAccount = false
    @State private var showSettingsMoodHistory = false
    @State private var showSettingsAppearance = false
    @State private var showSettingsFeatureVisibility = false
    @State private var showSettingsSwitchAccount = false
    @State private var showSettingsEditAccountName = false
    @State private var showSettingsAdminPanel = false
    @State private var showSettingsUpgrade = false

    @State private var showFloatingAddButton = true
    @State private var hasHandledOnboardingAction = false

    // Premium limit state
    @State private var showUpgradePrompt = false
    @State private var profileCount = 0
    @State private var medicationCount = 0
    @State private var appointmentCount = 0
    @State private var contactCount = 0
    @State private var noteCount = 0
    @State private var stickyReminderCount = 0
    @State private var toDoListCount = 0

    // Shared ViewModel for ToDo list creation
    @StateObject private var toDoListsViewModel = ToDoListsViewModel()

    // Shared model container for Notes feature - ensures all views use the same SwiftData context
    // Using @State to persist the container across view updates
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

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Left sidebar - iPhone Home style
                iPadHomeSidebar(
                    selectedContent: $selectedContent
                )
                .frame(width: 440)

                // Gap between panels
                Color.appBackground
                    .frame(width: 24)

                // Right content area with floating add button
                ZStack(alignment: .bottomTrailing) {
                    contentArea
                        .frame(maxWidth: .infinity)
                        .environment(\.iPadHomeAction, {
                            navigationPath = NavigationPath()
                            selectedContent = .none
                        })
                        .environment(\.hideFloatingAddButton, Binding(
                            get: { !showFloatingAddButton },
                            set: { showFloatingAddButton = !$0 }
                        ))
                        .environment(\.iPadAddNoteAction, {
                            if PremiumLimitsManager.shared.canCreateNote(appState: appState, currentCount: noteCount) {
                                showAddNote = true
                            } else {
                                showUpgradePrompt = true
                            }
                        })
                        .environment(\.iPadEditNoteAction, { note in
                            noteToEdit = note
                            showEditNote = true
                        })
                        .environment(\.iPadAddStickyReminderAction, {
                            if PremiumLimitsManager.shared.canCreateStickyReminder(appState: appState, currentCount: stickyReminderCount) {
                                showAddStickyReminder = true
                            } else {
                                showUpgradePrompt = true
                            }
                        })
                        .environment(\.iPadEditStickyReminderAction, { reminder in
                            stickyReminderToEdit = reminder
                            showEditStickyReminder = true
                        })
                        .environment(\.iPadViewStickyReminderAction, { reminder in
                            stickyReminderToView = reminder
                            showViewStickyReminder = true
                        })
                        .environment(\.iPadViewToDoListAction, { list in
                            toDoListToView = list
                            showViewToDoList = true
                        })
                        .environment(\.iPadEditProfileAction, { profile in
                            profileToEdit = profile
                            showEditProfile = true
                        })
                        .environment(\.iPadEditMedicationAction, { medication in
                            medicationToEdit = medication
                            showEditMedication = true
                        })
                        .environment(\.iPadEditAppointmentAction, { appointment in
                            appointmentToEdit = appointment
                            showEditAppointment = true
                        })
                        .environment(\.iPadEditUsefulContactAction, { contact in
                            usefulContactToEdit = contact
                            showEditUsefulContact = true
                        })
                        .environment(\.iPadEditImportantAccountAction, { account, profile in
                            importantAccountToEdit = account
                            importantAccountProfile = profile
                            showEditImportantAccount = true
                        })
                        .environment(\.iPadAddImportantAccountAction, { profile in
                            addImportantAccountProfile = profile
                            showAddImportantAccount = true
                        })
                        .environment(\.iPadAddMedicalConditionAction, { profile in
                            addMedicalConditionProfile = profile
                            showAddMedicalCondition = true
                        })
                        .environment(\.iPadAddGiftIdeaAction, { profile in
                            addGiftIdeaProfile = profile
                            showAddGiftIdea = true
                        })
                        .environment(\.iPadAddClothingSizeAction, { profile in
                            addClothingSizeProfile = profile
                            showAddClothingSize = true
                        })
                        // Settings panel actions
                        .environment(\.iPadShowInviteMemberAction, { showSettingsInviteMember = true })
                        .environment(\.iPadShowManageMembersAction, { showSettingsManageMembers = true })
                        .environment(\.iPadShowJoinAccountAction, { showSettingsJoinAccount = true })
                        .environment(\.iPadShowMoodHistoryAction, { showSettingsMoodHistory = true })
                        .environment(\.iPadShowAppearanceSettingsAction, { showSettingsAppearance = true })
                        .environment(\.iPadShowFeatureVisibilityAction, { showSettingsFeatureVisibility = true })
                        .environment(\.iPadShowSwitchAccountAction, { showSettingsSwitchAccount = true })
                        .environment(\.iPadShowEditAccountNameAction, { showSettingsEditAccountName = true })
                        .environment(\.iPadShowAdminPanelAction, { showSettingsAdminPanel = true })
                        .environment(\.iPadShowUpgradeAction, { showSettingsUpgrade = true })

                    // Floating add button with gradient (hidden when child views request it)
                    if showFloatingAddButton {
                        iPadFloatingAddButtonOverlay(
                            showAddMenu: $showAddMenu
                        )
                    }
                }
            }
            .background(Color.appBackground)

            // Add menu overlay (covers entire screen when open)
            if showAddMenu {
                iPadAddMenuOverlay(
                    showAddMenu: $showAddMenu,
                    isLimitedAccess: isLimitedAccess,
                    onAddProfile: {
                        if PremiumLimitsManager.shared.canCreateFriendProfile(appState: appState, currentCount: profileCount) {
                            selectedContent = .profiles
                            showAddProfile = true
                        } else {
                            showUpgradePrompt = true
                        }
                    },
                    onAddMedication: {
                        if PremiumLimitsManager.shared.canCreateMedication(appState: appState, currentCount: medicationCount) {
                            selectedContent = .medications
                            showAddMedication = true
                        } else {
                            showUpgradePrompt = true
                        }
                    },
                    onAddAppointment: {
                        if PremiumLimitsManager.shared.canCreateAppointment(appState: appState, currentCount: appointmentCount) {
                            selectedContent = .appointments
                            showAddAppointment = true
                        } else {
                            showUpgradePrompt = true
                        }
                    },
                    onAddContact: {
                        if PremiumLimitsManager.shared.canCreateUsefulContact(appState: appState, currentCount: contactCount) {
                            selectedContent = .contacts
                            showAddContact = true
                        } else {
                            showUpgradePrompt = true
                        }
                    },
                    onAddToDoList: {
                        if PremiumLimitsManager.shared.canCreateToDoList(appState: appState, currentCount: toDoListCount) {
                            selectedContent = .todoLists
                            showAddToDoList = true
                        } else {
                            showUpgradePrompt = true
                        }
                    },
                    onAddNote: {
                        if PremiumLimitsManager.shared.canCreateNote(appState: appState, currentCount: noteCount) {
                            selectedContent = .notes
                            showAddNote = true
                        } else {
                            showUpgradePrompt = true
                        }
                    },
                    onAddStickyReminder: {
                        if PremiumLimitsManager.shared.canCreateStickyReminder(appState: appState, currentCount: stickyReminderCount) {
                            selectedContent = .stickyReminders
                            showAddStickyReminder = true
                        } else {
                            showUpgradePrompt = true
                        }
                    }
                )
            }
        }
        .environment(\.navNamespace, navNamespace)
        .onChange(of: selectedContent) { _, _ in
            // Reset navigation path when sidebar selection changes
            navigationPath = NavigationPath()
        }
        // Side panel overlay for add actions - slides in from right
        .overlay {
            iPadSidePanelOverlay(
                showAddProfile: $showAddProfile,
                showAddMedication: $showAddMedication,
                showAddAppointment: $showAddAppointment,
                showAddContact: $showAddContact,
                showAddNote: $showAddNote,
                showEditNote: $showEditNote,
                noteToEdit: $noteToEdit,
                showAddToDoList: $showAddToDoList,
                showAddStickyReminder: $showAddStickyReminder,
                showEditStickyReminder: $showEditStickyReminder,
                stickyReminderToEdit: $stickyReminderToEdit,
                showViewStickyReminder: $showViewStickyReminder,
                stickyReminderToView: $stickyReminderToView,
                showViewToDoList: $showViewToDoList,
                toDoListToView: $toDoListToView,
                showEditProfile: $showEditProfile,
                profileToEdit: $profileToEdit,
                showEditMedication: $showEditMedication,
                medicationToEdit: $medicationToEdit,
                showEditAppointment: $showEditAppointment,
                appointmentToEdit: $appointmentToEdit,
                showEditUsefulContact: $showEditUsefulContact,
                usefulContactToEdit: $usefulContactToEdit,
                showEditImportantAccount: $showEditImportantAccount,
                importantAccountToEdit: $importantAccountToEdit,
                importantAccountProfile: $importantAccountProfile,
                showAddImportantAccount: $showAddImportantAccount,
                addImportantAccountProfile: $addImportantAccountProfile,
                showAddMedicalCondition: $showAddMedicalCondition,
                addMedicalConditionProfile: $addMedicalConditionProfile,
                showAddGiftIdea: $showAddGiftIdea,
                addGiftIdeaProfile: $addGiftIdeaProfile,
                showAddClothingSize: $showAddClothingSize,
                addClothingSizeProfile: $addClothingSizeProfile,
                showSettingsInviteMember: $showSettingsInviteMember,
                showSettingsManageMembers: $showSettingsManageMembers,
                showSettingsJoinAccount: $showSettingsJoinAccount,
                showSettingsMoodHistory: $showSettingsMoodHistory,
                showSettingsAppearance: $showSettingsAppearance,
                showSettingsFeatureVisibility: $showSettingsFeatureVisibility,
                showSettingsSwitchAccount: $showSettingsSwitchAccount,
                showSettingsEditAccountName: $showSettingsEditAccountName,
                showSettingsAdminPanel: $showSettingsAdminPanel,
                showSettingsUpgrade: $showSettingsUpgrade,
                toDoListsViewModel: toDoListsViewModel,
                appState: appState
            )
        }
        .onChange(of: showAddProfile) { _, isShowing in
            if !isShowing {
                NotificationCenter.default.post(name: .profilesDidChange, object: nil)
            }
        }
        .onChange(of: showAddMedication) { _, isShowing in
            if !isShowing {
                NotificationCenter.default.post(name: .medicationsDidChange, object: nil)
            }
        }
        .onChange(of: showAddAppointment) { _, isShowing in
            if !isShowing {
                NotificationCenter.default.post(name: .appointmentsDidChange, object: nil)
            }
        }
        .onChange(of: showAddContact) { _, isShowing in
            if !isShowing {
                NotificationCenter.default.post(name: .contactsDidChange, object: nil)
            }
        }
        .onChange(of: appState.currentAccount?.id) { _, _ in
            // Reset content selection and navigation when account changes
            selectedContent = .none
            navigationPath = NavigationPath()
            // Notify all feature views to reload their data
            NotificationCenter.default.post(name: .accountDidChange, object: nil)
        }
        // Shared model container for Notes - applied at root level to ensure all views
        // (NotesListView, NoteEditorView, side panels) share the same SwiftData context
        .modelContainer(notesModelContainer)
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
                selectedContent = .appointments
                navigationPath = NavigationPath()
                appointmentToEdit = appointment
                showEditAppointment = true
            }
        }
    }

    private func handlePendingProfileNavigation() {
        guard appState.pendingProfileId != nil else { return }
        appState.pendingProfileId = nil

        selectedContent = .birthdays
        navigationPath = NavigationPath()
    }

    private func handlePendingStickyReminderNavigation() {
        guard let reminderId = appState.pendingStickyReminderId else { return }
        appState.pendingStickyReminderId = nil

        Task {
            if let account = appState.currentAccount,
               let reminders = try? await appState.stickyReminderRepository.getReminders(accountId: account.id),
               let reminder = reminders.first(where: { $0.id == reminderId }) {
                await MainActor.run {
                    selectedContent = .stickyReminders
                    navigationPath = NavigationPath()
                    stickyReminderToView = reminder
                    showViewStickyReminder = true
                }
            } else {
                await MainActor.run {
                    selectedContent = .stickyReminders
                    navigationPath = NavigationPath()
                }
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
                // Navigate to Profiles and show Add Profile panel
                selectedContent = .profiles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showAddProfile = true
                }

            case .createReminder:
                // Navigate to Sticky Reminders and show Add panel
                selectedContent = .stickyReminders
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showAddStickyReminder = true
                }

            case .updateDetails:
                // Navigate to My Card and trigger edit panel
                selectedContent = .myCard
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: .editPrimaryProfileRequested, object: nil)
                }

            case .exploreApp:
                // Just stay on home - no action needed
                break
            }
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

            // Load to do list count
            let lists = try await appState.toDoRepository.getLists(accountId: account.id)
            toDoListCount = lists.count

            // Load note count from SwiftData
            await loadNoteCount(accountId: account.id)
        } catch {
            print("Error loading feature counts: \(error)")
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
            print("Error loading note count: \(error)")
            noteCount = 0
        }
    }

    // MARK: - Content Area
    @ViewBuilder
    private var contentArea: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch selectedContent {
                case .none:
                    emptyContentView
                case .myCard:
                    MyCardView()
                case .profiles:
                    ProfileListView()
                case .medications:
                    MedicationListView()
                case .appointments:
                    AppointmentListView()
                case .todoLists:
                    iPadToDoListsView()
                case .notes:
                    NotesFeatureView()
                case .stickyReminders:
                    iPadStickyRemindersView()
                case .birthdays:
                    BirthdaysView()
                case .contacts:
                    UsefulContactsListView()
                case .mood:
                    MoodDashboardView()
                case .settings:
                    iPadSettingsContentView(onClose: { selectedContent = .none })
                }
            }
            .navigationDestination(for: Profile.self) { profile in
                ProfileDetailView(profile: profile)
            }
            .navigationDestination(for: Medication.self) { medication in
                MedicationDetailView(medication: medication)
            }
            .navigationDestination(for: Appointment.self) { appointment in
                AppointmentDetailView(appointment: appointment)
            }
        }
        .id(selectedContent) // Force recreation when selection changes
        .tint(appAccentColor)
    }

    private var emptyContentView: some View {
        iPadEmptyContentView()
    }
}

// MARK: - iPad Empty Content View
struct iPadEmptyContentView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background image with 30% opacity
            Image("splash-background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.3)

            // Dark overlay for better readability
            Color.appBackground.opacity(0.3)

            // Stacked logo with animation and tagline
            VStack(spacing: 20) {
                Image("unforgotten-logo-stacked")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 250)
                    .opacity(logoOpacity * 0.6)
                    .scaleEffect(logoScale)

                Text("Because the important things in life\nshould stay Unforgotten.")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(logoOpacity * 0.6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}

// MARK: - iPad Home Sidebar
/// Displays the iPhone HomeView style content as a persistent sidebar
struct iPadHomeSidebar: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @Binding var selectedContent: iPadContentSelection
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(FeatureVisibilityManager.self) private var featureVisibility
    @State private var showAccountSwitcher = false

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
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with video/image
                    CustomizableHeaderView(
                        pageIdentifier: .home,
                        title: "Unforgotten",
                        showAccountSwitcherButton: appState.allAccounts.count > 1,
                        accountSwitcherAction: { showAccountSwitcher = true },
                        showSettingsButton: true,
                        settingsAction: { selectedContent = .settings },
                        roundedTopRightCorner: true,
                        useLogo: true,
                        logoImageName: "unforgotten-logo"
                    )

                    // Viewing As Bar (shown when viewing another account) - only on Home page for iPad
                    ViewingAsBar(showOnIPad: true)

                    // Content
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Today Card (if there are items)
                        if viewModel.hasTodayItems(showBirthdays: !isLimitedAccess) {
                            iPadSidebarTodayCard(viewModel: viewModel, showBirthdays: !isLimitedAccess)
                        }

                        // Navigation Items
                        VStack(spacing: AppDimensions.cardSpacing) {
                            if shouldShowFeature(.aboutMe) {
                                iPadSidebarNavItem(
                                    title: "About Me",
                                    icon: "person.crop.circle",
                                    isSelected: selectedContent == .myCard
                                ) {
                                    selectedContent = .myCard
                                }
                            }

                            if shouldShowFeature(.familyAndFriends) {
                                iPadSidebarNavItem(
                                    title: "Family and Friends",
                                    icon: "person.2",
                                    isSelected: selectedContent == .profiles
                                ) {
                                    selectedContent = .profiles
                                }
                            }

                            if shouldShowFeature(.medications) {
                                iPadSidebarNavItem(
                                    title: "Medications",
                                    icon: "pill",
                                    isSelected: selectedContent == .medications
                                ) {
                                    selectedContent = .medications
                                }
                            }

                            if shouldShowFeature(.appointments) {
                                iPadSidebarNavItem(
                                    title: "Appointments",
                                    icon: "calendar",
                                    isSelected: selectedContent == .appointments
                                ) {
                                    selectedContent = .appointments
                                }
                            }

                            if shouldShowFeature(.stickyReminders) {
                                iPadSidebarNavItem(
                                    title: "Sticky Reminders",
                                    icon: "pin.fill",
                                    isSelected: selectedContent == .stickyReminders
                                ) {
                                    selectedContent = .stickyReminders
                                }
                            }
                            
                            if shouldShowFeature(.todoLists) {
                                iPadSidebarNavItem(
                                    title: "To Do Lists",
                                    icon: "checklist",
                                    isSelected: selectedContent == .todoLists
                                ) {
                                    selectedContent = .todoLists
                                }
                            }

                            if shouldShowFeature(.notes) {
                                iPadSidebarNavItem(
                                    title: "Notes",
                                    icon: "note.text",
                                    isSelected: selectedContent == .notes
                                ) {
                                    selectedContent = .notes
                                }
                            }


                            if shouldShowFeature(.birthdays) {
                                iPadSidebarNavItem(
                                    title: "Birthdays",
                                    icon: "gift",
                                    isSelected: selectedContent == .birthdays
                                ) {
                                    selectedContent = .birthdays
                                }
                            }

                            if shouldShowFeature(.usefulContacts) {
                                iPadSidebarNavItem(
                                    title: "Useful Contacts",
                                    icon: "phone",
                                    isSelected: selectedContent == .contacts
                                ) {
                                    selectedContent = .contacts
                                }
                            }

                            if shouldShowFeature(.moodTracker) {
                                iPadSidebarNavItem(
                                    title: "Mood Tracker",
                                    icon: "face.smiling",
                                    isSelected: selectedContent == .mood
                                ) {
                                    selectedContent = .mood
                                }
                            }
                        }

                        // Upgrade banner (only show for free users on their own account)
                        if !isPremiumUser && !appState.isViewingOtherAccount {
                            iPadSidebarUpgradeBanner()
                        }

                        // Bottom spacing for gradient
                        Spacer()
                            .frame(height: 140)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Bottom gradient overlay (matches right panel)
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.appBackgroundLight.opacity(0.0),
                        Color.appBackgroundLight.opacity(0.5),
                        Color.appBackgroundLight.opacity(0.85),
                        Color.appBackgroundLight
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .bottom)
        }
        .background(Color.appBackgroundLight)
        .refreshable {
            await viewModel.loadData(appState: appState)
            await appState.generateTodaysMedicationLogs()
            await viewModel.loadData(appState: appState)
        }
        .task {
            await viewModel.loadData(appState: appState)
            await appState.generateTodaysMedicationLogs()
            await viewModel.loadData(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationsDidChange)) { _ in
            Task {
                await appState.generateTodaysMedicationLogs()
                await viewModel.loadData(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appointmentsDidChange)) { _ in
            Task {
                await viewModel.loadData(appState: appState)
            }
        }
        .overlay {
            if showAccountSwitcher {
                // Tap-to-dismiss background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showAccountSwitcher = false
                    }
                    .transition(.opacity)
                    .zIndex(99)
            }
        }
        .overlay(alignment: .topLeading) {
            if showAccountSwitcher {
                iPadAccountSwitcherPopover(isPresented: $showAccountSwitcher)
                    .environmentObject(appState)
                    .transition(.scale(scale: 0.8, anchor: .topLeading).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAccountSwitcher)
        .onChange(of: appState.currentAccount?.id) { _, _ in
            // Reload data when account changes
            Task {
                await viewModel.loadData(appState: appState)
                await appState.generateTodaysMedicationLogs()
                await viewModel.loadData(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            // Reload sidebar data when account changes from elsewhere
            Task {
                await viewModel.loadData(appState: appState)
                await appState.generateTodaysMedicationLogs()
                await viewModel.loadData(appState: appState)
            }
        }
    }
}

// MARK: - iPad Account Switcher Popover
struct iPadAccountSwitcherPopover: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Switch Account")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding()

            Divider()
                .background(Color.textSecondary.opacity(0.3))

            // Account List - sizes to fit content, scrolls if too many accounts
            VStack(spacing: 8) {
                ForEach(appState.allAccounts) { accountWithRole in
                    iPadAccountSwitcherRow(
                        accountWithRole: accountWithRole,
                        isSelected: appState.currentAccount?.id == accountWithRole.account.id,
                        onSelect: {
                            Task {
                                await appState.switchAccount(to: accountWithRole)
                                isPresented = false
                            }
                        }
                    )
                }
            }
            .padding()
        }
        .frame(width: 400)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(.top, 70) // Position below header
        .padding(.leading, 16)
    }
}

// MARK: - iPad Account Switcher Row
struct iPadAccountSwitcherRow: View {
    let accountWithRole: AccountWithRole
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Account icon
                ZStack {
                    Circle()
                        .fill(accountWithRole.isOwner ? appAccentColor : Color.cardBackgroundSoft)
                        .frame(width: 40, height: 40)

                    Image(systemName: accountWithRole.isOwner ? "house.fill" : "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(accountWithRole.isOwner ? .black : .textSecondary)
                }

                // Account info
                VStack(alignment: .leading, spacing: 2) {
                    Text(accountWithRole.displayName)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Text(accountWithRole.role.displayName)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Selected indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(appAccentColor)
                }
            }
            .padding(12)
            .background(isSelected ? appAccentColor.opacity(0.1) : Color.cardBackgroundSoft)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? appAccentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - iPad Sidebar Navigation Item
struct iPadSidebarNavItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : appAccentColor)
                    .frame(width: 28)

                Text(title)
                    .font(.appCardTitle)
                    .foregroundColor(isSelected ? .white : .textPrimary)

                Spacer()

                if !isSelected {
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(AppDimensions.cardPaddingLarge)
            .background(isSelected ? appAccentColor : Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }
}

// MARK: - iPad Sidebar Upgrade Banner
struct iPadSidebarUpgradeBanner: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var showUpgradeSheet = false

    var body: some View {
        Button {
            showUpgradeSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundColor(appAccentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Plan")
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    Text("Tap to upgrade")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Text("Upgrade")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appBackground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(appAccentColor)
                    .cornerRadius(12)
            }
            .padding(AppDimensions.cardPadding)
            .background(
                LinearGradient(
                    colors: [
                        appAccentColor.opacity(0.12),
                        appAccentColor.opacity(0.04)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(appAccentColor.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
        }
    }
}

// MARK: - iPad Sidebar Today Card
struct iPadSidebarTodayCard: View {
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
                        iPadSidebarMedicationRow(log: log, viewModel: viewModel)
                    case .appointment(let appointment):
                        iPadSidebarAppointmentRow(appointment: appointment, viewModel: viewModel)
                    case .birthday(let profile):
                        iPadSidebarBirthdayRow(profile: profile)
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

// MARK: - iPad Sidebar Medication Row
struct iPadSidebarMedicationRow: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    let log: MedicationLog
    @ObservedObject var viewModel: HomeViewModel
    @State private var isUpdating = false
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pill.fill")
                .font(.system(size: 18))
                .foregroundColor(.medicalRed)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.medicationName(for: log))
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(log.scheduledAt.formatted(date: .omitted, time: .shortened))
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

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
                            .frame(width: 50, height: 28)
                            .background(appAccentColor)
                            .cornerRadius(6)
                    } else {
                        Text("Take")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.appBackground)
                            .frame(width: 50, height: 28)
                            .background(appAccentColor)
                            .cornerRadius(6)
                    }
                }
                .disabled(isUpdating)
            } else {
                Text("Taken")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(appAccentColor)
            }

            Button {
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, AppDimensions.cardPadding)
        .padding(.vertical, 10)
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

// MARK: - iPad Sidebar Appointment Row
struct iPadSidebarAppointmentRow: View {
    let appointment: Appointment
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 18))
                .foregroundColor(.calendarBlue)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(appointment.title)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

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

            Button {
                viewModel.toggleAppointmentCompleted(appointmentId: appointment.id, appState: appState)
            } label: {
                Image(systemName: appointment.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 22))
                    .foregroundColor(appointment.isCompleted ? appAccentColor : .textSecondary.opacity(0.4))
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, AppDimensions.cardPadding)
        .padding(.vertical, 10)
        .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
            Button("View details") { }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - iPad Sidebar Birthday Row
struct iPadSidebarBirthdayRow: View {
    let profile: Profile
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 18))
                .foregroundColor(.calendarPink)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(profile.displayName)'s Birthday")
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                if let age = profile.age {
                    Text("Turning \(age + 1)")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Button {
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, AppDimensions.cardPadding)
        .padding(.vertical, 10)
        .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
            Button("View profile") { }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - iPad To Do Lists View (Uses full-screen overlay for detail)
struct iPadToDoListsView: View {
    @StateObject private var viewModel = ToDoListsViewModel()
    @EnvironmentObject var appState: AppState
    @State private var selectedList: ToDoList?
    @State private var showingAddList = false
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadViewToDoListAction) private var iPadViewToDoListAction

    var body: some View {
        iPadToDoListsListView(
            selectedList: $selectedList,
            viewModel: viewModel,
            onAddList: { showingAddList = true },
            useNavigationLinks: false,
            onListSelected: { list in
                // Use the full-screen overlay action if available
                if let viewAction = iPadViewToDoListAction {
                    viewAction(list)
                } else {
                    selectedList = list
                }
            }
        )
        .background(Color.appBackgroundLight)
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showingAddList) {
            AddToDoListSheet(viewModel: viewModel, onDismiss: { showingAddList = false }) { createdList in
                // Select and show the newly created list using full-screen overlay
                if let viewAction = iPadViewToDoListAction {
                    viewAction(createdList)
                } else {
                    selectedList = createdList
                }
            }
        }
    }
}

// MARK: - iPad To Do Lists List View
/// The list view for iPad that notifies when a list is selected
struct iPadToDoListsListView: View {
    @Binding var selectedList: ToDoList?
    @ObservedObject var viewModel: ToDoListsViewModel
    var onAddList: () -> Void
    var useNavigationLinks: Bool = false
    var onListSelected: ((ToDoList) -> Void)? = nil
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedType: String? = nil
    @State private var showingTypeFilter = false
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction

    var filteredLists: [ToDoList] {
        var lists = viewModel.lists

        // Filter by type
        if let type = selectedType {
            lists = lists.filter { $0.listType == type }
        }

        // Filter by search
        if !searchText.isEmpty {
            lists = lists.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        return lists
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    CustomizableHeaderView(
                        pageIdentifier: .todoLists,
                        title: "To Do Lists",
                        showBackButton: false,
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction,
                        showAddButton: true,
                        addAction: onAddList
                    )

                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Search Field with Type Filter Icon
                        HStack(spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.textSecondary)

                                TextField("Search lists", text: $searchText)
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(Color.cardBackground)
                            .cornerRadius(AppDimensions.cardCornerRadius)

                            Button(action: { showingTypeFilter = true }) {
                                Image(systemName: selectedType != nil ? "tag.fill" : "tag")
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedType != nil ? appAccentColor : .textSecondary)
                                    .frame(width: 44, height: 44)
                                    .background(Color.cardBackground)
                                    .cornerRadius(AppDimensions.cardCornerRadius)
                            }
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)

                        // Lists or Empty State
                        if filteredLists.isEmpty && !viewModel.isLoading {
                            toDoListsEmptyStateView
                        } else {
                            LazyVStack(spacing: AppDimensions.cardSpacing) {
                                ForEach(filteredLists) { list in
                                    if useNavigationLinks {
                                        // Portrait mode: Use NavigationLink for standard push transition
                                        NavigationLink(destination: ToDoListDetailView(list: list)) {
                                            ToDoListCard(list: list, isSelected: false)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        // Use button to show in floating panel
                                        Button {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                selectedList = list
                                                onListSelected?(list)
                                            }
                                        } label: {
                                            ToDoListCard(list: list, isSelected: selectedList?.id == list.id)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Type filter overlay when modal is shown
            if showingTypeFilter {
                ZStack {
                    Color.cardBackgroundLight.opacity(0.9)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingTypeFilter = false
                            }
                        }

                    iPadTypeFilterOverlay(
                        types: viewModel.listTypes,
                        selectedType: $selectedType,
                        viewModel: viewModel,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingTypeFilter = false
                            }
                        }
                    )
                }
                .zIndex(10)
                .transition(.opacity)
            }
        }
        .task {
            await viewModel.loadData(appState: appState)
        }
    }

    // MARK: - Empty State
    private var toDoListsEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.textSecondary)

            if selectedType != nil {
                // Filtered empty state (no lists match filter)
                Text("No \(selectedType!) lists")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                Text("Try selecting a different filter")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                // No lists at all
                Text("No To Do Lists")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                // Info card
                toDoListsInfoCard
                    .padding(.horizontal, 16)

                Button {
                    onAddList()
                } label: {
                    Text("Add List")
                        .font(.appBodyMedium)
                        .foregroundColor(.black)
                        .frame(width: 200)
                        .padding(.vertical, 14)
                        .background(appAccentColor)
                        .cornerRadius(AppDimensions.buttonCornerRadius)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: 400)
        .padding(.vertical, 60)
    }

    // MARK: - Info Card
    private var toDoListsInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(appAccentColor)

                Text("How To Do Lists Work")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                toDoListsInfoRow(icon: "list.bullet", text: "Create lists to organise tasks by category or project")
                toDoListsInfoRow(icon: "checkmark.circle", text: "Mark items as complete to track your progress")
                toDoListsInfoRow(icon: "tag", text: "Use types to filter and find lists quickly")
            }
        }
        .padding()
        .background(appAccentColor.opacity(0.2))
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    private func toDoListsInfoRow(icon: String, text: String) -> some View {
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
}

// MARK: - iPad Type Filter Overlay
private struct iPadTypeFilterOverlay: View {
    let types: [ToDoListType]
    @Binding var selectedType: String?
    @ObservedObject var viewModel: ToDoListsViewModel
    let onDismiss: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    @State private var typeToDelete: ToDoListType?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Filter by Type")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            .padding(.top, AppDimensions.cardPadding)
            .padding(.horizontal, AppDimensions.cardPadding)

            VStack(spacing: 8) {
                // All option
                Button {
                    selectedType = nil
                    onDismiss()
                } label: {
                    HStack {
                        Text("All")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        if selectedType == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(appAccentColor)
                        }
                    }
                    .padding(AppDimensions.cardPadding)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Type options
                ForEach(types) { type in
                    HStack(spacing: 0) {
                        Button {
                            selectedType = type.name
                            onDismiss()
                        } label: {
                            HStack {
                                Text(type.name)
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                if selectedType == type.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(appAccentColor)
                                }
                            }
                        }

                        Button {
                            typeToDelete = type
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.leading, AppDimensions.cardPadding)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 250)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .shadow(color: .black.opacity(0.3), radius: 12, y: 8)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .alert("Delete Type", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let type = typeToDelete {
                    deleteType(type)
                }
            }
        } message: {
            if let type = typeToDelete {
                Text("Are you sure you want to delete the type '\(type.name)'? This will not delete any lists.")
            }
        }
    }

    private func deleteType(_ type: ToDoListType) {
        Task {
            await viewModel.deleteType(type)
            // If the deleted type was selected, clear the filter
            if selectedType == type.name {
                selectedType = nil
            }
        }
    }
}

// MARK: - iPad To Do List Detail View
/// Customized detail view for iPad split panel with close button
struct iPadToDoListDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ToDoListDetailViewModel
    @State private var showingAddType = false
    @State private var showingTypeSelector = false
    @State private var newTypeName = ""
    @State private var newItemText = ""
    @State private var showKeyboardToolbar = false
    @State private var showDeleteConfirmation = false
    @State private var focusedItemId: UUID?
    @State private var activeOptionsMenuItemId: UUID?
    @State private var cardFrames: [UUID: CGRect] = [:]
    @FocusState private var newItemFocused: Bool
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(HeaderStyleManager.self) private var headerStyleManager

    let list: ToDoList
    let onClose: () -> Void
    var onDelete: (() -> Void)?

    private let compactHeaderHeight: CGFloat = AppDimensions.headerHeight / 2

    init(list: ToDoList, onClose: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ToDoListDetailViewModel(list: list))
        self.list = list
        self.onClose = onClose
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        // Compact Header with close button
                        ZStack(alignment: .bottom) {
                            // Background
                            GeometryReader { geometry in
                                if let uiImage = UIImage(named: "todo_header_default") {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                } else {
                                    LinearGradient(
                                        colors: [headerStyleManager.defaultAccentColor.opacity(0.8), headerStyleManager.defaultAccentColor.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                }
                            }
                            .frame(height: compactHeaderHeight)
                            .clipped()

                            // Gradient overlay
                            if activeOptionsMenuItemId == nil {
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }

                            // Header content with close button
                            VStack {
                                HStack {
                                    Button(action: onClose) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 36, height: 36)
                                            .background(Color.white.opacity(0.2))
                                            .clipShape(Circle())
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, AppDimensions.screenPadding)
                                .padding(.top, 60)

                                Spacer()
                            }
                        }
                        .frame(height: compactHeaderHeight)
                        .opacity(activeOptionsMenuItemId != nil ? 0 : 1)

                        VStack(spacing: AppDimensions.cardSpacing) {
                            // Title Edit Field with Type Icon and Delete Button
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("List Title")
                                        .font(.appCaption)
                                        .foregroundColor(.textSecondary)

                                    Spacer()

                                    if let type = viewModel.selectedType {
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                showingTypeSelector = true
                                            }
                                        }) {
                                            Text(type)
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(appAccentColor)
                                                .cornerRadius(6)
                                        }
                                    }
                                }

                                HStack(spacing: 12) {
                                    TextField("Enter title", text: $viewModel.listTitle)
                                        .font(.appBody)
                                        .foregroundColor(.textPrimary)
                                        .onChange(of: viewModel.listTitle) { _, _ in
                                            viewModel.saveTitle()
                                        }

                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showingTypeSelector = true
                                        }
                                    }) {
                                        Image(systemName: viewModel.selectedType != nil ? "tag.fill" : "tag")
                                            .font(.system(size: 20))
                                            .foregroundColor(viewModel.selectedType != nil ? appAccentColor : .textSecondary)
                                    }

                                    Button(action: { showDeleteConfirmation = true }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(AppDimensions.cardPadding)
                                .background(Color.cardBackground)
                                .cornerRadius(AppDimensions.cardCornerRadius)
                            }
                            .padding(.horizontal, AppDimensions.screenPadding)

                            // To Do Items
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Items")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                                    .padding(.horizontal, AppDimensions.screenPadding)

                                LazyVStack(spacing: 12) {
                                    ForEach(Array(viewModel.sortedItems.enumerated()), id: \.element.id) { index, item in
                                        ToDoItemCard(
                                            item: item,
                                            focusedItemId: $focusedItemId,
                                            onToggle: { viewModel.toggleItem(item) },
                                            onTextChange: { newText in
                                                viewModel.updateItemText(item, text: newText)
                                            },
                                            onDelete: { viewModel.deleteItem(item) },
                                            onMoveUp: index > 0 ? { viewModel.moveItemUp(item) } : nil,
                                            onMoveDown: index < viewModel.sortedItems.count - 1 ? { viewModel.moveItemDown(item) } : nil,
                                            activeOptionsMenuItemId: $activeOptionsMenuItemId
                                        )
                                        .background(
                                            GeometryReader { geometry in
                                                Color.clear
                                                    .preference(
                                                        key: CardFramePreferenceKey.self,
                                                        value: [item.id: geometry.frame(in: .global)]
                                                    )
                                            }
                                        )
                                        .padding(.horizontal, AppDimensions.screenPadding)
                                        .id(item.id)
                                    }
                                }
                            }

                            Spacer().frame(height: 300)
                        }
                        .padding(.top, AppDimensions.cardSpacing)
                    }
                }
                .ignoresSafeArea(edges: .top)
                .onPreferenceChange(CardFramePreferenceKey.self) { frames in
                    cardFrames = frames
                }
                .onChange(of: focusedItemId) { _, newValue in
                    if let itemId = newValue {
                        withAnimation {
                            proxy.scrollTo(itemId, anchor: .center)
                        }
                    }
                }
            }

            // Floating add button or keyboard toolbar
            VStack {
                Spacer()

                if showKeyboardToolbar {
                    KeyboardToolbarView(
                        text: $newItemText,
                        placeholder: "Add new item...",
                        isFocused: $newItemFocused,
                        accentColor: appAccentColor,
                        onSubmit: {
                            addNewItem()
                        },
                        onDismiss: {
                            showKeyboardToolbar = false
                            newItemFocused = false
                        }
                    )
                } else {
                    HStack {
                        Spacer()
                        Button(action: {
                            showKeyboardToolbar = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                newItemFocused = true
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(appAccentColor)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                        .padding(.trailing, AppDimensions.screenPadding)
                        .padding(.bottom, 30)
                    }
                }
            }
            .zIndex(2)

            // Type selector overlay
            if showingTypeSelector {
                ZStack {
                    Color.cardBackgroundLight.opacity(0.9)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingTypeSelector = false
                            }
                        }

                    iPadTypeSelectorOverlay(
                        types: viewModel.availableTypes,
                        selectedType: $viewModel.selectedType,
                        onAddNewType: { showingAddType = true },
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingTypeSelector = false
                            }
                        }
                    )
                }
                .zIndex(5)
                .transition(.opacity)
                .onDisappear {
                    viewModel.saveType()
                }
            }

            // Highlighted item overlay with options menu
            if let activeItemId = activeOptionsMenuItemId,
               let item = viewModel.items.first(where: { $0.id == activeItemId }),
               let frame = cardFrames[activeItemId],
               let index = viewModel.sortedItems.firstIndex(where: { $0.id == activeItemId }) {
                HighlightedItemOverlay(
                    item: item,
                    frame: frame,
                    onToggle: { viewModel.toggleItem(item) },
                    onMoveUp: index > 0 ? { viewModel.moveItemUp(item) } : nil,
                    onMoveDown: index < viewModel.sortedItems.count - 1 ? { viewModel.moveItemDown(item) } : nil,
                    onDelete: { viewModel.deleteItem(item) },
                    onDismiss: { activeOptionsMenuItemId = nil }
                )
                .zIndex(1000)
            }
        }
        .alert("Add New Type", isPresented: $showingAddType) {
            TextField("Type name", text: $newTypeName)
            Button("Cancel", role: .cancel) { newTypeName = "" }
            Button("Add") {
                viewModel.addNewType(name: newTypeName)
                newTypeName = ""
            }
        }
        .alert("Delete List", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteList()
            }
        } message: {
            Text("Are you sure you want to delete '\(viewModel.listTitle)'? This will also delete all items in the list.")
        }
        .task {
            await viewModel.loadData(appState: appState)
        }
    }

    private func addNewItem() {
        guard !newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        viewModel.addNewItemWithText(newItemText)
        newItemText = ""
        newItemFocused = true
    }

    private func deleteList() {
        Task {
            await viewModel.deleteList()
            onDelete?()
            onClose()
        }
    }
}

// MARK: - iPad Type Selector Overlay
private struct iPadTypeSelectorOverlay: View {
    let types: [ToDoListType]
    @Binding var selectedType: String?
    let onAddNewType: () -> Void
    let onDismiss: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Select Type")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
                Button {
                    onAddNewType()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(appAccentColor)
                }
            }
            .padding(.top, AppDimensions.cardPadding)
            .padding(.horizontal, AppDimensions.cardPadding)

            VStack(spacing: 8) {
                // None option
                Button {
                    selectedType = nil
                    onDismiss()
                } label: {
                    HStack {
                        Text("None")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        if selectedType == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(appAccentColor)
                        }
                    }
                    .padding(AppDimensions.cardPadding)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Type options
                ForEach(types) { type in
                    Button {
                        selectedType = type.name
                        onDismiss()
                    } label: {
                        HStack {
                            Text(type.name)
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                            Spacer()
                            if selectedType == type.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(appAccentColor)
                            }
                        }
                        .padding(AppDimensions.cardPadding)
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 250)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .shadow(color: .black.opacity(0.3), radius: 12, y: 8)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - iPad Settings Content View
/// Full-panel Settings view for the iPad content area with full-screen overlays
struct iPadSettingsContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @Environment(FeatureVisibilityManager.self) private var featureVisibility
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction

    // iPad environment actions for full-screen overlays
    @Environment(\.iPadShowInviteMemberAction) private var iPadShowInviteMemberAction
    @Environment(\.iPadShowManageMembersAction) private var iPadShowManageMembersAction
    @Environment(\.iPadShowJoinAccountAction) private var iPadShowJoinAccountAction
    @Environment(\.iPadShowMoodHistoryAction) private var iPadShowMoodHistoryAction
    @Environment(\.iPadShowAppearanceSettingsAction) private var iPadShowAppearanceSettingsAction
    @Environment(\.iPadShowFeatureVisibilityAction) private var iPadShowFeatureVisibilityAction
    @Environment(\.iPadShowSwitchAccountAction) private var iPadShowSwitchAccountAction
    @Environment(\.iPadShowEditAccountNameAction) private var iPadShowEditAccountNameAction
    @Environment(\.iPadShowAdminPanelAction) private var iPadShowAdminPanelAction
    @Environment(\.iPadShowUpgradeAction) private var iPadShowUpgradeAction

    let onClose: () -> Void

    @State private var showSignOutConfirm = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    var body: some View {
        settingsListView
            .background(Color.appBackgroundLight)
            .navigationBarHidden(true)
            .alert("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await appState.signOut()
                        onClose()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
    }

    // MARK: - Settings List View

    private var settingsListView: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    CustomizableHeaderView(
                        pageIdentifier: .settings,
                        title: "Settings",
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction
                    )

                    VStack(spacing: 24) {
                        // Appearance section
                        SettingsPanelSection(title: "APPEARANCE") {
                            SettingsPanelButtonRow(
                                icon: "paintpalette",
                                title: "Colors & Headers",
                                isSelected: false
                            ) {
                                iPadShowAppearanceSettingsAction?()
                            }
                        }

                        // Features section
                        SettingsPanelSection(title: "FEATURES") {
                            SettingsPanelButtonRow(
                                icon: "square.grid.2x2",
                                title: "Show/Hide Features",
                                isSelected: false
                            ) {
                                iPadShowFeatureVisibilityAction?()
                            }
                        }

                        // Account section
                        SettingsPanelSection(title: "ACCOUNT") {
                            if let account = appState.currentAccount {
                                // Only owner/admin can edit account name
                                if appState.currentUserRole?.canManageMembers == true {
                                    SettingsPanelButtonRowWithValue(
                                        icon: "person.circle",
                                        title: "Account Name",
                                        value: account.displayName,
                                        isSelected: false
                                    ) {
                                        iPadShowEditAccountNameAction?()
                                    }
                                } else {
                                    SettingsPanelInfoRow(
                                        icon: "person.circle",
                                        title: "Account Name",
                                        value: account.displayName
                                    )
                                }

                                if let role = appState.currentUserRole {
                                    SettingsPanelInfoRow(
                                        icon: "person.badge.shield.checkmark",
                                        title: "Your Role",
                                        value: role.displayName
                                    )
                                }
                            }

                            // Only show invite/manage if user can manage members
                            if appState.currentUserRole?.canManageMembers == true {
                                SettingsPanelButtonRow(
                                    icon: "person.badge.plus",
                                    title: "Invite Family Member",
                                    isSelected: false
                                ) {
                                    iPadShowInviteMemberAction?()
                                }

                                SettingsPanelButtonRow(
                                    icon: "person.2",
                                    title: "Manage Members",
                                    isSelected: false
                                ) {
                                    iPadShowManageMembersAction?()
                                }
                            }

                            SettingsPanelButtonRow(
                                icon: "envelope.badge",
                                title: "Join Another Account",
                                isSelected: false
                            ) {
                                iPadShowJoinAccountAction?()
                            }

                            // Switch Account (only show if multiple accounts)
                            if appState.allAccounts.count > 1 {
                                SettingsPanelButtonRow(
                                    icon: "arrow.left.arrow.right",
                                    title: "Switch Account",
                                    isSelected: false
                                ) {
                                    iPadShowSwitchAccountAction?()
                                }
                            }
                        }

                        // Mood section
                        SettingsPanelSection(title: "MOOD") {
                            SettingsPanelButtonRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "View Mood History",
                                isSelected: false
                            ) {
                                iPadShowMoodHistoryAction?()
                            }
                        }

                        // Upgrade section (only show if not premium)
                        if !appState.hasPremiumAccess {
                            SettingsPanelSection(title: "UPGRADE") {
                                SettingsPanelButtonRow(
                                    icon: "star.fill",
                                    title: "Upgrade to Premium",
                                    isSelected: false
                                ) {
                                    iPadShowUpgradeAction?()
                                }
                            }
                        }

                        // Admin section (only visible to app admins)
                        if appState.isAppAdmin {
                            SettingsPanelSection(title: "APP ADMINISTRATION") {
                                SettingsPanelButtonRow(
                                    icon: "crown.fill",
                                    title: "Admin Panel",
                                    isSelected: false
                                ) {
                                    iPadShowAdminPanelAction?()
                                }
                            }
                        }

                        // About section
                        SettingsPanelSection(title: "ABOUT") {
                            SettingsPanelInfoRow(
                                icon: "info.circle",
                                title: "Version",
                                value: "1.0.0"
                            )

                            SettingsPanelButtonRow(
                                icon: "lock.shield",
                                title: "Privacy Policy",
                                isSelected: false
                            ) {
                                showPrivacyPolicy = true
                            }

                            SettingsPanelButtonRow(
                                icon: "doc.text",
                                title: "Terms of Service",
                                isSelected: false
                            ) {
                                showTermsOfService = true
                            }
                        }

                        // Sign out
                        Button {
                            showSignOutConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .font(.appBodyMedium)
                            .foregroundColor(.medicalRed)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(AppDimensions.cardCornerRadius)
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)

                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - iPad Floating Add Button Overlay
/// Floating add button with gradient fade for iPad right panel
struct iPadFloatingAddButtonOverlay: View {
    @Binding var showAddMenu: Bool
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var isPressed = false

    var body: some View {
        VStack {
            Spacer()

            ZStack(alignment: .bottomTrailing) {
                // Gradient background that fades to match page background
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.appBackgroundLight.opacity(0.0),
                        Color.appBackgroundLight.opacity(0.5),
                        Color.appBackgroundLight.opacity(0.85),
                        Color.appBackgroundLight
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

                // Floating add button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showAddMenu.toggle()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.black)
                        .rotationEffect(.degrees(showAddMenu ? 45 : 0))
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(appAccentColor)
                                .shadow(color: appAccentColor.opacity(0.4), radius: isPressed ? 6 : 12, y: isPressed ? 3 : 6)
                        )
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 28)
                .padding(.bottom, 28)
                .hoverEffect(.lift)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isPressed = true
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isPressed = false
                            }
                        }
                )
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - iPad Add Menu Overlay
/// Full-screen overlay with add menu popup for iPad
struct iPadAddMenuOverlay: View {
    @Binding var showAddMenu: Bool
    var isLimitedAccess: Bool
    var onAddProfile: () -> Void
    var onAddMedication: () -> Void
    var onAddAppointment: () -> Void
    var onAddContact: () -> Void
    var onAddToDoList: () -> Void
    var onAddNote: () -> Void
    var onAddStickyReminder: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor
    @State private var isVisible = false

    var body: some View {
        ZStack {
            // Dark overlay - tap to dismiss (full screen)
            Color.black.opacity(isVisible ? 0.7 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissMenu()
                }
                .animation(.easeOut(duration: 0.25), value: isVisible)

            // Full-width bottom gradient - positioned at bottom
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.appBackgroundLight.opacity(0.0),
                        Color.appBackgroundLight.opacity(0.5),
                        Color.appBackgroundLight.opacity(0.85),
                        Color.appBackgroundLight
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .bottom)

            // Menu popup positioned in bottom trailing
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if isVisible {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            Text("Add a new")
                                .font(.appCardTitle)
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 16)

                            Divider()
                                .background(Color.white.opacity(0.1))

                            // Menu items - limited for Helper/Viewer roles
                            if !isLimitedAccess {
                                iPadAddMenuRow(icon: "person.2", title: "Family or Friend") {
                                    dismissAndExecute { onAddProfile() }
                                }
                            }

                            iPadAddMenuRow(icon: "pill", title: "Medication") {
                                dismissAndExecute { onAddMedication() }
                            }

                            iPadAddMenuRow(icon: "calendar", title: "Appointment") {
                                dismissAndExecute { onAddAppointment() }
                            }

                            iPadAddMenuRow(icon: "phone", title: "Contact") {
                                dismissAndExecute { onAddContact() }
                            }

                            if !isLimitedAccess {
                                iPadAddMenuRow(icon: "checklist", title: "To Do List") {
                                    dismissAndExecute { onAddToDoList() }
                                }

                                iPadAddMenuRow(icon: "note.text", title: "Note") {
                                    dismissAndExecute { onAddNote() }
                                }

                                iPadAddMenuRow(icon: "bell.badge", title: "Sticky Reminder") {
                                    dismissAndExecute { onAddStickyReminder() }
                                }
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .background(Color.cardBackgroundLight.opacity(0.95))
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85, anchor: .bottomTrailing)
                                .combined(with: .opacity)
                                .combined(with: .offset(x: 20, y: 20)),
                            removal: .scale(scale: 0.85, anchor: .bottomTrailing)
                                .combined(with: .opacity)
                                .combined(with: .offset(x: 20, y: 20))
                        ))
                    }
                }
                .padding(.trailing, 28)
                .padding(.bottom, 110)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isVisible = true
            }
        }
    }

    private func dismissMenu() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showAddMenu = false
        }
    }

    private func dismissAndExecute(_ action: @escaping () -> Void) {
        // Execute action immediately (navigation + set panel state)
        action()

        // Then animate the menu out
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showAddMenu = false
        }
    }
}

// MARK: - iPad Add Menu Row
struct iPadAddMenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(appAccentColor)
                    .frame(width: 24)

                Text(title)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - iPad Side Panel Overlay
/// Single overlay that handles all side panel presentations with slide-in from right animation
struct iPadSidePanelOverlay: View {
    @Binding var showAddProfile: Bool
    @Binding var showAddMedication: Bool
    @Binding var showAddAppointment: Bool
    @Binding var showAddContact: Bool
    @Binding var showAddNote: Bool
    @Binding var showEditNote: Bool
    @Binding var noteToEdit: LocalNote?
    @Binding var showAddToDoList: Bool
    @Binding var showAddStickyReminder: Bool
    @Binding var showEditStickyReminder: Bool
    @Binding var stickyReminderToEdit: StickyReminder?
    @Binding var showViewStickyReminder: Bool
    @Binding var stickyReminderToView: StickyReminder?
    @Binding var showViewToDoList: Bool
    @Binding var toDoListToView: ToDoList?
    @Binding var showEditProfile: Bool
    @Binding var profileToEdit: Profile?
    @Binding var showEditMedication: Bool
    @Binding var medicationToEdit: Medication?
    @Binding var showEditAppointment: Bool
    @Binding var appointmentToEdit: Appointment?
    @Binding var showEditUsefulContact: Bool
    @Binding var usefulContactToEdit: UsefulContact?
    @Binding var showEditImportantAccount: Bool
    @Binding var importantAccountToEdit: ImportantAccount?
    @Binding var importantAccountProfile: Profile?
    @Binding var showAddImportantAccount: Bool
    @Binding var addImportantAccountProfile: Profile?
    @Binding var showAddMedicalCondition: Bool
    @Binding var addMedicalConditionProfile: Profile?
    @Binding var showAddGiftIdea: Bool
    @Binding var addGiftIdeaProfile: Profile?
    @Binding var showAddClothingSize: Bool
    @Binding var addClothingSizeProfile: Profile?
    @Binding var showSettingsInviteMember: Bool
    @Binding var showSettingsManageMembers: Bool
    @Binding var showSettingsJoinAccount: Bool
    @Binding var showSettingsMoodHistory: Bool
    @Binding var showSettingsAppearance: Bool
    @Binding var showSettingsFeatureVisibility: Bool
    @Binding var showSettingsSwitchAccount: Bool
    @Binding var showSettingsEditAccountName: Bool
    @Binding var showSettingsAdminPanel: Bool
    @Binding var showSettingsUpgrade: Bool
    @ObservedObject var toDoListsViewModel: ToDoListsViewModel
    var appState: AppState

    /// Check if any panel is showing
    private var isAnyPanelShowing: Bool {
        showAddProfile || showAddMedication || showAddAppointment ||
        showAddContact || showAddNote || showEditNote || showAddToDoList || showAddStickyReminder || showEditStickyReminder || showViewStickyReminder || showViewToDoList ||
        showEditProfile || showEditMedication || showEditAppointment || showEditUsefulContact ||
        showEditImportantAccount || showAddImportantAccount || showAddMedicalCondition || showAddGiftIdea || showAddClothingSize ||
        showSettingsInviteMember || showSettingsManageMembers || showSettingsJoinAccount || showSettingsMoodHistory ||
        showSettingsAppearance || showSettingsFeatureVisibility || showSettingsSwitchAccount || showSettingsEditAccountName ||
        showSettingsAdminPanel || showSettingsUpgrade
    }

    /// Dismiss all panels
    private func dismissAll() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showAddProfile = false
            showAddMedication = false
            showAddAppointment = false
            showAddContact = false
            showAddNote = false
            showEditNote = false
            noteToEdit = nil
            showAddToDoList = false
            showAddStickyReminder = false
            showEditStickyReminder = false
            stickyReminderToEdit = nil
            showViewStickyReminder = false
            stickyReminderToView = nil
            showViewToDoList = false
            toDoListToView = nil
            showEditProfile = false
            profileToEdit = nil
            showEditMedication = false
            medicationToEdit = nil
            showEditAppointment = false
            appointmentToEdit = nil
            showEditUsefulContact = false
            usefulContactToEdit = nil
            showEditImportantAccount = false
            importantAccountToEdit = nil
            importantAccountProfile = nil
            showAddImportantAccount = false
            addImportantAccountProfile = nil
            showAddMedicalCondition = false
            addMedicalConditionProfile = nil
            showAddGiftIdea = false
            addGiftIdeaProfile = nil
            showAddClothingSize = false
            addClothingSizeProfile = nil
            showSettingsInviteMember = false
            showSettingsManageMembers = false
            showSettingsJoinAccount = false
            showSettingsMoodHistory = false
            showSettingsAppearance = false
            showSettingsFeatureVisibility = false
            showSettingsSwitchAccount = false
            showSettingsEditAccountName = false
            showSettingsAdminPanel = false
            showSettingsUpgrade = false
        }
    }

    var body: some View {
        ZStack {
            // Dimmed background
            if isAnyPanelShowing {
                Color.cardBackgroundLight.opacity(0.65)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissAll()
                    }
                    .transition(.opacity)
            }

            // Panel content - aligned to right
            GeometryReader { geometry in
                HStack {
                    Spacer()

                    if isAnyPanelShowing {
                        panelContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .frame(width: min(max(500, geometry.size.width * 0.45), 600), height: geometry.size.height * 0.8)
                            .background {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .fill(Color.cardBackgroundLight.opacity(0.85))
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.3), radius: 20, x: -5, y: 0)
                            .padding(.top, 40)
                            .padding(.trailing, 20)
                            .padding(.bottom, 40)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isAnyPanelShowing)
        .task(id: showAddToDoList) {
            if showAddToDoList {
                await toDoListsViewModel.loadData(appState: appState)
            }
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        if showAddProfile {
            AddProfileView(
                onDismiss: { dismissAll() },
                onSave: { _ in
                    dismissAll()
                    NotificationCenter.default.post(name: .profilesDidChange, object: nil)
                }
            )
            .environmentObject(appState)
        } else if showAddMedication {
            AddMedicationView(
                onDismiss: { dismissAll() }
            ) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .medicationsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showAddAppointment {
            AddAppointmentView(
                onDismiss: { dismissAll() }
            ) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .appointmentsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showAddContact {
            AddUsefulContactView(
                onDismiss: { dismissAll() }
            ) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .contactsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showAddNote {
            // New note - NoteEditorView handles its own UI including close button
            AddNoteSheetWrapper(onDismiss: { dismissAll() }, accountId: appState.currentAccount?.id)
                .environmentObject(appState)
        } else if showEditNote, let note = noteToEdit {
            // Edit existing note - NoteEditorView handles its own UI
            EditNoteSheetWrapper(note: note, onDismiss: { dismissAll() })
                .environmentObject(appState)
        } else if showAddToDoList {
            AddToDoListSheet(
                viewModel: toDoListsViewModel,
                onDismiss: { dismissAll() }
            ) { _ in
                dismissAll()
            }
            .environmentObject(appState)
        } else if showAddStickyReminder {
            AddStickyReminderView(
                onSave: { _ in
                    dismissAll()
                    NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
                },
                onDismiss: { dismissAll() }
            )
            .environmentObject(appState)
        } else if showEditStickyReminder, let reminder = stickyReminderToEdit {
            AddStickyReminderView(
                editingReminder: reminder,
                onSave: { _ in
                    dismissAll()
                    NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
                },
                onDismiss: { dismissAll() }
            )
            .environmentObject(appState)
        } else if showViewStickyReminder, let reminder = stickyReminderToView {
            iPadStickyReminderDetailView(
                reminder: reminder,
                onClose: { dismissAll() },
                onUpdate: { updatedReminder in
                    stickyReminderToView = updatedReminder
                },
                onEdit: { reminderToEdit in
                    // Switch from viewing to editing - close view panel and open edit panel
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showViewStickyReminder = false
                        stickyReminderToView = nil
                        stickyReminderToEdit = reminderToEdit
                        showEditStickyReminder = true
                    }
                }
            )
            .environmentObject(appState)
        } else if showViewToDoList, let list = toDoListToView {
            iPadToDoListDetailView(
                list: list,
                onClose: { dismissAll() },
                onDelete: {
                    toDoListsViewModel.lists.removeAll { $0.id == list.id }
                    dismissAll()
                }
            )
            .environmentObject(appState)
        } else if showEditProfile, let profile = profileToEdit {
            EditProfileView(profile: profile, onDismiss: { dismissAll() }) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .profilesDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showEditMedication, let medication = medicationToEdit {
            EditMedicationView(medication: medication, onDismiss: { dismissAll() }) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .medicationsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showEditAppointment, let appointment = appointmentToEdit {
            EditAppointmentView(appointment: appointment, onDismiss: { dismissAll() }) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .appointmentsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showEditUsefulContact, let contact = usefulContactToEdit {
            EditUsefulContactView(contact: contact, onDismiss: { dismissAll() }) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .contactsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showEditImportantAccount, let account = importantAccountToEdit, let profile = importantAccountProfile {
            AddEditImportantAccountView(
                profile: profile,
                mode: .edit(account),
                onDismiss: { dismissAll() },
                onSave: { _ in
                    dismissAll()
                    // Note: AddEditImportantAccountView.saveAccount() already posts .importantAccountsDidChange
                }
            )
            .environmentObject(appState)
        } else if showAddImportantAccount, let profile = addImportantAccountProfile {
            AddEditImportantAccountView(
                profile: profile,
                mode: .add,
                onDismiss: { dismissAll() },
                onSave: { _ in
                    dismissAll()
                    // Note: AddEditImportantAccountView.saveAccount() already posts .importantAccountsDidChange
                }
            )
            .environmentObject(appState)
        } else if showAddMedicalCondition, let profile = addMedicalConditionProfile {
            AddProfileDetailView(
                profile: profile,
                category: .medical,
                onDismiss: { dismissAll() },
                onSave: { _ in
                    dismissAll()
                    // Note: AddProfileDetailView.saveDetail() already posts .profileDetailsDidChange
                }
            )
            .environmentObject(appState)
        } else if showAddGiftIdea, let profile = addGiftIdeaProfile {
            AddProfileDetailView(
                profile: profile,
                category: .gifts,
                onDismiss: { dismissAll() },
                onSave: { _ in
                    dismissAll()
                    // Note: AddProfileDetailView.saveDetail() already posts .profileDetailsDidChange
                }
            )
            .environmentObject(appState)
        } else if showAddClothingSize, let profile = addClothingSizeProfile {
            AddProfileDetailView(
                profile: profile,
                category: .clothing,
                onDismiss: { dismissAll() },
                onSave: { _ in
                    dismissAll()
                    // Note: AddProfileDetailView.saveDetail() already posts .profileDetailsDidChange
                }
            )
            .environmentObject(appState)
        } else if showSettingsInviteMember {
            InviteMemberView()
                .environmentObject(appState)
        } else if showSettingsManageMembers {
            ManageMembersView()
                .environmentObject(appState)
        } else if showSettingsJoinAccount {
            JoinAccountView()
                .environmentObject(appState)
        } else if showSettingsMoodHistory {
            MoodHistoryView()
                .environmentObject(appState)
        } else if showSettingsAppearance {
            AppearanceSettingsView()
                .environmentObject(appState)
        } else if showSettingsFeatureVisibility {
            FeatureVisibilityView()
                .environmentObject(appState)
        } else if showSettingsSwitchAccount {
            SwitchAccountView()
                .environmentObject(appState)
        } else if showSettingsEditAccountName {
            EditAccountNameView()
                .environmentObject(appState)
        } else if showSettingsAdminPanel {
            AdminPanelView()
                .environmentObject(appState)
        } else if showSettingsUpgrade {
            UpgradeView(isEmbedded: true)
                .environmentObject(appState)
        }
    }
}

// MARK: - Add Note Sheet Wrapper
/// Wrapper for creating a new note in side panel - delegates to NoteEditorView
struct AddNoteSheetWrapper: View {
    let onDismiss: () -> Void
    let accountId: UUID?
    @Environment(\.modelContext) private var modelContext
    @StateObject private var syncService = NotesSyncService()

    @State private var note: LocalNote?

    var body: some View {
        Group {
            if let note = note {
                NoteEditorView(
                    note: note,
                    isNewNote: true,
                    onDelete: {
                        // Delete note if it was saved and synced
                        if let noteToDelete = self.note {
                            // Delete from Supabase if synced
                            if let remoteId = noteToDelete.supabaseId {
                                Task {
                                    try? await syncService.deleteRemote(id: remoteId)
                                }
                            }
                            modelContext.delete(noteToDelete)
                            try? modelContext.save()  // Persist deletion immediately
                        }
                        onDismiss()
                    },
                    onSave: {
                        // Insert into context when saved
                        if let noteToSave = self.note {
                            modelContext.insert(noteToSave)
                            try? modelContext.save()  // Persist insertion immediately
                        }
                        onDismiss()
                    },
                    onClose: onDismiss
                )
            } else {
                ProgressView()
                    .onAppear {
                        note = LocalNote(title: "", theme: .standard, accountId: accountId)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Note: Uses shared modelContainer from iPadRootView
    }
}

// MARK: - Edit Note Sheet Wrapper
/// Wrapper for editing an existing note in side panel
struct EditNoteSheetWrapper: View {
    let note: LocalNote
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext
    @StateObject private var syncService = NotesSyncService()

    var body: some View {
        NoteEditorView(
            note: note,
            isNewNote: false,
            onDelete: {
                // Delete from Supabase if synced
                if let remoteId = note.supabaseId {
                    Task {
                        try? await syncService.deleteRemote(id: remoteId)
                    }
                }
                modelContext.delete(note)
                try? modelContext.save()  // Persist deletion immediately
                onDismiss()
            },
            onClose: onDismiss
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Note: Uses shared modelContainer from iPadRootView
    }
}

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
                        Text("Reactivate")
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

// MARK: - Preview
#Preview("iPad Root View") {
    iPadRootView()
        .environmentObject(AppState())
        .environment(UserHeaderOverrides())
        .environment(UserPreferences())
        .environment(HeaderStyleManager())
        .environment(FeatureVisibilityManager())
}
