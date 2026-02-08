import SwiftUI

// MARK: - Section Presets
struct SectionPresets {
    static let hobbySections = [
        "Favourite TV Shows",
        "Favourite Movies",
        "Favourite Music",
        "Favourite Books",
        "Sports Teams",
        "Favourite Foods",
        "Favourite Places",
        "Collections",
        "Other Interests"
    ]

    static let activitySections = [
        "Indoor Activities",
        "Outdoor Activities",
        "Creative Activities",
        "Social Activities",
        "Games & Puzzles",
        "Exercise & Movement",
        "Activity Ideas",
        "Vacation Ideas",
        "Day Trip Ideas"
    ]

    static func sections(for category: ProfileCategoryType) -> [String] {
        switch category {
        case .hobbies: return hobbySections
        case .activities: return activitySections
        default: return []
        }
    }

    // Preset items for each section type
    static let presetItems: [String: [String]] = [
        // Hobbies
        "Favourite TV Shows": ["Antiques Roadshow", "Gardeners' World", "Strictly Come Dancing", "The Chase", "Coronation Street", "EastEnders", "Emmerdale", "Countdown", "Pointless", "Only Fools and Horses"],
        "Favourite Movies": ["The Sound of Music", "Mary Poppins", "Casablanca", "Gone with the Wind", "It's a Wonderful Life", "Brief Encounter", "The Great Escape", "Singin' in the Rain"],
        "Favourite Music": ["Frank Sinatra", "Elvis Presley", "The Beatles", "Vera Lynn", "Dean Martin", "Nat King Cole", "Cliff Richard", "Tom Jones", "Classical Music", "Jazz", "Big Band"],
        "Favourite Books": ["Agatha Christie", "Dick Francis", "Catherine Cookson", "Maeve Binchy", "Roald Dahl", "Newspapers", "Magazines", "Crossword Books"],
        "Sports Teams": ["Manchester United", "Liverpool", "Arsenal", "Chelsea", "England Football", "England Cricket", "England Rugby"],
        "Favourite Foods": ["Fish and Chips", "Roast Dinner", "Shepherd's Pie", "Cottage Pie", "Trifle", "Victoria Sponge", "Tea and Biscuits", "Scones"],
        "Favourite Places": ["The Seaside", "Country Walks", "Garden Centres", "National Trust", "Local Park", "Church"],
        "Collections": ["Stamps", "Coins", "Postcards", "Photographs", "China", "Thimbles"],
        "Other Interests": ["Gardening", "Bird Watching", "Knitting", "Crosswords", "Sudoku", "Reading"],

        // Activities
        "Indoor Activities": ["Jigsaw Puzzles", "Card Games", "Board Games", "Looking at Photos", "Watching Films", "Listening to Music", "Reading Aloud", "Reminiscing"],
        "Outdoor Activities": ["Garden Walk", "Feeding Birds", "Park Visit", "Seaside Trip", "Garden Centre", "Coffee Shop", "Scenic Drive"],
        "Creative Activities": ["Painting", "Colouring", "Knitting", "Crochet", "Flower Arranging", "Scrapbooking", "Simple Crafts"],
        "Social Activities": ["Family Visits", "Tea with Friends", "Church Groups", "Day Centre", "Singing Groups", "Memory Cafe"],
        "Games & Puzzles": ["Dominoes", "Snap", "Bingo", "Word Games", "Simple Quizzes", "Picture Matching"],
        "Exercise & Movement": ["Gentle Stretching", "Armchair Exercises", "Short Walks", "Dancing", "Ball Games"],
        "Relaxation": ["Hand Massage", "Listening to Music", "Looking at Nature", "Pet Therapy", "Aromatherapy"],
        "Day Trip Ideas": ["Beach Visit", "Country Pub", "Garden Centre", "Museum", "Farm Visit", "Market Day"]
    ]

    static func presets(for section: String) -> [String] {
        return presetItems[section] ?? []
    }
}

// MARK: - Section Based Category View
struct SectionBasedCategoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.iPadAddHobbySectionAction) private var iPadAddHobbySectionAction
    @Environment(\.iPadAddActivitySectionAction) private var iPadAddActivitySectionAction
    @Environment(\.iPadAddHobbyItemAction) private var iPadAddHobbyItemAction
    @Environment(\.iPadAddActivityItemAction) private var iPadAddActivityItemAction

    let profile: Profile
    let category: ProfileCategoryType
    let details: [ProfileDetail]

    @State private var currentDetails: [ProfileDetail]
    @State private var showAddSection = false
    @State private var showAddItem = false
    @State private var selectedSection: String?
    @State private var showSettings = false
    @State private var syncedDetailIds: Set<UUID> = []

    /// Check if iPad environment actions are available
    private var hasiPadSectionAction: Bool {
        switch category {
        case .hobbies: return iPadAddHobbySectionAction != nil
        case .activities: return iPadAddActivitySectionAction != nil
        default: return false
        }
    }

    private var hasiPadItemAction: Bool {
        switch category {
        case .hobbies: return iPadAddHobbyItemAction != nil
        case .activities: return iPadAddActivityItemAction != nil
        default: return false
        }
    }

    init(profile: Profile, category: ProfileCategoryType, details: [ProfileDetail]) {
        self.profile = profile
        self.category = category
        self.details = details
        self._currentDetails = State(initialValue: details)
    }

    /// Group details by their label (section name)
    private var groupedDetails: [(section: String, items: [ProfileDetail])] {
        let grouped = Dictionary(grouping: currentDetails) { $0.label }
        return grouped.map { (section: $0.key, items: $0.value) }
            .sorted { $0.section < $1.section }
    }

    /// Get existing section names
    private var existingSections: [String] {
        Array(Set(currentDetails.map { $0.label })).sorted()
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    CustomizableHeaderView(
                        pageIdentifier: .profileDetail,
                        title: profile.fullName,
                        subtitle: category.title,
                        showBackButton: true,
                        backAction: { dismiss() },
                        showAddButton: true,
                        addAction: {
                            // Use iPad full-screen action if available
                            if hasiPadSectionAction {
                                switch category {
                                case .hobbies:
                                    iPadAddHobbySectionAction?(profile)
                                case .activities:
                                    iPadAddActivitySectionAction?(profile)
                                default:
                                    break
                                }
                            } else {
                                showAddSection = true
                            }
                        }
                    )

                    // Content
                    VStack(spacing: AppDimensions.cardSpacing) {
                        if groupedDetails.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Text("No \(category.title.lowercased()) yet")
                                    .font(.appCardTitle)
                                    .foregroundColor(.textPrimary)

                                Text("Tap + to add a section")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            // Sections
                            ForEach(groupedDetails, id: \.section) { group in
                                SectionCard(
                                    sectionName: group.section,
                                    items: group.items,
                                    accentColor: appAccentColor,
                                    syncedDetailIds: syncedDetailIds,
                                    sourceName: profile.isSyncedProfile ? profile.displayName : nil,
                                    onAddItem: {
                                        // Use iPad full-screen action if available
                                        if hasiPadItemAction {
                                            switch category {
                                            case .hobbies:
                                                iPadAddHobbyItemAction?(profile, group.section)
                                            case .activities:
                                                iPadAddActivityItemAction?(profile, group.section)
                                            default:
                                                break
                                            }
                                        } else {
                                            selectedSection = group.section
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                showAddItem = true
                                            }
                                        }
                                    },
                                    onDeleteItem: { detail in
                                        Task {
                                            await deleteDetail(detail)
                                        }
                                    },
                                    onDeleteSection: {
                                        Task {
                                            await deleteSection(group.section)
                                        }
                                    }
                                )
                            }
                        }

                        // Bottom spacing
                        Spacer()
                            .frame(height: 120)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding(for: horizontalSizeClass))
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackgroundLight)
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showSettings) {
            SettingsPanelView(onDismiss: { showSettings = false })
        }
        .sidePanel(isPresented: $showAddSection) {
            AddSectionView(
                profile: profile,
                category: category,
                existingSections: existingSections,
                onDismiss: { showAddSection = false },
                onSectionAdded: { sectionName in
                    // After adding a section, open the add item sheet for that section
                    selectedSection = sectionName
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showAddSection = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showAddItem = true
                        }
                    }
                }
            )
        }
        .sidePanel(isPresented: Binding(
            get: { showAddItem && selectedSection != nil },
            set: { newValue in
                showAddItem = newValue
                if !newValue {
                    selectedSection = nil
                }
            }
        )) {
            if let section = selectedSection {
                AddSectionItemView(
                    profile: profile,
                    category: category,
                    sectionName: section,
                    onDismiss: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showAddItem = false
                        }
                        selectedSection = nil
                    },
                    onItemAdded: { newDetail in
                        currentDetails.append(newDetail)
                    }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDetailsDidChange)) { notification in
            // Reload details when they change (e.g., from iPad full-screen overlay or remote sync)
            let isRemoteSync = notification.userInfo?["isRemoteSync"] as? Bool ?? false

            // For remote sync notifications, check if this is for our profile or if profileId is missing (common for deletes)
            if let profileId = notification.userInfo?["profileId"] as? UUID {
                guard profileId == profile.id else { return }
            } else if !isRemoteSync {
                // Local notification without profileId - ignore
                return
            }
            // Remote sync without profileId (e.g., delete) - refresh to be safe

            Task {
                await reloadDetails(forceRefresh: isRemoteSync)
            }
        }
        .task {
            // Always refresh from network on appear to ensure data is current
            await reloadDetails(forceRefresh: true)
        }
    }

    private func reloadDetails(forceRefresh: Bool = false) async {
        do {
            let details: [ProfileDetail]
            if forceRefresh {
                details = try await appState.profileRepository.refreshProfileDetails(
                    profileId: profile.id,
                    category: category.detailCategory
                )
            } else {
                details = try await appState.profileRepository.getProfileDetails(
                    profileId: profile.id,
                    category: category.detailCategory
                )
            }
            currentDetails = details

            // Load synced detail IDs if this is a synced profile
            if profile.isSyncedProfile {
                syncedDetailIds = try await appState.profileSyncRepository.getSyncedDetailIds(for: profile.id)
            }
        } catch {
            #if DEBUG
            print("Failed to reload details: \(error)")
            #endif
        }
    }

    private func deleteDetail(_ detail: ProfileDetail) async {
        do {
            try await appState.profileRepository.deleteProfileDetail(id: detail.id)
            currentDetails.removeAll { $0.id == detail.id }
            NotificationCenter.default.post(name: .profileDetailsDidChange, object: nil, userInfo: ["profileId": profile.id])
        } catch {
            #if DEBUG
            print("Failed to delete detail: \(error)")
            #endif
        }
    }

    private func deleteSection(_ sectionName: String) async {
        let itemsToDelete = currentDetails.filter { $0.label == sectionName }
        for item in itemsToDelete {
            do {
                try await appState.profileRepository.deleteProfileDetail(id: item.id)
            } catch {
                #if DEBUG
                print("Failed to delete detail: \(error)")
                #endif
            }
        }
        currentDetails.removeAll { $0.label == sectionName }
        NotificationCenter.default.post(name: .profileDetailsDidChange, object: nil, userInfo: ["profileId": profile.id])
    }
}

// MARK: - Section Card
struct SectionCard: View {
    let sectionName: String
    let items: [ProfileDetail]
    let accentColor: Color
    let syncedDetailIds: Set<UUID>
    let sourceName: String?
    let onAddItem: () -> Void
    let onDeleteItem: (ProfileDetail) -> Void
    let onDeleteSection: () -> Void

    init(sectionName: String, items: [ProfileDetail], accentColor: Color, syncedDetailIds: Set<UUID> = [], sourceName: String? = nil, onAddItem: @escaping () -> Void, onDeleteItem: @escaping (ProfileDetail) -> Void, onDeleteSection: @escaping () -> Void) {
        self.sectionName = sectionName
        self.items = items
        self.accentColor = accentColor
        self.syncedDetailIds = syncedDetailIds
        self.sourceName = sourceName
        self.onAddItem = onAddItem
        self.onDeleteItem = onDeleteItem
        self.onDeleteSection = onDeleteSection
    }

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text(sectionName.uppercased())
                    .font(.appCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.textSecondary)

                Spacer()

                // Add item button
                Button(action: onAddItem) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(accentColor)
                        .frame(width: 28, height: 28)
                        .background(accentColor.opacity(0.2))
                        .clipShape(Circle())
                }

                // Delete section button
                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }

            // Items as tags
            FlowLayout(spacing: 8) {
                ForEach(items) { item in
                    ItemTag(
                        text: item.value,
                        accentColor: accentColor,
                        isSynced: syncedDetailIds.contains(item.id),
                        sourceName: sourceName,
                        onDelete: { onDeleteItem(item) }
                    )
                }
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .confirmationDialog(
            "Delete Section",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \"\(sectionName)\"", role: .destructive) {
                onDeleteSection()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete the section and all items in it.")
        }
    }
}

// MARK: - Item Tag
struct ItemTag: View {
    let text: String
    let accentColor: Color
    let isSynced: Bool
    let sourceName: String?
    let onDelete: () -> Void

    init(text: String, accentColor: Color, isSynced: Bool = false, sourceName: String? = nil, onDelete: @escaping () -> Void) {
        self.text = text
        self.accentColor = accentColor
        self.isSynced = isSynced
        self.sourceName = sourceName
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.appCaption)
                .foregroundColor(.textPrimary)

            if isSynced, let name = sourceName {
                SyncIndicator(sourceName: name)
            }

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(accentColor.opacity(0.15))
        .cornerRadius(16)
    }
}

// MARK: - Add Section View
struct AddSectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    let profile: Profile
    let category: ProfileCategoryType
    let existingSections: [String]
    let onDismiss: () -> Void
    let onSectionAdded: (String) -> Void

    @State private var customSectionName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var presetSections: [String] {
        SectionPresets.sections(for: category)
            .filter { !existingSections.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.white.opacity(0.5)))
                }

                Spacer()

                Text("Add Section")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Placeholder for balance
                Color.clear.frame(width: 48, height: 48)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

            ScrollView {
                VStack(spacing: 20) {
                    // Preset sections
                    if !presetSections.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SUGGESTED SECTIONS")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(presetSections, id: \.self) { section in
                                    Button {
                                        onSectionAdded(section)
                                    } label: {
                                        Text(section)
                                            .font(.appCaption)
                                            .foregroundColor(.textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }

                    // Custom section input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OR CREATE CUSTOM SECTION")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        HStack {
                            AppTextField(placeholder: "Section name", text: $customSectionName)

                            Button {
                                if !customSectionName.isBlank {
                                    onSectionAdded(customSectionName.trimmingCharacters(in: .whitespaces))
                                }
                            } label: {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(customSectionName.isBlank ? Color.gray.opacity(0.3) : appAccentColor)
                                    )
                            }
                            .disabled(customSectionName.isBlank)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                    }
                }
                .padding(AppDimensions.screenPadding)
            }
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Add Section Item View
struct AddSectionItemView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    let profile: Profile
    let category: ProfileCategoryType
    let sectionName: String
    let onDismiss: () -> Void
    let onItemAdded: (ProfileDetail) -> Void

    @State private var customItemName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var addedItems: [String] = []

    private var presetItems: [String] {
        SectionPresets.presets(for: sectionName)
            .filter { !addedItems.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.white.opacity(0.5)))
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Add to")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                    Text(sectionName)
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(.appBodyMedium)
                        .foregroundColor(appAccentColor)
                        .frame(width: 48, height: 48)
                }
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

            ScrollView {
                VStack(spacing: 20) {
                    // Added items preview
                    if !addedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ADDED")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(addedItems, id: \.self) { item in
                                    Text(item)
                                        .font(.appCaption)
                                        .foregroundColor(.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(appAccentColor.opacity(0.3))
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }

                    // Preset items
                    if !presetItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SUGGESTIONS")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(presetItems, id: \.self) { item in
                                    Button {
                                        Task {
                                            await addItem(item)
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(item)
                                                .font(.appCaption)
                                                .foregroundColor(.textPrimary)
                                            Image(systemName: "plus")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.textSecondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.cardBackgroundSoft)
                                        .cornerRadius(16)
                                    }
                                    .disabled(isLoading)
                                }
                            }
                        }
                    }

                    // Custom item input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ADD AN ITEM")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        HStack {
                            AppTextField(placeholder: "Item name", text: $customItemName)

                            Button {
                                if !customItemName.isBlank {
                                    Task {
                                        await addItem(customItemName.trimmingCharacters(in: .whitespaces))
                                        customItemName = ""
                                    }
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(customItemName.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                                    )
                            }
                            .disabled(customItemName.isBlank || isLoading)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                    }
                }
                .padding(AppDimensions.screenPadding)
            }
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
    }

    private func addItem(_ itemName: String) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true
        errorMessage = nil

        let insert = ProfileDetailInsert(
            accountId: account.id,
            profileId: profile.id,
            category: category.detailCategory,
            label: sectionName,
            value: itemName,
            status: nil
        )

        do {
            let newDetail = try await appState.profileRepository.createProfileDetail(insert)
            addedItems.append(itemName)
            onItemAdded(newDetail)
            NotificationCenter.default.post(name: .profileDetailsDidChange, object: nil, userInfo: ["profileId": profile.id])
        } catch {
            errorMessage = "Failed to add item. Please try again."
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    SectionBasedCategoryView(
        profile: Profile(
            id: UUID(),
            accountId: UUID(),
            type: .primary,
            fullName: "John Doe",
            preferredName: nil,
            relationship: nil,
            connectedToProfileId: nil,
            includeInFamilyTree: true,
            birthday: nil,
            isDeceased: false,
            dateOfDeath: nil,
            address: nil,
            phone: nil,
            email: nil,
            notes: nil,
            isFavourite: false,
            linkedUserId: nil,
            photoUrl: nil,
            sortOrder: 0,
            createdAt: Date(),
            updatedAt: Date()
        ),
        category: .hobbies,
        details: []
    )
    .environmentObject(AppState.forPreview())
}
