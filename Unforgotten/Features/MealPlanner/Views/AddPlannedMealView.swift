import SwiftUI

// MARK: - Add Planned Meal View
struct AddPlannedMealView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    // Pre-fill values (from tapping a cell in the week view)
    var prefillDate: Date?
    var prefillMealType: MealType?

    @State private var selectedDate: Date
    @State private var selectedMealType: MealType

    init(prefillDate: Date? = nil, prefillMealType: MealType? = nil) {
        self.prefillDate = prefillDate
        self.prefillMealType = prefillMealType
        self._selectedDate = State(initialValue: prefillDate ?? Date())
        self._selectedMealType = State(initialValue: prefillMealType ?? .dinner)
    }

    @State private var selectedRecipe: Recipe?
    @State private var notes = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showDatePicker = false
    @State private var showMealTypePicker = false

    // Recipe list
    @State private var recipes: [Recipe] = []
    @State private var recipeSearchText = ""
    @State private var isLoadingRecipes = true

    // Inline add recipe
    @State private var showNewRecipeField = false
    @State private var newRecipeName = ""
    @State private var newRecipeUrl = ""

    var filteredRecipes: [Recipe] {
        var result = recipes

        if !recipeSearchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(recipeSearchText) }
        }

        return result
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundLight.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(Color.textPrimary.opacity(0.2)))
                        }

                        Spacer()

                        Text("Add Meal")
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        Button {
                            Task { await saveMeal() }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(appAccentColor))
                        }
                        .disabled(selectedRecipe == nil || isLoading)
                        .opacity(selectedRecipe == nil ? 0.5 : 1)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.vertical, 16)

                    ScrollView {
                        VStack(spacing: 16) {
                            // Date card
                            dateCard

                            // Meal type card
                            mealTypeCard

                            // Recipe selection
                            if showNewRecipeField {
                                inlineNewRecipeSection
                            } else {
                                recipeSelectionSection
                            }

                            if let error = errorMessage {
                                Text(error)
                                    .font(.appCaption)
                                    .foregroundColor(.badgeRed)
                            }
                        }
                        .padding(AppDimensions.cardPadding)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await loadRecipes()
        }
    }

    // MARK: - Date Card

    @ViewBuilder
    private var dateCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 20))
                    .foregroundColor(.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Date")
                        .font(.appCardTitle)
                        .foregroundColor(.textSecondary)
                    Text(dateText)
                        .font(.appBody)
                        .foregroundColor(appAccentColor)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .rotationEffect(.degrees(showDatePicker ? 180 : 0))
            }
            .padding(AppDimensions.cardPadding)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDatePicker.toggle()
                }
            }

            if showDatePicker {
                DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(appAccentColor)
                    .padding(.horizontal, AppDimensions.cardPadding)
                    .padding(.bottom, AppDimensions.cardPadding)
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Meal Type Card

    @ViewBuilder
    private var mealTypeCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.textSecondary)

                Text("Meal Type")
                    .font(.appCardTitle)
                    .foregroundColor(.textSecondary)

                Spacer()

                Text(selectedMealType.displayName)
                    .font(.appCardTitle)
                    .foregroundColor(appAccentColor)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(appAccentColor)
            }
            .padding(AppDimensions.cardPadding)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showMealTypePicker.toggle()
                }
            }

            if showMealTypePicker {
                VStack(spacing: 0) {
                    ForEach(MealType.allCases) { type in
                        Divider()
                            .background(Color.textSecondary.opacity(0.15))

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMealType = type
                                showMealTypePicker = false
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Text(type.displayName)
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                if selectedMealType == type {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(appAccentColor)
                                }
                            }
                            .padding(.horizontal, AppDimensions.cardPadding)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Recipe Selection Section

    @ViewBuilder
    private var recipeSelectionSection: some View {
        VStack(spacing: 12) {
            // Search + New Meal button
            HStack(spacing: 8) {
                HStack {
                    TextField("Search Meals", text: $recipeSearchText)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)

                Button {
                    showNewRecipeField.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("New Meal")
                            .font(.appBody)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(appAccentColor)
                    .cornerRadius(AppDimensions.cardCornerRadius)
                }
            }

            // Recipe list
            VStack(spacing: 0) {
                if isLoadingRecipes {
                    ProgressView()
                        .tint(appAccentColor)
                        .padding(40)
                } else if filteredRecipes.isEmpty {
                    Text("No meal found. Create one first!")
                        .font(.appBody)
                        .foregroundColor(.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                } else {
                    ForEach(filteredRecipes) { recipe in
                        Button {
                            selectedRecipe = recipe
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: selectedRecipe?.id == recipe.id ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(selectedRecipe?.id == recipe.id ? appAccentColor : .textMuted)
                                    .font(.system(size: 22))

                                Text(recipe.name)
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)

                                Spacer()

                                if recipe.websiteUrl != nil {
                                    Image(systemName: "link")
                                        .font(.system(size: 12))
                                        .foregroundColor(.textSecondary)
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 18)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 300, alignment: .top)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }

    // MARK: - Inline New Recipe

    @ViewBuilder
    private var inlineNewRecipeSection: some View {
        VStack(spacing: 12) {
            AppTextField(placeholder: "Meal Name *", text: $newRecipeName)

            AppTextField(placeholder: "Website URL (optional)", text: $newRecipeUrl)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)

            HStack(spacing: 8) {
                Button {
                    showNewRecipeField = false
                    newRecipeName = ""
                    newRecipeUrl = ""
                } label: {
                    Text("Cancel")
                        .font(.appBody)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                                .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(AppDimensions.cardCornerRadius)
                }

                Button {
                    Task { await createAndSelectRecipe() }
                } label: {
                    Text("Add Meal")
                        .font(.appBody)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(appAccentColor)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                }
                .disabled(newRecipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newRecipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackgroundLight)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Data

    private func loadRecipes() async {
        guard let accountId = appState.currentAccount?.id else { return }
        isLoadingRecipes = true
        do {
            recipes = try await appState.mealPlannerRepository.getRecipes(accountId: accountId)
        } catch {
            #if DEBUG
            print("Error loading meals: \(error)")
            #endif
        }
        isLoadingRecipes = false
    }

    private func createAndSelectRecipe() async {
        guard let accountId = appState.currentAccount?.id else { return }
        let trimmedName = newRecipeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        do {
            let recipe = try await appState.mealPlannerRepository.createRecipe(
                accountId: accountId,
                name: trimmedName,
                websiteUrl: newRecipeUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newRecipeUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            recipes.append(recipe)
            recipes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            selectedRecipe = recipe
            showNewRecipeField = false
            newRecipeName = ""
            newRecipeUrl = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveMeal() async {
        guard let accountId = appState.currentAccount?.id,
              let recipe = selectedRecipe else { return }

        isLoading = true
        do {
            _ = try await appState.mealPlannerRepository.createPlannedMeal(
                accountId: accountId,
                recipeId: recipe.id,
                date: selectedDate,
                mealType: selectedMealType,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                recipeName: recipe.name
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
