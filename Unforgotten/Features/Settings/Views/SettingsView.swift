import SwiftUI
import UIKit
import StoreKit

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @Environment(HeaderStyleManager.self) private var headerStyleManager
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(FeatureVisibilityManager.self) private var featureVisibility

    // iPad environment actions
    @Environment(\.iPadShowInviteMemberAction) private var iPadShowInviteMemberAction
    @Environment(\.iPadShowManageMembersAction) private var iPadShowManageMembersAction
    @Environment(\.iPadShowJoinAccountAction) private var iPadShowJoinAccountAction
    @Environment(\.iPadShowMoodHistoryAction) private var iPadShowMoodHistoryAction
    @Environment(\.iPadShowAppearanceSettingsAction) private var iPadShowAppearanceSettingsAction
    @Environment(\.iPadShowFeatureVisibilityAction) private var iPadShowFeatureVisibilityAction
    @Environment(\.iPadShowSwitchAccountAction) private var iPadShowSwitchAccountAction
    @Environment(\.iPadShowEditAccountNameAction) private var iPadShowEditAccountNameAction
    @Environment(\.iPadShowAdminPanelAction) private var iPadShowAdminPanelAction
    @Environment(\.iPadShowUpgradeAction) private var iPadShowUpgradeAction

    @State private var showInviteMember = false
    @State private var showManageMembers = false
    @State private var showJoinAccount = false
    @State private var showMoodHistory = false
    @State private var showSignOutConfirm = false
    @State private var showAppearanceSettings = false
    @State private var showFeatureVisibility = false
    @State private var showSwitchAccount = false
    @State private var showEditAccountName = false
    @State private var showAdminPanel = false
    @State private var showUpgradeForInvite = false
    @State private var showUpgradeForJoin = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    /// Helper/Viewer roles have limited access
    private var isLimitedAccess: Bool {
        appState.currentUserRole == .helper || appState.currentUserRole == .viewer
    }

    /// Check if user has premium access (subscription or complimentary)
    private var isPremiumUser: Bool {
        appState.hasPremiumAccess
    }

    /// Check if user can invite members (premium feature)
    private var canInviteMembers: Bool {
        PremiumLimitsManager.shared.canInviteMembers(appState: appState)
    }

    /// Check if user can join other accounts (premium feature)
    private var canJoinOtherAccounts: Bool {
        PremiumLimitsManager.shared.canJoinOtherAccounts(appState: appState)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 50))
                            .foregroundColor(appAccentColor)

                        Text("Settings")
                            .font(.appLargeTitle)
                            .foregroundColor(.textPrimary)
                    }
                    .padding(.top, 40)

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

                            if let role = appState.currentUserRole {
                                SettingsRow(
                                    icon: "person.badge.shield.checkmark",
                                    title: "Your Role",
                                    value: role.displayName
                                )
                            }
                        }

                        // Only show invite/manage if user can manage members
                        if appState.currentUserRole?.canManageMembers == true {
                            SettingsButtonRow(
                                icon: canInviteMembers ? "person.badge.plus" : "crown.fill",
                                title: "Invite Family Member",
                                value: canInviteMembers ? nil : "Premium",
                                action: {
                                    if canInviteMembers {
                                        if let action = iPadShowInviteMemberAction {
                                            action()
                                        } else {
                                            showInviteMember = true
                                        }
                                    } else {
                                        if let action = iPadShowUpgradeAction {
                                            action()
                                        } else {
                                            showUpgradeForInvite = true
                                        }
                                    }
                                }
                            )

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

                        SettingsButtonRow(
                            icon: canJoinOtherAccounts ? "envelope.badge" : "crown.fill",
                            title: "Join Another Account",
                            value: canJoinOtherAccounts ? nil : "Premium",
                            action: {
                                if canJoinOtherAccounts {
                                    if let action = iPadShowJoinAccountAction {
                                        action()
                                    } else {
                                        showJoinAccount = true
                                    }
                                } else {
                                    if let action = iPadShowUpgradeAction {
                                        action()
                                    } else {
                                        showUpgradeForJoin = true
                                    }
                                }
                            }
                        )

                        // Switch Account (only show if multiple accounts)
                        if appState.allAccounts.count > 1 {
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
                    }

                    // Mood section (only for full access)
                    if appState.hasFullAccess {
                        SettingsSection(title: "MOOD") {
                            SettingsButtonRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "View Mood History",
                                action: {
                                    if let action = iPadShowMoodHistoryAction {
                                        action()
                                    } else {
                                        showMoodHistory = true
                                    }
                                }
                            )
                        }
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

                    // About section
                    SettingsSection(title: "ABOUT") {
                        SettingsRow(
                            icon: "info.circle",
                            title: "Version",
                            value: "1.0.0"
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
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sidePanel(isPresented: $showInviteMember) {
            InviteMemberView()
        }
        .sidePanel(isPresented: $showManageMembers) {
            ManageMembersView()
        }
        .sidePanel(isPresented: $showJoinAccount) {
            JoinAccountView()
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
        .sidePanel(isPresented: $showUpgradeForInvite) {
            UpgradeView()
        }
        .sidePanel(isPresented: $showUpgradeForJoin) {
            UpgradeView()
        }
        .sidePanel(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sidePanel(isPresented: $showTermsOfService) {
            TermsOfServiceView()
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
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
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

// MARK: - Invite Member View
struct InviteMemberView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    @State private var email = ""
    @State private var selectedRole: MemberRole = .helper
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var inviteCode: String = ""
    @State private var showShareSheet = false

    private let availableRoles: [MemberRole] = [.admin, .helper, .viewer]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Explanation
                        VStack(spacing: 12) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(appAccentColor)
                            
                            Text("Invite Family Member")
                                .font(.appTitle)
                                .foregroundColor(.textPrimary)
                            
                            Text("Share access to this account with a family member or carer.")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)
                        
                        // Email input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email Address")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                            
                            AppTextField(placeholder: "Enter email", text: $email, keyboardType: .emailAddress)
                        }
                        
                        // Role picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Role")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                            
                            ForEach(availableRoles, id: \.self) { role in
                                RoleOption(
                                    role: role,
                                    isSelected: selectedRole == role,
                                    action: { selectedRole = role }
                                )
                            }
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                        }
                        
                        PrimaryButton(title: "Send Invitation", isLoading: isLoading) {
                            Task { await sendInvite() }
                        }
                        .disabled(email.isBlank || !email.isValidEmail)
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Invitation Created", isPresented: $showSuccess) {
                Button("Copy Code") {
                    UIPasteboard.general.string = inviteCode
                    dismiss()
                }
                Button("Share") {
                    showShareSheet = true
                }
                Button("Done", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Share this code with \(email):\n\n\(inviteCode)\n\nThe code expires in 7 days.")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareMessage])
                    .onDisappear {
                        dismiss()
                    }
            }
        }
    }

    private var shareMessage: String {
        guard let accountName = appState.currentAccount?.displayName else {
            return "Join me on Unforgotten! Use code: \(inviteCode)"
        }
        return "You've been invited to join \"\(accountName)\" on Unforgotten!\n\nUse this code to join: \(inviteCode)\n\nDownload the app and enter this code in Settings > Join Another Account."
    }

    private func sendInvite() async {
        guard let account = appState.currentAccount,
              let userId = await SupabaseManager.shared.currentUserId else {
            errorMessage = "Unable to send invitation. Please try again."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let invitation = try await appState.invitationRepository.createInvitation(
                accountId: account.id,
                email: email,
                role: selectedRole,
                invitedBy: userId
            )

            // Store the invite code for sharing
            inviteCode = invitation.inviteCode
            isLoading = false
            showSuccess = true
        } catch {
            isLoading = false
            errorMessage = "Failed to create invitation: \(error.localizedDescription)"
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
    @Environment(\.appAccentColor) private var appAccentColor
    @StateObject private var viewModel = MoodHistoryViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
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
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Mood History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(appAccentColor)
                }
            }
            .task {
                await viewModel.loadEntries(appState: appState)
            }
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
            print("Error loading mood entries: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Manage Members View
struct ManageMembersView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @StateObject private var viewModel = ManageMembersViewModel()
    @State private var memberToRemove: MemberWithEmail?
    @State private var showRemoveConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 50))
                                .foregroundColor(appAccentColor)

                            Text("Manage Members")
                                .font(.appTitle)
                                .foregroundColor(.textPrimary)

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
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Manage Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(appAccentColor)
                }
            }
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
                    Text(memberWithEmail.email)
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

            // Build members with email
            var result: [MemberWithEmail] = []
            for member in members {
                let isCurrentUser = member.userId == currentUserId
                var email = "Unknown"

                if isCurrentUser, let userEmail = currentUserEmail {
                    // Current user - use their auth email
                    email = userEmail
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
                            abs($0.acceptedAt!.timeIntervalSince(member.createdAt)) < 60
                        }) {
                            email = acceptedInvitation.email
                        }
                    }
                }

                result.append(MemberWithEmail(
                    member: member,
                    email: email,
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
            print("Error loading members: \(error)")
        }

        isLoading = false
    }

    func revokeInvitation(_ invitation: AccountInvitation, appState: AppState) async {
        do {
            try await appState.invitationRepository.revokeInvitation(id: invitation.id)
            pendingInvitations.removeAll { $0.id == invitation.id }
        } catch {
            print("Error revoking invitation: \(error)")
        }
    }

    func removeMember(_ memberWithEmail: MemberWithEmail, appState: AppState) async {
        do {
            try await appState.accountRepository.removeMember(memberId: memberWithEmail.member.id)
            membersWithEmail.removeAll { $0.id == memberWithEmail.id }
        } catch {
            print("Error removing member: \(error)")
        }
    }
}

// MARK: - Switch Account View
struct SwitchAccountView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

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
                            ForEach(appState.allAccounts) { accountWithRole in
                                AccountSwitchRow(
                                    accountWithRole: accountWithRole,
                                    isSelected: appState.currentAccount?.id == accountWithRole.account.id,
                                    onSelect: {
                                        Task {
                                            await appState.switchAccount(to: accountWithRole)
                                            dismiss()
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
            .navigationTitle("Switch Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(appAccentColor)
                }
            }
        }
    }
}

// MARK: - Join Account View
struct JoinAccountView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var joinedAccountName: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "envelope.badge")
                                .font(.system(size: 50))
                                .foregroundColor(appAccentColor)

                            Text("Join Another Account")
                                .font(.appTitle)
                                .foregroundColor(.textPrimary)

                            Text("Enter the invitation code you received to join a family account.")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)

                        // Code input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Invitation Code")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            TextField("", text: $inviteCode)
                                .textFieldStyle(.plain)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(AppDimensions.cardCornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                                        .stroke(appAccentColor.opacity(0.3), lineWidth: 1)
                                )
                                .onChange(of: inviteCode) { _, newValue in
                                    // Limit to 6 characters and uppercase
                                    inviteCode = String(newValue.uppercased().prefix(6))
                                }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                                .multilineTextAlignment(.center)
                        }

                        PrimaryButton(title: "Join Account", isLoading: isLoading) {
                            Task { await joinAccount() }
                        }
                        .disabled(inviteCode.count != 6)
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .navigationTitle("Join Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Account Joined!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("You have successfully joined \"\(joinedAccountName)\". You can now access this account from the home screen.")
            }
        }
    }

    private func joinAccount() async {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            errorMessage = "You must be signed in to join an account."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Look up the invitation
            guard let invitation = try await appState.invitationRepository.getInvitationByCode(inviteCode) else {
                errorMessage = "Invalid invitation code. Please check and try again."
                isLoading = false
                return
            }

            // Check if invitation is still valid
            guard invitation.isActive else {
                if invitation.status == .expired || !invitation.isActive {
                    errorMessage = "This invitation has expired."
                } else if invitation.status == .revoked {
                    errorMessage = "This invitation has been revoked."
                } else if invitation.status == .accepted {
                    errorMessage = "This invitation has already been used."
                } else {
                    errorMessage = "This invitation is no longer valid."
                }
                isLoading = false
                return
            }

            // Accept the invitation first (adds user as account member)
            try await appState.invitationRepository.acceptInvitation(invitation: invitation, userId: userId)

            // Now fetch the account name (user has RLS permission after being added as member)
            let account = try await appState.accountRepository.getAccount(id: invitation.accountId)
            joinedAccountName = account.displayName

            // Reload account data
            await appState.loadAccountData()

            isLoading = false
            showSuccess = true
        } catch {
            isLoading = false
            errorMessage = "Failed to join account: \(error.localizedDescription)"
        }
    }
}

// MARK: - Edit Account Name View
struct EditAccountNameView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    @State private var accountName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 50))
                                .foregroundColor(appAccentColor)

                            Text("Edit Account Name")
                                .font(.appTitle)
                                .foregroundColor(.textPrimary)

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
            .navigationTitle("Edit Account Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                accountName = appState.currentAccount?.displayName ?? ""
            }
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
            dismiss()
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

    private let premiumFeatures = [
        "Unlimited friends",
        "Unlimited reminders",
        "Unlimited notes",
        "Unlimited medications",
        "Priority support",
        "Family sharing"
    ]

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
                        Image(systemName: "crown.fill")
                            .font(.system(size: 28))
                            .foregroundColor(appAccentColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upgrade to Premium")
                                .font(.appBodyMedium)
                                .foregroundColor(.textPrimary)

                            Text("Unlock all features")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.textSecondary)
                    }

                    // Feature highlights
                    HStack(spacing: 8) {
                        ForEach(["Unlimited", "Priority Support", "Family Sharing"], id: \.self) { feature in
                            Text(feature)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(appAccentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(appAccentColor.opacity(0.15))
                                .cornerRadius(8)
                        }
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var products: [Product] = []
    @State private var selectedProduct: Product? = nil
    @State private var purchaseState: PurchaseState = .idle
    @State private var errorMessage: String? = nil

    /// When true, the view is embedded in a panel and should not show NavigationStack or cancel button
    var isEmbedded: Bool = false

    private enum PurchaseState {
        case idle
        case loading
        case purchasing
        case success
    }

    private let productIds = [
        "com.unforgotten.premium.monthly",
        "com.unforgotten.premium.annual"
    ]

    private let premiumFeatures = [
        ("infinity", "Unlimited friends"),
        ("bell.badge", "Unlimited reminders"),
        ("note.text", "Unlimited notes"),
        ("pill", "Unlimited medications"),
        ("star.fill", "Priority support"),
        ("person.2", "Family sharing")
    ]

    var body: some View {
        Group {
            if isEmbedded {
                upgradeContent
            } else {
                NavigationStack {
                    upgradeContent
                        .navigationTitle("Premium")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    dismiss()
                                }
                            }
                        }
                }
            }
        }
        .task {
            await loadProducts()
        }
    }

    private var upgradeContent: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 60))
                                .foregroundColor(appAccentColor)

                            Text("Upgrade to Premium")
                                .font(.appLargeTitle)
                                .foregroundColor(.textPrimary)

                            Text("Get the most out of Unforgotten")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.top, 24)

                        // Features list
                        VStack(spacing: 12) {
                            ForEach(premiumFeatures, id: \.1) { icon, feature in
                                HStack(spacing: 14) {
                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(appAccentColor)
                                        .frame(width: 28)

                                    Text(feature)
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
                                .progressViewStyle(CircularProgressViewStyle(tint: appAccentColor))
                                .padding()
                        } else if products.isEmpty {
                            // Fallback pricing
                            VStack(spacing: 12) {
                                upgradePricingCard(
                                    title: "Monthly",
                                    price: "$4.99/month",
                                    isSelected: true,
                                    isBestValue: false
                                )

                                upgradePricingCard(
                                    title: "Annual",
                                    price: "$39.99/year",
                                    subtitle: "Save 33%",
                                    isSelected: false,
                                    isBestValue: true
                                )
                            }
                            .padding(.horizontal, AppDimensions.screenPadding)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(products.sorted { $0.price < $1.price }) { product in
                                    let isSelected = selectedProduct?.id == product.id
                                    let isAnnual = product.id.contains("annual")

                                    Button {
                                        selectedProduct = product
                                    } label: {
                                        upgradePricingCard(
                                            title: isAnnual ? "Annual" : "Monthly",
                                            price: product.displayPrice + (isAnnual ? "/year" : "/month"),
                                            subtitle: isAnnual ? "Save 33%" : nil,
                                            isSelected: isSelected,
                                            isBestValue: isAnnual
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
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
                                    backgroundColor: appAccentColor,
                                    action: { dismiss() }
                                )
                            } else {
                                PrimaryButton(
                                    title: "Subscribe",
                                    isLoading: purchaseState == .purchasing,
                                    backgroundColor: appAccentColor,
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
                    .background(appAccentColor)
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
                            .foregroundColor(appAccentColor)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(appAccentColor)
                }
            }
            .padding(20)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(isSelected ? appAccentColor : Color.cardBackgroundLight, lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    private func loadProducts() async {
        purchaseState = .loading
        do {
            let storeProducts = try await Product.products(for: productIds)
            await MainActor.run {
                products = storeProducts
                selectedProduct = storeProducts.first { $0.id.contains("annual") } ?? storeProducts.first
                purchaseState = .idle
            }
        } catch {
            print("Failed to load products: \(error)")
            await MainActor.run {
                purchaseState = .idle
            }
        }
    }

    private func purchase() {
        guard let product = selectedProduct ?? products.first else {
            dismiss()
            return
        }

        purchaseState = .purchasing
        errorMessage = nil

        Task {
            do {
                let result = try await product.purchase()

                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        await transaction.finish()
                        await MainActor.run {
                            UserDefaults.standard.set(true, forKey: "user_has_premium")
                            UserDefaults.standard.set(product.id, forKey: "user_subscription_product_id")
                            purchaseState = .success
                        }

                    case .unverified(_, let error):
                        await MainActor.run {
                            errorMessage = "Purchase verification failed. Please try again."
                            purchaseState = .idle
                        }
                        print("Unverified transaction: \(error)")
                    }

                case .userCancelled:
                    await MainActor.run {
                        purchaseState = .idle
                    }

                case .pending:
                    await MainActor.run {
                        errorMessage = "Purchase is pending approval."
                        purchaseState = .idle
                    }

                @unknown default:
                    await MainActor.run {
                        purchaseState = .idle
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Purchase failed. Please try again."
                    purchaseState = .idle
                }
                print("Purchase error: \(error)")
            }
        }
    }

    private func restorePurchases() async {
        do {
            try await AppStore.sync()

            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if productIds.contains(transaction.productID) {
                        await MainActor.run {
                            UserDefaults.standard.set(true, forKey: "user_has_premium")
                            UserDefaults.standard.set(transaction.productID, forKey: "user_subscription_product_id")
                            purchaseState = .success
                        }
                        return
                    }
                }
            }

            await MainActor.run {
                errorMessage = "No active subscription found."
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to restore purchases."
            }
            print("Restore error: \(error)")
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
            .environment(UserPreferences())
            .environment(UserHeaderOverrides())
            .environment(HeaderStyleManager())
            .environment(FeatureVisibilityManager())
    }
}
