import SwiftUI
import UIKit
import StoreKit

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToHomeTab) private var navigateToHomeTab
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @Environment(HeaderStyleManager.self) private var headerStyleManager
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(FeatureVisibilityManager.self) private var featureVisibility

    // iPad environment actions
    @Environment(\.iPadShowManageMembersAction) private var iPadShowManageMembersAction
    @Environment(\.iPadShowMoodHistoryAction) private var iPadShowMoodHistoryAction
    @Environment(\.iPadShowAppearanceSettingsAction) private var iPadShowAppearanceSettingsAction
    @Environment(\.iPadShowFeatureVisibilityAction) private var iPadShowFeatureVisibilityAction
    @Environment(\.iPadShowSwitchAccountAction) private var iPadShowSwitchAccountAction
    @Environment(\.iPadShowEditAccountNameAction) private var iPadShowEditAccountNameAction
    @Environment(\.iPadShowAdminPanelAction) private var iPadShowAdminPanelAction
    @Environment(\.iPadShowUpgradeAction) private var iPadShowUpgradeAction
    @Environment(\.iPadShowJoinAccountAction) private var iPadShowJoinAccountAction

    @State private var showManageMembers = false
    @State private var showMoodHistory = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showDeleteAccountFinalConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var showAppearanceSettings = false
    @State private var showFeatureVisibility = false
    @State private var showSwitchAccount = false
    @State private var showEditAccountName = false
    @State private var showAdminPanel = false
    @State private var showJoinAccount = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var feedbackKindToSend: FeedbackKind?
    @State private var showMailUnavailableAlert = false
    @State private var showHelpTutorials = false
    @State private var showRecentlyDeleted = false
    @State private var userEmail: String = ""
    @State private var isCheckmarkPressed = false
    @State private var allowNotifications: Bool = NotificationService.shared.allowNotifications
    @State private var hideNotificationPreviews: Bool = NotificationService.shared.hideNotificationPreviews
    @State private var morningBriefingEnabled: Bool = NotificationService.shared.dailySummaryEnabled


    /// Computed effective accent color (respects hasCustomAccentColor flag)
    private var effectiveAccentColor: Color {
        if userPreferences.hasCustomAccentColor {
            return userPreferences.accentColor
        } else {
            return headerStyleManager.defaultAccentColor
        }
    }

    /// Helper/Viewer roles have limited access
    private var isLimitedAccess: Bool {
        appState.currentUserRole == .helper || appState.currentUserRole == .viewer
    }

    /// Check if user has premium access (subscription or complimentary)
    private var isPremiumUser: Bool {
        appState.hasPremiumAccess
    }



    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header with Done button
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundColor(effectiveAccentColor)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(effectiveAccentColor.opacity(0.15))
                            )

                        Text("Settings")
                            .font(.appTitle)
                            .foregroundColor(.textPrimary)
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isCheckmarkPressed = true
                        }
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(150))
                            guard !Task.isCancelled else { return }
                            navigateToHomeTab?()
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.appBody.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(15)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.15))
                            )
                            .scaleEffect(isCheckmarkPressed ? 0.85 : 1.1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)
                .background(Color.appBackground)

                ScrollView {
                    VStack(spacing: 24) {
                        // Viewing As Bar (shown when viewing another account)
                    ViewingAsBar()
                        .padding(.horizontal, AppDimensions.screenPadding)

                    // Appearance section (available to all roles)
                    SettingsSection(title: "APPEARANCE") {
                        SettingsButtonRow(
                            icon: "paintpalette",
                            title: "Colors & Headers",
                            action: {
                                if let action = iPadShowAppearanceSettingsAction {
                                    action()
                                } else {
                                    showAppearanceSettings = true
                                }
                            }
                        )
                    }

                    // Features section (only for full access)
                    if appState.hasFullAccess {
                        SettingsSection(title: "FEATURES") {
                            SettingsButtonRow(
                                icon: "square.grid.2x2",
                                title: "Show/Hide Features",
                                action: {
                                    if let action = iPadShowFeatureVisibilityAction {
                                        action()
                                    } else {
                                        showFeatureVisibility = true
                                    }
                                }
                            )
                        }
                    }


                    // Support section
                    SettingsSection(title: "SUPPORT") {
                        SettingsButtonRow(
                            icon: "questionmark.circle.fill",
                            title: "Help & Tutorials",
                            action: { showHelpTutorials = true }
                        )
                    }


                    // Notifications section
                    SettingsSection(title: "NOTIFICATIONS") {
                        SettingsToggleRow(
                            icon: "bell.fill",
                            title: "Allow Notifications",
                            isOn: $allowNotifications
                        )
                        .onChange(of: allowNotifications) { _, newValue in
                            NotificationService.shared.allowNotifications = newValue
                            if newValue {
                                // Re-enable: request permission and reschedule
                                Task {
                                    _ = await NotificationService.shared.requestPermission()
                                }
                            }
                        }

                        if allowNotifications {
                            SettingsToggleRow(
                                icon: "eye.slash.fill",
                                title: "Hide Previews",
                                isOn: $hideNotificationPreviews
                            )
                            .onChange(of: hideNotificationPreviews) { _, newValue in
                                NotificationService.shared.hideNotificationPreviews = newValue
                            }

                            SettingsToggleRow(
                                icon: "sunrise.fill",
                                title: "Morning Briefing",
                                isOn: $morningBriefingEnabled
                            )
                            .onChange(of: morningBriefingEnabled) { _, newValue in
                                NotificationService.shared.dailySummaryEnabled = newValue
                                if newValue {
                                    Task {
                                        await DailySummaryLiveActivityService.shared.startOrUpdateDailySummary(appState: appState)
                                    }
                                }
                            }
                        }
                    }

                    // Current Account section
                    SettingsSection(title: "CURRENT ACCOUNT") {
                        if let account = appState.currentAccount {
                            // Only owner/admin can edit account name
                            if appState.currentUserRole?.canManageMembers == true {
                                SettingsButtonRow(
                                    icon: "person.circle",
                                    title: "Account Name",
                                    value: account.displayName,
                                    action: {
                                        if let action = iPadShowEditAccountNameAction {
                                            action()
                                        } else {
                                            showEditAccountName = true
                                        }
                                    }
                                )
                            } else {
                                SettingsRow(
                                    icon: "person.circle",
                                    title: "Account Name",
                                    value: account.displayName
                                )
                            }

                            // if let role = appState.currentUserRole {
                            //     SettingsRow(
                            //         icon: "person.badge.shield.checkmark",
                            //         title: "Your Role",
                            //         value: role.displayName
                            //     )
                            // }

                            if !userEmail.isEmpty {
                                SettingsRow(
                                    icon: "envelope",
                                    title: "Email",
                                    value: userEmail
                                )
                            }

                            SettingsRow(
                                icon: appState.subscriptionTier == .free ? "star" : "star.fill",
                                title: "Current Plan",
                                value: appState.subscriptionTier.displayName
                            )
                        }

                        // Only show manage members if user can manage members
                        if appState.currentUserRole?.canManageMembers == true {
                            SettingsButtonRow(
                                icon: "person.2",
                                title: "Manage Members",
                                action: {
                                    if let action = iPadShowManageMembersAction {
                                        action()
                                    } else {
                                        showManageMembers = true
                                    }
                                }
                            )
                        }

                        // Switch Account (only show for Family Plus with multiple accounts)
                        if appState.subscriptionTier.hasFamilyFeatures && appState.switchableAccounts.count > 1 {
                            SettingsButtonRow(
                                icon: "arrow.left.arrow.right",
                                title: "Switch Account",
                                action: {
                                    if let action = iPadShowSwitchAccountAction {
                                        action()
                                    } else {
                                        showSwitchAccount = true
                                    }
                                }
                            )
                        }

                        // Join an Account
                        SettingsButtonRow(
                            icon: "person.badge.plus",
                            title: "Join an Account",
                            action: {
                                if let action = iPadShowJoinAccountAction {
                                    action()
                                } else {
                                    showJoinAccount = true
                                }
                            }
                        )
                    }

                    
                    // Upgrade section (only show if not premium)
                    if !isPremiumUser {
                        UpgradeSettingsSection()
                    }

                    // Admin section (only visible to app admins)
                    if appState.isAppAdmin {
                        SettingsSection(title: "APP ADMINISTRATION") {
                            SettingsButtonRow(
                                icon: "crown.fill",
                                title: "Admin Panel",
                                action: {
                                    if let action = iPadShowAdminPanelAction {
                                        action()
                                    } else {
                                        showAdminPanel = true
                                    }
                                }
                            )
                        }
                    }

                    // Mood section
                    SettingsSection(title: "MOOD") {
                        SettingsButtonRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "View Mood History",
                            action: { showMoodHistory = true }
                        )
                    }

                    // Data section
                    SettingsSection(title: "DATA") {
                        SettingsButtonRow(
                            icon: "trash",
                            title: "Recently Deleted",
                            action: { showRecentlyDeleted = true }
                        )
                        SyncStatusSettingsRow(syncEngine: appState.syncEngine)
                    }


                    // Support section
                    SettingsSection(title: "SUPPORT") {
                        SettingsButtonRow(
                            icon: "ladybug",
                            title: "Report a Bug",
                            action: { handleFeedbackTap(.bugReport) }
                        )

                        SettingsButtonRow(
                            icon: "bubble.left.and.bubble.right",
                            title: "Send Feedback",
                            action: { handleFeedbackTap(.generalFeedback) }
                        )
                    }

                    // About section
                    SettingsSection(title: "ABOUT") {
                        SettingsRow(
                            icon: "info.circle",
                            title: "Version",
                            value: "1.0.0"
                        )

                        SettingsButtonRow(
                            icon: "star",
                            title: "Rate Unforgotten",
                            action: { ReviewRequestService.shared.openAppStoreReviewPage() }
                        )

                        SettingsButtonRow(
                            icon: "lock.shield",
                            title: "Privacy Policy",
                            action: { showPrivacyPolicy = true }
                        )

                        SettingsButtonRow(
                            icon: "doc.text",
                            title: "Terms of Service",
                            action: { showTermsOfService = true }
                        )
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

                    // Delete account
                    Button {
                        showDeleteAccountConfirm = true
                    } label: {
                        HStack {
                            if isDeletingAccount {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .medicalRed))
                            } else {
                                Image(systemName: "trash")
                            }
                            Text(isDeletingAccount ? "Deleting…" : "Delete Account")
                        }
                        .font(.appBodyMedium)
                        .foregroundColor(.medicalRed)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                    }
                    .disabled(isDeletingAccount)
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, 8)

                    Text("Permanently deletes your account and all your data. This cannot be undone.")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppDimensions.screenPadding)
                        .padding(.top, 6)

                    Spacer()
                        .frame(height: 40)
                }
            }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sidePanel(isPresented: $showManageMembers) {
            ManageMembersView()
        }
        .sidePanel(isPresented: $showMoodHistory) {
            MoodHistoryView()
        }
        .sidePanel(isPresented: $showAppearanceSettings) {
            AppearanceSettingsView()
                .environment(userPreferences)
                .environment(headerOverrides)
                .environment(headerStyleManager)
        }
        .sidePanel(isPresented: $showFeatureVisibility) {
            FeatureVisibilityView()
                .environment(featureVisibility)
        }
        .sidePanel(isPresented: $showSwitchAccount) {
            SwitchAccountView()
        }
        .sidePanel(isPresented: $showEditAccountName) {
            EditAccountNameView()
        }
        .sidePanel(isPresented: $showAdminPanel) {
            AdminPanelView()
        }
        .sidePanel(isPresented: $showJoinAccount) {
            JoinAccountView()
        }
        .sidePanel(isPresented: $showRecentlyDeleted) {
            RecentlyDeletedView()
        }
        .sidePanel(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sidePanel(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sidePanel(isPresented: $showHelpTutorials) {
            HelpTutorialsView()
        }
        .alert("Sign Out", isPresented: $showSignOutConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await appState.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account?", isPresented: $showDeleteAccountConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                showDeleteAccountFinalConfirm = true
            }
        } message: {
            Text("This will permanently delete your account, profiles, medications, appointments, and all other data associated with your account. This action cannot be undone.")
        }
        .alert("Are you absolutely sure?", isPresented: $showDeleteAccountFinalConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete My Account", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    do {
                        try await appState.deleteAccount()
                    } catch {
                        deleteAccountError = error.localizedDescription
                    }
                    isDeletingAccount = false
                }
            }
        } message: {
            Text("Your account and all associated data will be permanently deleted. This cannot be undone.")
        }
        .alert("Couldn't Delete Account", isPresented: Binding(
            get: { deleteAccountError != nil },
            set: { if !$0 { deleteAccountError = nil } }
        )) {
            Button("OK", role: .cancel) { deleteAccountError = nil }
        } message: {
            Text(deleteAccountError ?? "")
        }
        .sheet(item: $feedbackKindToSend) { kind in
            FeedbackMailView(kind: kind) {
                feedbackKindToSend = nil
            }
        }
        .alert("Mail Not Available", isPresented: $showMailUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("We couldn't open a mail composer. The feedback address has been copied to your clipboard:\n\n\(AppConfiguration.feedbackEmail)")
        }
        .task {
            if let user = await SupabaseManager.shared.currentUser {
                userEmail = user.email ?? ""
            }
        }
    }

    private func handleFeedbackTap(_ kind: FeedbackKind) {
        if FeedbackPresenter.canSendInAppMail() {
            feedbackKindToSend = kind
        } else if !FeedbackPresenter.openMailtoFallback(for: kind) {
            showMailUnavailableAlert = true
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(appAccentColor)
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

// MARK: - Settings Row
struct SettingsRow: View {
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

// MARK: - Settings Button Row
struct SettingsButtonRow: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let icon: String
    let title: String
    let value: String?
    let action: () -> Void

    init(icon: String, title: String, value: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.value = value
        self.action = action
    }

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
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(.textSecondary)
            }
            .padding()
            .background(Color.cardBackground)
        }
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
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

// MARK: - Account Switch Row
struct AccountSwitchRow: View {
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
                        .font(.title3)
                        .foregroundColor(appAccentColor)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundColor(.textSecondary.opacity(0.3))
                }
            }
            .padding()
            .background(isSelected ? appAccentColor.opacity(0.1) : Color.cardBackground)
        }
    }
}

// MARK: - Role Option
struct RoleOption: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let role: MemberRole
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.displayName)
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)
                    
                    Text(role.description)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? appAccentColor : .textSecondary)
            }
            .padding()
            .background(isSelected ? appAccentColor.opacity(0.1) : Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(isSelected ? appAccentColor : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Mood History View
struct MoodHistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.sidePanelDismiss) private var sidePanelDismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @StateObject private var viewModel = MoodHistoryViewModel()

    /// Dismisses the view using side panel dismiss if available, otherwise standard dismiss
    private func dismissView() {
        if let sidePanelDismiss {
            sidePanelDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with Done button
            HStack {
                Text("Mood History")
                    .font(.appTitle2)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("Done") {
                    dismissView()
                }
                .font(.appBody)
                .foregroundColor(appAccentColor)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

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
                            //icon: "face.smiling",
                            title: "No mood entries yet",
                            message: "Start tracking your mood to see history here"
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.top, 16)
            }
        }
        .background(Color.appBackground)
        .task {
            await viewModel.loadEntries(appState: appState)
        }
    }
}

// MARK: - Mood Entry Row
struct MoodEntryRow: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let entry: MoodEntry

    private let moodEmojis = ["", "😢", "😕", "😐", "🙂", "😊"]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        HStack {
            Text(moodEmojis[safe: entry.rating] ?? "")
                .font(.title)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: entry.date))
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
                
                if let note = entry.note {
                    Text(note)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { rating in
                    Image(systemName: rating <= entry.rating ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundColor(appAccentColor)
                }
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Mood History View Model
@MainActor
class MoodHistoryViewModel: ObservableObject {
    @Published var entries: [MoodEntry] = []
    @Published var isLoading = false
    
    var averageRating: Double? {
        guard !entries.isEmpty else { return nil }
        let sum = entries.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(entries.count)
    }
    
    func loadEntries(appState: AppState) async {
        guard let account = appState.currentAccount else { return }
        
        isLoading = true
        
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        
        do {
            entries = try await appState.moodRepository.getEntries(
                accountId: account.id,
                from: thirtyDaysAgo,
                to: Date()
            )
        } catch {
            #if DEBUG
            print("Error loading mood entries: \(error)")
            #endif
        }
        
        isLoading = false
    }
}

// MARK: - Manage Members View
struct ManageMembersView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.sidePanelDismiss) private var sidePanelDismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @Environment(HeaderStyleManager.self) private var headerStyleManager
    @StateObject private var viewModel = ManageMembersViewModel()
    @State private var memberToRemove: MemberWithEmail?
    @State private var showRemoveConfirm = false
    @State private var isCheckmarkPressed = false


    /// Computed effective accent color (respects hasCustomAccentColor flag)
    private var effectiveAccentColor: Color {
        if userPreferences.hasCustomAccentColor {
            return userPreferences.accentColor
        } else {
            return headerStyleManager.defaultAccentColor
        }
    }
    /// Dismisses the view using side panel dismiss if available, otherwise standard dismiss
    private func dismissView() {
        if let sidePanelDismiss {
            sidePanelDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with Done button
            HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 18))
                            .foregroundColor(effectiveAccentColor)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(effectiveAccentColor.opacity(0.15))
                            )

                        Text("Manage Members")
                            .font(.appTitle)
                            .foregroundColor(.textPrimary)
                    }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCheckmarkPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        dismissView()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.appBody.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(15)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.15))
                        )
                        .scaleEffect(isCheckmarkPressed ? 0.85 : 1.1)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {

                        Text("View and manage who has access to this account.")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

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
                                        canRemove: memberWithEmail.member.role != .owner && !memberWithEmail.isCurrentUser,
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
                            //icon: "person.2",
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
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color.appBackground)
        .task {
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
                    }
                }
                memberToRemove = nil
            }
        } message: {
            if let member = memberToRemove {
                Text("Are you sure you want to remove \(member.email) from this account? They will lose access immediately.")
            }
        }
    }
}

// MARK: - Member Row
struct MemberRow: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let memberWithEmail: MemberWithEmail
    let canRemove: Bool
    let onRemove: (() -> Void)?

    init(memberWithEmail: MemberWithEmail, canRemove: Bool = false, onRemove: (() -> Void)? = nil) {
        self.memberWithEmail = memberWithEmail
        self.canRemove = canRemove
        self.onRemove = onRemove
    }

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundColor(appAccentColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(memberWithEmail.displayName ?? memberWithEmail.email)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)

                    if memberWithEmail.isCurrentUser {
                        Text("(you)")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }

                Text(memberWithEmail.member.role.displayName)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if memberWithEmail.member.role == .owner {
                Text("Owner")
                    .font(.appCaption)
                    .foregroundColor(appAccentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(appAccentColor.opacity(0.2))
                    .cornerRadius(8)
            } else if canRemove, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.medicalRed)
                        .font(.title2)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
    }
}

// MARK: - Invitation Row
struct InvitationRow: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let invitation: AccountInvitation
    let onRevoke: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "envelope.badge.fill")
                .foregroundColor(appAccentColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(invitation.email)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)

                HStack(spacing: 8) {
                    Text(invitation.role.displayName)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    Text("•")
                        .foregroundColor(.textSecondary)

                    Text("Code: \(invitation.inviteCode)")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Button(action: onRevoke) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.medicalRed)
            }
        }
        .padding()
        .background(Color.cardBackground)
    }
}

// MARK: - Member With Email
/// Wrapper to associate email with account member
struct MemberWithEmail: Identifiable {
    let member: AccountMember
    let email: String
    let displayName: String?
    let isCurrentUser: Bool

    var id: UUID { member.id }
}

// MARK: - Manage Members View Model
@MainActor
class ManageMembersViewModel: ObservableObject {
    @Published var membersWithEmail: [MemberWithEmail] = []
    @Published var pendingInvitations: [AccountInvitation] = []
    @Published var isLoading = false

    func loadData(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            // Load members
            let members = try await appState.accountRepository.getAccountMembers(accountId: account.id)

            // Load all invitations (accepted ones have email info)
            let allInvitations = try await appState.invitationRepository.getInvitations(accountId: account.id)

            // Get current user info
            let currentUserId = await SupabaseManager.shared.currentUserId
            let currentUserEmail = await SupabaseManager.shared.currentUser?.email

            // Fetch AppUser for current user to get display name
            var currentAppUser: AppUser?
            if let currentUserId = currentUserId {
                currentAppUser = try? await appState.appUserRepository.getUser(id: currentUserId)
            }

            // Build members with email
            var result: [MemberWithEmail] = []
            for member in members {
                let isCurrentUser = member.userId == currentUserId
                var email = "Unknown"
                var displayName: String?

                if isCurrentUser, let userEmail = currentUserEmail {
                    // Current user - use their auth email
                    email = userEmail
                    displayName = currentAppUser?.displayName
                } else {
                    // Other member - find their email from accepted invitation using acceptedBy field
                    if let acceptedInvitation = allInvitations.first(where: {
                        $0.status == .accepted && $0.acceptedBy == member.userId
                    }) {
                        email = acceptedInvitation.email
                    }

                    // Fallback for legacy data: try timestamp matching (within 60 seconds)
                    if email == "Unknown" {
                        if let acceptedInvitation = allInvitations.first(where: {
                            $0.status == .accepted &&
                            $0.acceptedBy == nil &&
                            $0.acceptedAt != nil &&
                            abs(($0.acceptedAt ?? Date.distantPast).timeIntervalSince(member.createdAt)) < 60
                        }) {
                            email = acceptedInvitation.email
                        }
                    }

                    // Try to fetch display name and email from app_users table
                    if let otherUser = try? await appState.appUserRepository.getUser(id: member.userId) {
                        displayName = otherUser.displayName
                        // Use app_users email as fallback (e.g. for owner who was never invited)
                        if email == "Unknown" {
                            email = otherUser.email
                        }
                    }
                }

                // If still no display name, try to find it from linked profile
                if displayName == nil {
                    let profiles: [Profile] = (try? await SupabaseManager.shared.client
                        .from(TableName.profiles)
                        .select()
                        .eq("linked_user_id", value: member.userId)
                        .limit(1)
                        .execute()
                        .value) ?? []
                    if let profile = profiles.first {
                        displayName = profile.displayName
                    }
                }

                result.append(MemberWithEmail(
                    member: member,
                    email: email,
                    displayName: displayName,
                    isCurrentUser: isCurrentUser
                ))
            }

            // Sort: owner first, then current user, then by email
            membersWithEmail = result.sorted { first, second in
                if first.member.role == .owner && second.member.role != .owner { return true }
                if first.member.role != .owner && second.member.role == .owner { return false }
                if first.isCurrentUser && !second.isCurrentUser { return true }
                if !first.isCurrentUser && second.isCurrentUser { return false }
                return first.email < second.email
            }

            // Filter pending invitations
            pendingInvitations = allInvitations.filter { $0.status == .pending && $0.isActive }
        } catch {
            #if DEBUG
            print("Error loading members: \(error)")
            #endif
        }

        isLoading = false
    }

    func revokeInvitation(_ invitation: AccountInvitation, appState: AppState) async {
        do {
            try await appState.invitationRepository.revokeInvitation(id: invitation.id)
            pendingInvitations.removeAll { $0.id == invitation.id }
        } catch {
            #if DEBUG
            print("Error revoking invitation: \(error)")
            #endif
        }
    }

    func removeMember(_ memberWithEmail: MemberWithEmail, appState: AppState) async {
        do {
            try await appState.accountRepository.removeMember(memberId: memberWithEmail.member.id)
            membersWithEmail.removeAll { $0.id == memberWithEmail.id }
        } catch {
            #if DEBUG
            print("Error removing member: \(error)")
            #endif
        }
    }
}

// MARK: - Switch Account View
struct SwitchAccountView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.sidePanelDismiss) private var sidePanelDismiss
    @Environment(\.appAccentColor) private var appAccentColor

    /// Dismisses the view using side panel dismiss if available, otherwise standard dismiss
    private func dismissView() {
        if let sidePanelDismiss {
            sidePanelDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with Done button
            HStack {
                Text("Switch Account")
                    .font(.appTitle2)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("Done") {
                    dismissView()
                }
                .font(.appBody)
                .foregroundColor(appAccentColor)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(appAccentColor)

                        Text("Switch Account")
                            .font(.appTitle)
                            .foregroundColor(.textPrimary)

                        Text("Select which account you would like to view")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Account List
                    VStack(spacing: 8) {
                        ForEach(appState.switchableAccounts) { accountWithRole in
                            AccountSwitchRow(
                                accountWithRole: accountWithRole,
                                isSelected: appState.currentAccount?.id == accountWithRole.account.id,
                                onSelect: {
                                    Task {
                                        await appState.switchAccount(to: accountWithRole)
                                        dismissView()
                                    }
                                }
                            )
                        }
                    }

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
            }
        }
        .background(Color.appBackground)
    }
}


// MARK: - Edit Account Name View
struct EditAccountNameView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.sidePanelDismiss) private var sidePanelDismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(HeaderStyleManager.self) private var headerStyleManager
    @State private var isCheckmarkPressed = false
    @State private var accountName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
   
    /// Computed effective accent color (respects hasCustomAccentColor flag)
    private var effectiveAccentColor: Color {
        if userPreferences.hasCustomAccentColor {
            return userPreferences.accentColor
        } else {
            return headerStyleManager.defaultAccentColor
        }
    }

    /// Dismisses the view using side panel dismiss if available, otherwise standard dismiss
    private func dismissView() {
        if let sidePanelDismiss {
            sidePanelDismiss()
        } else {
            dismiss()
        }
    }


    var body: some View {
        VStack(spacing: 0) {
            // Custom header with Done button
            HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 18))
                            .foregroundColor(effectiveAccentColor)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(effectiveAccentColor.opacity(0.15))
                            )

                        Text("Edit Account Name")
                            .font(.appTitle)
                            .foregroundColor(.textPrimary)
                    }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCheckmarkPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        dismissView()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.appBody.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(15)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.15))
                        )
                        .scaleEffect(isCheckmarkPressed ? 0.85 : 1.1)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {

                        Text("This name helps identify the account for family members.")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account Name")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        AppTextField(placeholder: "Enter account name", text: $accountName)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                            .multilineTextAlignment(.center)
                    }

                    PrimaryButton(title: "Save", isLoading: isLoading) {
                        Task { await saveAccountName() }
                    }
                    .disabled(accountName.isBlank)
                }
                .padding(AppDimensions.screenPadding)
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
            dismissView()
        } catch {
            isLoading = false
            errorMessage = "Failed to update account name: \(error.localizedDescription)"
        }
    }
}

// MARK: - Upgrade Settings Section
struct UpgradeSettingsSection: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadShowUpgradeAction) private var iPadShowUpgradeAction
    @State private var showUpgradeSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UPGRADE")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, AppDimensions.screenPadding)

            Button {
                if let action = iPadShowUpgradeAction {
                    action()
                } else {
                    showUpgradeSheet = true
                }
            } label: {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        // Image(systemName: "crown.fill")
                        //     .font(.system(size: 28))
                        //     .foregroundColor(appAccentColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upgrade Your Plan")
                                .font(.appBodyMedium)
                                .foregroundColor(.textPrimary)

                            Text("Get unlimited features and more")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.textSecondary)
                    }

                    // Tier highlights
                    HStack(spacing: 8) {
                        // Premium badge
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                            Text("Premium $5.99")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(appAccentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(appAccentColor.opacity(0.15))
                        .cornerRadius(8)

                        // Family Plus badge
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 8))
                            Text("Family Plus $9.99")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.medicalRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.medicalRed.opacity(0.15))
                        .cornerRadius(8)

                        Spacer()
                    }
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                        .stroke(appAccentColor.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppDimensions.screenPadding)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
        }
    }
}

// MARK: - Upgrade View
struct UpgradeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sidePanelDismiss) private var sidePanelDismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var selectedProduct: Product? = nil
    @State private var purchaseState: PurchaseState = .idle
    @State private var errorMessage: String? = nil
    @State private var selectedTier: SelectedTier = .premium
    @State private var fallbackSelection: FallbackPricing = .premiumMonthly

    private let subscriptionManager = SubscriptionManager.shared

    /// When true, the view is embedded in a panel and should not show NavigationStack or cancel button
    var isEmbedded: Bool = false

    private enum PurchaseState {
        case idle
        case loading
        case purchasing
        case success
    }

    private enum SelectedTier {
        case premium
        case familyPlus
    }

    private enum FallbackPricing {
        case premiumMonthly, premiumAnnual
        case familyMonthly, familyAnnual
    }

    // Premium features list
    private let premiumFeatures: [(icon: String, text: String)] = [
        ("infinity", "Unlimited profiles, contacts, reminders and more"),
        ("calendar", "Unlimited appointments & Events"),
        ("bell.badge", "Unlimited Medications")
    ]

    // Family Plus features list
    private let familyPlusFeatures: [(icon: String, text: String)] = [
        ("checkmark.circle.fill", "Everything in Premium"),
        ("person.badge.plus", "Collaborate with family"),
        ("person.2", "Manage account members")
    ]

    /// Dismisses the view using side panel dismiss if available, otherwise standard dismiss
    private func dismissView() {
        if let sidePanelDismiss {
            sidePanelDismiss()
        } else {
            dismiss()
        }
    }

    private var tierColor: Color {
        selectedTier == .premium ? appAccentColor : .medicalRed
    }

    var body: some View {
        Group {
            if isEmbedded {
                upgradeContent
            } else {
                VStack(spacing: 0) {
                    // Custom header with Cancel button
                    HStack {
                        Button("Cancel") {
                            dismissView()
                        }
                        .font(.appBody)
                        .foregroundColor(appAccentColor)

                        Spacer()

                        Text("Upgrade")
                            .font(.appTitle2)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        // Invisible spacer for centering
                        Text("Cancel").opacity(0)
                            .font(.appBody)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.vertical, 16)
                    .background(Color.appBackground)

                    upgradeContent
                }
            }
        }
        .task {
            await loadProducts()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationSizing(.fitted)
    }

    private var upgradeContent: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        // Image(systemName: "crown.fill")
                        //     .font(.system(size: 60))
                        //     .foregroundColor(tierColor)

                        Text("Upgrade Your Plan")
                            .font(.appLargeTitle)
                            .foregroundColor(.textPrimary)

                        Text("Get the most out of Unforgotten")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 24)

                    // Tier selector
                    tierSelector
                        .padding(.horizontal, AppDimensions.screenPadding)

                    // Features list for selected tier
                    VStack(spacing: 10) {
                        let features = selectedTier == .premium ? premiumFeatures : familyPlusFeatures
                        ForEach(features, id: \.text) { feature in
                            HStack(spacing: 12) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(tierColor)
                                    .frame(width: 24)

                                Text(feature.text)
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.badgeGreen)
                            }
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(AppDimensions.cardCornerRadius)
                        }
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)

                    // Pricing
                    if purchaseState == .loading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: tierColor))
                            .padding()
                    } else {
                        pricingSection
                            .padding(.horizontal, AppDimensions.screenPadding)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppDimensions.screenPadding)
                    }

                    // Subscribe button
                    VStack(spacing: 12) {
                        if purchaseState == .success {
                            PrimaryButton(
                                title: "Done",
                                backgroundColor: tierColor,
                                action: { dismissView() }
                            )
                        } else {
                            PrimaryButton(
                                title: "Subscribe to \(selectedTier == .premium ? "Premium" : "Family Plus")",
                                isLoading: purchaseState == .purchasing,
                                backgroundColor: tierColor,
                                action: purchase
                            )

                            Button {
                                Task {
                                    await restorePurchases()
                                }
                            } label: {
                                Text("Restore Purchases")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)

                    // Terms
                    VStack(spacing: 8) {
                        Text("Subscription auto-renews unless cancelled at least 24 hours before the end of the current period.")
                            .font(.system(size: 10))
                            .foregroundColor(.textMuted)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            Button("Terms of Use") { }
                                .font(.system(size: 10))
                                .foregroundColor(.textSecondary)

                            Button("Privacy Policy") { }
                                .font(.system(size: 10))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Tier Selector
    private var tierSelector: some View {
        HStack(spacing: 0) {
            // Premium tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTier = .premium
                    updateSelectedProduct()
                }
            } label: {
                VStack(spacing: 4) {
                    Text("Premium")
                        .font(.appBodyMedium)
                        .foregroundColor(selectedTier == .premium ? .textPrimary : .textSecondary)
                    Text(premiumMonthlyDisplayPrice + "/mo")
                        .font(.appCaption)
                        .foregroundColor(selectedTier == .premium ? appAccentColor : .textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedTier == .premium ? appAccentColor.opacity(0.15) : Color.clear)
                .cornerRadius(12)
            }

            // Family Plus tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTier = .familyPlus
                    updateSelectedProduct()
                }
            } label: {
                VStack(spacing: 4) {
                    Text("Family Plus")
                        .font(.appBodyMedium)
                        .foregroundColor(selectedTier == .familyPlus ? .textPrimary : .textSecondary)
                    Text(familyMonthlyDisplayPrice + "/mo")
                        .font(.appCaption)
                        .foregroundColor(selectedTier == .familyPlus ? .medicalRed : .textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedTier == .familyPlus ? Color.medicalRed.opacity(0.15) : Color.clear)
                .cornerRadius(12)
            }
        }
        .padding(4)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Pricing Section
    private var pricingSection: some View {
        VStack(spacing: 12) {
            let tierProducts = productsForSelectedTier
            if tierProducts.isEmpty {
                // Fallback when StoreKit products haven't loaded yet
                if selectedTier == .premium {
                    Button {
                        fallbackSelection = .premiumMonthly
                    } label: {
                        upgradePricingCard(
                            title: "Monthly",
                            price: premiumMonthlyDisplayPrice + "/month",
                            isSelected: fallbackSelection == .premiumMonthly,
                            isBestValue: false
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        fallbackSelection = .premiumAnnual
                    } label: {
                        upgradePricingCard(
                            title: "Annual",
                            price: premiumAnnualDisplayPrice + "/year",
                            subtitle: "Save 44%",
                            isSelected: fallbackSelection == .premiumAnnual,
                            isBestValue: true
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        fallbackSelection = .familyMonthly
                    } label: {
                        upgradePricingCard(
                            title: "Monthly",
                            price: familyMonthlyDisplayPrice + "/month",
                            isSelected: fallbackSelection == .familyMonthly,
                            isBestValue: false
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        fallbackSelection = .familyAnnual
                    } label: {
                        upgradePricingCard(
                            title: "Annual",
                            price: familyAnnualDisplayPrice + "/year",
                            subtitle: "Save 42%",
                            isSelected: fallbackSelection == .familyAnnual,
                            isBestValue: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(tierProducts.sorted { $0.price < $1.price }) { product in
                    let isSelected = selectedProduct?.id == product.id
                    let isAnnual = product.id.contains("annual")

                    Button {
                        selectedProduct = product
                    } label: {
                        upgradePricingCard(
                            title: isAnnual ? "Annual" : "Monthly",
                            price: product.displayPrice + (isAnnual ? "/year" : "/month"),
                            subtitle: isAnnual ? "Save over 40%" : nil,
                            isSelected: isSelected,
                            isBestValue: isAnnual
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var productsForSelectedTier: [Product] {
        let tier: SubscriptionTier = selectedTier == .premium ? .premium : .familyPlus
        return subscriptionManager.products(for: tier)
    }

    private var premiumMonthlyDisplayPrice: String {
        subscriptionManager.product(for: .premium, period: .monthly)?.displayPrice ?? "---"
    }

    private var premiumAnnualDisplayPrice: String {
        subscriptionManager.product(for: .premium, period: .annual)?.displayPrice ?? "---"
    }

    private var familyMonthlyDisplayPrice: String {
        subscriptionManager.product(for: .familyPlus, period: .monthly)?.displayPrice ?? "---"
    }

    private var familyAnnualDisplayPrice: String {
        subscriptionManager.product(for: .familyPlus, period: .annual)?.displayPrice ?? "---"
    }

    private func updateSelectedProduct() {
        let tier: SubscriptionTier = selectedTier == .premium ? .premium : .familyPlus
        selectedProduct = subscriptionManager.product(for: tier, period: .annual)
            ?? subscriptionManager.products(for: tier).first
        // Update fallback selection to match tier
        fallbackSelection = selectedTier == .premium ? .premiumMonthly : .familyMonthly
    }

    private func upgradePricingCard(
        title: String,
        price: String,
        subtitle: String? = nil,
        isSelected: Bool,
        isBestValue: Bool
    ) -> some View {
        VStack(spacing: 0) {
            if isBestValue {
                Text("BEST VALUE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(tierColor)
                    .clipShape(Capsule())
                    .offset(y: 12)
                    .zIndex(1)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    Text(price)
                        .font(.appTitle)
                        .foregroundColor(.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.appCaption)
                            .foregroundColor(tierColor)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(tierColor)
                }
            }
            .padding(20)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(isSelected ? tierColor : Color.cardBackgroundLight, lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    private func loadProducts() async {
        purchaseState = .loading
        await subscriptionManager.loadProducts()
        // Select annual premium by default
        selectedProduct = subscriptionManager.product(for: .premium, period: .annual)
            ?? subscriptionManager.products(for: .premium).first
        purchaseState = .idle
    }

    private func purchase() {
        purchaseState = .purchasing
        errorMessage = nil

        Task {
            // If no product selected, try loading products first
            if selectedProduct == nil && productsForSelectedTier.isEmpty {
                await subscriptionManager.loadProducts()
                updateSelectedProduct()
            }

            guard let product = selectedProduct ?? productsForSelectedTier.first else {
                errorMessage = "Unable to load subscription products. Please check your connection and try again."
                purchaseState = .idle
                return
            }

            do {
                let transaction = try await subscriptionManager.purchase(product)

                if transaction != nil {
                    // SubscriptionManager already updated tier and UserDefaults
                    appState.objectWillChange.send()
                    purchaseState = .success
                } else {
                    // User cancelled
                    purchaseState = .idle
                }
            } catch let error as SubscriptionError {
                errorMessage = error.localizedDescription
                purchaseState = .idle
            } catch {
                errorMessage = "Purchase failed. Please try again."
                purchaseState = .idle
                #if DEBUG
                print("Purchase error: \(error)")
                #endif
            }
        }
    }

    private func restorePurchases() async {
        do {
            try await subscriptionManager.restorePurchases()

            if subscriptionManager.subscriptionTier != .free {
                appState.objectWillChange.send()
                selectedTier = subscriptionManager.subscriptionTier == .familyPlus ? .familyPlus : .premium
                purchaseState = .success
            } else {
                errorMessage = "No active subscription found."
            }
        } catch {
            errorMessage = "Failed to restore purchases."
            #if DEBUG
            print("Restore error: \(error)")
            #endif
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState.forPreview())
            .environment(UserPreferences())
            .environment(UserHeaderOverrides())
            .environment(HeaderStyleManager())
            .environment(FeatureVisibilityManager())
    }
}
