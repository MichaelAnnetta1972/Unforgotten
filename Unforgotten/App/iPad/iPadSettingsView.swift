//
//  iPadSettingsView.swift
//  Unforgotten
//
//  iPad-specific Settings view for the content area
//

import SwiftUI

// MARK: - iPad Settings Content View
/// Full-panel Settings view for the iPad content area with full-screen overlays
struct iPadSettingsContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @Environment(FeatureVisibilityManager.self) private var featureVisibility
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction

    // iPad environment actions for full-screen overlays
    @Environment(\.iPadShowManageMembersAction) private var iPadShowManageMembersAction
    @Environment(\.iPadShowMoodHistoryAction) private var iPadShowMoodHistoryAction
    @Environment(\.iPadShowAppearanceSettingsAction) private var iPadShowAppearanceSettingsAction
    @Environment(\.iPadShowFeatureVisibilityAction) private var iPadShowFeatureVisibilityAction
    @Environment(\.iPadShowSwitchAccountAction) private var iPadShowSwitchAccountAction
    @Environment(\.iPadShowEditAccountNameAction) private var iPadShowEditAccountNameAction
    @Environment(\.iPadShowAdminPanelAction) private var iPadShowAdminPanelAction
    @Environment(\.iPadShowHelpTutorialsAction) private var iPadShowHelpTutorialsAction
    @Environment(\.iPadShowUpgradeAction) private var iPadShowUpgradeAction
    @Environment(\.iPadShowJoinAccountAction) private var iPadShowJoinAccountAction

    let onClose: () -> Void

    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showDeleteAccountFinalConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showRecentlyDeleted = false
    @State private var feedbackKindToSend: FeedbackKind?
    @State private var showMailUnavailableAlert = false
    @State private var userEmail: String = ""
    @State private var allowNotifications: Bool = NotificationService.shared.allowNotifications
    @State private var hideNotificationPreviews: Bool = NotificationService.shared.hideNotificationPreviews
    @State private var morningBriefingEnabled: Bool = NotificationService.shared.dailySummaryEnabled

    var body: some View {
        settingsListView
            .background(Color.appBackgroundLight)
            .navigationBarHidden(true)
            .alert("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await appState.signOut()
                        onClose()
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
                            onClose()
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
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showRecentlyDeleted) {
                RecentlyDeletedView()
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

    // MARK: - Settings List View

    private var settingsListView: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    CustomizableHeaderView(
                        pageIdentifier: .settings,
                        title: "Settings",
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction
                    )

                    VStack(spacing: 24) {
                        // Viewing As Bar (shown when viewing another account)
                        ViewingAsBar(showOnIPad: true)
                            .padding(.horizontal, AppDimensions.screenPadding)

                        // Appearance section
                        SettingsPanelSection(title: "APPEARANCE") {
                            SettingsPanelButtonRow(
                                icon: "paintpalette",
                                title: "Colors & Headers",
                                isSelected: false
                            ) {
                                iPadShowAppearanceSettingsAction?()
                            }
                        }

                        // Features section
                        SettingsPanelSection(title: "FEATURES") {
                            SettingsPanelButtonRow(
                                icon: "square.grid.2x2",
                                title: "Show/Hide Features",
                                isSelected: false
                            ) {
                                iPadShowFeatureVisibilityAction?()
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

                                SettingsPanelToggleRow(
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

                        // Account section
                        SettingsPanelSection(title: "ACCOUNT") {
                            if let account = appState.currentAccount {
                                // Only owner/admin can edit account name
                                if appState.currentUserRole?.canManageMembers == true {
                                    SettingsPanelButtonRowWithValue(
                                        icon: "person.circle",
                                        title: "Account Name",
                                        value: account.displayName,
                                        isSelected: false
                                    ) {
                                        iPadShowEditAccountNameAction?()
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

                                SettingsPanelInfoRow(
                                    icon: appState.subscriptionTier == .free ? "star" : "star.fill",
                                    title: "Current Plan",
                                    value: appState.subscriptionTier.displayName
                                )
                            }

                            // Only show manage members if user can manage members
                            if appState.currentUserRole?.canManageMembers == true {
                                SettingsPanelButtonRow(
                                    icon: "person.2",
                                    title: "Manage Members",
                                    isSelected: false
                                ) {
                                    iPadShowManageMembersAction?()
                                }
                            }

                            // Switch Account (only show for Family Plus with multiple accounts)
                            if appState.subscriptionTier.hasFamilyFeatures && appState.switchableAccounts.count > 1 {
                                SettingsPanelButtonRow(
                                    icon: "arrow.left.arrow.right",
                                    title: "Switch Account",
                                    isSelected: false
                                ) {
                                    iPadShowSwitchAccountAction?()
                                }
                            }

                            // Join an Account
                            SettingsPanelButtonRow(
                                icon: "person.badge.plus",
                                title: "Join an Account",
                                isSelected: false
                            ) {
                                iPadShowJoinAccountAction?()
                            }
                        }

                        // Mood section
                        SettingsPanelSection(title: "MOOD") {
                            SettingsPanelButtonRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "View Mood History",
                                isSelected: false
                            ) {
                                iPadShowMoodHistoryAction?()
                            }
                        }

                        // Upgrade section (only show if not premium)
                        if !appState.hasPremiumAccess {
                            SettingsPanelSection(title: "UPGRADE") {
                                SettingsPanelButtonRow(
                                    icon: "star.fill",
                                    title: "Upgrade to Premium",
                                    isSelected: false
                                ) {
                                    iPadShowUpgradeAction?()
                                }
                            }
                        }

                        // Admin section (only visible to app admins)
                        if appState.isAppAdmin {
                            SettingsPanelSection(title: "APP ADMINISTRATION") {
                                SettingsPanelButtonRow(
                                    icon: "crown.fill",
                                    title: "Admin Panel",
                                    isSelected: false
                                ) {
                                    iPadShowAdminPanelAction?()
                                }
                            }
                        }

                        // Data section
                        SettingsPanelSection(title: "DATA") {
                            SettingsPanelButtonRow(
                                icon: "trash",
                                title: "Recently Deleted",
                                isSelected: false
                            ) {
                                showRecentlyDeleted = true
                            }
                            SyncStatusSettingsRow(syncEngine: appState.syncEngine)
                        }

                        // Support section
                        SettingsPanelSection(title: "SUPPORT") {
                            SettingsPanelButtonRow(
                                icon: "questionmark.circle.fill",
                                title: "Help & Tutorials",
                                isSelected: false
                            ) {
                                iPadShowHelpTutorialsAction?()
                            }

                            SettingsPanelButtonRow(
                                icon: "ladybug",
                                title: "Report a Bug",
                                isSelected: false
                            ) {
                                handleFeedbackTap(.bugReport)
                            }

                            SettingsPanelButtonRow(
                                icon: "bubble.left.and.bubble.right",
                                title: "Send Feedback",
                                isSelected: false
                            ) {
                                handleFeedbackTap(.generalFeedback)
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
                                icon: "star",
                                title: "Rate Unforgotten",
                                isSelected: false
                            ) {
                                ReviewRequestService.shared.openAppStoreReviewPage()
                            }

                            SettingsPanelButtonRow(
                                icon: "lock.shield",
                                title: "Privacy Policy",
                                isSelected: false
                            ) {
                                showPrivacyPolicy = true
                            }

                            SettingsPanelButtonRow(
                                icon: "doc.text",
                                title: "Terms of Service",
                                isSelected: false
                            ) {
                                showTermsOfService = true
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
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}
