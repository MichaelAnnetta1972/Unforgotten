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

// MARK: - Calendar Display Mode
enum CalendarDisplayMode: String {
    case month
    case week
}


// MARK: - Calendar View Model
@MainActor
class CalendarViewModel: ObservableObject {
    // MARK: - UserDefaults Keys for Filter Persistence
    private enum FilterDefaultsKey {
        static let selectedFilters = "CalendarSelectedFilters"
        static let selectedCountdownTypes = "CalendarSelectedCountdownTypes"
        static let selectedCustomTypeNames = "CalendarSelectedCustomTypeNames"
        static let hasPersistedFilters = "CalendarHasPersistedFilters"
    }

    // MARK: - Published Properties
    @Published var displayMode: CalendarDisplayMode = .month
    @Published var selectedTab: CalendarTab = .personal
    @Published var selectedDate: Date? = nil
    @Published var currentMonth: Date = Date()
    @Published var currentWeekStart: Date = Calendar.current.startOfWeek(for: Date())
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

    @Published var collapseMultiDay = true

    @Published var isLoading = false
    @Published var isLoadingEvents = false
    @Published var error: String?

    // MARK: - Initialization

    init() {
        restoreFilterSettings()
    }

    // MARK: - Month-Based Loading Cache
    /// Tracks which months have already been loaded to avoid re-fetching
    private var loadedMonthKeys: Set<String> = []
    /// Weak reference to appState for month-change event loading
    private weak var appStateRef: AppState?
    /// Cached medication data (medications + their schedules) to avoid re-fetching on every month load
    private var cachedMedications: [(medication: Medication, schedules: [MedicationSchedule])]?
    /// Cached shared events (fetched once via RPC, reused across month loads)
    private var cachedSharedAppointments: [Appointment]?
    private var cachedSharedCountdowns: [Countdown]?
    /// Cached to-do lists with due dates (fetched once, filtered per month)
    private var cachedToDoLists: [ToDoList]?

    /// Returns a "yyyy-MM" key for a given date
    private func monthKey(for date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return "\(year)-\(String(format: "%02d", month))"
    }

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

    /// Whether any multi-day (grouped) countdown events exist in the loaded data
    var hasMultiDayEvents: Bool {
        events.contains { event in
            if case .countdown(let cd, _, _) = event { return cd.groupId != nil }
            return false
        }
    }

    /// Map of groupId → total day count for multi-day countdown events
    var countdownGroupDayCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for event in events {
            if case .countdown(let cd, _, _) = event, let gid = cd.groupId {
                counts[gid, default: 0] += 1
            }
        }
        return counts
    }

    /// Collapse multi-day grouped events, keeping only the first (earliest) per group.
    /// For recurring groups, each recurrence block is treated independently so that
    /// collapsing still shows one entry per repeating week rather than one entry total.
    private func collapseMultiDayGroups(_ events: [CalendarEvent]) -> [CalendarEvent] {
        guard collapseMultiDay else { return events }
        let calendar = Calendar.current
        // Track seen (groupId, weekStart) pairs so each recurrence block collapses independently
        var seenGroupWeeks: Set<String> = []
        return events.filter { event in
            if case .countdown(let cd, _, let displayDate) = event, let gid = cd.groupId {
                let eventDate = displayDate ?? cd.date
                // Use the start-of-week as a recurrence block key
                let weekStart = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: eventDate)
                let key = "\(gid)-\(weekStart.yearForWeekOfYear ?? 0)-\(weekStart.weekOfYear ?? 0)"
                return seenGroupWeeks.insert(key).inserted
            }
            return true
        }
    }

    /// Whether all countdown sub-types are selected
    var allCountdownSubTypesSelected: Bool {
        let allStandardSelected = Set(availableCountdownTypes).isSubset(of: selectedCountdownTypes)
        let allCustomSelected = Set(availableCustomTypeNames).isSubset(of: selectedCustomTypeNames)
        return allStandardSelected && allCustomSelected
    }

    /// Resolves a member's display name using their linked profile's preferred name/full name.
    /// Falls back to primary profile name if no linked/source profile match is found,
    /// which handles Apple Sign-In users whose AppUser.displayName may be unset.
    func profileName(for member: AccountMemberWithUser) -> String {
        // First try: profile linked or synced to this user
        if let profile = profiles.first(where: { ($0.linkedUserId ?? $0.sourceUserId) == member.userId }) {
            return profile.displayName
        }
        // Second try: if the member owns this account, use the primary profile name
        if member.role == .owner,
           let primaryProfile = profiles.first(where: { $0.type == .primary }) {
            return primaryProfile.displayName
        }
        return member.displayName
    }

    // MARK: - Computed Properties

    /// Events filtered by the selected type filters, countdown sub-type filters, and member filters
    var filteredEvents: [CalendarEvent] {
        let result = events.filter { event in
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
        return result
    }

    /// Events for the selected date (respects both tab selection and filters)
    /// Collapse is applied here so grouped multi-day events show as one card
    var eventsForSelectedDate: [CalendarEvent] {
        guard let selectedDate = selectedDate else { return [] }
        let calendar = Calendar.current
        let eventsToFilter = selectedTab == .family ? familyEvents : filteredEvents
        let dayEvents = eventsToFilter.filter { event in
            calendar.isDate(event.date, inSameDayAs: selectedDate)
        }.sorted { $0.dateTime < $1.dateTime }
        return collapseMultiDayGroups(dayEvents)
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
        let memberFiltered = sharedEvents.filter { event in
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
        return memberFiltered
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
    /// Collapse is applied here so grouped multi-day events show as one card
    var eventsForCurrentMonth: [CalendarEvent] {
        let calendar = Calendar.current
        let eventsToFilter = selectedTab == .family ? familyEvents : filteredEvents
        let monthEvents = eventsToFilter.filter { event in
            calendar.isDate(event.date, equalTo: currentMonth, toGranularity: .month)
        }.sorted { $0.dateTime < $1.dateTime }
        return collapseMultiDayGroups(monthEvents)
    }

    /// Events grouped by date for list view
    /// Collapse is applied here so grouped multi-day events show as one card
    var eventsGroupedByDate: [(date: Date, events: [CalendarEvent])] {
        let eventsToGroup = collapseMultiDayGroups(selectedTab == .family ? familyEvents : filteredEvents)
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

        appStateRef = appState
        isLoading = true
        error = nil

        do {
            // Phase 1: Load profiles and account members in parallel (needed for event loading)
            async let profilesTask = appState.profileRepository.getProfiles(accountId: account.id)
            async let membersTask = appState.accountRepository.getAccountMembersWithUsers(accountId: account.id)

            let (loadedProfiles, loadedMembers) = try await (profilesTask, membersTask)
            profiles = loadedProfiles
            accountMembers = loadedMembers

            // Add connected users from profiles to accountMembers so they appear in the member filter.
            let existingMemberUserIds = Set(accountMembers.map { $0.userId })
            let connectedProfiles = profiles.filter { profile in
                let connectedUserId = profile.linkedUserId ?? profile.sourceUserId
                return connectedUserId != nil && !profile.isLocalOnly
            }
            var seenUserIds = Set<UUID>()
            for profile in connectedProfiles {
                guard let userId = profile.linkedUserId ?? profile.sourceUserId else { continue }
                guard !existingMemberUserIds.contains(userId) else { continue }
                guard seenUserIds.insert(userId).inserted else { continue }

                let appUser = AppUser(
                    id: userId,
                    email: profile.email ?? "",
                    displayName: profile.displayName,
                    isAppAdmin: false,
                    hasComplimentaryAccess: false,
                    createdAt: profile.createdAt,
                    updatedAt: profile.updatedAt
                )
                let syntheticMember = AccountMember(
                    id: userId,
                    accountId: account.id,
                    userId: userId,
                    role: .viewer,
                    createdAt: Date()
                )
                accountMembers.append(AccountMemberWithUser(member: syntheticMember, user: appUser))
            }

            // Phase 2: Load family sharing data FIRST so shared IDs are available
            // when events are created (isShared flag is set at event creation time)
            await loadFamilySharingData(appState: appState, accountId: account.id)

            // Phase 3: Load events for current month (uses sharedAppointmentIds/sharedCountdownIds)
            await loadEventsForMonth(currentMonth, appState: appState)

        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("CalendarViewModel error: \(error)")
            #endif
        }

        isLoading = false
    }

    /// Loads family sharing metadata (shared IDs, shares, share members) in parallel
    private func loadFamilySharingData(appState: AppState, accountId: UUID) async {
        do {
            // Load shared IDs and full share objects in parallel
            async let sharedIdsTask = appState.familyCalendarRepository.getSharedEventIdsForUser(accountId: accountId)
            async let sharesTask = appState.familyCalendarRepository.getSharesVisibleToUser()

            let (sharedIds, loadedShares) = try await (sharedIdsTask, sharesTask)
            sharedAppointmentIds = sharedIds.appointmentIds
            sharedCountdownIds = sharedIds.countdownIds
            familyShares = loadedShares

            // Load share members in parallel (instead of sequential loop)
            let memberResults = await withTaskGroup(of: (UUID, Set<UUID>)?.self) { group in
                for share in loadedShares {
                    group.addTask {
                        do {
                            let members = try await appState.familyCalendarRepository.getMembersForShare(shareId: share.id)
                            return (share.id, Set(members.map { $0.memberUserId }))
                        } catch {
                            #if DEBUG
                            print("Failed to load members for share \(share.id): \(error)")
                            #endif
                            return nil
                        }
                    }
                }

                var map: [UUID: Set<UUID>] = [:]
                for await result in group {
                    if let (shareId, memberIds) = result {
                        map[shareId] = memberIds
                    }
                }
                return map
            }
            familyShareMembers = memberResults
        } catch {
            #if DEBUG
            print("Failed to load family sharing data: \(error)")
            #endif
        }
    }

    // MARK: - Month-Based Event Loading

    /// Loads events for a given month (with 1-month buffer on each side).
    /// Skips months that have already been loaded. New events are merged into the existing array.
    func loadEventsForMonth(_ month: Date, appState: AppState? = nil) async {
        guard let appState = appState ?? appStateRef,
              let account = appState.currentAccount else { return }

        let calendar = Calendar.current

        // The 3 months we want covered: previous, current, next
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let prevMonth = calendar.date(byAdding: .month, value: -1, to: monthStart),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return }
        let monthStarts = [prevMonth, monthStart, nextMonth]

        // Find which months still need loading
        let unloadedMonths = monthStarts.filter { !loadedMonthKeys.contains(monthKey(for: $0)) }
        guard !unloadedMonths.isEmpty,
              let rangeStart = unloadedMonths.min(),
              let maxMonth = unloadedMonths.max(),
              let rangeEnd = calendar.date(byAdding: .month, value: 1, to: maxMonth) else { return }

        isLoadingEvents = true

        // Load all event types in parallel for the date range
        async let appointmentsTask = loadAppointments(appState: appState, accountId: account.id, startDate: rangeStart, endDate: rangeEnd)
        async let countdownsTask = loadCountdowns(appState: appState, accountId: account.id, startDate: rangeStart, endDate: rangeEnd)
        async let birthdaysTask = loadBirthdays(appState: appState, accountId: account.id, startDate: rangeStart, endDate: rangeEnd)
        async let medicationsTask = loadMedications(appState: appState, accountId: account.id, startDate: rangeStart, endDate: rangeEnd)
        async let todoListsTask = loadToDoLists(appState: appState, accountId: account.id, startDate: rangeStart, endDate: rangeEnd)

        let (appointments, countdowns, birthdays, medications, todoLists) = await (
            appointmentsTask,
            countdownsTask,
            birthdaysTask,
            medicationsTask,
            todoListsTask
        )

        // Merge new events with existing ones (avoid duplicates by ID)
        var newEvents: [CalendarEvent] = []
        newEvents.append(contentsOf: appointments)
        newEvents.append(contentsOf: countdowns)
        newEvents.append(contentsOf: birthdays)
        newEvents.append(contentsOf: medications)
        newEvents.append(contentsOf: todoLists)

        let existingIds = Set(events.map { $0.id })
        let uniqueNewEvents = newEvents.filter { !existingIds.contains($0.id) }
        events.append(contentsOf: uniqueNewEvents)

        // Mark these months as loaded
        for monthDate in unloadedMonths {
            loadedMonthKeys.insert(monthKey(for: monthDate))
        }

        // Auto-select any custom type names that aren't yet known to the filter.
        // On first load (no persisted filters) this selects all; on subsequent loads
        // it adds newly-appeared names (e.g. from a shared countdown) so they aren't
        // silently hidden by a stale persisted filter set.
        let newCustomNames = Set(availableCustomTypeNames).subtracting(selectedCustomTypeNames)
        if !newCustomNames.isEmpty {
            selectedCustomTypeNames.formUnion(newCustomNames)
            saveFilterSettings()
        }

        isLoadingEvents = false
    }

    /// Force a full reload (e.g., after creating/editing an event)
    func reloadEvents() async {
        loadedMonthKeys.removeAll()
        cachedMedications = nil
        cachedSharedAppointments = nil
        cachedSharedCountdowns = nil
        cachedToDoLists = nil
        events.removeAll()
        await loadEventsForMonth(currentMonth)
    }

    // MARK: - Private Event Loaders

    private func loadAppointments(appState: AppState, accountId: UUID, startDate: Date, endDate: Date) async -> [CalendarEvent] {
        do {
            let ownAppointments = try await appState.appointmentRepository.getAppointmentsInRange(accountId: accountId, startDate: startDate, endDate: endDate)
            let ownIds = Set(ownAppointments.map { $0.id })
            var allAppointments = ownAppointments

            // Fetch shared appointments via RPC once, then reuse cache
            if cachedSharedAppointments == nil {
                do {
                    cachedSharedAppointments = try await appState.appointmentRepository.getSharedAppointments()
                } catch {
                    cachedSharedAppointments = []
                    #if DEBUG
                    print("Failed to load shared appointments: \(error)")
                    #endif
                }
            }

            if let shared = cachedSharedAppointments {
                let newShared = shared.filter { apt in
                    !ownIds.contains(apt.id) &&
                    apt.date >= startDate && apt.date < endDate
                }
                allAppointments.append(contentsOf: newShared)
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

    private func loadCountdowns(appState: AppState, accountId: UUID, startDate: Date, endDate: Date) async -> [CalendarEvent] {
        do {
            let ownCountdowns = try await appState.countdownRepository.getCountdownsInRange(accountId: accountId, startDate: startDate, endDate: endDate)
            let ownIds = Set(ownCountdowns.map { $0.id })
            var allCountdowns = ownCountdowns

            // Fetch shared countdowns via RPC once, then reuse cache
            if cachedSharedCountdowns == nil {
                do {
                    cachedSharedCountdowns = try await appState.countdownRepository.getSharedCountdowns()
                } catch {
                    cachedSharedCountdowns = []
                    #if DEBUG
                    print("Failed to load shared countdowns: \(error)")
                    #endif
                }
            }

            if let shared = cachedSharedCountdowns {
                let newShared = shared.filter { cd in
                    !ownIds.contains(cd.id) &&
                    (cd.isRecurring || (cd.date >= startDate && cd.date < endDate))
                }
                allCountdowns.append(contentsOf: newShared)
            }

            let calendar = Calendar.current

            // For recurring grouped events, find the earliest date per group so we can
            // calculate each day's offset from the group start
            var groupEarliestDates: [UUID: Date] = [:]
            for cd in allCountdowns {
                if let gid = cd.groupId, cd.isRecurring {
                    let day = calendar.startOfDay(for: cd.date)
                    if let existing = groupEarliestDates[gid] {
                        if day < existing { groupEarliestDates[gid] = day }
                    } else {
                        groupEarliestDates[gid] = day
                    }
                }
            }

            return allCountdowns.flatMap { cd -> [CalendarEvent] in
                let isShared = sharedCountdownIds.contains(cd.id)

                // Recurring countdowns: generate occurrence entries within the requested range
                if cd.isRecurring && !cd.recurrenceHasEnded {
                    let unit = cd.recurrenceUnit ?? .year
                    let interval = cd.recurrenceInterval ?? 1

                    // For grouped recurring events, generate occurrences based on the group's
                    // earliest date, then offset each day within the group accordingly
                    let baseDate: Date
                    let dayOffset: Int
                    if let gid = cd.groupId, let groupStart = groupEarliestDates[gid] {
                        baseDate = groupStart
                        dayOffset = calendar.dateComponents([.day], from: groupStart, to: calendar.startOfDay(for: cd.date)).day ?? 0
                    } else {
                        baseDate = cd.date
                        dayOffset = 0
                    }

                    let occurrences = baseDate.recurrenceDates(
                        unit: unit,
                        interval: interval,
                        in: startDate...endDate,
                        endDate: cd.recurrenceEndDate
                    )

                    var events: [CalendarEvent] = []

                    // Include the original date if it falls in range
                    let startDay = calendar.startOfDay(for: cd.date)
                    if startDay >= startDate && startDay <= endDate {
                        events.append(CalendarEvent.countdown(cd, isShared: isShared, displayDate: startDay))
                    }

                    for occurrenceDate in occurrences {
                        let displayDate = calendar.date(byAdding: .day, value: dayOffset, to: occurrenceDate) ?? occurrenceDate
                        // Skip if this is the same as the original date (already added above)
                        if !calendar.isDate(displayDate, inSameDayAs: startDay) {
                            events.append(CalendarEvent.countdown(cd, isShared: isShared, displayDate: displayDate))
                        }
                    }

                    return events.isEmpty
                        ? [CalendarEvent.countdown(cd, isShared: isShared)]
                        : events
                }

                // Grouped events (new multi-day) or single-day — each is its own calendar event
                if cd.groupId != nil || cd.endDate == nil {
                    return [CalendarEvent.countdown(cd, isShared: isShared)]
                }

                // Legacy multi-day events (endDate set, no groupId) — expand into per-day entries
                guard let endDate = cd.endDate else {
                    return [CalendarEvent.countdown(cd, isShared: isShared)]
                }

                let cdStartDay = calendar.startOfDay(for: cd.date)
                let endDay = calendar.startOfDay(for: endDate)
                var events: [CalendarEvent] = []
                var currentDay = cdStartDay

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

    private func loadBirthdays(appState: AppState, accountId: UUID, startDate: Date, endDate: Date) async -> [CalendarEvent] {
        // Birthdays use already-loaded profiles (no extra fetch needed)
        // Generate birthday events for the requested date range
        let calendar = Calendar.current
        return profiles.compactMap { profile -> CalendarEvent? in
            guard let birthday = profile.birthday else { return nil }
            let nextOccurrence = birthday.nextOccurrenceDate()
            // Only include if the next occurrence falls within the range
            guard nextOccurrence >= startDate && nextOccurrence < endDate else { return nil }
            let upcoming = UpcomingBirthday(profile: profile, daysUntil: birthday.daysUntilNextOccurrence())
            return CalendarEvent.birthday(upcoming)
        }
    }

    private func loadMedications(appState: AppState, accountId: UUID, startDate: Date, endDate: Date) async -> [CalendarEvent] {
        do {
            // Cache medication data on first load to avoid re-fetching on subsequent months
            if cachedMedications == nil {
                let medications = try await appState.medicationRepository.getMedications(accountId: accountId)
                let activeMedications = medications.filter { !$0.isPaused }

                // Fetch all schedules in parallel instead of sequentially
                let medData = await withTaskGroup(of: (Medication, [MedicationSchedule])?.self) { group in
                    for medication in activeMedications {
                        group.addTask {
                            do {
                                let schedules = try await appState.medicationRepository.getSchedules(medicationId: medication.id)
                                return (medication, schedules)
                            } catch {
                                #if DEBUG
                                print("Failed to load schedules for medication \(medication.id): \(error)")
                                #endif
                                return nil
                            }
                        }
                    }

                    var results: [(medication: Medication, schedules: [MedicationSchedule])] = []
                    for await result in group {
                        if let (medication, schedules) = result {
                            results.append((medication: medication, schedules: schedules))
                        }
                    }
                    return results
                }
                cachedMedications = medData
            }

            guard let medData = cachedMedications else { return [] }

            var medEvents: [CalendarEvent] = []
            let calendar = Calendar.current
            let rangeStartDay = calendar.startOfDay(for: startDate)
            let rangeEndDay = calendar.startOfDay(for: endDate)

            for item in medData {
                for schedule in item.schedules {
                    guard schedule.scheduleType == .scheduled,
                          let entries = schedule.scheduleEntries else { continue }

                    for entry in entries {
                        // Iterate days in the requested range
                        var currentDay = rangeStartDay
                        while currentDay < rangeEndDay {
                            let weekday = calendar.component(.weekday, from: currentDay) - 1
                            if entry.daysOfWeek.contains(weekday) {
                                if currentDay >= schedule.startDate {
                                    if let scheduleEnd = schedule.endDate, currentDay > scheduleEnd {
                                        // Past schedule end, skip
                                    } else {
                                        medEvents.append(CalendarEvent.medication(item.medication, entry, currentDay))
                                    }
                                }
                            }
                            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
                            currentDay = nextDay
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

    private func loadToDoLists(appState: AppState, accountId: UUID, startDate: Date, endDate: Date) async -> [CalendarEvent] {
        do {
            // Cache to-do lists on first load to avoid re-fetching on every month scroll
            if cachedToDoLists == nil {
                cachedToDoLists = try await appState.toDoRepository.getListsWithDueDates(accountId: accountId)
            }

            guard let lists = cachedToDoLists else { return [] }

            // Filter to only include lists with due dates in the range
            return lists.compactMap { list -> CalendarEvent? in
                guard let dueDate = list.dueDate else { return nil }
                guard dueDate >= startDate && dueDate < endDate else { return nil }
                return CalendarEvent.todoList(list)
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
        saveFilterSettings()
    }

    func selectAllFilters() {
        selectedFilters = Set(CalendarEventFilter.allCases)
        saveFilterSettings()
    }

    func clearAllFilters() {
        selectedFilters = []
        saveFilterSettings()
    }

    func toggleCountdownType(_ type: CountdownType) {
        if selectedCountdownTypes.contains(type) {
            selectedCountdownTypes.remove(type)
        } else {
            selectedCountdownTypes.insert(type)
        }
        saveFilterSettings()
    }

    func toggleCustomTypeName(_ name: String) {
        if selectedCustomTypeNames.contains(name) {
            selectedCustomTypeNames.remove(name)
        } else {
            selectedCustomTypeNames.insert(name)
        }
        saveFilterSettings()
    }

    func selectAllCountdownSubTypes() {
        selectedCountdownTypes = Set(CountdownType.allCases)
        selectedCustomTypeNames = Set(availableCustomTypeNames)
        saveFilterSettings()
    }

    func clearAllCountdownSubTypes() {
        selectedCountdownTypes = []
        selectedCustomTypeNames = []
        saveFilterSettings()
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
            Task { await loadEventsForMonth(newMonth) }
        }
    }

    func goToNextMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
            Task { await loadEventsForMonth(newMonth) }
        }
    }

    func goToPreviousWeek() {
        let calendar = Calendar.current
        if let newWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) {
            currentWeekStart = newWeekStart
            // Keep currentMonth in sync so events load correctly
            currentMonth = newWeekStart
            Task { await loadEventsForMonth(newWeekStart) }
        }
    }

    func goToNextWeek() {
        let calendar = Calendar.current
        if let newWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) {
            currentWeekStart = newWeekStart
            currentMonth = newWeekStart
            Task { await loadEventsForMonth(newWeekStart) }
        }
    }

    func goToToday() {
        currentMonth = Date()
        currentWeekStart = Calendar.current.startOfWeek(for: Date())
        Task { await loadEventsForMonth(currentMonth) }
        selectedDate = nil
    }

    /// Clear the selected date
    func clearSelection() {
        selectedDate = nil
    }

    // MARK: - Filter Persistence

    func saveFilterSettings() {
        let defaults = UserDefaults.standard
        let filterRawValues = selectedFilters.map { $0.rawValue }
        let countdownRawValues = selectedCountdownTypes.map { $0.rawValue }
        let customNames = Array(selectedCustomTypeNames)

        defaults.set(filterRawValues, forKey: FilterDefaultsKey.selectedFilters)
        defaults.set(countdownRawValues, forKey: FilterDefaultsKey.selectedCountdownTypes)
        defaults.set(customNames, forKey: FilterDefaultsKey.selectedCustomTypeNames)
        defaults.set(true, forKey: FilterDefaultsKey.hasPersistedFilters)
    }

    private func restoreFilterSettings() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: FilterDefaultsKey.hasPersistedFilters) else { return }

        if let filterRawValues = defaults.stringArray(forKey: FilterDefaultsKey.selectedFilters) {
            selectedFilters = Set(filterRawValues.compactMap { CalendarEventFilter(rawValue: $0) })
        }
        if let countdownRawValues = defaults.stringArray(forKey: FilterDefaultsKey.selectedCountdownTypes) {
            selectedCountdownTypes = Set(countdownRawValues.compactMap { CountdownType(rawValue: $0) })
        }
        if let customNames = defaults.stringArray(forKey: FilterDefaultsKey.selectedCustomTypeNames) {
            selectedCustomTypeNames = Set(customNames)
        }
    }
}
