import SwiftUI

// MARK: - Calendar List View
struct CalendarListView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.appAccentColor) private var appAccentColor

    var scrollProxy: ScrollViewProxy?
    @Binding var scrollToTodayTrigger: Bool
    var onEventSelected: ((CalendarEvent) -> Void)?

    private let calendar = Calendar.current

    init(viewModel: CalendarViewModel, scrollProxy: ScrollViewProxy? = nil, scrollToTodayTrigger: Binding<Bool> = .constant(false), onEventSelected: ((CalendarEvent) -> Void)? = nil) {
        self.viewModel = viewModel
        self.scrollProxy = scrollProxy
        self._scrollToTodayTrigger = scrollToTodayTrigger
        self.onEventSelected = onEventSelected
    }

    /// All events sorted by date/time for flat list display (collapse applied for cards)
    private var sortedEvents: [CalendarEvent] {
        let eventsToSort = viewModel.selectedTab == .family ? viewModel.familyEvents : viewModel.filteredEvents
        let collapsed = viewModel.collapseMultiDay ? collapseGroups(eventsToSort) : eventsToSort
        return collapsed.sorted { $0.dateTime < $1.dateTime }
    }

    /// Collapse multi-day grouped events, keeping only the first (earliest) per group
    private func collapseGroups(_ events: [CalendarEvent]) -> [CalendarEvent] {
        var seenGroups: Set<UUID> = []
        return events.filter { event in
            if case .countdown(let cd, _, _) = event, let gid = cd.groupId {
                return seenGroups.insert(gid).inserted
            }
            return true
        }
    }

    var body: some View {
        LazyVStack(spacing: AppDimensions.cardSpacing) {
            ForEach(sortedEvents) { event in
                Button {
                    onEventSelected?(event)
                } label: {
                    CalendarEventRow(event: event, showDate: true, multiDayCount: multiDayCount(for: event))
                }
                .buttonStyle(PlainButtonStyle())
                .id(eventId(for: event))
            }
        }
        .onAppear {
            scrollToToday()
        }
        .onChange(of: scrollToTodayTrigger) { _, _ in
            scrollToToday()
        }
    }

    // MARK: - Scroll to Today

    private func scrollToToday() {
        // Find the first event that is today or later
        let today = calendar.startOfDay(for: Date())
        if let firstTodayEvent = sortedEvents.first(where: { calendar.startOfDay(for: $0.date) >= today }) {
            withAnimation {
                scrollProxy?.scrollTo(eventId(for: firstTodayEvent), anchor: .top)
            }
        }
    }

    private func multiDayCount(for event: CalendarEvent) -> Int? {
        guard viewModel.collapseMultiDay else { return nil }
        if case .countdown(let cd, _, _) = event, let gid = cd.groupId {
            return viewModel.countdownGroupDayCounts[gid]
        }
        return nil
    }

    private func eventId(for event: CalendarEvent) -> String {
        "event-\(event.id)"
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        CalendarListView(viewModel: CalendarViewModel())
            .padding()
    }
    .background(Color.appBackgroundLight)
}
