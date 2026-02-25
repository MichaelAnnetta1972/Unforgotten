import SwiftUI

// MARK: - Calendar Tab
enum CalendarTab: String, CaseIterable, Identifiable {
    case personal
    case family

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .personal: return "Personal"
        case .family: return "Family"
        }
    }
}

// MARK: - Calendar View Mode
enum CalendarViewMode: String, CaseIterable, Identifiable {
    case month
    case list

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .month: return "calendar"
        case .list: return "list.bullet"
        }
    }
}

// MARK: - Calendar View Model
@MainActor
class CalendarViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTab: CalendarTab = .personal
    @Published var viewMode: CalendarViewMode = .month
    @Published var selectedDate: Date? = nil
    @Published var currentMonth: Date = Date()
    @Published var selectedFilters: Set<CalendarEventFilter> = Set(CalendarEventFilter.allCases)
    @Published var selectedCountdownTypes: Set<CountdownType> = Set(CountdownType.allCases) // Sub-filter for standard countdown types
    @Published var selectedCustomTypeNames: Set<String> = [] // Sub-filter for custom countdown type names (populated on data load)
    @Published var selectedMemberFilters: Set<UUID> = [] // Empty means "all members" - stores user IDs

    @Published var events: [CalendarEvent] = []
    @Published var profiles: [Profile] = [] // All profiles for the account
    @Published var accountMembers: [AccountMemberWithUser] = [] // Invited family members
    @Published var sharedAppointmentIds: Set<UUID> = []
    @Published var sharedCountdownIds: Set<UUID> = []
    @Published var familyShares: [FamilyCalendarShare] = [] // Full share objects for filtering by sharedByUserId
    @Published var familyShareMembers: [UUID: Set<UUID>] = [:] // Maps shareId -> set of memberUserIds

    @Published var isLoading = false
    @Published var error: String?

    /// All account members that can be used for filtering
    /// Returns all members sorted by display name - the filter allows filtering events
    /// by profiles linked to these members via linkedUserId
    var membersWithEvents: [AccountMemberWithUser] {
        // Return all account members - they represent the "invited family members"
        // The filter will work for any events linked to profiles that have linkedUserId set
        return accountMembers.sorted { profileName(for: $0) < profileName(for: $1) }
    }

    /// Helper to check which profiles are linked to account members (for debugging)
    var linkedProfileUserIds: Set<UUID> {
        Set(profiles.compactMap { $0.linkedUserId ?? $0.sourceUserId })
    }

    /// Standard countdown types that are actually in use (excluding .custom which is shown by name)
    var availableCountdownTypes: [CountdownType] {
        let countdownEvents = events.compactMap { event -> Countdown? in
            if case .countdown(let cd, _, _) = event { return cd }
            return nil
        }
        let usedTypes = Set(countdownEvents.map { $0.type })
        return CountdownType.allCases.filter { usedTypes.contains($0) && $0 != .custom }
    }

    /// Unique custom type names used by existing countdowns
    var availableCustomTypeNames: [String] {
        let countdownEvents = events.compactMap { event -> Countdown? in
            if case .countdown(let cd, _, _) = event { return cd }
            return nil
        }
        let names = countdownEvents
            .filter { $0.type == .custom }
            .compactMap { $0.customType }
        return Array(Set(names)).sorted()
    }

    /// Whether all countdown sub-types are selected
    var allCountdownSubTypesSelected: Bool {
        let allStandardSelected = Set(availableCountdownTypes).isSubset(of: selectedCountdownTypes)
        let allCustomSelected = Set(availableCustomTypeNames).isSubset(of: selectedCustomTypeNames)
        return allStandardSelected && allCustomSelected
    }

    /// Resolves a member's display name using their linked profile's preferred name/full name
    func profileName(for member: AccountMemberWithUser) -> String {
        if let profile = profiles.first(where: { ($0.linkedUserId ?? $0.sourceUserId) == member.userId }) {
            return profile.displayName
        }
        return member.displayName
    }

    // MARK: - Computed Properties

    /// Events filtered by the selected type filters, countdown sub-type filters, and member filters
    var filteredEvents: [CalendarEvent] {
        events.filter { event in
            // Must match type filter
            guard selectedFilters.contains(event.filterType) else { return false }

            // For countdown events, also check the sub-type filter
            if case .countdown(let cd, _, _) = event {
                if cd.type == .custom {
                    if let customName = cd.customType, !customName.isEmpty {
                        guard selectedCustomTypeNames.contains(customName) else { return false }
                    }
                } else {
                    guard selectedCountdownTypes.contains(cd.type) else { return false }
                }
            }

            // If no member filters selected, show all events
            if selectedMemberFilters.isEmpty {
                return true
            }

            // If member filters are selected:
            // - Events with a profileId: check if that profile's linkedUserId matches a selected member
            // - Countdowns (no profileId) are always shown when any member filter is active
            if let profileId = event.profileId {
                // Find the profile and check its linkedUserId
                if let profile = profiles.first(where: { $0.id == profileId }),
                   let linkedUserId = profile.linkedUserId ?? profile.sourceUserId {
                    return selectedMemberFilters.contains(linkedUserId)
                }
                // Profile not linked to any user - don't show when filtering by members
                return false
            } else {
                // Countdowns don't have a profile, always include them
                return true
            }
        }
    }

    /// Events for the selected date (respects both tab selection and filters)
    var eventsForSelectedDate: [CalendarEvent] {
        guard let selectedDate = selectedDate else { return [] }
        let calendar = Calendar.current
        let eventsToFilter = selectedTab == .family ? familyEvents : filteredEvents
        return eventsToFilter.filter { event in
            calendar.isDate(event.date, inSameDayAs: selectedDate)
        }.sorted { $0.dateTime < $1.dateTime }
    }

    /// Events for the family calendar (only shared events)
    /// When member filters are active, filters by events that are:
    /// - Shared BY a selected member, OR
    /// - Shared WITH a selected member
    var familyEvents: [CalendarEvent] {
        // Start with events filtered by type and countdown sub-type
        let typeFilteredEvents = events.filter { event in
            guard selectedFilters.contains(event.filterType) else { return false }

            // For countdown events, also check the sub-type filter
            if case .countdown(let cd, _, _) = event {
                if cd.type == .custom {
                    if let customName = cd.customType, !customName.isEmpty {
                        return selectedCustomTypeNames.contains(customName)
                    }
                } else {
                    return selectedCountdownTypes.contains(cd.type)
                }
            }
            return true
        }

        // Filter to only shared events
        let sharedEvents = typeFilteredEvents.filter { $0.isSharedToFamily }

        // If no member filters selected, show all shared events
        if selectedMemberFilters.isEmpty {
            return sharedEvents
        }

        // Filter by events shared by OR shared with the selected members
        return sharedEvents.filter { event in
            // Get the event's UUID
            let eventId: UUID?
            let eventType: CalendarEventType?

            switch event {
            case .appointment(let apt, _):
                eventId = apt.id
                eventType = .appointment
            case .countdown(let cd, _, _):
                eventId = cd.id
                eventType = .countdown
            case .birthday, .medication, .todoList:
                // Birthdays, medications, and to-do lists can't be shared to family calendar
                return false
            }

            guard let id = eventId, let type = eventType else { return false }

            // Find the share for this event
            if let share = familyShares.first(where: { $0.eventId == id && $0.eventType == type }) {
                // Check if shared BY a selected member
                if selectedMemberFilters.contains(share.sharedByUserId) {
                    return true
                }

                // Check if shared WITH a selected member
                if let shareMembers = familyShareMembers[share.id] {
                    return !shareMembers.isDisjoint(with: selectedMemberFilters)
                }
            }

            return false
        }
    }

    /// Get events for a specific date
    func events(for date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        let eventsToFilter = selectedTab == .family ? familyEvents : filteredEvents
        return eventsToFilter.filter { event in
            calendar.isDate(event.date, inSameDayAs: date)
        }
    }

    /// Get dates that have events in the current month
    func datesWithEvents(in month: Date) -> Set<Date> {
        let calendar = Calendar.current
        let eventsToFilter = selectedTab == .family ? familyEvents : filteredEvents

        var dates = Set<Date>()
        for event in eventsToFilter {
            if calendar.isDate(event.date, equalTo: month, toGranularity: .month) {
                let startOfDay = calendar.startOfDay(for: event.date)
                dates.insert(startOfDay)
            }
        }
        return dates
    }

    /// Get event colors for a specific date (for calendar dots)
    func eventColors(for date: Date) -> [Color] {
        let dayEvents = events(for: date)
        let uniqueFilters = Set(dayEvents.map { $0.filterType })
        return uniqueFilters.map { $0.color }
    }

    /// Events for the current month (respects both tab selection and filters)
    var eventsForCurrentMonth: [CalendarEvent] {
        let calendar = Calendar.current
        let eventsToFilter = selectedTab == .family ? familyEvents : filteredEvents
        return eventsToFilter.filter { event in
            calendar.isDate(event.date, equalTo: currentMonth, toGranularity: .month)
        }.sorted { $0.dateTime < $1.dateTime }
    }

    /// Events grouped by date for list view
    var eventsGroupedByDate: [(date: Date, events: [CalendarEvent])] {
        let eventsToGroup = selectedTab == .family ? familyEvents : filteredEvents
        let sorted = eventsToGroup.sorted { $0.dateTime < $1.dateTime }

        var grouped: [(date: Date, events: [CalendarEvent])] = []
        var currentDate: Date?
        var currentEvents: [CalendarEvent] = []

        let calendar = Calendar.current
        for event in sorted {
            let eventDate = calendar.startOfDay(for: event.date)
            if eventDate != currentDate {
                if let date = currentDate, !currentEvents.isEmpty {
                    grouped.append((date: date, events: currentEvents))
                }
                currentDate = eventDate
                currentEvents = [event]
            } else {
                currentEvents.append(event)
            }
        }

        if let date = currentDate, !currentEvents.isEmpty {
            grouped.append((date: date, events: currentEvents))
        }

        return grouped
    }

    // MARK: - Data Loading

    func loadData(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true
        error = nil

        do {
            // Load profiles for member filtering (profiles link to events via profileId)
            profiles = try await appState.profileRepository.getProfiles(accountId: account.id)

            // Load account members (invited family members) for filtering
            accountMembers = try await appState.accountRepository.getAccountMembersWithUsers(accountId: account.id)

            // Load shared event IDs and full share objects (for member filtering)
            let sharedIds = try await appState.familyCalendarRepository.getSharedEventIdsForUser(accountId: account.id)
            sharedAppointmentIds = sharedIds.appointmentIds
            sharedCountdownIds = sharedIds.countdownIds

            // Load full share objects for filtering by sharedByUserId (across all accounts)
            familyShares = try await appState.familyCalendarRepository.getSharesVisibleToUser()

            // Load share members for each share (for filtering by "shared with")
            var memberMap: [UUID: Set<UUID>] = [:]
            for share in familyShares {
                let members = try await appState.familyCalendarRepository.getMembersForShare(shareId: share.id)
                memberMap[share.id] = Set(members.map { $0.memberUserId })
            }
            familyShareMembers = memberMap

            // Add all connected users (from profile_syncs) to accountMembers so they appear in the member filter
            let existingMemberUserIds = Set(accountMembers.map { $0.userId })
            if let currentUserId = await SupabaseManager.shared.currentUserId {
                let syncs = try await appState.profileSyncRepository.getSyncsForUser(userId: currentUserId)
                var connectedUserIds = Set<UUID>()
                for sync in syncs {
                    if sync.inviterUserId == currentUserId {
                        connectedUserIds.insert(sync.acceptorUserId)
                    } else {
                        connectedUserIds.insert(sync.inviterUserId)
                    }
                }
                // Remove users already in accountMembers
                connectedUserIds.subtract(existingMemberUserIds)
                // Look up connected users and create synthetic AccountMemberWithUser entries
                for userId in connectedUserIds {
                    if let appUser = try? await appState.appUserRepository.getUser(id: userId) {
                        let syntheticMember = AccountMember(
                            id: userId,
                            accountId: account.id,
                            userId: userId,
                            role: .viewer,
                            createdAt: Date()
                        )
                        accountMembers.append(AccountMemberWithUser(member: syntheticMember, user: appUser))
                    }
                }
            }

            // Load all event types in parallel
            async let appointmentsTask = loadAppointments(appState: appState, accountId: account.id)
            async let countdownsTask = loadCountdowns(appState: appState, accountId: account.id)
            async let birthdaysTask = loadBirthdays(appState: appState, accountId: account.id)
            async let medicationsTask = loadMedications(appState: appState, accountId: account.id)
            async let todoListsTask = loadToDoLists(appState: appState, accountId: account.id)

            let (appointments, countdowns, birthdays, medications, todoLists) = await (
                appointmentsTask,
                countdownsTask,
                birthdaysTask,
                medicationsTask,
                todoListsTask
            )

            // Combine all events
            var allEvents: [CalendarEvent] = []
            allEvents.append(contentsOf: appointments)
            allEvents.append(contentsOf: countdowns)
            allEvents.append(contentsOf: birthdays)
            allEvents.append(contentsOf: medications)
            allEvents.append(contentsOf: todoLists)

            events = allEvents

            // Initialize custom type name selections to include all available custom types
            selectedCustomTypeNames = Set(availableCustomTypeNames)

        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("CalendarViewModel error: \(error)")
            #endif
        }

        isLoading = false
    }

    private func loadAppointments(appState: AppState, accountId: UUID) async -> [CalendarEvent] {
        do {
            let ownAppointments = try await appState.appointmentRepository.getAppointments(accountId: accountId)
            let ownIds = Set(ownAppointments.map { $0.id })
            var allAppointments = ownAppointments

            // Fetch shared appointments via RPC (bypasses RLS on appointments table)
            do {
                let shared = try await appState.appointmentRepository.getSharedAppointments()
                let newShared = shared.filter { !ownIds.contains($0.id) }
                allAppointments.append(contentsOf: newShared)
            } catch {
                #if DEBUG
                print("Failed to load shared appointments: \(error)")
                #endif
            }

            return allAppointments.map { apt in
                let isShared = sharedAppointmentIds.contains(apt.id)
                return CalendarEvent.appointment(apt, isShared: isShared)
            }
        } catch {
            #if DEBUG
            print("Failed to load appointments: \(error)")
            #endif
            return []
        }
    }

    private func loadCountdowns(appState: AppState, accountId: UUID) async -> [CalendarEvent] {
        do {
            let ownCountdowns = try await appState.countdownRepository.getCountdowns(accountId: accountId)
            let ownIds = Set(ownCountdowns.map { $0.id })
            var allCountdowns = ownCountdowns

            // Fetch shared countdowns via RPC (bypasses RLS on countdowns table)
            do {
                let shared = try await appState.countdownRepository.getSharedCountdowns()
                let newShared = shared.filter { !ownIds.contains($0.id) }
                allCountdowns.append(contentsOf: newShared)
            } catch {
                #if DEBUG
                print("Failed to load shared countdowns: \(error)")
                #endif
            }

            let calendar = Calendar.current
            return allCountdowns.flatMap { cd -> [CalendarEvent] in
                let isShared = sharedCountdownIds.contains(cd.id)

                // Grouped events (new multi-day) or single-day — each is its own calendar event
                if cd.groupId != nil || cd.endDate == nil {
                    return [CalendarEvent.countdown(cd, isShared: isShared)]
                }

                // Legacy multi-day events (endDate set, no groupId) — expand into per-day entries
                guard let endDate = cd.endDate else {
                    return [CalendarEvent.countdown(cd, isShared: isShared)]
                }

                let startDay = calendar.startOfDay(for: cd.date)
                let endDay = calendar.startOfDay(for: endDate)
                var events: [CalendarEvent] = []
                var currentDay = startDay

                while currentDay <= endDay {
                    events.append(CalendarEvent.countdown(cd, isShared: isShared, displayDate: currentDay))
                    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
                    currentDay = nextDay
                }

                return events
            }
        } catch {
            #if DEBUG
            print("Failed to load countdowns: \(error)")
            #endif
            return []
        }
    }

    private func loadBirthdays(appState: AppState, accountId: UUID) async -> [CalendarEvent] {
        do {
            let profiles = try await appState.profileRepository.getProfiles(accountId: accountId)
            return profiles.compactMap { profile -> CalendarEvent? in
                guard profile.birthday != nil else { return nil }
                let upcoming = UpcomingBirthday(profile: profile, daysUntil: profile.birthday?.daysUntilNextOccurrence() ?? 0)
                return CalendarEvent.birthday(upcoming)
            }
        } catch {
            #if DEBUG
            print("Failed to load birthdays: \(error)")
            #endif
            return []
        }
    }

    private func loadMedications(appState: AppState, accountId: UUID) async -> [CalendarEvent] {
        do {
            let medications = try await appState.medicationRepository.getMedications(accountId: accountId)
            var medEvents: [CalendarEvent] = []

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // Generate medication events for the next 30 days
            for medication in medications {
                // Skip paused medications
                guard !medication.isPaused else { continue }

                // Load schedules for this medication
                let schedules = try await appState.medicationRepository.getSchedules(medicationId: medication.id)

                for schedule in schedules {
                    guard schedule.scheduleType == .scheduled,
                          let entries = schedule.scheduleEntries else { continue }

                    for entry in entries {
                        // Check each day in the next 30 days
                        for dayOffset in 0..<30 {
                            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

                            // Check if this day of week is in the schedule
                            let weekday = calendar.component(.weekday, from: date) - 1 // 0-6 (Sunday-Saturday)
                            if entry.daysOfWeek.contains(weekday) {
                                // Check date range
                                if date < schedule.startDate { continue }
                                if let endDate = schedule.endDate, date > endDate { continue }

                                medEvents.append(CalendarEvent.medication(medication, entry, date))
                            }
                        }
                    }
                }
            }

            return medEvents
        } catch {
            #if DEBUG
            print("Failed to load medications: \(error)")
            #endif
            return []
        }
    }

    private func loadToDoLists(appState: AppState, accountId: UUID) async -> [CalendarEvent] {
        do {
            let lists = try await appState.toDoRepository.getListsWithDueDates(accountId: accountId)
            return lists.map { list in
                CalendarEvent.todoList(list)
            }
        } catch {
            #if DEBUG
            print("Failed to load todo lists: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Actions

    func toggleFilter(_ filter: CalendarEventFilter) {
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
        } else {
            selectedFilters.insert(filter)
        }
    }

    func selectAllFilters() {
        selectedFilters = Set(CalendarEventFilter.allCases)
    }

    func clearAllFilters() {
        selectedFilters = []
    }

    func toggleCountdownType(_ type: CountdownType) {
        if selectedCountdownTypes.contains(type) {
            selectedCountdownTypes.remove(type)
        } else {
            selectedCountdownTypes.insert(type)
        }
    }

    func toggleCustomTypeName(_ name: String) {
        if selectedCustomTypeNames.contains(name) {
            selectedCustomTypeNames.remove(name)
        } else {
            selectedCustomTypeNames.insert(name)
        }
    }

    func selectAllCountdownSubTypes() {
        selectedCountdownTypes = Set(CountdownType.allCases)
        selectedCustomTypeNames = Set(availableCustomTypeNames)
    }

    func clearAllCountdownSubTypes() {
        selectedCountdownTypes = []
        selectedCustomTypeNames = []
    }

    func toggleMemberFilter(_ userId: UUID) {
        if selectedMemberFilters.contains(userId) {
            selectedMemberFilters.remove(userId)
        } else {
            selectedMemberFilters.insert(userId)
        }
    }

    func selectAllMembers() {
        selectedMemberFilters = Set(membersWithEvents.map { $0.userId })
    }

    func clearAllMembers() {
        selectedMemberFilters = []
    }

    func goToPreviousMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    func goToNextMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    func goToToday() {
        currentMonth = Date()
        selectedDate = nil
    }

    /// Clear the selected date
    func clearSelection() {
        selectedDate = nil
    }
}
