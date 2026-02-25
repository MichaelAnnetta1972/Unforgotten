import SwiftUI

// MARK: - Settings Panel View
/// iPad-optimized Settings view for side panel presentation with split-view sub-menus
struct SettingsPanelView: View {
    @EnvironmentObject var appState: AppState
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @Environment(HeaderStyleManager.self) private var headerStyleManager
    @Environment(FeatureVisibilityManager.self) private var featureVisibility
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var onDismiss: (() -> Void)? = nil

    // Selected sub-menu
    enum SettingsSubMenu: Identifiable {
        case appearance
        case features
        case editAccountName
        case manageMembers
        case switchAccount
        case moodHistory
        case upgrade
        case adminPanel
        case privacyPolicy
        case termsOfService

        var id: String {
            switch self {
            case .appearance: return "appearance"
            case .features: return "features"
            case .editAccountName: return "editAccountName"
            case .manageMembers: return "manageMembers"
            case .switchAccount: return "switchAccount"
            case .moodHistory: return "moodHistory"
            case .upgrade: return "upgrade"
            case .adminPanel: return "adminPanel"
            case .privacyPolicy: return "privacyPolicy"
            case .termsOfService: return "termsOfService"
            }
        }

        var title: String {
            switch self {
            case .appearance: return "Colors & Headers"
            case .features: return "Show/Hide Features"
            case .editAccountName: return "Edit Account Name"
            case .manageMembers: return "Manage Members"
            case .switchAccount: return "Switch Account"
            case .moodHistory: return "Mood History"
            case .upgrade: return "Upgrade to Premium"
            case .adminPanel: return "Admin Panel"
            case .privacyPolicy: return "Privacy Policy"
            case .termsOfService: return "Terms of Service"
            }
        }
    }

    @State private var selectedSubMenu: SettingsSubMenu?
    @State private var showSignOutConfirm = false
    @State private var showUpgradePrompt = false
    @State private var userEmail: String = ""
    @State private var allowNotifications: Bool = NotificationService.shared.allowNotifications
    @State private var hideNotificationPreviews: Bool = NotificationService.shared.hideNotificationPreviews


    /// Whether to show split view (side-by-side) on iPad
    private var showSplitLayout: Bool {
        horizontalSizeClass == .regular
    }


    var body: some View {
        Group {
            if showSplitLayout {
                // iPad: Side-by-side split view
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Main settings list
                        settingsListView
                            .frame(width: selectedSubMenu != nil ? geometry.size.width * 0.5 : geometry.size.width)

                        // Detail view (slides in from right)
                        if let subMenu = selectedSubMenu {
                            detailView(for: subMenu)
                                .frame(width: geometry.size.width * 0.5)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedSubMenu)
                }
            } else {
                // iPhone: Stack navigation style - show detail full screen when selected
                if let subMenu = selectedSubMenu {
                    detailViewWithBackButton(for: subMenu)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    settingsListView
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedSubMenu)
        .background(Color.appBackgroundLight)
        .alert("Sign Out", isPresented: $showSignOutConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await appState.signOut()
                    onDismiss?()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .task {
            if let user = await SupabaseManager.shared.currentUser {
                userEmail = user.email ?? ""
            }
        }
    }

    // MARK: - Settings List View

    private var settingsListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    if selectedSubMenu != nil {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSubMenu = nil
                        }
                    } else {
                        onDismiss?()
                    }
                } label: {
                    Image(systemName: selectedSubMenu != nil ? "chevron.left" : "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color.cardBackgroundSoft)
                        )
                }

                Spacer()

                Text("Settings")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Invisible spacer for centering
                Color.clear
                    .frame(width: 48, height: 48)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackgroundLight)

            ScrollView {
                VStack(spacing: 24) {
                    // Header icon
                    VStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 40))
                            .foregroundColor(appAccentColor)

                        if !showSplitLayout {
                            Text("Settings")
                                .font(.appTitle)
                                .foregroundColor(.textPrimary)
                        }
                    }
                    .padding(.top, 16)

                    // Appearance section
                    SettingsPanelSection(title: "APPEARANCE") {
                        SettingsPanelButtonRow(
                            icon: "paintpalette",
                            title: "Colors & Headers",
                            isSelected: selectedSubMenu == .appearance
                        ) {
                            selectSubMenu(.appearance)
                        }
                    }

                    // Features section
                    SettingsPanelSection(title: "FEATURES") {
                        SettingsPanelButtonRow(
                            icon: "square.grid.2x2",
                            title: "Show/Hide Features",
                            isSelected: selectedSubMenu == .features
                        ) {
                            selectSubMenu(.features)
                        }
                    }

                    // Notifications section
                    SettingsPanelSection(title: "NOTIFICATIONS") {
                        SettingsPanelToggleRow(
                            icon: "bell.fill",
                            title: "Allow Notifications",
                            isOn: $allowNotifications
                        )
                        .onChange(of: allowNotifications) { _, newValue in
                            NotificationService.shared.allowNotifications = newValue
                            if newValue {
                                Task {
                                    _ = await NotificationService.shared.requestPermission()
                                    await NotificationService.shared.scheduleMorningBriefingTrigger()
                                }
                            }
                        }

                        if allowNotifications {
                            SettingsPanelToggleRow(
                                icon: "eye.slash.fill",
                                title: "Hide Previews",
                                isOn: $hideNotificationPreviews
                            )
                            .onChange(of: hideNotificationPreviews) { _, newValue in
                                NotificationService.shared.hideNotificationPreviews = newValue
                            }

                        }
                    }

                    // Account section
                    SettingsPanelSection(title: "ACCOUNT") {
                        if let account = appState.currentAccount {
                            // Only owner/admin can edit account name
                            if appState.currentUserRole?.canManageMembers == true {
                                SettingsPanelButtonRowWithValue(
                                    icon: "person.circle",
                                    title: "Account Name",
                                    value: account.displayName,
                                    isSelected: selectedSubMenu == .editAccountName
                                ) {
                                    selectSubMenu(.editAccountName)
                                }
                            } else {
                                SettingsPanelInfoRow(
                                    icon: "person.circle",
                                    title: "Account Name",
                                    value: account.displayName
                                )
                            }

                            if let role = appState.currentUserRole {
                                SettingsPanelInfoRow(
                                    icon: "person.badge.shield.checkmark",
                                    title: "Your Role",
                                    value: role.displayName
                                )
                            }

                            if !userEmail.isEmpty {
                                SettingsPanelInfoRow(
                                    icon: "envelope",
                                    title: "Email",
                                    value: userEmail
                                )
                            }
                        }

                        // Only show manage members if user can manage members
                        if appState.currentUserRole?.canManageMembers == true {
                            SettingsPanelButtonRow(
                                icon: "person.2",
                                title: "Manage Members",
                                isSelected: selectedSubMenu == .manageMembers
                            ) {
                                selectSubMenu(.manageMembers)
                            }
                        }

                        // Switch Account (only show if multiple accounts)
                        if appState.allAccounts.count > 1 {
                            SettingsPanelButtonRow(
                                icon: "arrow.left.arrow.right",
                                title: "Switch Account",
                                isSelected: selectedSubMenu == .switchAccount
                            ) {
                                selectSubMenu(.switchAccount)
                            }
                        }
                    }

                    // Mood section
                    SettingsPanelSection(title: "MOOD") {
                        SettingsPanelButtonRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "View Mood History",
                            isSelected: selectedSubMenu == .moodHistory
                        ) {
                            selectSubMenu(.moodHistory)
                        }
                    }

                    // Upgrade section (only show if not premium)
                    if !appState.hasPremiumAccess {
                        SettingsPanelSection(title: "UPGRADE") {
                            SettingsPanelButtonRow(
                                icon: "star.fill",
                                title: "Upgrade to Premium",
                                isSelected: selectedSubMenu == .upgrade
                            ) {
                                selectSubMenu(.upgrade)
                            }
                        }
                    }

                    // Admin section (only visible to app admins)
                    if appState.isAppAdmin {
                        SettingsPanelSection(title: "APP ADMINISTRATION") {
                            SettingsPanelButtonRow(
                                icon: "crown.fill",
                                title: "Admin Panel",
                                isSelected: selectedSubMenu == .adminPanel
                            ) {
                                selectSubMenu(.adminPanel)
                            }
                        }
                    }

                    // About section
                    SettingsPanelSection(title: "ABOUT") {
                        SettingsPanelInfoRow(
                            icon: "info.circle",
                            title: "Version",
                            value: "1.0.0"
                        )

                        SettingsPanelButtonRow(
                            icon: "lock.shield",
                            title: "Privacy Policy",
                            isSelected: selectedSubMenu == .privacyPolicy
                        ) {
                            selectSubMenu(.privacyPolicy)
                        }

                        SettingsPanelButtonRow(
                            icon: "doc.text",
                            title: "Terms of Service",
                            isSelected: selectedSubMenu == .termsOfService
                        ) {
                            selectSubMenu(.termsOfService)
                        }
                    }

                    // Sign out
                    Button {
                        showSignOutConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(.appBodyMedium)
                        .foregroundColor(.medicalRed)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)

                    Spacer()
                        .frame(height: 40)
                }
            }
        }
        .background(Color.appBackgroundLight)
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private func detailView(for subMenu: SettingsSubMenu) -> some View {
        VStack(spacing: 0) {
            // Detail header
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSubMenu = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.cardBackgroundSoft)
                        .clipShape(Circle())
                }

                Spacer()

                Text(subMenu.title)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

            // Detail content
            switch subMenu {
            case .appearance:
                AppearanceSettingsPanelContent()
                    .environment(userPreferences)
                    .environment(headerOverrides)
                    .environment(headerStyleManager)
            case .features:
                FeaturesPanelContent()
                    .environment(featureVisibility)
            case .editAccountName:
                EditAccountNamePanelContent(onSave: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSubMenu = nil
                    }
                })
            case .manageMembers:
                ManageMembersPanelContent()
            case .switchAccount:
                SwitchAccountPanelContent()
            case .moodHistory:
                MoodHistoryPanelContent()
            case .upgrade:
                UpgradePanelContent()
            case .adminPanel:
                AdminPanelContentView()
            case .privacyPolicy:
                PrivacyPolicyPanelContent()
            case .termsOfService:
                TermsOfServicePanelContent()
            }
        }
        .background(Color.appBackground)
    }

    // MARK: - Detail View with Back Button (for iPhone full-screen)

    @ViewBuilder
    private func detailViewWithBackButton(for subMenu: SettingsSubMenu) -> some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSubMenu = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Settings")
                            .font(.appBody)
                    }
                    .foregroundColor(appAccentColor)
                }

                Spacer()

                Text(subMenu.title)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Invisible spacer for centering
                Color.clear
                    .frame(width: 80, height: 40)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

            // Detail content
            switch subMenu {
            case .appearance:
                AppearanceSettingsPanelContent()
                    .environment(userPreferences)
                    .environment(headerOverrides)
                    .environment(headerStyleManager)
            case .features:
                FeaturesPanelContent()
                    .environment(featureVisibility)
            case .editAccountName:
                EditAccountNamePanelContent(onSave: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSubMenu = nil
                    }
                })
            case .manageMembers:
                ManageMembersPanelContent()
            case .switchAccount:
                SwitchAccountPanelContent()
            case .moodHistory:
                MoodHistoryPanelContent()
            case .upgrade:
                UpgradePanelContent()
            case .adminPanel:
                AdminPanelContentView()
            case .privacyPolicy:
                PrivacyPolicyPanelContent()
            case .termsOfService:
                TermsOfServicePanelContent()
            }
        }
        .background(Color.appBackground)
    }

    private func selectSubMenu(_ subMenu: SettingsSubMenu) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedSubMenu == subMenu {
                selectedSubMenu = nil
            } else {
                selectedSubMenu = subMenu
            }
        }
    }
}

// MARK: - Settings Panel Section
struct SettingsPanelSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, AppDimensions.screenPadding)

            VStack(spacing: 1) {
                content
            }
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .padding(.horizontal, AppDimensions.screenPadding)
        }
    }
}

// MARK: - Settings Panel Button Row
struct SettingsPanelButtonRow: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let icon: String
    let title: String
    var value: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(appAccentColor)
                    .frame(width: 30)

                Text(title)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)

                Spacer()

                if let value = value {
                    Text(value)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(isSelected ? appAccentColor : .textSecondary)
            }
            .padding()
            .background(isSelected ? appAccentColor.opacity(0.1) : Color.cardBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Panel Info Row
struct SettingsPanelInfoRow: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(appAccentColor)
                .frame(width: 30)

            Text(title)
                .font(.appBody)
                .foregroundColor(.textPrimary)

            Spacer()

            Text(value)
                .font(.appBody)
                .foregroundColor(.textSecondary)
        }
        .padding()
        .background(Color.cardBackground)
    }
}

// MARK: - Settings Panel Toggle Row
struct SettingsPanelToggleRow: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(appAccentColor)
                .frame(width: 30)

            Text(title)
                .font(.appBody)
                .foregroundColor(.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(appAccentColor)
                .labelsHidden()
        }
        .padding()
        .background(Color.cardBackground)
    }
}

// MARK: - Settings Panel Account Row
/// Account switching row for the iPad settings panel
struct SettingsPanelAccountRow: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let accountWithRole: AccountWithRole
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Account icon
                ZStack {
                    Circle()
                        .fill(accountWithRole.isOwner ? appAccentColor : Color.cardBackgroundSoft)
                        .frame(width: 36, height: 36)

                    Image(systemName: accountWithRole.isOwner ? "house.fill" : "person.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(accountWithRole.isOwner ? .black : .textSecondary)
                }

                // Account info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(accountWithRole.displayName)
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        if accountWithRole.isOwner {
                            Text("Your Account")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    // Role badge
                    Text(accountWithRole.role.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Selected indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(appAccentColor)
                }
            }
            .padding()
            .background(isSelected ? appAccentColor.opacity(0.1) : Color.cardBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Appearance Settings Panel Content
struct AppearanceSettingsPanelContent: View {
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @Environment(HeaderStyleManager.self) private var headerStyleManager

    private var effectiveAccentColor: Color {
        if userPreferences.hasCustomAccentColor {
            return userPreferences.accentColor
        } else {
            return headerStyleManager.defaultAccentColor
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Change the way Unforgotten looks by choosing a theme style. You can even choose an accent colour to make the app feel like your own.")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 16)

                // Header Style Section
                HeaderStylePicker()
                    .padding(.horizontal, AppDimensions.screenPadding)

                // Accent Color Section
                AccentColorPickerWithReset()
                    .padding(.horizontal, AppDimensions.screenPadding)

                // Custom Headers Section
                CustomHeadersSection()
                    .padding(.horizontal, AppDimensions.screenPadding)

                Spacer()
                    .frame(height: 40)
            }
        }
        .background(Color.appBackground)
    }
}

// MARK: - Manage Members Panel Content
struct ManageMembersPanelContent: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @StateObject private var viewModel = ManageMembersViewModel()
    @State private var memberToRemove: MemberWithEmail?
    @State private var showRemoveConfirm = false

    /// Check if current user can remove members (must be owner or admin)
    private var canRemoveMembers: Bool {
        guard let role = appState.currentUserRole else { return false }
        return role == .owner || role == .admin
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40))
                        .foregroundColor(appAccentColor)

                    Text("View and manage who has access to this account.")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                // Current Members Section
                if !viewModel.membersWithEmail.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CURRENT MEMBERS")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, AppDimensions.screenPadding)

                        VStack(spacing: 1) {
                            ForEach(viewModel.membersWithEmail) { memberWithEmail in
                                MemberRow(
                                    memberWithEmail: memberWithEmail,
                                    canRemove: canRemoveMembers && !memberWithEmail.isCurrentUser && memberWithEmail.member.role != .owner,
                                    onRemove: {
                                        memberToRemove = memberWithEmail
                                        showRemoveConfirm = true
                                    }
                                )
                            }
                        }
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                        .padding(.horizontal, AppDimensions.screenPadding)
                    }
                }

                // Pending Invitations Section
                if !viewModel.pendingInvitations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PENDING INVITATIONS")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, AppDimensions.screenPadding)

                        VStack(spacing: 1) {
                            ForEach(viewModel.pendingInvitations) { invitation in
                                InvitationRow(
                                    invitation: invitation,
                                    onRevoke: {
                                        Task {
                                            await viewModel.revokeInvitation(invitation, appState: appState)
                                        }
                                    }
                                )
                            }
                        }
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                        .padding(.horizontal, AppDimensions.screenPadding)
                    }
                }

                if viewModel.membersWithEmail.isEmpty && viewModel.pendingInvitations.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "person.2",
                        title: "No members yet",
                        message: "Invite family members to share access to this account"
                    )
                    .padding(.top, 40)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .tint(appAccentColor)
                        .padding(.top, 40)
                }

                Spacer()
                    .frame(height: 40)
            }
        }
        .background(Color.appBackground)
        .task {
            await viewModel.loadData(appState: appState)
        }
        .refreshable {
            await viewModel.loadData(appState: appState)
        }
        .alert("Remove Member", isPresented: $showRemoveConfirm) {
            Button("Cancel", role: .cancel) {
                memberToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let member = memberToRemove {
                    Task {
                        await viewModel.removeMember(member, appState: appState)
                        memberToRemove = nil
                    }
                }
            }
        } message: {
            if let member = memberToRemove {
                Text("Are you sure you want to remove \(member.email) from this account? They will lose access immediately.")
            }
        }
    }
}

// MARK: - Switch Account Panel Content
struct SwitchAccountPanelContent: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    /// Optional callback when account is switched (for iPad to close panel)
    var onAccountSwitched: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(appAccentColor)

                    Text("Select which account you would like to view")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                // Account List
                VStack(spacing: 8) {
                    ForEach(appState.allAccounts) { accountWithRole in
                        SwitchAccountRow(
                            accountWithRole: accountWithRole,
                            isSelected: appState.currentAccount?.id == accountWithRole.account.id,
                            onSelect: {
                                Task {
                                    await appState.switchAccount(to: accountWithRole)
                                    onAccountSwitched?()
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)

                Spacer()
                    .frame(height: 40)
            }
        }
        .background(Color.appBackground)
    }
}

// MARK: - Switch Account Row (Panel)
struct SwitchAccountRow: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let accountWithRole: AccountWithRole
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Account icon
                ZStack {
                    Circle()
                        .fill(accountWithRole.isOwner ? appAccentColor : Color.cardBackgroundSoft)
                        .frame(width: 44, height: 44)

                    Image(systemName: accountWithRole.isOwner ? "house.fill" : "person.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(accountWithRole.isOwner ? .black : .textSecondary)
                }

                // Account info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(accountWithRole.displayName)
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        if accountWithRole.isOwner {
                            Text("Your Account")
                                .font(.system(size: 10))
                                .foregroundColor(.textSecondary)
                        }
                    }

                    Text(accountWithRole.role.displayName)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Selected indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(appAccentColor)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.textSecondary.opacity(0.3))
                }
            }
            .padding(AppDimensions.cardPadding)
            .background(isSelected ? appAccentColor.opacity(0.1) : Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(isSelected ? appAccentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Mood History Panel Content
struct MoodHistoryPanelContent: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @StateObject private var viewModel = MoodHistoryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary
                if let average = viewModel.averageRating {
                    VStack(spacing: 8) {
                        Text("30-Day Average")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { rating in
                                Image(systemName: rating <= Int(average.rounded()) ? "star.fill" : "star")
                                    .foregroundColor(appAccentColor)
                            }
                        }

                        Text(String(format: "%.1f", average))
                            .font(.appTitle)
                            .foregroundColor(.textPrimary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.cardCornerRadius)
                    .padding(.horizontal, AppDimensions.screenPadding)
                }

                // Entries list
                LazyVStack(spacing: AppDimensions.cardSpacing) {
                    ForEach(viewModel.entries) { entry in
                        MoodEntryRow(entry: entry)
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)

                if viewModel.entries.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "face.smiling",
                        title: "No mood entries yet",
                        message: "Start tracking your mood to see history here"
                    )
                    .padding(.top, 40)
                }

                Spacer()
                    .frame(height: 40)
            }
            .padding(.top, 16)
        }
        .background(Color.appBackground)
        .task {
            await viewModel.loadEntries(appState: appState)
        }
    }
}

// MARK: - Features Panel Content
struct FeaturesPanelContent: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(FeatureVisibilityManager.self) private var featureVisibility

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 40))
                        .foregroundColor(appAccentColor)

                    Text("Choose which features appear on your home screen.")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)
                .padding(.horizontal, AppDimensions.screenPadding)

                // Feature toggles
                VStack(spacing: 1) {
                    ForEach(Feature.allCases) { feature in
                        FeatureToggleRowPanel(feature: feature)
                    }
                }
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
                .padding(.horizontal, AppDimensions.screenPadding)

                // Reset button
                Button {
                    withAnimation {
                        featureVisibility.resetToDefaults()
                    }
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                } label: {
                    Text("Reset to Defaults")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 8)

                Spacer()
                    .frame(height: 40)
            }
        }
        .background(Color.appBackground)
    }
}

// MARK: - Feature Toggle Row Panel
struct FeatureToggleRowPanel: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(FeatureVisibilityManager.self) private var featureVisibility
    let feature: Feature

    private var isVisible: Bool {
        featureVisibility.isVisible(feature)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.system(size: 20))
                .foregroundColor(isVisible ? appAccentColor : .textSecondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.displayName)
                    .font(.appBody)
                    .foregroundColor(isVisible ? .textPrimary : .textSecondary)

                if !feature.canBeHidden {
                    Text("Required")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            if feature.canBeHidden {
                Toggle("", isOn: Binding(
                    get: { isVisible },
                    set: { newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            featureVisibility.setVisibility(feature, isVisible: newValue)
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                ))
                .tint(appAccentColor)
                .labelsHidden()
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(Color.cardBackground)
    }
}

// MARK: - Settings Panel Button Row With Value
struct SettingsPanelButtonRowWithValue: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let icon: String
    let title: String
    let value: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(appAccentColor)
                    .frame(width: 30)

                Text(title)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text(value)
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .foregroundColor(isSelected ? appAccentColor : .textSecondary)
            }
            .padding()
            .background(isSelected ? appAccentColor.opacity(0.1) : Color.cardBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Account Name Panel Content
struct EditAccountNamePanelContent: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    @State private var accountName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var onSave: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 40))
                        .foregroundColor(appAccentColor)

                    Text("This name helps identify the account for family members.")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Name")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    AppTextField(placeholder: "Enter account name", text: $accountName)
                }
                .padding(.horizontal, AppDimensions.screenPadding)

                if let error = errorMessage {
                    Text(error)
                        .font(.appCaption)
                        .foregroundColor(.medicalRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppDimensions.screenPadding)
                }

                PrimaryButton(title: "Save", isLoading: isLoading) {
                    Task { await saveAccountName() }
                }
                .disabled(accountName.isBlank)
                .padding(.horizontal, AppDimensions.screenPadding)

                Spacer()
                    .frame(height: 40)
            }
        }
        .background(Color.appBackground)
        .onAppear {
            accountName = appState.currentAccount?.displayName ?? ""
        }
    }

    private func saveAccountName() async {
        guard var account = appState.currentAccount else {
            errorMessage = "No account found."
            return
        }

        let trimmedName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Account name cannot be empty."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Create updated account with new name
            account = Account(
                id: account.id,
                ownerUserId: account.ownerUserId,
                displayName: trimmedName,
                createdAt: account.createdAt,
                updatedAt: account.updatedAt
            )

            // Update in database
            let updatedAccount = try await appState.accountRepository.updateAccount(account)

            // Update local state
            await MainActor.run {
                appState.currentAccount = updatedAccount
                // Also update in allAccounts list
                if let index = appState.allAccounts.firstIndex(where: { $0.account.id == updatedAccount.id }) {
                    let existingRole = appState.allAccounts[index]
                    appState.allAccounts[index] = AccountWithRole(
                        account: updatedAccount,
                        role: existingRole.role,
                        isOwner: existingRole.isOwner
                    )
                }
            }

            isLoading = false
            onSave?()
        } catch {
            isLoading = false
            errorMessage = "Failed to update account name: \(error.localizedDescription)"
        }
    }
}

// MARK: - Upgrade Panel Content
/// Embeds the full UpgradeView for panel presentation
struct UpgradePanelContent: View {
    var body: some View {
        UpgradeView(isEmbedded: true)
    }
}

// MARK: - Admin Panel Content View
struct AdminPanelContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    @StateObject private var viewModel = AdminPanelViewModel()
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textSecondary)

                TextField("Search by email...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 12)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(appAccentColor)
                Spacer()
            } else if filteredUsers.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "person.2.slash",
                    title: "No users found",
                    message: searchText.isEmpty ? "No users in the system yet" : "No users match your search"
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredUsers) { user in
                            AdminUserRow(
                                user: user,
                                onToggleAdmin: {
                                    Task {
                                        await viewModel.toggleAppAdmin(user: user, appState: appState)
                                    }
                                },
                                onToggleComplimentary: {
                                    Task {
                                        await viewModel.toggleComplimentaryAccess(user: user, appState: appState)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color.appBackground)
        .task {
            await viewModel.loadUsers(appState: appState)
        }
        .refreshable {
            await viewModel.loadUsers(appState: appState)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }

    private var filteredUsers: [AppUser] {
        if searchText.isEmpty {
            return viewModel.users
        }
        return viewModel.users.filter { user in
            user.email.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsPanelView()
        .environmentObject(AppState.forPreview())
        .environment(UserPreferences())
        .environment(UserHeaderOverrides())
        .environment(HeaderStyleManager())
        .environment(FeatureVisibilityManager())
}
