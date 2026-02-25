import SwiftUI

// MARK: - Add Planned Meal View
struct AddPlannedMealView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    // Pre-fill values (from tapping a cell in the week view)
    var prefillDate: Date?
    var prefillMealType: MealType?

    @State private var selectedDate: Date = Date()
    @State private var selectedMealType: MealType = .breakfast
    @State private var selectedRecipe: Recipe?
    @State private var notes = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

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

        // Filter by selected meal type - show recipes tagged for this type or with no type (Any)
        result = result.filter { $0.mealType == nil || $0.mealType == selectedMealType }

        if !recipeSearchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(recipeSearchText) }
        }

        return result
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
                                .background(Circle().fill(Color.white.opacity(0.15)))
                        }

                        Spacer()

                        Text("Plan a Meal")
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
                        VStack(spacing: 20) {
                            // Date picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .tint(appAccentColor)
                                    .padding(12)
                                    //.background(Color.cardBackground)
                                    .cornerRadius(AppDimensions.cardCornerRadius)
                            }

                            // Meal type picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Meal")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                HStack(spacing: 0) {
                                    ForEach(MealType.allCases) { type in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedMealType = type
                                            }
                                        } label: {
                                            Text(type.displayName)
                                                .font(.appCardTitle)
                                                .foregroundColor(selectedMealType == type ? .black : .textSecondary)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(
                                                    selectedMealType == type ? appAccentColor : Color.clear
                                                )
                                        }
                                    }
                                }
                                .background(Color.cardBackgroundSoft)
                                .cornerRadius(AppDimensions.cardCornerRadius)
                            }

                            // Recipe selection
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Recipe")
                                        .font(.appCaption)
                                        .foregroundColor(.textSecondary)

                                    Spacer()

                                    Button {
                                        showNewRecipeField.toggle()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: showNewRecipeField ? "xmark" : "plus")
                                                .font(.system(size: 12))
                                            Text(showNewRecipeField ? "Cancel" : "New Meal")
                                                .font(.appBody)
                                        }
                                        .foregroundColor(appAccentColor)
                                    }
                                }

                                if showNewRecipeField {
                                    inlineNewRecipeSection
                                } else {
                                    recipeSelectionSection
                                }
                            }

                            // Notes
                            AppTextField(placeholder: "Notes (optional)", text: $notes)

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
        .onAppear {
            if let date = prefillDate {
                selectedDate = date
            }
            if let mealType = prefillMealType {
                selectedMealType = mealType
            }
        }
        .task {
            await loadRecipes()
        }
    }

    // MARK: - Recipe Selection Section

    @ViewBuilder
    private var recipeSelectionSection: some View {
        VStack(spacing: 8) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textSecondary)
                    .font(.system(size: 14))
                TextField("Search meals", text: $recipeSearchText)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)
            }
            .padding(12)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)

            if isLoadingRecipes {
                ProgressView()
                    .tint(appAccentColor)
                    .padding()
            } else if filteredRecipes.isEmpty {
                Text("No meal found. Create one first!")
                    .font(.appCaption)
                    .foregroundColor(.textMuted)
                    .padding()
            } else {
                // Recipe list (scrollable, max height)
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredRecipes) { recipe in
                            Button {
                                selectedRecipe = recipe
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedRecipe?.id == recipe.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedRecipe?.id == recipe.id ? appAccentColor : .textMuted)
                                        .font(.system(size: 20))

                                    Text(recipe.name)
                                        .font(.appBody)
                                        .foregroundColor(.textPrimary)

                                    Spacer()

                                    if recipe.websiteUrl != nil {
                                        Image(systemName: "link")
                                            .font(.system(size: 12))
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(selectedRecipe?.id == recipe.id ? appAccentColor.opacity(0.1) : Color.clear)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 250)
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
            }
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
        .padding(12)
        .background(Color.cardBackground)
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
