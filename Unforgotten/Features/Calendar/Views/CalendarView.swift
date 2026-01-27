import SwiftUI

// MARK: - Calendar View
struct CalendarView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CalendarViewModel()
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // iPad environment actions for full-screen overlays
    @Environment(\.iPadCalendarFilterAction) private var iPadCalendarFilterAction
    @Environment(\.iPadCalendarMemberFilterAction) private var iPadCalendarMemberFilterAction
    @Environment(\.iPadCalendarFilterBinding) private var iPadCalendarFilterBinding
    @Environment(\.iPadCalendarMemberFilterBinding) private var iPadCalendarMemberFilterBinding
    @Environment(\.iPadCalendarMembersWithEventsBinding) private var iPadCalendarMembersWithEventsBinding
    @Environment(\.iPadCalendarDayDetailAction) private var iPadCalendarDayDetailAction
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.dismiss) private var dismiss

    @State private var showingFilters = false
    @State private var showingMemberFilters = false
    @State private var showingDayDetail = false
    @State private var scrollToTodayTrigger = false

    // Navigation state for event detail views (iPhone only - iPad uses iPadRootView navigation)
    @State private var selectedAppointment: Appointment?
    @State private var selectedCountdown: Countdown?
    @State private var selectedProfile: Profile?
    @State private var selectedMedication: Medication?

    private var isiPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed Header Section
                VStack(spacing: 0) {
                    // Header
                    CustomizableHeaderView(
                        pageIdentifier: .calendar,
                        title: "Calendar",
                        showBackButton: iPadHomeAction == nil,
                        backAction: { dismiss() },
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction
                    )

                    // Viewing As Bar
                    ViewingAsBar()

                    // Tab Picker and Controls - fixed below header
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Tab Picker - full width on iPhone, inline on iPad
                        if !isiPad {
                            calendarTabPicker
                        }

                        // Controls Row (Tab Picker on iPad + View Mode Toggle + Filters)
                        controlsRow
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                    .padding(.bottom, AppDimensions.cardSpacing)
                    .background(Color.appBackgroundLight)
                }

                // Scrollable Content Section
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: AppDimensions.cardSpacing) {
                            // Calendar Content
                            if viewModel.viewMode == .month {
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
                            } else {
                                CalendarListView(viewModel: viewModel, scrollProxy: scrollProxy, scrollToTodayTrigger: $scrollToTodayTrigger) { event in
                                    handleEventSelection(event)
                                }
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
            }

            // Event Type Filter overlay (only shown on iPhone - iPad uses full-screen overlay from iPadRootView)
            if showingFilters && !isiPad {
                CalendarFilterView(
                    selectedFilters: $viewModel.selectedFilters,
                    isPresented: $showingFilters
                )
            }

            // Member Filter overlay (only shown on iPhone - iPad uses full-screen overlay from iPadRootView)
            if showingMemberFilters && !isiPad {
                CalendarMemberFilterView(
                    selectedMemberFilters: $viewModel.selectedMemberFilters,
                    isPresented: $showingMemberFilters,
                    membersWithEvents: viewModel.membersWithEvents
                )
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
        }
        .onChange(of: showingDayDetail) { _, isShowing in
            // Clear selection when modal is dismissed (iPhone)
            if !isShowing {
                viewModel.clearSelection()
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
        .onChange(of: iPadCalendarFilterBinding?.wrappedValue) { _, newValue in
            // Sync iPad filter binding back to viewModel
            if let newValue = newValue {
                viewModel.selectedFilters = newValue
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
            // After data loads, sync members with events to iPad
            iPadCalendarMembersWithEventsBinding?.wrappedValue = viewModel.membersWithEvents
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
                                .padding(.horizontal, 12)
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
                // Trigger scroll to today in list mode
                if viewModel.viewMode == .list {
                    scrollToTodayTrigger.toggle()
                }
            } label: {
                Text("Today")
                    .font(.appCaption)
                    .foregroundColor(.textPrimary)
                    .frame(minWidth: 60)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.pillCornerRadius)
            }

            Spacer()

            // View mode toggle
            HStack(spacing: 4) {
                ForEach(CalendarViewMode.allCases) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.viewMode = mode
                        }
                    } label: {
                        Image(systemName: mode.icon)
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.viewMode == mode ? .black : .textSecondary)
                            .frame(width: 36, height: 36)
                            .background(
                                viewModel.viewMode == mode ? appAccentColor : Color.clear
                            )
                            .cornerRadius(8)
                    }
                }
            }
            .padding(4)
            .background(Color.cardBackgroundSoft)
            .cornerRadius(12)

            // Event Type Filter button
            Button {
                // On iPad, use the environment action for full-screen overlay
                if let iPadAction = iPadCalendarFilterAction {
                    iPadAction()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingFilters = true
                    }
                }
            } label: {
                Image(systemName: viewModel.selectedFilters.count < CalendarEventFilter.allCases.count
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.selectedFilters.count < CalendarEventFilter.allCases.count
                        ? appAccentColor
                        : .textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.cardCornerRadius)
            }

            // Member Filter button (only shown when Family tab is selected)
            if viewModel.selectedTab == .family {
                Button {
                    // On iPad, use the environment action for full-screen overlay
                    if let iPadAction = iPadCalendarMemberFilterAction {
                        iPadAction()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showingMemberFilters = true
                        }
                    }
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
                .foregroundColor(.textSecondary)

            ForEach(viewModel.eventsForCurrentMonth) { event in
                Button {
                    handleEventSelection(event)
                } label: {
                    CalendarEventRow(event: event, showFullDetails: true, showDate: true)
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

    // MARK: - Event Selection Handler

    private func handleEventSelection(_ event: CalendarEvent) {
        switch event {
        case .appointment(let appointment, _):
            selectedAppointment = appointment
        case .countdown(let countdown, _):
            selectedCountdown = countdown
        case .birthday(let upcomingBirthday):
            selectedProfile = upcomingBirthday.profile
        case .medication(let medication, _, _):
            selectedMedication = medication
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
