import SwiftUI
import SwiftData
import UIKit
import UserNotifications

// MARK: - App Delegate for Orientation Lock and Notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait  // Lock to portrait only
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Set up notification center delegate early
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        return true
    }
}

@main
struct UnforgottenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var userPreferences = UserPreferences()
    @State private var headerOverrides = UserHeaderOverrides()
    @State private var headerStyleManager = HeaderStyleManager()
    @State private var featureVisibility = FeatureVisibilityManager()
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Local Storage
    private let localStorageContainer: ModelContainer
    @StateObject private var appState: AppState

    init() {
        // Initialize the local storage container
        let container: ModelContainer
        do {
            container = try LocalStorageContainer.create()
        } catch {
            fatalError("Failed to create local storage container: \(error)")
        }
        self.localStorageContainer = container

        // Initialize AppState with the model context
        let context = ModelContext(container)
        _appState = StateObject(wrappedValue: AppState(modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                userPreferences: userPreferences,
                headerOverrides: headerOverrides,
                headerStyleManager: headerStyleManager,
                featureVisibility: featureVisibility
            )
            .environmentObject(appState)
            .task {
                // Configure sync service with manager references
                await MainActor.run {
                    PreferencesSyncService.shared.configure(
                        userPreferences: userPreferences,
                        headerStyleManager: headerStyleManager,
                        featureVisibilityManager: featureVisibility
                    )
                }
            }
            .onChange(of: appState.currentAccount) { _, newAccount in
                // When account changes, load preferences from Supabase
                Task {
                    await loadPreferencesForAccount(newAccount)
                }
            }
            .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
                // Clear IDs when signing out
                if !isAuthenticated {
                    userPreferences.currentUserId = nil
                    userPreferences.currentAccountId = nil
                    headerStyleManager.currentUserId = nil
                    headerStyleManager.currentAccountId = nil
                    featureVisibility.currentUserId = nil
                    featureVisibility.currentAccountId = nil
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // App became active - check for pending notification navigation
                    #if DEBUG
                    print("📱 App became active, checking pending notifications")
                    #endif

                    // Re-sync sticky reminders to catch any changes while app was inactive
                    // This ensures notifications are scheduled on this device even if it
                    // wasn't running when a reminder was created on another device
                    Task {
                        await appState.syncStickyReminderNotifications()
                    }

                    // Refresh data from server when app becomes active
                    // This catches any changes made on other devices
                    Task {
                        await appState.refreshDataFromRemote()
                    }
                }
            }
        }
    }

    /// Load preferences from Supabase when account changes
    private func loadPreferencesForAccount(_ account: Account?) async {
        guard let account = account,
              let userId = await SupabaseManager.shared.currentUserId else {
            return
        }

        // Set user/account IDs on managers for syncing
        await MainActor.run {
            userPreferences.currentUserId = userId
            userPreferences.currentAccountId = account.id
            headerStyleManager.currentUserId = userId
            headerStyleManager.currentAccountId = account.id
            featureVisibility.currentUserId = userId
            featureVisibility.currentAccountId = account.id
        }

        // Load preferences from Supabase
        await PreferencesSyncService.shared.loadFromRemote(userId: userId, accountId: account.id)
    }
}

// MARK: - App Root View
/// Wrapper view that observes UserPreferences and HeaderStyleManager to update tint color reactively
struct AppRootView: View {
    @Bindable var userPreferences: UserPreferences
    var headerOverrides: UserHeaderOverrides
    @Bindable var headerStyleManager: HeaderStyleManager
    var featureVisibility: FeatureVisibilityManager

    /// The effective accent color based on whether user has a custom color or uses style default
    var effectiveAccentColor: Color {
        if userPreferences.hasCustomAccentColor {
            return userPreferences.accentColor
        } else {
            return headerStyleManager.defaultAccentColor
        }
    }

    var body: some View {
        RootView()
            .environment(userPreferences)
            .environment(headerOverrides)
            .environment(headerStyleManager)
            .environment(featureVisibility)
            .environment(\.appAccentColor, effectiveAccentColor)
            .tint(effectiveAccentColor)
            .preferredColorScheme(.dark)
    }
}

// MARK: - App State
@MainActor
final class AppState: ObservableObject {
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var currentAccount: Account?
    @Published var currentUserRole: MemberRole?
    @Published var showMoodPrompt = false
    @Published var hasCompletedOnboarding = false

    // MARK: - Multi-Account Support
    @Published var allAccounts: [AccountWithRole] = []
    @Published var isViewingOtherAccount: Bool = false

    /// The user's own account (where they are the owner)
    var ownedAccount: AccountWithRole? {
        allAccounts.first { $0.isOwner }
    }

    /// Current account with role information
    var currentAccountWithRole: AccountWithRole? {
        guard let currentAccount = currentAccount else { return nil }
        return allAccounts.first { $0.account.id == currentAccount.id }
    }

    /// Whether the current role has full access (owner or admin)
    var hasFullAccess: Bool {
        currentUserRole == .owner || currentUserRole == .admin
    }

    /// Whether the current role can edit data (owner, admin, or helper)
    var canEdit: Bool {
        currentUserRole?.canWrite ?? false
    }

    // MARK: - Navigation State (for deep linking from notifications)
    @Published var pendingAppointmentId: UUID?
    @Published var pendingProfileId: UUID?
    @Published var pendingStickyReminderId: UUID?

    // MARK: - Post-Onboarding Navigation
    @Published var pendingOnboardingAction: OnboardingFirstAction?

    // MARK: - Local Storage & Sync
    private let modelContext: ModelContext
    let syncEngine: SyncEngine

    // MARK: - Remote Repositories (for operations not cached locally)
    let authRepository = AuthRepository()
    let accountRepository = AccountRepository()
    let invitationRepository = InvitationRepository()
    let appUserRepository = AppUserRepository()
    let familyCalendarRepository = FamilyCalendarRepository()
    let profileSyncRepository = ProfileSyncRepository()

    // MARK: - Cached Repositories (offline-first)
    let cachedProfileRepository: CachedProfileRepository
    let cachedMedicationRepository: CachedMedicationRepository
    let cachedAppointmentRepository: CachedAppointmentRepository
    let cachedUsefulContactRepository: CachedUsefulContactRepository
    let cachedMoodRepository: CachedMoodRepository
    let cachedToDoRepository: CachedToDoRepository
    let cachedImportantAccountRepository: CachedImportantAccountRepository
    let cachedStickyReminderRepository: CachedStickyReminderRepository
    let cachedCountdownRepository: CachedCountdownRepository

    // MARK: - Legacy Repository Access (for backward compatibility)
    // These provide access to cached repositories through the old property names
    var profileRepository: CachedProfileRepository { cachedProfileRepository }
    var medicationRepository: CachedMedicationRepository { cachedMedicationRepository }
    var appointmentRepository: CachedAppointmentRepository { cachedAppointmentRepository }
    var usefulContactRepository: CachedUsefulContactRepository { cachedUsefulContactRepository }
    var moodRepository: CachedMoodRepository { cachedMoodRepository }
    var toDoRepository: CachedToDoRepository { cachedToDoRepository }
    var importantAccountRepository: CachedImportantAccountRepository { cachedImportantAccountRepository }
    var stickyReminderRepository: CachedStickyReminderRepository { cachedStickyReminderRepository }
    var countdownRepository: CachedCountdownRepository { cachedCountdownRepository }
    // Note: Notes feature uses its own SwiftData container (see Features/Notes/)

    // MARK: - App Admin State
    @Published var isAppAdmin = false
    @Published var currentAppUser: AppUser?

    // MARK: - UserDefaults Keys
    private let selectedAccountIdKey = "selectedAccountId"
    private let subscriptionTierKey = "user_subscription_tier"
    private let legacyPremiumKey = "user_has_premium" // For migration from old system

    // MARK: - Subscription Tier

    /// The user's current subscription tier
    var subscriptionTier: SubscriptionTier {
        // Check for complimentary access first (grants Family Plus)
        if currentAppUser?.hasComplimentaryAccess == true {
            return .familyPlus
        }

        // Check stored subscription tier
        if let tierString = UserDefaults.standard.string(forKey: subscriptionTierKey),
           let tier = SubscriptionTier(rawValue: tierString) {
            return tier
        }

        // Migration: Check legacy premium key for users upgrading from old system
        if UserDefaults.standard.bool(forKey: legacyPremiumKey) {
            // Assume old premium users get Premium tier (not Family Plus)
            return .premium
        }

        return .free
    }

    /// Whether the current user has premium access (Premium or Family Plus tier)
    var hasPremiumAccess: Bool {
        return subscriptionTier.hasPremiumFeatures
    }

    /// Whether the current user has Family Plus access
    var hasFamilyAccess: Bool {
        return subscriptionTier.hasFamilyFeatures
    }

    /// Update the user's subscription tier (called after successful purchase)
    func setSubscriptionTier(_ tier: SubscriptionTier) {
        UserDefaults.standard.set(tier.rawValue, forKey: subscriptionTierKey)
        // Clear legacy key if present
        UserDefaults.standard.removeObject(forKey: legacyPremiumKey)
        objectWillChange.send()
    }

    // MARK: - Initialization
    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Initialize sync engine
        let syncEngine = SyncEngine(modelContext: modelContext)
        self.syncEngine = syncEngine

        // Initialize cached repositories
        self.cachedProfileRepository = CachedProfileRepository(
            modelContext: modelContext,
            remoteRepository: ProfileRepository(),
            syncEngine: syncEngine
        )
        self.cachedMedicationRepository = CachedMedicationRepository(
            modelContext: modelContext,
            remoteRepository: MedicationRepository(),
            syncEngine: syncEngine
        )
        self.cachedAppointmentRepository = CachedAppointmentRepository(
            modelContext: modelContext,
            remoteRepository: AppointmentRepository(),
            syncEngine: syncEngine
        )
        self.cachedUsefulContactRepository = CachedUsefulContactRepository(
            modelContext: modelContext,
            remoteRepository: UsefulContactRepository(),
            syncEngine: syncEngine
        )
        self.cachedMoodRepository = CachedMoodRepository(
            modelContext: modelContext,
            remoteRepository: MoodRepository(),
            syncEngine: syncEngine
        )
        self.cachedToDoRepository = CachedToDoRepository(
            modelContext: modelContext,
            remoteRepository: ToDoRepository(),
            syncEngine: syncEngine
        )
        self.cachedImportantAccountRepository = CachedImportantAccountRepository(
            modelContext: modelContext,
            remoteRepository: ImportantAccountRepository(),
            syncEngine: syncEngine
        )
        self.cachedStickyReminderRepository = CachedStickyReminderRepository(
            modelContext: modelContext,
            remoteRepository: StickyReminderRepository(),
            syncEngine: syncEngine
        )
        self.cachedCountdownRepository = CachedCountdownRepository(
            modelContext: modelContext,
            remoteRepository: CountdownRepository(),
            syncEngine: syncEngine
        )

        // Setup notification categories and delegate
        NotificationService.shared.setupNotificationCategories()
        NotificationService.shared.delegate = self

        Task {
            await checkAuthState()
            // Request notification permissions
            _ = await NotificationService.shared.requestPermission()
            // Re-schedule notifications on app launch
            await rescheduleNotifications()
            // Process any pending notifications after app is fully loaded
            // Small delay to ensure views are mounted and ready to observe changes
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                NotificationService.shared.processPendingNotifications()
            }
        }
    }
    
    /// Creates an AppState instance for SwiftUI Previews
    @MainActor
    static func forPreview() -> AppState {
        do {
            let container = try LocalStorageContainer.createPreviewContainer()
            let context = ModelContext(container)
            return AppState(modelContext: context)
        } catch {
            fatalError("Failed to create preview AppState: \(error)")
        }
    }

    // MARK: - Auth State
    func checkAuthState() async {
        isLoading = true

        if let user = await authRepository.getCurrentUser() {
            isAuthenticated = true
            await syncAppUser(userId: user.id, email: user.email ?? "")
            await loadAccountData()
            await checkMoodPrompt()
        } else {
            isAuthenticated = false
            isAppAdmin = false
            currentAppUser = nil
        }

        isLoading = false
    }

    // MARK: - Sync App User
    /// Ensures the current user exists in app_users table and updates admin status
    private func syncAppUser(userId: UUID, email: String) async {
        // Always check hardcoded admins first as a baseline
        let isHardcodedAdmin = AppAdminService.shared.isAppAdmin(email: email)
        #if DEBUG
        print("🔐 Checking admin status for: \(email), hardcoded admin: \(isHardcodedAdmin)")
        #endif

        do {
            // First ensure the user exists (creates if needed)
            _ = try await appUserRepository.ensureUserExists(userId: userId, email: email)
            // Then always fetch fresh data to get latest complimentary access status
            if let freshUser = try await appUserRepository.getUser(id: userId) {
                currentAppUser = freshUser
                // User is admin if either hardcoded OR set in database
                isAppAdmin = freshUser.isAppAdmin || isHardcodedAdmin
                #if DEBUG
                print("🔐 App user synced, isAppAdmin: \(isAppAdmin), hasComplimentaryAccess: \(freshUser.hasComplimentaryAccess)")
                #endif
            }
        } catch {
            #if DEBUG
            print("🔐 Error syncing app user (table may not exist yet): \(error)")
            #endif
            // Fall back to checking hardcoded admins only
            isAppAdmin = isHardcodedAdmin
            #if DEBUG
            print("🔐 Using fallback, isAppAdmin: \(isAppAdmin)")
            #endif
        }
    }

    // MARK: - Refresh App User Status
    /// Refreshes the current user's app_user record to get latest complimentary access status
    func refreshAppUserStatus() async {
        guard let userId = await SupabaseManager.shared.currentUserId else { return }

        do {
            if let freshUser = try await appUserRepository.getUser(id: userId) {
                currentAppUser = freshUser
                isAppAdmin = freshUser.isAppAdmin || AppAdminService.shared.isAppAdmin(email: freshUser.email)
                #if DEBUG
                print("🔐 App user refreshed, hasComplimentaryAccess: \(freshUser.hasComplimentaryAccess)")
                #endif
            }
        } catch {
            #if DEBUG
            print("🔐 Error refreshing app user: \(error)")
            #endif
        }
    }
    
    // MARK: - Load Account Data
    func loadAccountData() async {
        do {
            // First, try to load from local cache for instant UI (offline-first)
            let cachedAccounts = try await loadAccountsFromCache()

            if !cachedAccounts.isEmpty {
                // Show cached data immediately
                allAccounts = cachedAccounts
                await selectAndLoadAccount()

                // Then sync in background
                Task {
                    await syncAccountDataInBackground()
                }
            } else {
                // No cache - fetch from network (first-time user or cleared cache)
                allAccounts = try await accountRepository.getAllUserAccounts()

                // Cache the fetched accounts and members locally for future offline access
                await cacheAccountsLocally(allAccounts)

                await selectAndLoadAccount()

                // Sync all entity data for the selected account
                if let account = currentAccount {
                    Task {
                        await syncEngine.performFullSync(accountId: account.id)
                    }
                }
            }
        } catch {
            #if DEBUG
            print("Error loading account: \(error)")
            #endif
            currentAccount = nil
            currentUserRole = nil
            allAccounts = []
            isViewingOtherAccount = false
            hasCompletedOnboarding = false
        }
    }

    /// Load accounts from local cache
    private func loadAccountsFromCache() async throws -> [AccountWithRole] {
        let descriptor = FetchDescriptor<LocalAccount>(
            predicate: #Predicate { !$0.locallyDeleted }
        )
        let localAccounts = try modelContext.fetch(descriptor)

        // Convert to AccountWithRole (we'll need to fetch roles separately)
        var result: [AccountWithRole] = []
        for local in localAccounts {
            let localAccountId = local.id
            let memberDescriptor = FetchDescriptor<LocalAccountMember>(
                predicate: #Predicate { $0.accountId == localAccountId && !$0.locallyDeleted }
            )
            let members = try modelContext.fetch(memberDescriptor)

            // Find current user's membership
            if let userId = await SupabaseManager.shared.currentUserId,
               let membership = members.first(where: { $0.userId == userId }) {
                let account = local.toRemote()
                let role = MemberRole(rawValue: membership.role) ?? .viewer
                let isOwner = local.ownerUserId == userId
                result.append(AccountWithRole(account: account, role: role, isOwner: isOwner))
            }
        }

        return result
    }

    /// Cache accounts and members locally for offline access
    private func cacheAccountsLocally(_ accountsWithRoles: [AccountWithRole]) async {
        guard let userId = await SupabaseManager.shared.currentUserId else { return }

        // Get the set of account IDs the user currently has access to
        let currentAccountIds = Set(accountsWithRoles.map { $0.account.id })

        // Remove memberships for accounts the user no longer has access to
        let allMembershipsDescriptor = FetchDescriptor<LocalAccountMember>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let allMemberships = try? modelContext.fetch(allMembershipsDescriptor) {
            for membership in allMemberships {
                if !currentAccountIds.contains(membership.accountId) {
                    // User no longer has access to this account - remove the membership
                    modelContext.delete(membership)
                    #if DEBUG
                    print("🗑️ Removed cached membership for account: \(membership.accountId)")
                    #endif
                }
            }
        }

        for accountWithRole in accountsWithRoles {
            let account = accountWithRole.account

            // Check if account already exists locally
            let accountId = account.id
            let existingDescriptor = FetchDescriptor<LocalAccount>(
                predicate: #Predicate { $0.id == accountId }
            )

            if let existing = try? modelContext.fetch(existingDescriptor).first {
                // Update existing account
                existing.update(from: account)
            } else {
                // Insert new account
                let localAccount = LocalAccount(from: account)
                modelContext.insert(localAccount)
            }

            // Cache the membership
            let memberDescriptor = FetchDescriptor<LocalAccountMember>(
                predicate: #Predicate { $0.accountId == accountId && $0.userId == userId }
            )

            if let existingMember = try? modelContext.fetch(memberDescriptor).first {
                // Update existing membership
                existingMember.role = accountWithRole.role.rawValue
                existingMember.isSynced = true
            } else {
                // Insert new membership
                let localMember = LocalAccountMember(
                    id: UUID(),
                    accountId: account.id,
                    userId: userId,
                    role: accountWithRole.role.rawValue,
                    isSynced: true
                )
                modelContext.insert(localMember)
            }
        }

        try? modelContext.save()

        #if DEBUG
        print("🔄 Cached \(accountsWithRoles.count) accounts locally")
        #endif
    }

    /// Select and load the appropriate account
    private func selectAndLoadAccount() async {
        var accountToLoad: Account?

        // Check if there's a previously selected account
        if let savedAccountIdString = UserDefaults.standard.string(forKey: selectedAccountIdKey),
           let savedAccountId = UUID(uuidString: savedAccountIdString),
           let savedAccount = allAccounts.first(where: { $0.account.id == savedAccountId }) {
            accountToLoad = savedAccount.account
        }
        // Otherwise, default to owned account first
        else if let owned = ownedAccount {
            accountToLoad = owned.account
        }
        // Fall back to first available account
        else if let first = allAccounts.first {
            accountToLoad = first.account
        }

        if let account = accountToLoad {
            currentAccount = account
            currentUserRole = allAccounts.first(where: { $0.account.id == account.id })?.role
            isViewingOtherAccount = !(ownedAccount?.account.id == account.id)
            hasCompletedOnboarding = true

            // Save the selected account
            UserDefaults.standard.set(account.id.uuidString, forKey: selectedAccountIdKey)

            // Start realtime sync for cross-device updates
            await RealtimeSyncService.shared.startListening(accountId: account.id)
        } else {
            currentAccount = nil
            currentUserRole = nil
            isViewingOtherAccount = false
            hasCompletedOnboarding = false
        }
    }

    /// Sync account data in background
    private func syncAccountDataInBackground() async {
        guard let account = currentAccount else { return }

        do {
            // Fetch fresh account list from server
            let freshAccounts = try await accountRepository.getAllUserAccounts()
            allAccounts = freshAccounts

            // Cache the fresh accounts locally
            await cacheAccountsLocally(freshAccounts)

            // Update role if changed
            if let freshRole = freshAccounts.first(where: { $0.account.id == account.id })?.role {
                currentUserRole = freshRole
            }

            // Perform full sync for all entity data
            await syncEngine.performFullSync(accountId: account.id)

            #if DEBUG
            print("🔄 Background sync completed for account: \(account.id)")
            #endif
        } catch {
            #if DEBUG
            print("🔄 Background sync failed: \(error)")
            #endif
        }
    }

    // MARK: - Switch Account
    /// Switch to a different account
    func switchAccount(to accountWithRole: AccountWithRole) async {
        // Cancel all pending notifications from the previous account before switching
        NotificationService.shared.removeAllPendingNotifications()
        #if DEBUG
        print("📱 Cancelled notifications from previous account before switching")
        #endif

        currentAccount = accountWithRole.account
        currentUserRole = accountWithRole.role
        isViewingOtherAccount = !accountWithRole.isOwner

        // Persist selection
        UserDefaults.standard.set(accountWithRole.account.id.uuidString, forKey: selectedAccountIdKey)

        // Start realtime sync for the new account
        await RealtimeSyncService.shared.startListening(accountId: accountWithRole.account.id)

        // Trigger background sync for the new account
        Task {
            await syncEngine.performFullSync(accountId: accountWithRole.account.id)
        }

        // Reload notifications for the new account
        await rescheduleNotifications()

        // Check mood prompt for new account
        await checkMoodPrompt()
    }

    // MARK: - Switch to Own Account
    /// Convenience method to switch back to user's own account
    func switchToOwnAccount() async {
        guard let owned = ownedAccount else { return }
        await switchAccount(to: owned)
    }

    // MARK: - Refresh Accounts List
    /// Refresh the list of accounts (e.g., after accepting an invitation)
    func refreshAccountsList() async {
        do {
            allAccounts = try await accountRepository.getAllUserAccounts()
        } catch {
            #if DEBUG
            print("Error refreshing accounts: \(error)")
            #endif
        }
    }
    
    // MARK: - Check Mood Prompt
    func checkMoodPrompt() async {
        // Don't show mood prompt when viewing another account (helpers shouldn't fill it out)
        guard !isViewingOtherAccount else {
            showMoodPrompt = false
            return
        }

        guard let account = currentAccount,
              let userId = await SupabaseManager.shared.currentUserId else {
            return
        }

        do {
            let todaysMood = try await moodRepository.getTodaysEntry(
                accountId: account.id,
                userId: userId
            )
            showMoodPrompt = (todaysMood == nil)
        } catch {
            #if DEBUG
            print("Error checking mood: \(error)")
            #endif
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        do {
            // Stop realtime sync
            await RealtimeSyncService.shared.stopListening()

            // Cancel all pending notifications from the previous account
            // This prevents notifications from firing after signing out
            NotificationService.shared.removeAllPendingNotifications()
            #if DEBUG
            print("📱 Cancelled all pending notifications on sign out")
            #endif

            try await authRepository.signOut()
            isAuthenticated = false
            currentAccount = nil
            currentUserRole = nil
            allAccounts = []
            isViewingOtherAccount = false
            hasCompletedOnboarding = false
            isAppAdmin = false
            currentAppUser = nil
            // Clear saved account selection
            UserDefaults.standard.removeObject(forKey: selectedAccountIdKey)
        } catch {
            #if DEBUG
            print("Error signing out: \(error)")
            #endif
        }
    }
    
    // MARK: - Complete Onboarding
    func completeOnboarding(accountName: String, primaryProfileName: String, birthday: Date?, firstAction: OnboardingFirstAction? = nil) async throws {
        #if DEBUG
        print("🔵 Starting onboarding...")
        print("🔵 Account name: \(accountName)")
        print("🔵 Profile name: \(primaryProfileName)")
        #endif

        // Verify we have a valid authenticated user before proceeding
        guard let userId = await SupabaseManager.shared.currentUserId else {
            #if DEBUG
            print("❌ No authenticated user found during onboarding")
            #endif
            throw SupabaseError.notAuthenticated
        }
        #if DEBUG
        print("🔵 Authenticated user ID: \(userId)")
        #endif

        // Create account
        #if DEBUG
        print("🔵 Creating account...")
        #endif
        let account = try await accountRepository.createAccount(
            displayName: accountName
        )
        #if DEBUG
        print("✅ Account created: \(account.id)")
        #endif

        // Create primary profile
        #if DEBUG
        print("🔵 Creating primary profile...")
        #endif
        let profileInsert = ProfileInsert(
            accountId: account.id,
            type: .primary,
            fullName: primaryProfileName,
            birthday: birthday,
            linkedUserId: userId
        )
        let profile = try await profileRepository.createProfile(profileInsert)
        #if DEBUG
        print("✅ Profile created: \(profile.id)")
        #endif

        // Update state
        currentAccount = account
        currentUserRole = .owner
        hasCompletedOnboarding = true

        // Store the selected first action for navigation after onboarding completes
        pendingOnboardingAction = firstAction
        #if DEBUG
        print("✅ Onboarding state updated with action: \(String(describing: firstAction))")
        #endif

        // Start realtime sync for the new account
        await RealtimeSyncService.shared.startListening(accountId: account.id)

        // Refresh accounts list to include the new account
        await refreshAccountsList()

        // Check mood prompt
        await checkMoodPrompt()
        #if DEBUG
        print("✅ Onboarding complete!")
        #endif
    }
    
    // MARK: - Record Mood
    func recordMood(rating: Int, note: String? = nil) async {
        #if DEBUG
        print("📝 recordMood called with rating: \(rating)")
        #endif

        guard let account = currentAccount else {
            #if DEBUG
            print("❌ recordMood failed: no currentAccount")
            #endif
            return
        }

        guard let userId = await SupabaseManager.shared.currentUserId else {
            #if DEBUG
            print("❌ recordMood failed: no currentUserId")
            #endif
            return
        }

        #if DEBUG
        print("📝 Recording mood for account: \(account.id), user: \(userId)")
        #endif

        do {
            // Check if there's already a mood entry for today
            if let existingEntry = try await moodRepository.getTodaysEntry(accountId: account.id, userId: userId) {
                // Update existing entry
                #if DEBUG
                print("📝 Updating existing mood entry: \(existingEntry.id)")
                #endif
                _ = try await moodRepository.updateEntry(id: existingEntry.id, rating: rating, note: note)
                #if DEBUG
                print("✅ Mood entry updated")
                #endif
            } else {
                // Create new entry
                let entry = MoodEntryInsert(
                    accountId: account.id,
                    userId: userId,
                    rating: rating,
                    note: note
                )
                let created = try await moodRepository.createEntry(entry)
                #if DEBUG
                print("✅ Mood entry created: \(created.id)")
                #endif
            }
            showMoodPrompt = false
        } catch {
            #if DEBUG
            print("❌ Error recording mood: \(error)")
            #endif
        }
    }
    
    // MARK: - Generate Today's Medication Logs
    func generateTodaysMedicationLogs() async {
        guard let account = currentAccount else { return }

        do {
            // Generate logs locally for offline support
            try await syncEngine.generateLocalMedicationLogs(accountId: account.id)
        } catch {
            #if DEBUG
            print("Error generating medication logs: \(error)")
            #endif
        }
    }

    // MARK: - Re-schedule Notifications
    func rescheduleNotifications() async {
        guard let account = currentAccount else {
            #if DEBUG
            print("📱 No account, skipping notification re-schedule")
            #endif
            return
        }

        #if DEBUG
        print("📱 Re-scheduling notifications for account: \(account.id)")
        #endif

        do {
            // Fetch upcoming appointments (next 30 days)
            let appointments = try await appointmentRepository.getUpcomingAppointments(
                accountId: account.id,
                days: 30
            )

            // Fetch all profiles (for birthday reminders)
            let profiles = try await profileRepository.getProfiles(accountId: account.id)

            // Fetch medications and their schedules
            let medications = try await medicationRepository.getMedications(accountId: account.id)
            var schedules: [UUID: [MedicationSchedule]] = [:]
            for medication in medications {
                let medicationSchedules = try await medicationRepository.getSchedules(medicationId: medication.id)
                schedules[medication.id] = medicationSchedules
            }

            // Fetch all sticky reminders (including dismissed) to properly cancel dismissed ones
            let allStickyReminders = try await stickyReminderRepository.getReminders(accountId: account.id)
            let activeStickyReminders = allStickyReminders.filter { $0.isActive && !$0.isDismissed }

            // Re-schedule all notifications
            await NotificationService.shared.rescheduleAllNotifications(
                appointments: appointments,
                profiles: profiles,
                medications: medications,
                schedules: schedules
            )

            // Re-schedule sticky reminder notifications (pass all reminders to cancel dismissed ones)
            await NotificationService.shared.rescheduleAllStickyReminders(
                activeReminders: activeStickyReminders,
                allReminders: allStickyReminders
            )
        } catch {
            #if DEBUG
            print("Error re-scheduling notifications: \(error)")
            #endif
        }
    }

    // MARK: - Sync Sticky Reminder Notifications
    /// Syncs sticky reminders from Supabase and schedules local notifications.
    /// Called when app comes to foreground to catch any changes made while inactive.
    func syncStickyReminderNotifications() async {
        guard let account = currentAccount else {
            #if DEBUG
            print("📱 No account, skipping sticky reminder sync")
            #endif
            return
        }

        #if DEBUG
        print("📱 Syncing sticky reminder notifications for account: \(account.id)")
        #endif

        do {
            // Fetch all sticky reminders from Supabase
            let allStickyReminders = try await stickyReminderRepository.getReminders(accountId: account.id)
            let activeStickyReminders = allStickyReminders.filter { $0.isActive && !$0.isDismissed }

            // Reschedule all sticky reminder notifications
            await NotificationService.shared.rescheduleAllStickyReminders(
                activeReminders: activeStickyReminders,
                allReminders: allStickyReminders
            )

            #if DEBUG
            print("📱 Synced \(activeStickyReminders.count) active sticky reminders")
            #endif
        } catch {
            #if DEBUG
            print("Error syncing sticky reminder notifications: \(error)")
            #endif
        }
    }

    // MARK: - Refresh Data From Remote
    /// Refresh cached data from the remote server when app becomes active
    /// This ensures data syncs across devices even without realtime subscriptions
    func refreshDataFromRemote() async {
        guard let account = currentAccount else {
            #if DEBUG
            print("📱 No account, skipping data refresh")
            #endif
            return
        }

        #if DEBUG
        print("📱 Refreshing data from remote for account: \(account.id)")
        #endif

        // Refresh countdowns
        do {
            _ = try await countdownRepository.refreshFromRemote(accountId: account.id)
            NotificationCenter.default.post(name: .countdownsDidChange, object: nil)
            #if DEBUG
            print("📱 Refreshed countdowns from remote")
            #endif
        } catch {
            #if DEBUG
            print("📱 Error refreshing countdowns: \(error)")
            #endif
        }

        // Refresh appointments
        do {
            _ = try await appointmentRepository.refreshFromRemote(accountId: account.id)
            NotificationCenter.default.post(name: .appointmentsDidChange, object: nil)
            #if DEBUG
            print("📱 Refreshed appointments from remote")
            #endif
        } catch {
            #if DEBUG
            print("📱 Error refreshing appointments: \(error)")
            #endif
        }

        // Refresh sticky reminders
        do {
            _ = try await stickyReminderRepository.refreshFromRemote(accountId: account.id)
            NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
            #if DEBUG
            print("📱 Refreshed sticky reminders from remote")
            #endif
        } catch {
            #if DEBUG
            print("📱 Error refreshing sticky reminders: \(error)")
            #endif
        }
    }

    // MARK: - Schedule Birthday Reminder
    func scheduleBirthdayReminder(for profile: Profile) async {
        guard let birthday = profile.birthday else { return }
        await NotificationService.shared.scheduleBirthdayReminder(
            profileId: profile.id,
            name: profile.displayName,
            birthday: birthday
        )
    }

    // MARK: - Cancel Birthday Reminder
    func cancelBirthdayReminder(for profileId: UUID) {
        NotificationService.shared.cancelBirthdayReminder(profileId: profileId)
    }
}

// MARK: - NotificationHandlerDelegate
extension AppState: NotificationHandlerDelegate {

    /// Handle "Mark as Taken" action from medication notification
    func handleMedicationTaken(medicationId: UUID, scheduledTime: Date) async {
        guard let account = currentAccount else {
            #if DEBUG
            print("📱 No account for medication taken action")
            #endif
            return
        }

        do {
            // Find the medication log for this medication and scheduled time
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: scheduledTime)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let logs = try await medicationRepository.getLogs(
                medicationId: medicationId,
                from: startOfDay,
                to: endOfDay
            )

            // Find the log closest to the scheduled time
            if let log = logs.first(where: { log in
                let logHour = calendar.component(.hour, from: log.scheduledAt)
                let logMinute = calendar.component(.minute, from: log.scheduledAt)
                let scheduledHour = calendar.component(.hour, from: scheduledTime)
                let scheduledMinute = calendar.component(.minute, from: scheduledTime)
                return logHour == scheduledHour && logMinute == scheduledMinute
            }) {
                // Update the log status to taken
                _ = try await medicationRepository.updateLogStatus(
                    logId: log.id,
                    status: .taken,
                    takenAt: Date()
                )
                #if DEBUG
                print("📱 Marked medication as taken: \(medicationId)")
                #endif
            } else {
                #if DEBUG
                print("📱 Could not find medication log to mark as taken")
                #endif
            }
        } catch {
            #if DEBUG
            print("📱 Error marking medication as taken: \(error)")
            #endif
        }
    }

    /// Handle "Snooze" action from medication notification
    func handleMedicationSnooze(medicationId: UUID, medicationName: String, doseDescription: String?) async {
        // Schedule a new notification in 10 minutes
        await NotificationService.shared.scheduleMedicationSnooze(
            medicationId: medicationId,
            medicationName: medicationName,
            doseDescription: doseDescription
        )
    }

    /// Handle "View" action from appointment notification
    nonisolated func handleAppointmentView(appointmentId: UUID) {
        Task { @MainActor in
            pendingAppointmentId = appointmentId
        }
    }

    /// Handle tap on birthday notification
    nonisolated func handleBirthdayView(profileId: UUID) {
        Task { @MainActor in
            pendingProfileId = profileId
        }
    }

    /// Handle "Dismiss" action from sticky reminder notification
    func handleStickyReminderDismiss(reminderId: UUID) async {
        do {
            _ = try await stickyReminderRepository.dismissReminder(id: reminderId)
            await NotificationService.shared.cancelStickyReminder(reminderId: reminderId)
            NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
            #if DEBUG
            print("📱 Dismissed sticky reminder: \(reminderId)")
            #endif
        } catch {
            #if DEBUG
            print("📱 Error dismissing sticky reminder: \(error)")
            #endif
        }
    }

    /// Handle tap on sticky reminder notification
    nonisolated func handleStickyReminderTapped(reminderId: UUID) {
        Task { @MainActor in
            pendingStickyReminderId = reminderId
        }
    }
}
