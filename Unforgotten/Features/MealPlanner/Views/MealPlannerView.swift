import SwiftUI

// MARK: - Meal Planner View
struct MealPlannerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction

    @State private var selectedTab = 0 // 0 = Meal Plan, 1 = Recipes
    @State private var showAddMeal = false
    @State private var showAddRecipe = false
    @State private var recipes: [Recipe] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var recipeToEdit: Recipe?
    @State private var recipeToDelete: Recipe?
    @State private var showDeleteConfirmation = false
    @State private var recipeListHeight: CGFloat = 0
    @AppStorage("mealPlannerMealTypeFilters") private var savedMealFilters: String = ""

    private var selectedMealFilters: Set<MealType> {
        get {
            guard !savedMealFilters.isEmpty else { return [] }
            let types = savedMealFilters.split(separator: ",").compactMap { MealType(rawValue: String($0)) }
            return Set(types)
        }
    }

    private func setMealFilters(_ filters: Set<MealType>) {
        savedMealFilters = filters.map(\.rawValue).joined(separator: ",")
    }

    // For pre-filling add meal form
    @State private var prefillDate: Date?
    @State private var prefillMealType: MealType?
    @State private var mealRefreshTrigger = 0

    private var canEdit: Bool {
        appState.canEdit
    }

    var filteredRecipes: [Recipe] {
        var result = recipes

        // Filter by meal type if filters are active
        if !selectedMealFilters.isEmpty {
            result = result.filter { recipe in
                guard let type = recipe.mealType else { return true } // Show "Any" recipes always
                return selectedMealFilters.contains(type)
            }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    CustomizableHeaderView(
                        pageIdentifier: .mealPlanner,
                        title: "Meal Planner",
                        showBackButton: iPadHomeAction == nil,
                        backAction: { dismiss() },
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction,
                        showAddButton: canEdit,
                        addAction: {
                            if selectedTab == 0 {
                                prefillDate = nil
                                prefillMealType = nil
                                showAddMeal = true
                            } else {
                                showAddRecipe = true
                            }
                        }
                    )

                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Tab picker with filter
                        HStack(spacing: 12) {
                            HStack(spacing: 0) {
                                ForEach([(0, "Meal Plan"), (1, "Meals")], id: \.0) { tag, title in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedTab = tag
                                        }
                                    } label: {
                                        Text(title)
                                            .font(.appCardTitle)
                                            .foregroundColor(selectedTab == tag ? .black : .textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                selectedTab == tag ? appAccentColor : Color.clear
                                            )
                                    }
                                }
                            }
                            .background(Color.cardBackgroundSoft)
                            .cornerRadius(AppDimensions.cardCornerRadius)

                            Menu {
                                Button {
                                    setMealFilters([])
                                } label: {
                                    if selectedMealFilters.isEmpty {
                                        Label("All", systemImage: "checkmark")
                                    } else {
                                        Text("All")
                                    }
                                }

                                ForEach(MealType.allCases) { mealType in
                                    Button {
                                        var filters = selectedMealFilters
                                        if filters.contains(mealType) {
                                            filters.remove(mealType)
                                        } else {
                                            filters.insert(mealType)
                                        }
                                        // If all three are selected, reset to show all
                                        if filters.count == MealType.allCases.count {
                                            filters = []
                                        }
                                        setMealFilters(filters)
                                    } label: {
                                        if selectedMealFilters.contains(mealType) {
                                            Label(mealType.displayName, systemImage: "checkmark")
                                        } else {
                                            Text(mealType.displayName)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: !selectedMealFilters.isEmpty ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(!selectedMealFilters.isEmpty ? appAccentColor : .textSecondary)
                                    .frame(width: 44, height: 44)
                                    .background(Color.cardBackground)
                                    .cornerRadius(AppDimensions.cardCornerRadius)
                            }
                            .tint(appAccentColor)
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)
                        .padding(.top, AppDimensions.cardSpacing)

                        if selectedTab == 0 {
                            MealPlanWeekView(
                                onAddMeal: { date, mealType in
                                    prefillDate = date
                                    prefillMealType = mealType
                                    showAddMeal = true
                                },
                                onOpenRecipe: { recipeId in
                                    if let recipe = recipes.first(where: { $0.id == recipeId }) {
                                        recipeToEdit = recipe
                                    } else {
                                        // Recipe not yet loaded, fetch and open
                                        Task {
                                            await loadRecipes()
                                            if let recipe = recipes.first(where: { $0.id == recipeId }) {
                                                recipeToEdit = recipe
                                            }
                                        }
                                    }
                                },
                                refreshTrigger: mealRefreshTrigger,
                                mealTypeFilters: selectedMealFilters
                            )
                        } else {
                            recipesSection
                        }
                    }

                    Spacer().frame(height: 140)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarHidden(true)
        .task {
            await loadRecipes()
        }
        .refreshable {
            await loadRecipes()
            mealRefreshTrigger += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .mealsDidChange)) { _ in
            Task {
                await loadRecipes()
                mealRefreshTrigger += 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            Task {
                await loadRecipes()
                mealRefreshTrigger += 1
            }
        }
        .sheet(isPresented: $showAddMeal, onDismiss: {
            mealRefreshTrigger += 1
        }) {
            AddPlannedMealView(
                prefillDate: prefillDate,
                prefillMealType: prefillMealType
            )
            .environmentObject(appState)
        }
        .sheet(isPresented: $showAddRecipe) {
            AddRecipeSheet(onSave: { recipe in
                recipes.append(recipe)
                recipes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            })
            .environmentObject(appState)
        }
        .sheet(item: $recipeToEdit) { recipe in
            EditRecipeSheet(recipe: recipe, onSave: { updated in
                if let index = recipes.firstIndex(where: { $0.id == updated.id }) {
                    recipes[index] = updated
                }
            })
            .environmentObject(appState)
        }
        .alert("Delete Recipe", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                recipeToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let recipe = recipeToDelete {
                    Task {
                        await deleteRecipe(recipe)
                        recipeToDelete = nil
                    }
                }
            }
        } message: {
            if let recipe = recipeToDelete {
                Text("Are you sure you want to delete \"\(recipe.name)\"?")
            }
        }
    }

    // MARK: - Recipes Section

    @ViewBuilder
    private var recipesSection: some View {
        VStack(spacing: AppDimensions.cardSpacing) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textSecondary)
                TextField("Search meals", text: $searchText)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .padding(.horizontal, AppDimensions.screenPadding)

            if isLoading {
                LoadingView(message: "Loading recipes...")
                    .padding(.top, 40)
            } else if filteredRecipes.isEmpty {
                EmptyStateView(
                    icon: "fork.knife",
                    title: "No Recipes Yet",
                    message: "Add your favourite recipes to get started with meal planning."
                )
                .padding(.top, 40)
            } else {
                List {
                    ForEach(filteredRecipes) { recipe in
                        RecipeCard(
                            recipe: recipe,
                            accentColor: appAccentColor,
                            onEdit: {
                                recipeToEdit = recipe
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if canEdit {
                                Button(role: .destructive) {
                                    recipeToDelete = recipe
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: AppDimensions.cardSpacing / 2, leading: AppDimensions.screenPadding, bottom: AppDimensions.cardSpacing / 2, trailing: AppDimensions.screenPadding))
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(height: recipeListHeight)
                .onChange(of: filteredRecipes.count) { _, count in
                    let rowHeight: CGFloat = 72
                    let spacing: CGFloat = AppDimensions.cardSpacing
                    recipeListHeight = CGFloat(count) * (rowHeight + spacing)
                }
                .onAppear {
                    let rowHeight: CGFloat = 72
                    let spacing: CGFloat = AppDimensions.cardSpacing
                    recipeListHeight = CGFloat(filteredRecipes.count) * (rowHeight + spacing)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadRecipes() async {
        guard let accountId = appState.currentAccount?.id else { return }
        isLoading = true
        do {
            recipes = try await appState.mealPlannerRepository.getRecipes(accountId: accountId)
        } catch {
            #if DEBUG
            print("Error loading recipes: \(error)")
            #endif
        }
        isLoading = false
    }

    private func deleteRecipe(_ recipe: Recipe) async {
        do {
            try await appState.mealPlannerRepository.deleteRecipe(id: recipe.id)
            recipes.removeAll { $0.id == recipe.id }
        } catch {
            #if DEBUG
            print("Error deleting recipe: \(error)")
            #endif
        }
    }
}

// MARK: - Recipe Card

private struct RecipeCard: View {
    let recipe: Recipe
    let accentColor: Color
    var onEdit: () -> Void

    var body: some View {
        Button { onEdit() } label: {
            HStack(spacing: 12) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 16))
                    .foregroundColor(accentColor)
                    .frame(width: 36, height: 36)
                    .background(accentColor.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.name)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)

                    if let url = recipe.websiteUrl, !url.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 12))
                            Text("View Recipe")
                                .font(.appCaption)
                        }
                        .foregroundColor(accentColor)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Recipe Sheet

struct AddRecipeSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.openURL) private var openURL

    @State private var name = ""
    @State private var selectedMealType: MealType?
    @State private var websiteUrl = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var onSave: (Recipe) -> Void

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

                        Text("New Meal")
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        Button {
                            Task { await saveRecipe() }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .frame(width: 48, height: 48)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(appAccentColor))
                            }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.vertical, 16)

                    ScrollView {
                        VStack(spacing: 20) {
                            // Recipe image
                            Button {
                                showImagePicker = true
                            } label: {
                                GeometryReader { geo in
                                    if let image = selectedImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: geo.size.width, height: geo.size.width)
                                            .clipped()
                                            .cornerRadius(AppDimensions.cardCornerRadius)
                                    } else {
                                        ZStack {
                                            Color.cardBackground
                                            VStack(spacing: 8) {
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 28))
                                                    .foregroundColor(.textSecondary)
                                                Text("Add Photo")
                                                    .font(.appCaption)
                                                    .foregroundColor(.textSecondary)
                                            }
                                        }
                                        .frame(width: geo.size.width, height: geo.size.width)
                                        .cornerRadius(AppDimensions.cardCornerRadius)
                                    }
                                }
                                .aspectRatio(1, contentMode: .fit)
                            }

                            AppTextField(placeholder: "Meal Name *", text: $name)

                            // Meal type selector
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Type")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                HStack(spacing: 0) {
                                    // "Any" option
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedMealType = nil
                                        }
                                    } label: {
                                        Text("Any")
                                            .font(.appCardTitle)
                                            .foregroundColor(selectedMealType == nil ? .black : .textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                selectedMealType == nil ? appAccentColor : Color.clear
                                            )
                                    }

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

                            // Website URL with launch button
                            HStack(spacing: 8) {
                                AppTextField(placeholder: "Website URL (optional)", text: $websiteUrl)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.URL)

                                if !websiteUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Button {
                                        let trimmed = websiteUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                                        let urlString = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
                                        if let url = URL(string: urlString) {
                                            openURL(url)
                                        }
                                    } label: {
                                        Image(systemName: "safari")
                                            .font(.system(size: 20))
                                            .foregroundColor(appAccentColor)
                                            .frame(width: 48, height: 48)
                                            .background(Color.cardBackground)
                                            .cornerRadius(AppDimensions.cardCornerRadius)
                                    }
                                }
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
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }

    private func saveRecipe() async {
        guard let accountId = appState.currentAccount?.id else { return }
        isLoading = true
        do {
            let recipeId = UUID()
            var imageUrl: String?

            if let image = selectedImage {
                imageUrl = try await ImageUploadService.shared.uploadRecipePhoto(image: image, recipeId: recipeId)
            }

            let recipe = try await appState.mealPlannerRepository.createRecipe(
                accountId: accountId,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                websiteUrl: websiteUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : websiteUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                imageUrl: imageUrl,
                mealType: selectedMealType
            )
            onSave(recipe)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Edit Recipe Sheet

struct EditRecipeSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.openURL) private var openURL

    let recipe: Recipe
    var onSave: (Recipe) -> Void

    @State private var name: String = ""
    @State private var selectedMealType: MealType?
    @State private var websiteUrl: String = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundLight.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(Color.white.opacity(0.15)))
                        }

                        Spacer()

                        Text("Edit Recipe")
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        Button {
                            Task { await updateRecipe() }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .frame(width: 48, height: 48)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(appAccentColor))
                            }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.vertical, 16)

                    ScrollView {
                        VStack(spacing: 20) {
                            // Recipe image
                            Button {
                                showImagePicker = true
                            } label: {
                                GeometryReader { geo in
                                    if let image = selectedImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: geo.size.width, height: geo.size.width)
                                            .clipped()
                                            .cornerRadius(AppDimensions.cardCornerRadius)
                                    } else if let imageUrl = recipe.imageUrl, let url = URL(string: imageUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: geo.size.width, height: geo.size.width)
                                                    .clipped()
                                                    .cornerRadius(AppDimensions.cardCornerRadius)
                                            case .failure:
                                                recipeImagePlaceholder(width: geo.size.width)
                                            case .empty:
                                                ZStack {
                                                    Color.cardBackground
                                                        .frame(width: geo.size.width, height: geo.size.width)
                                                        .cornerRadius(AppDimensions.cardCornerRadius)
                                                    ProgressView()
                                                }
                                            @unknown default:
                                                recipeImagePlaceholder(width: geo.size.width)
                                            }
                                        }
                                    } else {
                                        recipeImagePlaceholder(width: geo.size.width)
                                    }
                                }
                                .aspectRatio(1, contentMode: .fit)
                            }

                            AppTextField(placeholder: "Recipe Name *", text: $name)

                            // Meal type selector
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Type")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                HStack(spacing: 0) {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedMealType = nil
                                        }
                                    } label: {
                                        Text("Any")
                                            .font(.appCardTitle)
                                            .foregroundColor(selectedMealType == nil ? .black : .textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                selectedMealType == nil ? appAccentColor : Color.clear
                                            )
                                    }

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

                            // Website URL with launch button
                            HStack(spacing: 8) {
                                AppTextField(placeholder: "Website URL (optional)", text: $websiteUrl)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.URL)

                                if !websiteUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Button {
                                        let trimmed = websiteUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                                        let urlString = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
                                        if let url = URL(string: urlString) {
                                            openURL(url)
                                        }
                                    } label: {
                                        Image(systemName: "safari")
                                            .font(.system(size: 20))
                                            .foregroundColor(appAccentColor)
                                            .frame(width: 48, height: 48)
                                            .background(Color.cardBackground)
                                            .cornerRadius(AppDimensions.cardCornerRadius)
                                    }
                                }
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
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
        .onAppear {
            name = recipe.name
            selectedMealType = recipe.mealType
            websiteUrl = recipe.websiteUrl ?? ""
        }
    }

    @ViewBuilder
    private func recipeImagePlaceholder(width: CGFloat) -> some View {
        ZStack {
            Color.cardBackground
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.textSecondary)
                Text("Add Photo")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(width: width, height: width)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    private func updateRecipe() async {
        isLoading = true
        do {
            var updated = recipe

            if let image = selectedImage {
                let imageUrl = try await ImageUploadService.shared.uploadRecipePhoto(image: image, recipeId: recipe.id)
                updated.imageUrl = imageUrl
            }

            updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.mealType = selectedMealType
            updated.websiteUrl = websiteUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : websiteUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            let saved = try await appState.mealPlannerRepository.updateRecipe(updated)
            onSave(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
