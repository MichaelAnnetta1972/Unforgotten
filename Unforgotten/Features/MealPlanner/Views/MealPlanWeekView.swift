import SwiftUI

// MARK: - Meal Type Tag
/// Small pill shown next to a planned meal indicating its meal type.
struct MealTypeTag: View {
    let mealType: MealType
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Text(mealType.displayName)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(appAccentColor)
            //.padding(.horizontal, 12)
            //.padding(.vertical, 5)
            //.background(appAccentColor.opacity(0.18))
            //.clipShape(Capsule())
    }
}

// MARK: - Meal Plan Week View
struct MealPlanWeekView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    var onAddMeal: (Date, MealType) -> Void
    var onOpenRecipe: (UUID) -> Void = { _ in }
    var refreshTrigger: Int = 0

    @State private var weekOffset = 0
    @State private var meals: [PlannedMeal] = []
    @State private var recipes: [Recipe] = []
    @State private var isLoading = true
    @State private var mealToDelete: PlannedMeal?

    private var canEdit: Bool { appState.canEdit }

    private var calendar: Calendar { Calendar.current }

    private var weekStart: Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        // Monday = start of week (weekday 2 in gregorian)
        let daysToSubtract = (weekday + 5) % 7
        let thisMonday = calendar.date(byAdding: .day, value: -daysToSubtract, to: today)!
        return calendar.date(byAdding: .weekOfYear, value: weekOffset, to: thisMonday)!
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: weekStart)
        let end = formatter.string(from: weekDays.last ?? weekStart)
        return "\(start) - \(end)"
    }

    private var isCurrentWeek: Bool {
        weekOffset == 0
    }

    var body: some View {
        VStack(spacing: 20) {
            // Week navigation
            HStack {
                Button {
                    weekOffset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                VStack(spacing: 2) {
                    if isCurrentWeek {
                        Text("This Week")
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)
                    }
                    Text(weekRangeText)
                        .font(isCurrentWeek ? .appCaption : .appCardTitle)
                        .foregroundColor(isCurrentWeek ? .textSecondary : .textPrimary)

                    if !isCurrentWeek {
                        Button {
                            weekOffset = 0
                        } label: {
                            Text("Go to This Week")
                                .font(.appCaption)
                                .foregroundColor(appAccentColor)
                        }
                    }
                }

                Spacer()

                Button {
                    weekOffset += 1
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, AppDimensions.screenPadding)

            if isLoading {
                LoadingView(message: "Loading meals...")
                    .padding(.top, 40)
            } else {
                // Day cards
                VStack(spacing: 20) {
                    ForEach(weekDays, id: \.self) { day in
                        dayCard(for: day)
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)
            }
        }
        .task(id: "\(weekOffset)-\(refreshTrigger)") {
            await loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mealsDidChange)) { _ in
            Task { await loadData() }
        }
        .sheet(item: $mealToDelete) { meal in
            MealActionSheet(
                meal: meal,
                onOpen: {
                    mealToDelete = nil
                    onOpenRecipe(meal.recipeId)
                },
                onRemove: {
                    mealToDelete = nil
                    Task { await deleteMeal(meal) }
                }
            )
            .presentationDetents([.height(220)])
        }
    }

    // MARK: - Day Card

    @ViewBuilder
    private func dayCard(for day: Date) -> some View {
        let dayMeals = mealsForDay(day)

        VStack(alignment: .leading, spacing: 12) {
            // Day heading + add button
            HStack {
                Text(dayHeading(for: day))
                    .font(.appCardTitle)
                    .foregroundColor(isToday(day) ? appAccentColor : .textMuted)

                Spacer()

                if canEdit {
                    Button {
                        onAddMeal(day, .dinner)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.textSecondary.opacity(0.4))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle().stroke(Color.textSecondary.opacity(0.4), lineWidth: 1.5)
                            )
                    }
                }
            }

            // Meals card (only if there are meals)
            if !dayMeals.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(dayMeals.enumerated()), id: \.element.id) { index, meal in
                        if index > 0 {
                            Divider()
                                .background(Color.textSecondary.opacity(0.15))
                                .padding(.leading, 76)
                        }
                        mealRow(meal)
                    }
                }
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
            }
        }
    }

    // MARK: - Meal Row

    @ViewBuilder
    private func mealRow(_ meal: PlannedMeal) -> some View {
        Button {
            mealToDelete = meal
        } label: {
            HStack(spacing: 14) {

                VStack(alignment: .leading, spacing: 6) {
                    MealTypeTag(mealType: meal.mealType)

                    Text(meal.recipeName ?? "Meal")
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                }

                Spacer(minLength: 0)

                mealThumbnail(for: meal)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func mealThumbnail(for meal: PlannedMeal) -> some View {
        let imageUrl = recipes.first(where: { $0.id == meal.recipeId })?.imageUrl

        Group {
            if let imageUrl, !imageUrl.isEmpty {
                SignedAsyncImage(reference: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .empty:
                        ZStack {
                            Color.textMuted
                            ProgressView().tint(appAccentColor)
                        }
                    default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            Color.cardBackgroundLight
            Image(systemName: "fork.knife")
                .font(.system(size: 18))
                .foregroundColor(.textMuted)
        }
    }

    // MARK: - Helpers

    private func mealsForDay(_ day: Date) -> [PlannedMeal] {
        let dayStart = calendar.startOfDay(for: day)
        return meals
            .filter { calendar.startOfDay(for: $0.date) == dayStart }
            .sorted { sortIndex($0.mealType) < sortIndex($1.mealType) }
    }

    private func sortIndex(_ mealType: MealType) -> Int {
        MealType.allCases.firstIndex(of: mealType) ?? 0
    }

    private func dayHeading(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    // MARK: - Data

    private func loadData() async {
        guard let accountId = appState.currentAccount?.id else { return }
        isLoading = true
        do {
            async let mealsResult = appState.mealPlannerRepository.getPlannedMealsForWeek(
                accountId: accountId,
                weekStart: weekStart
            )
            async let recipesResult = appState.mealPlannerRepository.getRecipes(accountId: accountId)
            meals = try await mealsResult
            recipes = try await recipesResult
        } catch {
            #if DEBUG
            print("Error loading meals: \(error)")
            #endif
        }
        isLoading = false
    }

    private func deleteMeal(_ meal: PlannedMeal) async {
        do {
            try await appState.mealPlannerRepository.deletePlannedMeal(id: meal.id)
            meals.removeAll { $0.id == meal.id }
        } catch {
            #if DEBUG
            print("Error deleting meal: \(error)")
            #endif
        }
    }
}

// MARK: - Meal Action Sheet

private struct MealActionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let meal: PlannedMeal
    var onOpen: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with X button
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }

                Spacer()

                Text(meal.recipeName ?? "Meal")
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Invisible spacer to balance the X button
                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Action buttons
            VStack(spacing: 10) {
                Button {
                    onOpen()
                } label: {
                    HStack {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 16))
                        Text("Open")
                            .font(.appCardTitle)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(appAccentColor)
                    .cornerRadius(AppDimensions.cardCornerRadius)
                }

                Button {
                    onRemove()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                        Text("Remove")
                            .font(.appCardTitle)
                    }
                    .foregroundColor(.badgeRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.badgeRed.opacity(0.1))
                    .cornerRadius(AppDimensions.cardCornerRadius)
                }
            }
            .padding(.horizontal, AppDimensions.screenPadding)

            Spacer()
        }
        .background(Color.appBackgroundLight)
    }
}
