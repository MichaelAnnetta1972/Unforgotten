import SwiftUI

// MARK: - Mood Dashboard View
struct MoodDashboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @StateObject private var viewModel = MoodDashboardViewModel()
    @State private var showMoodPrompt = false
    @State private var editingEntry: MoodEntry? = nil

    private let moodEmojis = ["", "😢", "😕", "😐", "🙂", "😊"]
    private let moodLabels = ["", "Sad", "Not Great", "Okay", "Good", "Great"]

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header scrolls with content - uses style-based assets from HeaderStyleManager
                    CustomizableHeaderView(
                        pageIdentifier: .mood,
                        title: "Mood Tracker",
                        showBackButton: iPadHomeAction == nil,
                        backAction: { dismiss() },
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction
                    )

                    // Content
                    VStack(spacing: AppDimensions.cardSpacing) {
                            // Today's mood or prompt to record
                            if let todayMood = viewModel.todaysMood {
                                TodayMoodCard(entry: todayMood, moodEmojis: moodEmojis, moodLabels: moodLabels) {
                                    editingEntry = todayMood
                                }
                            } else {
                                RecordMoodCard {
                                    showMoodPrompt = true
                                }
                            }

                            // 30-Day Summary
                            if !viewModel.entries.isEmpty {
                                MoodSummaryCard(viewModel: viewModel, moodEmojis: moodEmojis)

                                // Weekly trend
                                WeeklyTrendCard(viewModel: viewModel, moodEmojis: moodEmojis)
                            }

                            // History section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("HISTORY")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                if viewModel.entries.isEmpty && !viewModel.isLoading {
                                    EmptyStateView(
                                        icon: "face.smiling",
                                        title: "No mood entries yet",
                                        message: "Start tracking your mood to see patterns over time",
                                        buttonTitle: "Record Mood",
                                        buttonAction: { showMoodPrompt = true }
                                    )
                                    .padding(.top, 20)
                                } else {
                                    LazyVStack(spacing: AppDimensions.cardSpacing) {
                                        ForEach(viewModel.entries) { entry in
                                            MoodEntryCard(entry: entry, moodEmojis: moodEmojis)
                                        }
                                    }
                                }
                            }

                            // Loading state
                            if viewModel.isLoading {
                                LoadingView(message: "Loading mood data...")
                                    .padding(.top, 40)
                            }

                            // Bottom spacing for nav bar
                            Spacer()
                                .frame(height: 120)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showMoodPrompt, onDismiss: {
            // Refresh data when mood prompt is dismissed
            Task {
                await viewModel.loadData(appState: appState)
            }
        }) {
            MoodPromptView()
                .environmentObject(appState)
        }
        .sheet(item: $editingEntry, onDismiss: {
            Task {
                await viewModel.loadData(appState: appState)
            }
        }) { entry in
            MoodPromptView(existingEntry: entry)
                .environmentObject(appState)
        }
        .task {
            await viewModel.loadData(appState: appState)
        }
        .refreshable {
            await viewModel.loadData(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            Task {
                await viewModel.loadData(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .moodEntriesDidChange)) { _ in
            Task {
                await viewModel.loadData(appState: appState)
            }
        }
    }
}

// MARK: - Today Mood Card
struct TodayMoodCard: View {
    let entry: MoodEntry
    let moodEmojis: [String]
    let moodLabels: [String]
    var onEdit: (() -> Void)? = nil

    @Environment(\.appAccentColor) private var appAccentColor

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("TODAY")
                    .font(.appCaption)
                    .fontWeight(.bold)
                    .foregroundColor(appAccentColor)

                Spacer()

                if let onEdit {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.caption)
                            Text("Edit")
                                .font(.appCaption)
                        }
                        .foregroundColor(appAccentColor)
                    }
                }

                Text(dateFormatter.string(from: entry.date))
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            HStack(spacing: 16) {
                Text(moodEmojis[safe: entry.rating] ?? "")
                    .font(.system(size: 50))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Feeling \(moodLabels[safe: entry.rating] ?? "")")
                        .font(.appTitle)
                        .foregroundColor(.textPrimary)

                    if let note = entry.note, !note.isEmpty {
                        Text(note)
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(appAccentColor.opacity(0.15))
        .cornerRadius(AppDimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                .stroke(appAccentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Record Mood Card
struct RecordMoodCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentYellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text("How are you feeling today?")
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)

                    Text("Tap to record your mood")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.textSecondary)
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }
}

// MARK: - Mood Summary Card
struct MoodSummaryCard: View {
    @ObservedObject var viewModel: MoodDashboardViewModel
    let moodEmojis: [String]
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("30-DAY SUMMARY")
                    .font(.appCaption)
                    .fontWeight(.bold)
                    .foregroundColor(.textSecondary)

                Spacer()
            }

            HStack(spacing: 24) {
                // Average mood
                VStack(spacing: 8) {
                    if let average = viewModel.averageRating {
                        Text(moodEmojis[safe: Int(average.rounded())] ?? "")
                            .font(.system(size: 36))

                        Text(String(format: "%.1f", average))
                            .font(.appTitle)
                            .foregroundColor(.textPrimary)

                        Text("Average")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 60)

                // Total entries
                VStack(spacing: 8) {
                    Text("\(viewModel.entries.count)")
                        .font(.appLargeTitle)
                        .foregroundColor(Color.white)

                    Text("Entries")
                        .font(.appCaption)
                        .foregroundColor(Color.white)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 60)

                // Most common mood
                if let mostCommon = viewModel.mostCommonRating {
                    VStack(spacing: 8) {
                        Text(moodEmojis[safe: mostCommon] ?? "")
                            .font(.system(size: 36))

                        Text("Most Common")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Weekly Trend Card
struct WeeklyTrendCard: View {
    @ObservedObject var viewModel: MoodDashboardViewModel
    let moodEmojis: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LAST 7 DAYS")
                .font(.appCaption)
                .fontWeight(.bold)
                .foregroundColor(.textSecondary)

            HStack(spacing: 8) {
                ForEach(viewModel.lastSevenDays, id: \.date) { day in
                    VStack(spacing: 8) {
                        if let rating = day.rating {
                            Text(moodEmojis[safe: rating] ?? "")
                                .font(.title2)
                        } else {
                            Circle()
                                .stroke(Color.textSecondary.opacity(0.3), lineWidth: 2)
                                .frame(width: 28, height: 28)
                        }

                        Text(day.dayLabel)
                            .font(.appCaptionSmall)
                            .foregroundColor(day.isToday ? .accentYellow : .textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Mood Entry Card
struct MoodEntryCard: View {
    let entry: MoodEntry
    let moodEmojis: [String]
    @Environment(\.appAccentColor) private var appAccentColor

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    var body: some View {
        HStack {
            Text(moodEmojis[safe: entry.rating] ?? "")
                .font(.title)

            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: entry.date))
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                if let note = entry.note {
                    Text(note)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { rating in
                    Image(systemName: rating <= entry.rating ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundColor(appAccentColor)
                }
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Day Data
struct DayData {
    let date: Date
    let rating: Int?
    let dayLabel: String
    let isToday: Bool
}

// MARK: - Mood Dashboard View Model
@MainActor
class MoodDashboardViewModel: ObservableObject {
    @Published var entries: [MoodEntry] = []
    @Published var todaysMood: MoodEntry?
    @Published var isLoading = false
    @Published var error: String?

    var averageRating: Double? {
        guard !entries.isEmpty else { return nil }
        let sum = entries.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(entries.count)
    }

    var mostCommonRating: Int? {
        guard !entries.isEmpty else { return nil }
        var counts: [Int: Int] = [:]
        for entry in entries {
            counts[entry.rating, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var lastSevenDays: [DayData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"

            let rating = entries.first { entry in
                calendar.isDate(entry.date, inSameDayAs: date)
            }?.rating

            return DayData(
                date: date,
                rating: rating,
                dayLabel: dayFormatter.string(from: date),
                isToday: daysAgo == 0
            )
        }
    }

    func loadData(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let now = Date()

        // Use UTC calendar for consistent date comparison with stored data
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let todayUTC = utcCalendar.startOfDay(for: now)

        do {
            entries = try await appState.moodRepository.getEntries(
                accountId: account.id,
                from: thirtyDaysAgo,
                to: now
            )

            // Find today's mood - compare using UTC dates
            todaysMood = entries.first { entry in
                utcCalendar.isDate(entry.date, inSameDayAs: todayUTC)
            }
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        MoodDashboardView()
            .environmentObject(AppState.forPreview())
    }
}
