import SwiftUI

// MARK: - Profile List View (Family and Friends)
struct ProfileListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.iPadAddProfileAction) private var iPadAddProfileAction

    @StateObject private var viewModel = ProfileListViewModel()
    @State private var showAddProfile = false
    @State private var showUpgradePrompt = false
    @State private var profileToDelete: Profile?
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""
    @State private var listContentHeight: CGFloat = 0

    /// Check if user can add more friend profiles
    private var canAddProfile: Bool {
        PremiumLimitsManager.shared.canCreateFriendProfile(
            appState: appState,
            currentCount: viewModel.profiles.count
        )
    }

    private var filteredProfiles: [Profile] {
        let base = viewModel.profiles
        if searchText.isEmpty {
            return base
        }
        return base.filter { profile in
            profile.displayName.localizedCaseInsensitiveContains(searchText) ||
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
                            // On iPad, use the environment action to trigger the root-level panel
                            if let iPadAddAction = iPadAddProfileAction {
                                iPadAddAction()
                            } else {
                                // On iPhone, use local state
                                if canAddProfile {
                                    showAddProfile = true
                                } else {
                                    showUpgradePrompt = true
                                }
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

                        // Profile list with swipe-to-delete
                        if !filteredProfiles.isEmpty {
                            List {
                                ForEach(filteredProfiles) { profile in
                                    ZStack {
                                        NavigationLink(destination: ProfileDetailView(profile: profile)) {
                                            EmptyView()
                                        }
                                        .opacity(0)

                                        ProfileListRow(
                                            profile: profile,
                                            isPinned: viewModel.isPinned(profile.id),
                                            onTogglePin: { viewModel.togglePin(profile.id) }
                                        )
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        if appState.canEdit {
                                            Button(role: .destructive) {
                                                profileToDelete = profile
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
                            .frame(height: listContentHeight)
                            .onChange(of: filteredProfiles.count) { _, count in
                                let rowHeight: CGFloat = 76
                                let spacing: CGFloat = AppDimensions.cardSpacing
                                listContentHeight = CGFloat(count) * (rowHeight + spacing)
                            }
                            .onAppear {
                                let rowHeight: CGFloat = 76
                                let spacing: CGFloat = AppDimensions.cardSpacing
                                listContentHeight = CGFloat(filteredProfiles.count) * (rowHeight + spacing)
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
                                    // On iPad, use the environment action to trigger the root-level panel
                                    if let iPadAddAction = iPadAddProfileAction {
                                        iPadAddAction()
                                    } else {
                                        // On iPhone, use local state
                                        if canAddProfile {
                                            showAddProfile = true
                                        } else {
                                            showUpgradePrompt = true
                                        }
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
        // Only show sidePanel on iPhone - iPad handles this at iPadRootView level
        .sidePanel(isPresented: iPadHomeAction == nil ? $showAddProfile : .constant(false)) {
            AddProfileView { _ in
                // Profile was saved - post notification to trigger a single authoritative reload
                // The .profilesDidChange handler will do a force-refresh from the server
                NotificationCenter.default.post(name: .profilesDidChange, object: nil)
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
                // Force refresh from network to get synced profile updates
                await viewModel.loadProfiles(appState: appState, forceRefresh: true)
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
    var isPinned: Bool = false
    var onTogglePin: (() -> Void)? = nil

    var body: some View {
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
                Text(profile.displayName)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)

                HStack(spacing: 8) {
                    if profile.isSyncedProfile {
                        Text("Connected")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.accentYellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentYellow.opacity(0.15))
                            .cornerRadius(4)
                    }

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

            Spacer()

            // Pin button
            if let onTogglePin = onTogglePin {
                Button {
                    onTogglePin()
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 16))
                        .foregroundColor(isPinned ? .accentYellow : .textSecondary)
                        .rotationEffect(.degrees(45))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
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
    @Published var pinnedProfileIds: Set<UUID> = []
    @Published var isLoading = false
    @Published var error: String?

    private let pinnedProfilesKey = "pinned_profile_ids"

    init() {
        loadPinnedIds()
    }

    // MARK: - Pinned Profiles

    func isPinned(_ profileId: UUID) -> Bool {
        pinnedProfileIds.contains(profileId)
    }

    func togglePin(_ profileId: UUID) {
        if pinnedProfileIds.contains(profileId) {
            pinnedProfileIds.remove(profileId)
        } else {
            pinnedProfileIds.insert(profileId)
        }
        savePinnedIds()
        sortProfiles()
    }

    private func loadPinnedIds() {
        if let strings = UserDefaults.standard.stringArray(forKey: pinnedProfilesKey) {
            pinnedProfileIds = Set(strings.compactMap { UUID(uuidString: $0) })
        }
    }

    private func savePinnedIds() {
        let strings = pinnedProfileIds.map { $0.uuidString }
        UserDefaults.standard.set(strings, forKey: pinnedProfilesKey)
    }

    private func sortProfiles() {
        profiles.sort { a, b in
            let aPinned = pinnedProfileIds.contains(a.id)
            let bPinned = pinnedProfileIds.contains(b.id)
            if aPinned != bPinned {
                return aPinned
            }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    private var loadTask: Task<Void, Never>?

    func loadProfiles(appState: AppState, forceRefresh: Bool = false) async {
        guard let account = appState.currentAccount else { return }

        // Cancel any in-progress load to prevent overlapping fetches that can cause duplicates
        loadTask?.cancel()

        let task = Task {
            isLoading = true

            do {
                try Task.checkCancellation()

                // Use refreshProfiles when force refresh is requested (e.g., from realtime notification)
                var loaded: [Profile]
                if forceRefresh {
                    loaded = try await appState.profileRepository.refreshProfiles(accountId: account.id)
                } else {
                    loaded = try await appState.profileRepository.getProfiles(accountId: account.id)
                }

                try Task.checkCancellation()

                #if DEBUG
                print("📋 ProfileListViewModel: Loaded \(loaded.count) profiles for account \(account.id) (forceRefresh: \(forceRefresh))")
                for profile in loaded {
                    print("📋   - [\(profile.id.uuidString)] \(profile.fullName): type=\(profile.type.rawValue), sourceUserId=\(profile.sourceUserId?.uuidString ?? "nil"), isLocalOnly=\(profile.isLocalOnly), isSyncedProfile=\(profile.isSyncedProfile)")
                }
                #endif

                // Filter out primary profile for family list
                loaded = loaded.filter { $0.type != .primary }

                // Deduplicate by profile ID (keep first occurrence)
                var seenIds = Set<UUID>()
                loaded = loaded.filter { profile in
                    if seenIds.contains(profile.id) {
                        return false
                    }
                    seenIds.insert(profile.id)
                    return true
                }

                profiles = loaded
                // Sort with pinned profiles first, then alphabetically
                sortProfiles()
            } catch {
                if !error.isCancellation {
                    self.error = error.localizedDescription
                }
            }

            isLoading = false
        }
        loadTask = task
        await task.value
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
    var isOwnProfile: Bool = false
    @StateObject private var viewModel = ProfileDetailViewModel()
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showInviteMember = false
    @State private var inviteEmail: String = ""
    @State private var showUpgradePrompt = false
    @State private var showSharingPreferences = false
    @State private var syncedDetailIds: Set<UUID> = []
    @State private var hasActiveSyncConnections = false
    @State private var sharingPreferences: [SharingCategoryKey: Bool] = [:]
    @State private var isSharingLoading = false
    @State private var syncedProfileSharingPrefs: [SharingCategoryKey: Bool] = [:]
    @Environment(\.appAccentColor) private var appAccentColor

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
        .sidePanel(isPresented: $showInviteMember) {
            InviteShareView(profileEmail: inviteEmail, onDismiss: { showInviteMember = false })
        }
        .sidePanel(isPresented: $showSharingPreferences) {
            SharingPreferencesView(profile: profile, onDismiss: { showSharingPreferences = false })
        }
        .task {
            await viewModel.loadDetails(profile: profile, appState: appState, forceRefresh: true)
            // Load synced detail IDs if this is a synced profile
            if profile.isSyncedProfile {
                do {
                    syncedDetailIds = try await appState.profileSyncRepository.getSyncedDetailIds(for: profile.id)
                } catch {
                    #if DEBUG
                    print("Error loading synced detail IDs: \(error)")
                    #endif
                }
            }
            // Load sharing preferences if viewing own profile
            if isOwnProfile {
                await loadSharingPreferences()
            }
            // Load sharing preferences for synced profiles to gate category visibility
            if profile.isSyncedProfile {
                await loadSyncedProfileSharingPreferences()
            }
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
                await viewModel.loadDetails(profile: profile, appState: appState, forceRefresh: isRemoteSync)
                // Reload synced detail IDs if this is a synced profile
                if profile.isSyncedProfile {
                    do {
                        syncedDetailIds = try await appState.profileSyncRepository.getSyncedDetailIds(for: profile.id)
                    } catch {
                        #if DEBUG
                        print("Error reloading synced detail IDs: \(error)")
                        #endif
                    }
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
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
        }
    }

    // MARK: - Sharing Preferences Helpers

    /// Whether a category card should be visible. For own profiles and non-synced profiles,
    /// all categories are visible. For synced profiles, categories are only visible if the
    /// source user has sharing enabled for that category.
    /// Important Accounts additionally requires full access for non-synced profiles.
    private func isCategoryVisible(_ category: SharingCategoryKey) -> Bool {
        if category == .importantAccounts {
            // Important Accounts requires full access OR synced profile with sharing enabled
            if !profile.isSyncedProfile {
                return hasFullAccess
            }
            return syncedProfileSharingPrefs[category] ?? true
        }
        // For non-synced profiles, all other categories are always visible
        if !profile.isSyncedProfile {
            return true
        }
        // For synced profiles, check sharing preferences
        return syncedProfileSharingPrefs[category] ?? true
    }

    private func loadSharingPreferences() async {
        do {
            let prefs = try await appState.profileSharingPreferencesRepository.getPreferences(profileId: profile.id)
            var dict: [SharingCategoryKey: Bool] = [:]
            // Default all to true
            for key in SharingCategoryKey.allCases {
                dict[key] = true
            }
            // Override with stored values
            for pref in prefs {
                if let key = SharingCategoryKey(rawValue: pref.category) {
                    dict[key] = pref.isShared
                }
            }
            sharingPreferences = dict

            // Check if user has active sync connections
            if let userId = await SupabaseManager.shared.currentUserId {
                let syncs = try await appState.profileSyncRepository.getSyncsForUser(userId: userId)
                hasActiveSyncConnections = !syncs.isEmpty
            }
        } catch {
            #if DEBUG
            print("Error loading sharing preferences: \(error)")
            #endif
        }
    }

    private func toggleSharingPreference(category: SharingCategoryKey, newValue: Bool) {
        // Optimistic update
        sharingPreferences[category] = newValue
        isSharingLoading = true

        Task {
            do {
                try await appState.profileSharingPreferencesRepository.updatePreference(
                    profileId: profile.id,
                    category: category,
                    isShared: newValue
                )
                NotificationCenter.default.post(
                    name: .profileSharingPreferencesDidChange,
                    object: nil,
                    userInfo: ["profileId": profile.id, "category": category.rawValue]
                )
            } catch {
                // Revert on failure
                sharingPreferences[category] = !newValue
                #if DEBUG
                print("Error updating sharing preference: \(error)")
                #endif
            }
            isSharingLoading = false
        }
    }

    private func loadSyncedProfileSharingPreferences() async {
        do {
            guard let currentUserId = await SupabaseManager.shared.currentUserId else { return }

            // Find the source profile ID via the sync connection
            var sourceProfileId: UUID?
            if let syncConnectionId = profile.syncConnectionId,
               let sync = try await appState.profileSyncRepository.getSyncById(id: syncConnectionId) {
                // Determine which side is the source: the other user's source profile
                if sync.acceptorSyncedProfileId == profile.id {
                    sourceProfileId = sync.inviterSourceProfileId
                } else if sync.inviterSyncedProfileId == profile.id {
                    sourceProfileId = sync.acceptorSourceProfileId
                }
            }

            guard let sourceId = sourceProfileId else { return }

            let prefs = try await appState.profileSharingPreferencesRepository.getPreferences(
                profileId: sourceId,
                targetUserId: currentUserId
            )
            var dict: [SharingCategoryKey: Bool] = [:]
            // Default all to true (shared by default)
            for key in SharingCategoryKey.allCases {
                dict[key] = true
            }
            // Override with stored values
            for pref in prefs {
                if let key = SharingCategoryKey(rawValue: pref.category) {
                    dict[key] = pref.isShared
                }
            }
            syncedProfileSharingPrefs = dict
        } catch {
            #if DEBUG
            print("Error loading synced profile sharing preferences: \(error)")
            #endif
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
                    // Relationship (hidden for own profile)
                    if let relationship = profile.relationship, !isOwnProfile {
                        DetailItemCard(label: "Relationship", value: relationship)
                    }

                    // Birthday with age at death
                    if let birthday = profile.birthday {
                        ProfileBirthdayCard(
                            birthday: birthday,
                            age: profile.ageAtDeath,
                            isSynced: profile.isFieldSynced("birthday"),
                            sourceName: profile.isSyncedProfile ? profile.displayName : nil
                        )
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
                        // Medical (hidden for synced profiles if sharing is off)
                        if isCategoryVisible(.medical) {
                            NavigationLink(destination: ProfileCategoryListView(
                                profile: profile,
                                category: .medical,
                                details: viewModel.medicalConditions + viewModel.allergies,
                                isOwnProfile: isOwnProfile
                            )) {
                                CategoryCardView(
                                    title: "Medical\nConditions",
                                    iconName: "icon-medical",
                                    hasContent: !(viewModel.medicalConditions + viewModel.allergies).isEmpty
                                )
                            }
                        }

                        // Gift Ideas
                        if isCategoryVisible(.giftIdea) {
                            NavigationLink(destination: ProfileCategoryListView(
                                profile: profile,
                                category: .gifts,
                                details: viewModel.giftIdeas,
                                isOwnProfile: isOwnProfile
                            )) {
                                CategoryCardView(
                                    title: "Gift\nIdeas",
                                    iconName: "icon-gifts",
                                    hasContent: !viewModel.giftIdeas.isEmpty
                                )
                            }
                        }

                        // Clothing Sizes
                        if isCategoryVisible(.clothing) {
                            NavigationLink(destination: ProfileCategoryListView(
                                profile: profile,
                                category: .clothing,
                                details: viewModel.clothingSizes,
                                isOwnProfile: isOwnProfile
                            )) {
                                CategoryCardView(
                                    title: "Clothing\nSizes",
                                    iconName: "icon-clothing",
                                    hasContent: !viewModel.clothingSizes.isEmpty
                                )
                            }
                        }

                        // Hobbies & Interests
                        if isCategoryVisible(.hobby) {
                            NavigationLink(destination: SectionBasedCategoryView(
                                profile: profile,
                                category: .hobbies,
                                details: viewModel.hobbies,
                                isOwnProfile: isOwnProfile
                            )) {
                                CategoryCardView(
                                    title: "Hobbies &\nInterests",
                                    iconName: "icon-hobbies",
                                    hasContent: !viewModel.hobbies.isEmpty
                                )
                            }
                        }

                        // Activity Ideas
                        if isCategoryVisible(.activityIdea) {
                            NavigationLink(destination: SectionBasedCategoryView(
                                profile: profile,
                                category: .activities,
                                details: viewModel.activityIdeas,
                                isOwnProfile: isOwnProfile
                            )) {
                                CategoryCardView(
                                    title: "Activity\nIdeas",
                                    iconName: "icon-activities",
                                    hasContent: !viewModel.activityIdeas.isEmpty
                                )
                            }
                        }

                        // Important Accounts (full access or synced profile with sharing enabled)
                        if isCategoryVisible(.importantAccounts) {
                            NavigationLink(destination: ImportantAccountsListView(profile: profile)) {
                                CategoryCardView(
                                    title: "Important\nAccounts",
                                    iconName: "icon-accounts",
                                    hasContent: viewModel.hasImportantAccounts
                                )
                            }
                        }

                        // Family Tree (only for primary profile with full access)
                        if hasFullAccess && profile.type == .primary {
                            NavigationLink(destination: FamilyTreeView()) {
                                CategoryCardView(
                                    title: "Family\nTree",
                                    iconName: "icon-connections",
                                    hasContent: true
                                )
                            }
                        }

                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                }

                // Sharing Preferences card (only for synced/connected profiles)
                if profile.isSyncedProfile {
                    Button(action: { showSharingPreferences = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.badge.shield.checkmark")
                                .font(.system(size: 20))
                                .foregroundColor(appAccentColor)
                                .frame(width: 40, height: 40)
                                .background(appAccentColor.opacity(0.15))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sharing Preferences")
                                    .font(.appCardTitle)
                                    .foregroundColor(.textPrimary)

                                Text("Control what \(profile.displayName) can see")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(AppDimensions.cardPadding)
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, AppDimensions.screenPadding)
                }

                // Key Information
                VStack(alignment: .leading, spacing: AppDimensions.cardSpacing) {
                    Text("KEY INFORMATION")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    VStack(spacing: AppDimensions.cardSpacing) {
                        if let relationship = profile.relationship, !isOwnProfile {
                            DetailItemCard(label: "Relationship", value: relationship)
                        }

                        if let address = profile.address {
                            DetailItemCard(
                                label: "Address",
                                value: address,
                                isSynced: profile.isFieldSynced("address"),
                                sourceName: profile.isSyncedProfile ? profile.displayName : nil
                            )
                        }

                        if let phone = profile.phone {
                            DetailItemCard(
                                label: "Phone",
                                value: phone,
                                isSynced: profile.isFieldSynced("phone"),
                                sourceName: profile.isSyncedProfile ? profile.displayName : nil
                            )
                        }

                        if let email = profile.email {
                            EmailCardWithInvite(
                                email: email,
                                isSynced: profile.isFieldSynced("email"),
                                sourceName: profile.isSyncedProfile ? profile.displayName : nil,
                                showInviteButton: !profile.isSyncedProfile && !isOwnProfile,
                                canInvite: appState.currentUserRole?.canManageMembers == true,
                                onInvite: {
                                    inviteEmail = email
                                    showInviteMember = true
                                }
                            )
                        }

                        if let birthday = profile.birthday {
                            ProfileBirthdayCard(
                                birthday: birthday,
                                age: profile.age,
                                isSynced: profile.isFieldSynced("birthday"),
                                sourceName: profile.isSyncedProfile ? profile.displayName : nil
                            )
                        }

                        // Custom Fields (Additional Information)
                        ForEach(viewModel.customFields) { field in
                            DetailItemCard(
                                label: field.label,
                                value: field.value,
                                isSynced: syncedDetailIds.contains(field.id),
                                sourceName: syncedDetailIds.contains(field.id) ? profile.displayName : nil
                            )
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
        .overlay(alignment: .bottomLeading) {
            // "Connected" tag for synced profiles - only show when profile has a photo
            // (when no photo is set, the header area is kept clean)
            if profile.isSyncedProfile,
               let photoUrl = profile.photoUrl, !photoUrl.isEmpty {
                Text("Connected")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentYellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentYellow.opacity(0.2))
                    .cornerRadius(6)
                    .padding(.leading, AppDimensions.screenPadding)
                    .padding(.bottom, 52) // Position above the name text
            }
        }
    }
}

// MARK: - Email Card With Invite Button
/// A detail card for email that optionally shows an "Invite" button
struct EmailCardWithInvite: View {
    let email: String
    let isSynced: Bool
    let sourceName: String?
    let showInviteButton: Bool
    let canInvite: Bool
    let onInvite: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor

    init(
        email: String,
        isSynced: Bool = false,
        sourceName: String? = nil,
        showInviteButton: Bool,
        canInvite: Bool,
        onInvite: @escaping () -> Void
    ) {
        self.email = email
        self.isSynced = isSynced
        self.sourceName = sourceName
        self.showInviteButton = showInviteButton
        self.canInvite = canInvite
        self.onInvite = onInvite
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Email")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    if isSynced, let name = sourceName {
                        SyncIndicator(sourceName: name)
                    }
                }

                Text(email)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            if showInviteButton && canInvite {
                Button(action: onInvite) {
                    Text("Invite")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(appAccentColor)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Profile Birthday Card
/// A detail card for birthday on profile detail view with optional sync indicator and age display
struct ProfileBirthdayCard: View {
    let birthday: Date
    let age: Int?
    let isSynced: Bool
    let sourceName: String?

    init(
        birthday: Date,
        age: Int? = nil,
        isSynced: Bool = false,
        sourceName: String? = nil
    ) {
        self.birthday = birthday
        self.age = age
        self.isSynced = isSynced
        self.sourceName = sourceName
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Birthday")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    if isSynced, let name = sourceName {
                        SyncIndicator(sourceName: name)
                    }
                }

                Text(birthday.formattedBirthday())
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            if let age = age {
                Text("\(age)")
                    .font(.appTitle)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Category Card View (Liquid Glass Effect)
struct CategoryCardView: View {
    let title: String
    let iconName: String
    var systemIcon: Bool = false
    var hasContent: Bool = false
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
                .foregroundColor(.white)
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
                   .fill(hasContent ? appAccentColor.opacity(0.6) : Color.cardBackgroundLight.opacity(0.8))

                // Subtle color tint overlay
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                 .fill(hasContent ? appAccentColor.opacity(0.3) : Color.cardBackgroundLight.opacity(0.8))


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
    @Published var hasImportantAccounts: Bool = false
    @Published var isLoading = false
    @Published var error: String?

    func loadDetails(profile: Profile, appState: AppState, forceRefresh: Bool = false) async {
        isLoading = true

        do {
            let allDetails: [ProfileDetail]
            if forceRefresh {
                allDetails = try await appState.profileRepository.refreshProfileDetails(profileId: profile.id)
            } else {
                allDetails = try await appState.profileRepository.getProfileDetails(profileId: profile.id)
            }

            clothingSizes = allDetails.filter { $0.category == .clothing }
            giftIdeas = allDetails.filter { $0.category == .giftIdea }
            medicalConditions = allDetails.filter { $0.category == .medicalCondition }
            allergies = allDetails.filter { $0.category == .allergy }
            customFields = allDetails.filter { $0.category == .note }
            hobbies = allDetails.filter { $0.category == .hobby }
            activityIdeas = allDetails.filter { $0.category == .activityIdea }

            // Check if important accounts exist
            let accounts: [ImportantAccount]
            if profile.isSyncedProfile {
                accounts = try await appState.importantAccountRepository.getSharedAccounts(syncedProfileId: profile.id)
            } else {
                accounts = try await appState.importantAccountRepository.getAccounts(profileId: profile.id)
            }
            hasImportantAccounts = !accounts.isEmpty
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
                ProfileDetailView(profile: profile, showHomeButton: iPadHomeAction != nil, homeAction: iPadHomeAction, isOwnProfile: true)
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
