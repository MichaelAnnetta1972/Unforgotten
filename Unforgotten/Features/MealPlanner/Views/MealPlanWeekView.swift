import SwiftUI

// MARK: - Meal Plan Week View
struct MealPlanWeekView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    var onAddMeal: (Date, MealType) -> Void
    var onOpenRecipe: (UUID) -> Void = { _ in }
    var refreshTrigger: Int = 0
    var mealTypeFilters: Set<MealType> = []

    private var visibleMealTypes: [MealType] {
        if mealTypeFilters.isEmpty {
            return MealType.allCases
        }
        return MealType.allCases.filter { mealTypeFilters.contains($0) }
    }

    @State private var weekOffset = 0
    @State private var meals: [PlannedMeal] = []
    @State private var isLoading = true
    @State private var mealToDelete: PlannedMeal?

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
        VStack(spacing: 24) {
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
                // Week grid
                weekGrid
            }
        }
        .task(id: "\(weekOffset)-\(refreshTrigger)") {
            await loadMeals()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mealsDidChange)) { _ in
            Task { await loadMeals() }
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

    // MARK: - Week Grid

    @ViewBuilder
    private var weekGrid: some View {
        VStack(spacing: 8) {
            // Column headers: empty + Breakfast / Lunch / Dinner
            HStack(spacing: 8) {
                Text("")
                    .frame(width: 56)

                ForEach(visibleMealTypes) { mealType in
                    HStack(spacing: 4) {
                        Image(systemName: mealType.icon)
                            .font(.system(size: 12))
                            .foregroundColor(appAccentColor)
                        Text(mealType.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, AppDimensions.screenPadding)

            // Day rows
            ForEach(weekDays, id: \.self) { day in
                HStack(spacing: 8) {
                    // Day label
                    VStack(spacing: 4) {
                        Text(dayAbbreviation(for: day))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isToday(day) ? appAccentColor : .textSecondary)
                        Text(dayNumber(for: day))
                            .font(.system(size: 14, weight: isToday(day) ? .bold : .regular))
                            .foregroundColor(isToday(day) ? appAccentColor : .textPrimary)
                    }
                    .frame(width: 40)
                    .padding(8)
                    .background(Color.cardBackground)
                    .cornerRadius(8)
                    .frame(height: 50)


                    // Meal cells for each type
                    ForEach(visibleMealTypes) { mealType in
                        mealCell(for: day, mealType: mealType)
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)
            }
        }
    }

    // MARK: - Meal Cell

    @ViewBuilder
    private func mealCell(for day: Date, mealType: MealType) -> some View {
        let meal = mealForDayAndType(day: day, mealType: mealType)

        Button {
            if let meal = meal {
                mealToDelete = meal
            } else {
                onAddMeal(day, mealType)
            }
        } label: {
            HStack {
                if let meal = meal {
                    Text(meal.recipeName ?? "Meal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(.textMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(meal != nil ? appAccentColor.opacity(opacityForMealType(mealType)) : Color.cardBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func opacityForMealType(_ mealType: MealType) -> Double {
        switch mealType {
        case .breakfast: return 0.1
        case .lunch: return 0.15
        case .dinner: return 0.2
        }
    }

    private func mealForDayAndType(day: Date, mealType: MealType) -> PlannedMeal? {
        let dayStart = calendar.startOfDay(for: day)
        return meals.first { meal in
            calendar.startOfDay(for: meal.date) == dayStart && meal.mealType == mealType
        }
    }

    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    // MARK: - Data

    private func loadMeals() async {
        guard let accountId = appState.currentAccount?.id else { return }
        isLoading = true
        do {
            meals = try await appState.mealPlannerRepository.getPlannedMealsForWeek(
                accountId: accountId,
                weekStart: weekStart
            )
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
