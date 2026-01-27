import SwiftUI

// MARK: - Profile List View (Family and Friends)
struct ProfileListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction

    @StateObject private var viewModel = ProfileListViewModel()
    @State private var showAddProfile = false
    @State private var showUpgradePrompt = false
    @State private var profileToDelete: Profile?
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""

    /// Check if user can add more friend profiles
    private var canAddProfile: Bool {
        PremiumLimitsManager.shared.canCreateFriendProfile(
            appState: appState,
            currentCount: viewModel.profiles.count
        )
    }

    private var filteredProfiles: [Profile] {
        if searchText.isEmpty {
            return viewModel.profiles
        }
        return viewModel.profiles.filter { profile in
            profile.fullName.localizedCaseInsensitiveContains(searchText) ||
            (profile.relationship?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }


    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header scrolls with content - uses style-based assets from HeaderStyleManager
                    CustomizableHeaderView(
                        pageIdentifier: .profiles,
                        title: "Family and Friends",
                        showBackButton: iPadHomeAction == nil,
                        backAction: { dismiss() },
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction,
                        showAddButton: true,
                        addAction: {
                            if canAddProfile {
                                showAddProfile = true
                            } else {
                                showUpgradePrompt = true
                            }
                        }
                    )

                    // Content
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Search field
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.textSecondary)

                            TextField("Search family and friends...", text: $searchText)
                                .font(.appBody)
                                .foregroundColor(.textPrimary)

                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }
                        .padding(AppDimensions.cardPadding)
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                        .padding(.horizontal, AppDimensions.screenPadding)

                        // Profile list
                        LazyVStack(spacing: AppDimensions.cardSpacing) {
                            ForEach(filteredProfiles) { profile in
                                ProfileListRow(
                                    profile: profile,
                                    onDelete: {
                                        profileToDelete = profile
                                        showDeleteConfirmation = true
                                    }
                                )
                                .padding(.horizontal, AppDimensions.screenPadding)
                            }
                        }

                        // Loading state
                        if viewModel.isLoading && viewModel.profiles.isEmpty {
                            LoadingView(message: "Loading profiles...")
                                .padding(.top, 40)
                                .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        // Empty state - no profiles at all
                        if viewModel.profiles.isEmpty && !viewModel.isLoading {
                            EmptyStateView(
                                icon: "person.2.fill",
                                title: "No family or friends yet",
                                message: "Add your first family member or friend",
                                buttonTitle: "Add Person",
                                buttonAction: {
                                    if canAddProfile {
                                        showAddProfile = true
                                    } else {
                                        showUpgradePrompt = true
                                    }
                                }
                            )
                            .padding(.top, 40)
                            .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        // Premium limit reached banner (shown when there are profiles but limit reached)
                        if !viewModel.profiles.isEmpty && !canAddProfile {
                            PremiumFeatureLockBanner(
                                feature: .friendProfiles,
                                onUpgrade: { showUpgradePrompt = true }
                            )
                            .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        // No search results
                        if !viewModel.profiles.isEmpty && filteredProfiles.isEmpty && !searchText.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.textSecondary)

                                Text("No results found")
                                    .font(.appCardTitle)
                                    .foregroundColor(.textPrimary)

                                Text("No matches for \"\(searchText)\"")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                            }
                            .padding(.top, 40)
                            .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        // Bottom spacing for nav bar
                        Spacer()
                            .frame(height: 120)
                    }
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showAddProfile) {
            AddProfileView { newProfile in
                Task {
                    await viewModel.loadProfiles(appState: appState)
                }
            }
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadProfiles(appState: appState)
        }
        .refreshable {
            await viewModel.loadProfiles(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilesDidChange)) { _ in
            Task {
                await viewModel.loadProfiles(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            Task {
                await viewModel.loadProfiles(appState: appState)
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .alert("Delete Profile", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                profileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    Task {
                        await viewModel.deleteProfile(id: profile.id, appState: appState)
                        profileToDelete = nil
                    }
                }
            }
        } message: {
            if let profile = profileToDelete {
                Text("Are you sure you want to delete \(profile.displayName)? This action cannot be undone.")
            }
        }
    }
}

// MARK: - Profile List Row
struct ProfileListRow: View {
    let profile: Profile
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            // Full card navigation link
            NavigationLink(destination: ProfileDetailView(profile: profile)) {
                HStack(spacing: 12) {
                    // Profile photo with optional deceased indicator
                    ZStack(alignment: .bottomTrailing) {
                        AsyncProfileImage(url: profile.photoUrl, size: 44)
                            .opacity(profile.isDeceased ? 0.7 : 1.0)

                        if profile.isDeceased {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                                .background(
                                    Circle()
                                        .fill(Color.cardBackground)
                                        .frame(width: 16, height: 16)
                                )
                                .offset(x: 2, y: 2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.fullName)
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)

                        HStack(spacing: 8) {
                            if let subtitle = profile.relationship {
                                Text(subtitle)
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                            }

                            if profile.isDeceased {
                                Text("In Memory")
                                    .font(.appCaption)
                                    .foregroundColor(.textMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.cardBackgroundLight.opacity(0.6))
                                    .cornerRadius(6)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    // Invisible spacer for delete button area
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .frame(maxWidth: .infinity)
                .padding(AppDimensions.cardPadding)
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Delete button - overlaid on top
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, AppDimensions.cardPadding)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile List Header
struct ProfileListHeaderView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "1a237e"),
                    Color(hex: "4a148c")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: AppDimensions.headerHeight)
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Back button
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Home")
                    }
                    .font(.appBodyMedium)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentYellow)
                    .cornerRadius(20)
                }
                
                Spacer()
                
                Text("Family and Friends")
                    .font(.appTitle)
                    .foregroundColor(.accentYellow)
            }
            .padding(AppDimensions.screenPadding)
        }
        .frame(height: AppDimensions.headerHeight)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .padding(.horizontal, AppDimensions.screenPadding)
    }
}

// MARK: - Profile List View Model
@MainActor
class ProfileListViewModel: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadProfiles(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            profiles = try await appState.profileRepository.getProfiles(accountId: account.id)
            // Filter out primary profile for family list
            profiles = profiles.filter { $0.type != .primary }
            // Sort alphabetically by first name (case-insensitive)
            profiles.sort { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    func deleteProfile(id: UUID, appState: AppState) async {
        do {
            try await appState.profileRepository.deleteProfile(id: id)
            profiles.removeAll { $0.id == id }
        } catch {
            self.error = "Failed to delete profile: \(error.localizedDescription)"
        }
    }
}

// MARK: - Profile Detail View
struct ProfileDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.iPadEditProfileAction) private var iPadEditProfileAction

    @State var profile: Profile
    var showHomeButton: Bool = false
    var homeAction: (() -> Void)? = nil
    @StateObject private var viewModel = ProfileDetailViewModel()
    @State private var showEditProfile = false
    @State private var showSettings = false

    /// Whether the current user has full access (owner or admin)
    private var hasFullAccess: Bool {
        appState.hasFullAccess
    }

    /// Whether the current user can edit
    private var canEdit: Bool {
        appState.canEdit
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header scrolls with content
                ProfileDetailHeaderView(
                    profile: profile,
                    showHomeButton: showHomeButton,
                    homeAction: homeAction,
                    onBack: { dismiss() },
                    onEdit: canEdit ? {
                        // Use full-screen overlay action if available
                        if let editAction = iPadEditProfileAction {
                            editAction(profile)
                        } else {
                            showEditProfile = true
                        }
                    } : nil
                )

                // Viewing As Bar (shown when viewing another account)
                ViewingAsBar()

                // Content - simplified for deceased profiles
                if profile.isDeceased {
                    deceasedProfileContent
                } else {
                    livingProfileContent
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackgroundLight)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sidePanel(isPresented: $showSettings) {
            SettingsPanelView(onDismiss: { showSettings = false })
        }
        .sidePanel(isPresented: $showEditProfile) {
            EditProfileView(profile: profile, onDismiss: { showEditProfile = false }) { updatedProfile in
                profile = updatedProfile
                showEditProfile = false
                Task {
                    await viewModel.loadDetails(profile: profile, appState: appState)
                }
            }
        }
        .task {
            await viewModel.loadDetails(profile: profile, appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilesDidChange)) { _ in
            // Reload the profile when it changes (e.g., after editing from iPad overlay)
            Task {
                if let updatedProfile = try? await appState.profileRepository.getProfile(id: profile.id) {
                    profile = updatedProfile
                    await viewModel.loadDetails(profile: profile, appState: appState)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDetailsDidChange)) { notification in
            // Reload details when profile details change (medical conditions, gift ideas, clothing sizes)
            if let profileId = notification.userInfo?["profileId"] as? UUID, profileId == profile.id {
                Task {
                    await viewModel.loadDetails(profile: profile, appState: appState)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .editPrimaryProfileRequested)) { _ in
            // Open edit sheet when requested (e.g., from onboarding completion)
            if profile.type == .primary && canEdit {
                if let editAction = iPadEditProfileAction {
                    editAction(profile)
                } else {
                    showEditProfile = true
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    // MARK: - Deceased Profile Content
    /// Simplified view for deceased profiles - shows only essential memorial information
    private var deceasedProfileContent: some View {
        VStack(spacing: AppDimensions.cardSpacing) {
            // Memorial indicator
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.textSecondary)

                Text("In Loving Memory")
                    .font(.appCardTitle)
                    .foregroundColor(.textSecondary)

                Spacer()
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .padding(.horizontal, AppDimensions.screenPadding)

            // Key Information for deceased
            VStack(alignment: .leading, spacing: AppDimensions.cardSpacing) {
                Text("MEMORIAL INFORMATION")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                VStack(spacing: AppDimensions.cardSpacing) {
                    // Relationship
                    if let relationship = profile.relationship {
                        DetailItemCard(label: "Relationship", value: relationship)
                    }

                    // Birthday with age at death
                    if let birthday = profile.birthday {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Birthday")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                Text(birthday.formattedBirthday())
                                    .font(.appCardTitle)
                                    .foregroundColor(.textPrimary)
                            }

                            Spacer()

                            if let ageAtDeath = profile.ageAtDeath {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(ageAtDeath)")
                                        .font(.appTitle)
                                        .foregroundColor(.textSecondary)
                                    Text("years old")
                                        .font(.appCaption)
                                        .foregroundColor(.textMuted)
                                }
                            }
                        }
                        .padding(AppDimensions.cardPadding)
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                    }

                    // Date of Death
                    if let deathDate = profile.dateOfDeath {
                        DetailItemCard(label: "Date of Passing", value: deathDate.formattedBirthday())
                    }

                    // Family Connection (for family tree)
                    if profile.includeInFamilyTree && profile.connectedToProfileId != nil {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Family Connection")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                Text("Included in Family Tree")
                                    .font(.appCardTitle)
                                    .foregroundColor(.textPrimary)
                            }

                            Spacer()

                            Image(systemName: "person.3.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(AppDimensions.cardPadding)
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                    }
                }
            }
            .padding(.horizontal, AppDimensions.screenPadding)

            // Bottom spacing for nav bar
            Spacer()
                .frame(height: 120)
        }
        .padding(.top, AppDimensions.cardSpacing)
    }

    // MARK: - Living Profile Content
    /// Full profile view with all categories and information
    private var livingProfileContent: some View {
        VStack(spacing: AppDimensions.cardSpacing) {
                // Category cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Medical
                        NavigationLink(destination: ProfileCategoryListView(
                            profile: profile,
                            category: .medical,
                            details: viewModel.medicalConditions + viewModel.allergies
                        )) {
                            CategoryCardView(
                                title: "Medical\nConditions",
                                iconName: "icon-medical"
                            )
                        }

                        // Gift Ideas (visible to all roles)
                        NavigationLink(destination: ProfileCategoryListView(
                            profile: profile,
                            category: .gifts,
                            details: viewModel.giftIdeas
                        )) {
                            CategoryCardView(
                                title: "Gift\nIdeas",
                                iconName: "icon-gifts"
                            )
                        }

                        // Clothing Sizes (visible to all roles)
                        NavigationLink(destination: ProfileCategoryListView(
                            profile: profile,
                            category: .clothing,
                            details: viewModel.clothingSizes
                        )) {
                            CategoryCardView(
                                title: "Clothing\nSizes",
                                iconName: "icon-clothing"
                            )
                        }

                        // Hobbies & Interests (visible to all roles)
                        NavigationLink(destination: SectionBasedCategoryView(
                            profile: profile,
                            category: .hobbies,
                            details: viewModel.hobbies
                        )) {
                            CategoryCardView(
                                title: "Hobbies &\nInterests",
                                iconName: "icon-hobbies"
                            )
                        }

                        // Activity Ideas (visible to all roles)
                        NavigationLink(destination: SectionBasedCategoryView(
                            profile: profile,
                            category: .activities,
                            details: viewModel.activityIdeas
                        )) {
                            CategoryCardView(
                                title: "Activity\nIdeas",
                                iconName: "icon-activities"
                            )
                        }

                        // Important Accounts (only for full access - contains sensitive info)
                        if hasFullAccess {
                            NavigationLink(destination: ImportantAccountsListView(profile: profile)) {
                                CategoryCardView(
                                    title: "Important\nAccounts",
                                    iconName: "icon-accounts"
                                )
                            }
                        }

                        // Family Tree (only for primary profile with full access)
                        if hasFullAccess && profile.type == .primary {
                            NavigationLink(destination: FamilyTreeView()) {
                                CategoryCardView(
                                    title: "Family\nTree",
                                    iconName: "icon-connections"
                                )
                            }
                        }

                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                }

                // Key Information
                VStack(alignment: .leading, spacing: AppDimensions.cardSpacing) {
                    Text("KEY INFORMATION")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    VStack(spacing: AppDimensions.cardSpacing) {
                        if let relationship = profile.relationship {
                            DetailItemCard(label: "Relationship", value: relationship)
                        }

                        if let address = profile.address {
                            DetailItemCard(label: "Address", value: address)
                        }

                        if let phone = profile.phone {
                            DetailItemCard(label: "Phone", value: phone)
                        }

                        if let email = profile.email {
                            DetailItemCard(label: "Email", value: email)
                        }

                        if let birthday = profile.birthday {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Birthday")
                                        .font(.appCaption)
                                        .foregroundColor(.textSecondary)

                                    Text(birthday.formattedBirthday())
                                        .font(.appCardTitle)
                                        .foregroundColor(.textPrimary)
                                }

                                Spacer()

                                if let age = profile.age {
                                    Text("\(age)")
                                        .font(.appTitle)
                                        .foregroundColor(.textSecondary)
                                }
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(Color.cardBackground)
                            .cornerRadius(AppDimensions.cardCornerRadius)
                        }

                        // Custom Fields (Additional Information)
                        ForEach(viewModel.customFields) { field in
                            DetailItemCard(label: field.label, value: field.value)
                        }
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)

                // Bottom spacing for nav bar
                Spacer()
                    .frame(height: 120)
        }
        .padding(.top, AppDimensions.cardSpacing)
    }
}

/// MARK: - Profile Detail Header
struct ProfileDetailHeaderView: View {
    let profile: Profile
    var showHomeButton: Bool = false
    var homeAction: (() -> Void)? = nil
    let onBack: () -> Void
    let onEdit: (() -> Void)?

    init(profile: Profile, showHomeButton: Bool = false, homeAction: (() -> Void)? = nil, onBack: @escaping () -> Void, onEdit: (() -> Void)? = nil) {
        self.profile = profile
        self.showHomeButton = showHomeButton
        self.homeAction = homeAction
        self.onBack = onBack
        self.onEdit = onEdit
    }

    var body: some View {
        CustomizableHeaderView(
            pageIdentifier: .profileDetail,
            title: profile.fullName,
            showBackButton: !showHomeButton,
            backAction: onBack,
            showHomeButton: showHomeButton,
            homeAction: homeAction,
            showEditButton: onEdit != nil,
            editAction: onEdit,
            editButtonPosition: .bottomRight
        )
        .overlay(alignment: .bottomLeading) {
            // Circular profile photo above the name
            if let photoUrl = profile.photoUrl, !photoUrl.isEmpty {
                AsyncProfileImage(url: photoUrl, size: 70)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .padding(.leading, AppDimensions.screenPadding)
                    .padding(.bottom, 70) // Position above the name text
            }
        }
    }
}

// MARK: - Category Card View (Liquid Glass Effect)
struct CategoryCardView: View {
    let title: String
    let iconName: String
    var systemIcon: Bool = false
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            // Center icon with subtle glow
            Group {
                if systemIcon {
                    Image(systemName: iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .foregroundColor(.white)
                } else {
                    Image(iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                }
            }
            .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 0)

            // Title - allows up to 2 lines
            Text(title)
                .font(.appBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(width: AppDimensions.categoryCardWidth, height: AppDimensions.categoryCardHeight)
        // Liquid glass background layers
        .background {
            ZStack {
                // Base frosted glass material
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    //.fill(.ultraThinMaterial)
                   .fill(Color.cardBackgroundLight.opacity(0.8))

                // Subtle color tint overlay
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                 .fill(Color.cardBackgroundLight.opacity(0.8))
                 //  .fill(appAccentColor.opacity(0.6))


                // Top-left light refraction highlight
         //       RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
         //           .fill(
         //               LinearGradient(
         //                   colors: [
         //                       Color.white.opacity(0.15),
         //                       Color.white.opacity(0.08),
         //                       Color.clear,
         //                       Color.clear
         //                   ],
         //                   startPoint: .topLeading,
         //                   endPoint: .bottomTrailing
         //               )
         //           )

                // Bottom-right subtle glow
        //      RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
        //        .fill(
        //                RadialGradient(
        //                    colors: [
        //                        .white.opacity(0.1),
        //                        Color.clear
        //                    ],
        //                    center: .bottomTrailing,
        //                    startRadius: 0,
        //                    endRadius: 120
        //                )
        //            )
            }
        }
        // Multi-layer border for liquid glass depth
    //    .overlay(
    //        RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
    //            .stroke(
    //                LinearGradient(
    //                    colors: [
    //                        Color.white.opacity(0.5),
    //                        Color.white.opacity(0.2),
    //                        Color.white.opacity(0.05),
    //                        Color.white.opacity(0.15)
    //                    ],
    //                    startPoint: .topLeading,
    //                    endPoint: .bottomTrailing
    //                ),
    //                lineWidth: 1
    //            )
    //    )
        // Inner glow effect
    //    .overlay(
    //        RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius - 1)
    //            .stroke(Color.white.opacity(0.1), lineWidth: 1)
    //            .padding(1)
    //    )
        // Soft outer shadow for depth
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .shadow(color: appAccentColor.opacity(0.1), radius: 15, x: 0, y: 0)
    }
}

// MARK: - Profile Detail View Model
@MainActor
class ProfileDetailViewModel: ObservableObject {
    @Published var clothingSizes: [ProfileDetail] = []
    @Published var giftIdeas: [ProfileDetail] = []
    @Published var medicalConditions: [ProfileDetail] = []
    @Published var allergies: [ProfileDetail] = []
    @Published var customFields: [ProfileDetail] = []
    @Published var hobbies: [ProfileDetail] = []
    @Published var activityIdeas: [ProfileDetail] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadDetails(profile: Profile, appState: AppState) async {
        isLoading = true

        do {
            let allDetails = try await appState.profileRepository.getProfileDetails(profileId: profile.id)

            clothingSizes = allDetails.filter { $0.category == .clothing }
            giftIdeas = allDetails.filter { $0.category == .giftIdea }
            medicalConditions = allDetails.filter { $0.category == .medicalCondition }
            allergies = allDetails.filter { $0.category == .allergy }
            customFields = allDetails.filter { $0.category == .note }
            hobbies = allDetails.filter { $0.category == .hobby }
            activityIdeas = allDetails.filter { $0.category == .activityIdea }
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - My Card View (Primary Profile)
struct MyCardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = MyCardViewModel()
    @Environment(\.dismiss) var dismiss
    @Environment(\.iPadHomeAction) private var iPadHomeAction

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            if let profile = viewModel.primaryProfile {
                ProfileDetailView(profile: profile, showHomeButton: iPadHomeAction != nil, homeAction: iPadHomeAction)
            } else if viewModel.isLoading {
                LoadingView()
            } else {
                EmptyStateView(
                    icon: "person.circle",
                    title: "No profile found",
                    message: "Your primary profile hasn't been set up yet."
                )
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadPrimaryProfile(appState: appState)
        }
    }
}

@MainActor
class MyCardViewModel: ObservableObject {
    @Published var primaryProfile: Profile?
    @Published var isLoading = false
    
    func loadPrimaryProfile(appState: AppState) async {
        guard let account = appState.currentAccount else { return }
        
        isLoading = true
        
        do {
            primaryProfile = try await appState.profileRepository.getPrimaryProfile(accountId: account.id)
        } catch {
            #if DEBUG
            print("Error loading primary profile: \(error)")
            #endif
        }
        
        isLoading = false
    }
}

// MARK: - Preview
#Preview("Profile List") {
    NavigationStack {
        ProfileListView()
            .environmentObject(AppState.forPreview())
    }
}
