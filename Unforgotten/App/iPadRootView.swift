//
//  iPadRootView.swift
//  Unforgotten
//
//  iPad layout with persistent Home sidebar and content area
//  Component views are extracted to the iPad/ folder for maintainability
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
    case calendar
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
    @State private var showAddCountdown = false
    @State private var showEditCountdown = false
    @State private var countdownToEdit: Countdown?

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
    @State private var showEditGiftIdea = false
    @State private var editGiftIdeaDetail: ProfileDetail?
    @State private var showAddClothingSize = false
    @State private var addClothingSizeProfile: Profile?
    @State private var showEditClothingSize = false
    @State private var editClothingSizeDetail: ProfileDetail?

    // Hobbies & Activities overlays
    @State private var showAddHobbySection = false
    @State private var addHobbySectionProfile: Profile?
    @State private var showAddActivitySection = false
    @State private var addActivitySectionProfile: Profile?
    @State private var showAddHobbyItem = false
    @State private var addHobbyItemProfile: Profile?
    @State private var addHobbyItemSection: String?
    @State private var showAddActivityItem = false
    @State private var addActivityItemProfile: Profile?
    @State private var addActivityItemSection: String?

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

    // Appointment filter state (shared with AppointmentListView on iPad)
    @State private var showAppointmentFilter = false
    @State private var selectedAppointmentTypeFilter: AppointmentType? = nil

    // ToDo List filter state (shared with ToDoListsContent on iPad)
    @State private var showToDoListFilter = false
    @State private var selectedToDoListTypeFilter: String? = nil

    // ToDo Detail type selector state (for full-screen overlay)
    @State private var showToDoDetailTypeSelector = false
    @State private var toDoDetailTypeSelectorViewModel: ToDoListDetailViewModel? = nil
    @State private var toDoDetailTypeSelectorBinding: Binding<String?>? = nil
    @State private var toDoDetailTypeSelectorAddAction: (() -> Void)? = nil

    // Calendar filter state (shared with CalendarView on iPad)
    @State private var showCalendarFilter = false
    @State private var showCalendarMemberFilter = false
    @State private var selectedCalendarFilters: Set<CalendarEventFilter> = Set(CalendarEventFilter.allCases)
    @State private var selectedCalendarMemberFilters: Set<UUID> = []
    @State private var calendarMembersWithEvents: [AccountMemberWithUser] = []

    // Calendar day detail state (for full-screen overlay on iPad)
    @State private var showCalendarDayDetail = false
    @State private var calendarDayDetailDate: Date = Date()
    @State private var calendarDayDetailEvents: [CalendarEvent] = []
    @State private var calendarDayDetailOnDismiss: (() -> Void)? = nil

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

    // MARK: - Body

    var body: some View {
        bodyWithNotifications
            .onAppear {
                handlePendingOnboardingAction()
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

    // MARK: - View Composition

    /// Content area with all environment modifiers applied
    @ViewBuilder
    private var contentAreaWithEnvironments: some View {
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
            .environment(\.iPadAddMedicationAction, {
                if PremiumLimitsManager.shared.canCreateMedication(appState: appState, currentCount: medicationCount) {
                    showAddMedication = true
                } else {
                    showUpgradePrompt = true
                }
            })
            .environment(\.iPadAddAppointmentAction, {
                showAddAppointment = true
            })
            .environment(\.iPadAddContactAction, {
                if PremiumLimitsManager.shared.canCreateUsefulContact(appState: appState, currentCount: contactCount) {
                    showAddContact = true
                } else {
                    showUpgradePrompt = true
                }
            })
            .environment(\.iPadAppointmentFilterAction, {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAppointmentFilter = true
                }
            })
            .environment(\.iPadAppointmentFilterBinding, $selectedAppointmentTypeFilter)
            .environment(\.iPadAddToDoListAction, {
                if PremiumLimitsManager.shared.canCreateToDoList(appState: appState, currentCount: toDoListCount) {
                    showAddToDoList = true
                } else {
                    showUpgradePrompt = true
                }
            })
            .environment(\.iPadToDoListFilterAction, {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showToDoListFilter = true
                }
            })
            .environment(\.iPadToDoListFilterBinding, $selectedToDoListTypeFilter)
            .environment(\.iPadCalendarFilterAction, {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showCalendarFilter = true
                }
            })
            .environment(\.iPadCalendarMemberFilterAction, {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showCalendarMemberFilter = true
                }
            })
            .environment(\.iPadCalendarFilterBinding, $selectedCalendarFilters)
            .environment(\.iPadCalendarMemberFilterBinding, $selectedCalendarMemberFilters)
            .environment(\.iPadCalendarMembersWithEventsBinding, $calendarMembersWithEvents)
            .environment(\.iPadCalendarDayDetailAction, { date, events, onDismiss in
                calendarDayDetailDate = date
                calendarDayDetailEvents = events
                calendarDayDetailOnDismiss = onDismiss
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showCalendarDayDetail = true
                }
            })
            .environment(\.iPadCalendarDayDetailDismissAction, {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showCalendarDayDetail = false
                }
            })
            .environment(\.iPadCalendarEventSelectedAction, { event in
                // Dismiss the day detail first
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showCalendarDayDetail = false
                }
                // Navigate to the appropriate detail view
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    handleCalendarEventNavigation(event)
                }
            })
            .environment(\.iPadToDoDetailTypeSelectorAction, { viewModel, selectedTypeBinding, addAction in
                toDoDetailTypeSelectorViewModel = viewModel
                toDoDetailTypeSelectorBinding = selectedTypeBinding
                toDoDetailTypeSelectorAddAction = addAction
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showToDoDetailTypeSelector = true
                }
            })
            .environment(\.iPadAddStickyReminderAction, {
                if PremiumLimitsManager.shared.canCreateStickyReminder(appState: appState, currentCount: stickyReminderCount) {
                    showAddStickyReminder = true
                } else {
                    showUpgradePrompt = true
                }
            })
            .environment(\.iPadAddCountdownAction, {
                showAddCountdown = true
            })
            .environment(\.iPadEditCountdownAction, { countdown in
                countdownToEdit = countdown
                showEditCountdown = true
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
            .environment(\.iPadEditGiftIdeaAction, { detail in
                editGiftIdeaDetail = detail
                showEditGiftIdea = true
            })
            .environment(\.iPadAddClothingSizeAction, { profile in
                addClothingSizeProfile = profile
                showAddClothingSize = true
            })
            .environment(\.iPadEditClothingSizeAction, { detail in
                editClothingSizeDetail = detail
                showEditClothingSize = true
            })
            .environment(\.iPadAddHobbySectionAction, { profile in
                addHobbySectionProfile = profile
                showAddHobbySection = true
            })
            .environment(\.iPadAddActivitySectionAction, { profile in
                addActivitySectionProfile = profile
                showAddActivitySection = true
            })
            .environment(\.iPadAddHobbyItemAction, { profile, section in
                addHobbyItemProfile = profile
                addHobbyItemSection = section
                showAddHobbyItem = true
            })
            .environment(\.iPadAddActivityItemAction, { profile, section in
                addActivityItemProfile = profile
                addActivityItemSection = section
                showAddActivityItem = true
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
    }

    /// Type selector overlay for ToDo Detail
    @ViewBuilder
    private var toDoDetailTypeSelectorOverlay: some View {
        if showToDoDetailTypeSelector, let viewModel = toDoDetailTypeSelectorViewModel, let binding = toDoDetailTypeSelectorBinding {
            ZStack {
                Color.appBackgroundLight.opacity(0.8)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showToDoDetailTypeSelector = false
                        }
                    }

                iPadToDoDetailTypeSelectorOverlay(
                    viewModel: viewModel,
                    selectedType: binding,
                    onAddNewType: {
                        toDoDetailTypeSelectorAddAction?()
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showToDoDetailTypeSelector = false
                        }
                    }
                )
            }
            .transition(.opacity)
        }
    }

    /// Main layout ZStack
    private var mainLayoutZStack: some View {
        ZStack {
            HStack(spacing: 0) {
                // Left sidebar - iPhone Home style
                iPadHomeSidebar(
                    selectedContent: $selectedContent
                )
                .frame(width: 400)

                // Gap between panels
                Color.appBackground
                    .frame(width: 24)

                // Right content area with floating add button
                ZStack(alignment: .bottomTrailing) {
                    contentAreaWithEnvironments

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
                addMenuOverlay
            }

            // Appointment type filter overlay (covers entire screen when open)
            if showAppointmentFilter {
                appointmentFilterOverlay
            }

            // ToDo List type filter overlay (covers entire screen when open)
            if showToDoListFilter {
                toDoListFilterOverlay
            }

            // Calendar event type filter overlay (covers entire screen when open)
            if showCalendarFilter {
                calendarFilterOverlay
            }

            // Calendar member filter overlay (covers entire screen when open)
            if showCalendarMemberFilter {
                calendarMemberFilterOverlay
            }

            // Calendar day detail overlay (covers entire screen when open)
            if showCalendarDayDetail {
                calendarDayDetailOverlay
            }
        }
        .environment(\.navNamespace, navNamespace)
    }

    /// Add menu overlay
    private var addMenuOverlay: some View {
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
                selectedContent = .appointments
                showAddAppointment = true
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
            },
            onAddCountdown: {
                selectedContent = .birthdays
                showAddCountdown = true
            }
        )
    }

    /// Appointment filter overlay
    private var appointmentFilterOverlay: some View {
        ZStack {
            Color.cardBackground.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showAppointmentFilter = false
                    }
                }

            AppointmentTypeFilterOverlay(
                selectedType: $selectedAppointmentTypeFilter,
                isShowing: showAppointmentFilter,
                onDismiss: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showAppointmentFilter = false
                    }
                }
            )
        }
        .zIndex(10)
        .transition(.opacity)
    }

    /// ToDo List filter overlay
    private var toDoListFilterOverlay: some View {
        ZStack {
            Color.appBackgroundLight.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showToDoListFilter = false
                    }
                }

            iPadToDoListFilterOverlay(
                types: toDoListsViewModel.availableFilterTypes,
                selectedType: $selectedToDoListTypeFilter,
                onDismiss: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showToDoListFilter = false
                    }
                }
            )
        }
        .zIndex(10)
        .transition(.opacity)
    }

    /// Calendar event type filter overlay
    private var calendarFilterOverlay: some View {
        CalendarFilterView(
            selectedFilters: $selectedCalendarFilters,
            isPresented: $showCalendarFilter
        )
        .zIndex(10)
        .transition(.opacity)
    }

    /// Calendar member filter overlay
    private var calendarMemberFilterOverlay: some View {
        CalendarMemberFilterView(
            selectedMemberFilters: $selectedCalendarMemberFilters,
            isPresented: $showCalendarMemberFilter,
            membersWithEvents: calendarMembersWithEvents
        )
        .zIndex(10)
        .transition(.opacity)
    }

    /// Calendar day detail overlay
    private var calendarDayDetailOverlay: some View {
        CalendarDayDetailView(
            date: calendarDayDetailDate,
            events: calendarDayDetailEvents,
            isPresented: $showCalendarDayDetail,
            onEventSelected: { event in
                // Dismiss and navigate
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showCalendarDayDetail = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    handleCalendarEventNavigation(event)
                }
            }
        )
        .zIndex(10)
        .transition(.opacity)
        .onChange(of: showCalendarDayDetail) { _, isShowing in
            if !isShowing {
                // Call the onDismiss callback to clear the calendar selection
                calendarDayDetailOnDismiss?()
                calendarDayDetailOnDismiss = nil
            }
        }
    }

    /// Handle navigation to event detail views from calendar
    private func handleCalendarEventNavigation(_ event: CalendarEvent) {
        switch event {
        case .appointment(let appointment, _):
            // Navigate using the direct type (Appointment) which is registered in contentArea
            navigationPath.append(appointment)
        case .countdown(let countdown, _):
            // Countdowns need a navigation destination - append the countdown directly
            navigationPath.append(countdown)
        case .birthday(let upcomingBirthday):
            // Navigate using the direct type (Profile) which is registered in contentArea
            navigationPath.append(upcomingBirthday.profile)
        case .medication(let medication, _, _):
            // Navigate using the direct type (Medication) which is registered in contentArea
            navigationPath.append(medication)
        }
    }

    /// Side panel overlay
    private var sidePanelOverlay: some View {
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
            showEditGiftIdea: $showEditGiftIdea,
            editGiftIdeaDetail: $editGiftIdeaDetail,
            showAddClothingSize: $showAddClothingSize,
            addClothingSizeProfile: $addClothingSizeProfile,
            showEditClothingSize: $showEditClothingSize,
            editClothingSizeDetail: $editClothingSizeDetail,
            showAddHobbySection: $showAddHobbySection,
            addHobbySectionProfile: $addHobbySectionProfile,
            showAddActivitySection: $showAddActivitySection,
            addActivitySectionProfile: $addActivitySectionProfile,
            showAddHobbyItem: $showAddHobbyItem,
            addHobbyItemProfile: $addHobbyItemProfile,
            addHobbyItemSection: $addHobbyItemSection,
            showAddActivityItem: $showAddActivityItem,
            addActivityItemProfile: $addActivityItemProfile,
            addActivityItemSection: $addActivityItemSection,
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
            showAddCountdown: $showAddCountdown,
            showEditCountdown: $showEditCountdown,
            countdownToEdit: $countdownToEdit,
            toDoListsViewModel: toDoListsViewModel,
            appState: appState,
            toDoDetailTypeSelectorAction: { viewModel, selectedTypeBinding, addAction in
                toDoDetailTypeSelectorViewModel = viewModel
                toDoDetailTypeSelectorBinding = selectedTypeBinding
                toDoDetailTypeSelectorAddAction = addAction
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showToDoDetailTypeSelector = true
                }
            }
        )
    }

    /// Main layout with overlays
    private var mainLayoutWithOverlays: some View {
        mainLayoutZStack
            .overlay { sidePanelOverlay }
            .overlay { toDoDetailTypeSelectorOverlay }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showToDoDetailTypeSelector)
    }

    /// Body with change handlers
    private var bodyWithChangeHandlers: some View {
        mainLayoutWithOverlays
            .onChange(of: selectedContent) { _, _ in
                navigationPath = NavigationPath()
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
                selectedContent = .none
                navigationPath = NavigationPath()
                NotificationCenter.default.post(name: .accountDidChange, object: nil)
            }
    }

    /// Body with notifications
    private var bodyWithNotifications: some View {
        bodyWithChangeHandlers
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
    }

    // MARK: - Check Pending Notifications on Appear

    private func checkPendingNotifications() {
        guard appState.isAuthenticated, appState.hasCompletedOnboarding else { return }

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch action {
            case .addFriend:
                selectedContent = .profiles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showAddProfile = true
                }

            case .createReminder:
                selectedContent = .stickyReminders
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showAddStickyReminder = true
                }

            case .updateDetails:
                selectedContent = .myCard
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: .editPrimaryProfileRequested, object: nil)
                }

            case .exploreApp:
                break
            }
        }
    }

    // MARK: - Load Feature Counts for Premium Limits

    private func loadFeatureCounts() async {
        guard let account = appState.currentAccount else { return }

        do {
            let profiles = try await appState.profileRepository.getProfiles(accountId: account.id)
            profileCount = profiles.filter { $0.type != .primary }.count

            let medications = try await appState.medicationRepository.getMedications(accountId: account.id)
            medicationCount = medications.count

            let appointments = try await appState.appointmentRepository.getAppointments(accountId: account.id)
            appointmentCount = appointments.count

            let contacts = try await appState.usefulContactRepository.getContacts(accountId: account.id)
            contactCount = contacts.count

            let reminders = try await appState.stickyReminderRepository.getReminders(accountId: account.id)
            stickyReminderCount = reminders.count

            let lists = try await appState.toDoRepository.getLists(accountId: account.id)
            toDoListCount = lists.count

            await loadNoteCount(accountId: account.id)
        } catch {
            #if DEBUG
            print("Error loading feature counts: \(error)")
            #endif
        }
    }

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

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch selectedContent {
                case .none:
                    iPadEmptyContentView()
                case .myCard:
                    MyCardView()
                case .profiles:
                    ProfileListView()
                case .medications:
                    MedicationListView()
                case .appointments:
                    AppointmentListView()
                case .calendar:
                    CalendarView()
                case .todoLists:
                    iPadToDoListsView(viewModel: toDoListsViewModel)
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
            .navigationDestination(for: Countdown.self) { countdown in
                CountdownDetailView(countdown: countdown)
            }
        }
        .id(selectedContent)
        .tint(appAccentColor)
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
