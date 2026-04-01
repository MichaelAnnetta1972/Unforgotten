import SwiftUI

// MARK: - Calendar View
struct CalendarView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CalendarViewModel()
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // iPad environment actions for full-screen overlays
    @Environment(\.iPadCalendarFilterBinding) private var iPadCalendarFilterBinding
    @Environment(\.iPadCalendarCountdownTypeFilterBinding) private var iPadCalendarCountdownTypeFilterBinding
    @Environment(\.iPadCalendarCustomTypeNameFilterBinding) private var iPadCalendarCustomTypeNameFilterBinding
    @Environment(\.iPadCalendarMemberFilterBinding) private var iPadCalendarMemberFilterBinding
    @Environment(\.iPadCalendarMembersWithEventsBinding) private var iPadCalendarMembersWithEventsBinding
    @Environment(\.iPadCalendarDayDetailAction) private var iPadCalendarDayDetailAction
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.navigateToHomeTab) private var navigateToHomeTab
    @Environment(\.dismiss) private var dismiss

    @State private var showingDayDetail = false
    @State private var showingFilterPanel = false
    @State private var showingMemberFilter = false

    // Navigation state for event detail views (iPhone only - iPad uses iPadRootView navigation)
    @State private var selectedAppointment: Appointment?
    @State private var selectedCountdown: Countdown?
    @State private var selectedProfile: Profile?
    @State private var selectedMedication: Medication?
    @State private var selectedToDoList: ToDoList?

    private var isiPad: Bool {
        horizontalSizeClass == .regular
    }

    /// Whether any main type filter is not at its default (all selected) state
    private var hasActiveFilters: Bool {
        viewModel.selectedFilters.count < CalendarEventFilter.allCases.count
    }

    /// Whether any countdown sub-type filter is deselected
    private var hasActiveCountdownSubFilters: Bool {
        !viewModel.allCountdownSubTypesSelected
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            VStack(spacing: 0) {
                if isiPad {
                    // iPad: Fixed Header Section
                    VStack(spacing: 0) {
                        CustomizableHeaderView(
                            pageIdentifier: .calendar,
                            title: "Calendar",
                            showBackButton: iPadHomeAction == nil,
                            backAction: { dismiss() },
                            showHomeButton: iPadHomeAction != nil,
                            homeAction: iPadHomeAction,
                            tutorialVideoURL: "https://unforgottenapp.com/tutorials/Calendar.mp4"
                        )

                        ViewingAsBar()

                        VStack(spacing: AppDimensions.cardSpacing) {
                            controlsRow
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)
                        .padding(.top, AppDimensions.cardSpacing)
                        .padding(.bottom, AppDimensions.cardSpacing)
                        .background(Color.appBackgroundLight)
                    }
                }

                // Scrollable Content Section
                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // iPhone: Header scrolls with content
                        if !isiPad {
                            VStack(spacing: 0) {
                                CustomizableHeaderView(
                                    pageIdentifier: .calendar,
                                    title: "Calendar",
                                    showBackButton: true,
                                    backAction: { navigateToHomeTab?() ?? dismiss() },
                                    showHomeButton: false,
                                    homeAction: nil,
                                    tutorialVideoURL: "https://unforgottenapp.com/tutorials/Calendar.mp4",
                                    heightOverride: AppDimensions.headerHeight
                                )

                                ViewingAsBar()

                                VStack(spacing: AppDimensions.cardSpacing) {
                                    calendarTabPicker
                                    controlsRow
                                }
                                .padding(.horizontal, AppDimensions.screenPadding)
                                .padding(.top, AppDimensions.cardSpacing)
                                .padding(.bottom, AppDimensions.cardSpacing)
                            }
                            .padding(.horizontal, -AppDimensions.screenPadding)
                        }

                        // Calendar Content
                        CalendarMonthView(viewModel: viewModel) {
                            // On iPad, use full-screen overlay from iPadRootView
                            if let iPadAction = iPadCalendarDayDetailAction,
                               let selectedDate = viewModel.selectedDate {
                                iPadAction(selectedDate, viewModel.eventsForSelectedDate) {
                                    // onDismiss callback - clear the selection
                                    viewModel.clearSelection()
                                }
                            } else {
                                showingDayDetail = true
                            }
                        }

                        // Month events list (like Appointment Calendar view)
                        if !viewModel.eventsForCurrentMonth.isEmpty {
                            monthEventsSection
                        }

                        // Loading state
                        if viewModel.isLoading && viewModel.events.isEmpty {
                            LoadingView(message: "Loading calendar...")
                                .padding(.top, 40)
                        }

                        // Empty state
                        if !viewModel.isLoading && viewModel.filteredEvents.isEmpty {
                            emptyStateView
                        }
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.bottom, 100)
                }
            }


            // Day detail overlay (only shown on iPhone - iPad uses full-screen overlay from iPadRootView)
            if showingDayDetail && !isiPad, let selectedDate = viewModel.selectedDate {
                CalendarDayDetailView(
                    date: selectedDate,
                    events: viewModel.eventsForSelectedDate,
                    isPresented: $showingDayDetail,
                    onEventSelected: { event in
                        handleEventSelection(event)
                    }
                )
            }

            // Filter panel overlay
            if showingFilterPanel {
                CalendarFilterView(
                    selectedFilters: $viewModel.selectedFilters,
                    selectedCountdownTypes: $viewModel.selectedCountdownTypes,
                    selectedCustomTypeNames: $viewModel.selectedCustomTypeNames,
                    isPresented: $showingFilterPanel,
                    availableCountdownTypes: viewModel.availableCountdownTypes,
                    availableCustomTypeNames: viewModel.availableCustomTypeNames
                )
            }

            // Member filter panel overlay
            if showingMemberFilter {
                CalendarMemberFilterView(
                    selectedMemberFilters: $viewModel.selectedMemberFilters,
                    isPresented: $showingMemberFilter,
                    membersWithEvents: viewModel.membersWithEvents,
                    memberNameResolver: { viewModel.profileName(for: $0) }
                )
            }
        }
        .onChange(of: showingDayDetail) { _, isShowing in
            // Clear selection when modal is dismissed (iPhone)
            if !isShowing {
                viewModel.clearSelection()
            }
        }
        .onChange(of: showingFilterPanel) { _, isShowing in
            // Sync filter state to iPad bindings when panel closes
            if !isShowing {
                iPadCalendarFilterBinding?.wrappedValue = viewModel.selectedFilters
                iPadCalendarCountdownTypeFilterBinding?.wrappedValue = viewModel.selectedCountdownTypes
                iPadCalendarCustomTypeNameFilterBinding?.wrappedValue = viewModel.selectedCustomTypeNames
            }
        }
        .onChange(of: showingMemberFilter) { _, isShowing in
            // Sync member filter state to iPad bindings when panel closes
            if !isShowing {
                iPadCalendarMemberFilterBinding?.wrappedValue = viewModel.selectedMemberFilters
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedAppointment != nil },
            set: { if !$0 { selectedAppointment = nil } }
        )) {
            if let appointment = selectedAppointment {
                AppointmentDetailView(appointment: appointment)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedCountdown != nil },
            set: { if !$0 { selectedCountdown = nil } }
        )) {
            if let countdown = selectedCountdown {
                CountdownDetailView(countdown: countdown)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedProfile != nil },
            set: { if !$0 { selectedProfile = nil } }
        )) {
            if let profile = selectedProfile {
                ProfileDetailView(profile: profile)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedMedication != nil },
            set: { if !$0 { selectedMedication = nil } }
        )) {
            if let medication = selectedMedication {
                MedicationDetailView(medication: medication)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedToDoList != nil },
            set: { if !$0 { selectedToDoList = nil } }
        )) {
            if let list = selectedToDoList {
                ToDoListDetailView(list: list)
            }
        }
        .onChange(of: iPadCalendarFilterBinding?.wrappedValue) { _, newValue in
            // Sync iPad filter binding back to viewModel
            if let newValue = newValue {
                viewModel.selectedFilters = newValue
            }
        }
        .onChange(of: iPadCalendarCountdownTypeFilterBinding?.wrappedValue) { _, newValue in
            // Sync iPad countdown type filter binding back to viewModel
            if let newValue = newValue {
                viewModel.selectedCountdownTypes = newValue
            }
        }
        .onChange(of: iPadCalendarCustomTypeNameFilterBinding?.wrappedValue) { _, newValue in
            // Sync iPad custom type name filter binding back to viewModel
            if let newValue = newValue {
                viewModel.selectedCustomTypeNames = newValue
            }
        }
        .onChange(of: iPadCalendarMemberFilterBinding?.wrappedValue) { _, newValue in
            // Sync iPad member filter binding back to viewModel
            if let newValue = newValue {
                viewModel.selectedMemberFilters = newValue
            }
        }
        .onChange(of: viewModel.membersWithEvents) { _, newValue in
            // Sync membersWithEvents to iPad binding
            iPadCalendarMembersWithEventsBinding?.wrappedValue = newValue
        }
        .onChange(of: viewModel.selectedMemberFilters) { _, newValue in
            // Sync viewModel member filters to iPad binding
            if iPadCalendarMemberFilterBinding?.wrappedValue != newValue {
                iPadCalendarMemberFilterBinding?.wrappedValue = newValue
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .task {
            await viewModel.loadData(appState: appState)
            // After data loads, sync state to iPad bindings
            iPadCalendarMembersWithEventsBinding?.wrappedValue = viewModel.membersWithEvents
            iPadCalendarCustomTypeNameFilterBinding?.wrappedValue = viewModel.selectedCustomTypeNames
        }
    }

    // MARK: - Tab Picker (Full Width - iPhone only)

    private var calendarTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(CalendarTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    Text(tab.displayName)
                        .font(.appCardTitle)
                        .foregroundColor(viewModel.selectedTab == tab ? .black : .textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            viewModel.selectedTab == tab ? appAccentColor : Color.clear
                        )
                }
            }
        }
        .background(Color.cardBackgroundSoft)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Controls Row

    private var controlsRow: some View {
        HStack(spacing: 8) {
            // Tab Picker (Personal / Family) - compact, iPad only
            if isiPad {
                HStack(spacing: 0) {
                    ForEach(CalendarTab.allCases) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedTab = tab
                            }
                        } label: {
                            Text(tab.displayName)
                                .font(.appCaption)
                                .lineLimit(1)
                                .foregroundColor(viewModel.selectedTab == tab ? .black : .textSecondary)
                                .frame(minWidth: 60)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.selectedTab == tab ? appAccentColor : Color.clear
                                )
                        }
                    }
                }
                .fixedSize()
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.pillCornerRadius)
            }

            // Today button
            Button {
                viewModel.goToToday()
            } label: {
                Text("Today")
                    .font(.appCaption)
                    .foregroundColor(appAccentColor)
                    .frame(minWidth: 60)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.pillCornerRadius)
            }

            Spacer()

            // Collapse multi-day events toggle
            if viewModel.hasMultiDayEvents {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.collapseMultiDay.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.collapseMultiDay ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                        .font(.system(size: 20))
                        .foregroundColor(viewModel.collapseMultiDay ? appAccentColor : .textSecondary)
                        .frame(width: 44, height: 44)
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                }
            }

            // Event Type Filter button - opens slide-in panel
            Button {
                showingFilterPanel = true
            } label: {
                Image(systemName: hasActiveFilters || hasActiveCountdownSubFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20))
                    .foregroundColor(hasActiveFilters || hasActiveCountdownSubFilters
                        ? appAccentColor
                        : .textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.cardCornerRadius)
            }

            // Member Filter button (only shown when Family tab is selected)
            if viewModel.selectedTab == .family {
                Button {
                    showingMemberFilter = true
                } label: {
                    Image(systemName: !viewModel.selectedMemberFilters.isEmpty
                        ? "person.2.circle.fill"
                        : "person.2.circle")
                        .font(.system(size: 20))
                        .foregroundColor(!viewModel.selectedMemberFilters.isEmpty
                            ? appAccentColor
                            : .textSecondary)
                        .frame(width: 44, height: 44)
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                }
            }
        }
    }

    // MARK: - Month Events Section

    private var monthEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THIS MONTH")
                .font(.appCaption)
                .foregroundColor(appAccentColor)

            ForEach(viewModel.eventsForCurrentMonth) { event in
                Button {
                    handleEventSelection(event)
                } label: {
                    CalendarEventRow(event: event, showFullDetails: true, showDate: true, multiDayCount: monthEventMultiDayCount(for: event))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.textSecondary)

            Text(viewModel.selectedTab == .family ? "No Family Events" : "No Events")
                .font(.appTitle)
                .foregroundColor(.textPrimary)

            Text(viewModel.selectedTab == .family
                ? "Events shared to the family calendar will appear here."
                : "Your appointments, events, birthdays, and medications will appear here.")
                .font(.appBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Multi-Day Count Helper

    private func monthEventMultiDayCount(for event: CalendarEvent) -> Int? {
        guard viewModel.collapseMultiDay else { return nil }
        if case .countdown(let cd, _, _) = event, let gid = cd.groupId {
            return viewModel.countdownGroupDayCounts[gid]
        }
        return nil
    }

    // MARK: - Filter Toggles

    private func toggleMemberFilter(_ userId: UUID) {
        if viewModel.selectedMemberFilters.contains(userId) {
            viewModel.selectedMemberFilters.remove(userId)
        } else {
            viewModel.selectedMemberFilters.insert(userId)
        }
        iPadCalendarMemberFilterBinding?.wrappedValue = viewModel.selectedMemberFilters
    }

    // MARK: - Event Selection Handler

    private func handleEventSelection(_ event: CalendarEvent) {
        switch event {
        case .appointment(let appointment, _):
            selectedAppointment = appointment
        case .countdown(let countdown, _, _):
            selectedCountdown = countdown
        case .birthday(let upcomingBirthday):
            selectedProfile = upcomingBirthday.profile
        case .medication(let medication, _, _):
            selectedMedication = medication
        case .todoList(let list):
            selectedToDoList = list
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        CalendarView()
            .environmentObject(AppState.forPreview())
    }
}
