import SwiftUI

// MARK: - Calendar List View
struct CalendarListView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.appAccentColor) private var appAccentColor

    var scrollProxy: ScrollViewProxy?
    @Binding var scrollToTodayTrigger: Bool

    private let calendar = Calendar.current

    init(viewModel: CalendarViewModel, scrollProxy: ScrollViewProxy? = nil, scrollToTodayTrigger: Binding<Bool> = .constant(false)) {
        self.viewModel = viewModel
        self.scrollProxy = scrollProxy
        self._scrollToTodayTrigger = scrollToTodayTrigger
    }

    /// All events sorted by date/time for flat list display
    private var sortedEvents: [CalendarEvent] {
        let eventsToSort = viewModel.selectedTab == .family ? viewModel.familyEvents : viewModel.filteredEvents
        return eventsToSort.sorted { $0.dateTime < $1.dateTime }
    }

    var body: some View {
        LazyVStack(spacing: AppDimensions.cardSpacing) {
            ForEach(sortedEvents) { event in
                CalendarEventRow(event: event, showDate: true)
                    .id(eventId(for: event))
            }
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
