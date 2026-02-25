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
    @Environment(\.iPadShowUpgradeAction) private var iPadShowUpgradeAction

    let onClose: () -> Void

    @State private var showSignOutConfirm = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var userEmail: String = ""
    @State private var allowNotifications: Bool = NotificationService.shared.allowNotifications
    @State private var hideNotificationPreviews: Bool = NotificationService.shared.hideNotificationPreviews

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
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
            .task {
                if let user = await SupabaseManager.shared.currentUser {
                    userEmail = user.email ?? ""
                }
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

                            // Switch Account (only show if multiple accounts)
                            if appState.allAccounts.count > 1 {
                                SettingsPanelButtonRow(
                                    icon: "arrow.left.arrow.right",
                                    title: "Switch Account",
                                    isSelected: false
                                ) {
                                    iPadShowSwitchAccountAction?()
                                }
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
