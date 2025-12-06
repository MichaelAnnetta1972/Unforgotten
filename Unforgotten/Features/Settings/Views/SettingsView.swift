import SwiftUI
import UIKit

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showInviteMember = false
    @State private var showManageMembers = false
    @State private var showJoinAccount = false
    @State private var showMoodHistory = false
    @State private var showSignOutConfirm = false
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.accentYellow)
                        
                        Text("Settings")
                            .font(.appLargeTitle)
                            .foregroundColor(.textPrimary)
                    }
                    .padding(.top, 40)
                    
                    // Account section
                    SettingsSection(title: "ACCOUNT") {
                        if let account = appState.currentAccount {
                            SettingsRow(
                                icon: "person.circle",
                                title: "Account Name",
                                value: account.displayName
                            )
                            
                            if let timezone = account.timezone {
                                SettingsRow(
                                    icon: "globe",
                                    title: "Timezone",
                                    value: timezone
                                )
                            }
                        }
                        
                        // Only show invite/manage if user can manage members
                        if appState.currentUserRole?.canManageMembers == true {
                            SettingsButtonRow(
                                icon: "person.badge.plus",
                                title: "Invite Family Member",
                                action: { showInviteMember = true }
                            )

                            SettingsButtonRow(
                                icon: "person.2",
                                title: "Manage Members",
                                action: { showManageMembers = true }
                            )
                        }

                        SettingsButtonRow(
                            icon: "envelope.badge",
                            title: "Join Another Account",
                            action: { showJoinAccount = true }
                        )
                    }

                    // Mood section
                    SettingsSection(title: "MOOD") {
                        SettingsButtonRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "View Mood History",
                            action: { showMoodHistory = true }
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
                            icon: "doc.text",
                            title: "Privacy Policy",
                            action: openPrivacyPolicy
                        )
                        
                        SettingsButtonRow(
                            icon: "doc.text",
                            title: "Terms of Service",
                            action: openTermsOfService
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
        .sheet(isPresented: $showInviteMember) {
            InviteMemberView()
        }
        .sheet(isPresented: $showManageMembers) {
            ManageMembersView()
        }
        .sheet(isPresented: $showJoinAccount) {
            JoinAccountView()
        }
        .sheet(isPresented: $showMoodHistory) {
            MoodHistoryView()
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
    
    private func openPrivacyPolicy() {
        // TODO: Add privacy policy URL
    }
    
    private func openTermsOfService() {
        // TODO: Add terms URL
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
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentYellow)
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
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentYellow)
                    .frame(width: 30)
                
                Text(title)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.textSecondary)
            }
            .padding()
            .background(Color.cardBackground)
        }
    }
}

// MARK: - Invite Member View
struct InviteMemberView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
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
                                .foregroundColor(.accentYellow)
                            
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
                    .foregroundColor(isSelected ? .accentYellow : .textSecondary)
            }
            .padding()
            .background(isSelected ? Color.accentYellow.opacity(0.1) : Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(isSelected ? Color.accentYellow : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Mood History View
struct MoodHistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
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
                                            .foregroundColor(.accentYellow)
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
                    .foregroundColor(.accentYellow)
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
                        .foregroundColor(.accentYellow)
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
    @StateObject private var viewModel = ManageMembersViewModel()

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
                                .foregroundColor(.accentYellow)

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
                        if !viewModel.members.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CURRENT MEMBERS")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                                    .padding(.horizontal, AppDimensions.screenPadding)

                                VStack(spacing: 1) {
                                    ForEach(viewModel.members, id: \.id) { member in
                                        MemberRow(member: member)
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

                        if viewModel.members.isEmpty && viewModel.pendingInvitations.isEmpty && !viewModel.isLoading {
                            EmptyStateView(
                                icon: "person.2",
                                title: "No members yet",
                                message: "Invite family members to share access to this account"
                            )
                            .padding(.top, 40)
                        }

                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.accentYellow)
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
                    .foregroundColor(.accentYellow)
                }
            }
            .task {
                await viewModel.loadData(appState: appState)
            }
        }
    }
}

// MARK: - Member Row
struct MemberRow: View {
    let member: AccountMember

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.accentYellow)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.userId.uuidString.prefix(8) + "...")
                    .font(.appBody)
                    .foregroundColor(.textPrimary)

                Text(member.role.displayName)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if member.role == .owner {
                Text("Owner")
                    .font(.appCaption)
                    .foregroundColor(.accentYellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentYellow.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.cardBackground)
    }
}

// MARK: - Invitation Row
struct InvitationRow: View {
    let invitation: AccountInvitation
    let onRevoke: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "envelope.badge.fill")
                .foregroundColor(.accentYellow)
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

// MARK: - Manage Members View Model
@MainActor
class ManageMembersViewModel: ObservableObject {
    @Published var members: [AccountMember] = []
    @Published var pendingInvitations: [AccountInvitation] = []
    @Published var isLoading = false

    func loadData(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            // Load members
            members = try await appState.accountRepository.getAccountMembers(accountId: account.id)

            // Load pending invitations
            let allInvitations = try await appState.invitationRepository.getInvitations(accountId: account.id)
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
}

// MARK: - Join Account View
struct JoinAccountView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

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
                                .foregroundColor(.accentYellow)

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
                                        .stroke(Color.accentYellow.opacity(0.3), lineWidth: 1)
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

            // Get the account name for the success message
            let account = try await appState.accountRepository.getAccount(id: invitation.accountId)
            joinedAccountName = account.displayName

            // Accept the invitation
            try await appState.invitationRepository.acceptInvitation(invitation: invitation, userId: userId)

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

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
    }
}
