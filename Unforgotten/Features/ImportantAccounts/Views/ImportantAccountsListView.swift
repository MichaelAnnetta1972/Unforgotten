import SwiftUI

// MARK: - Important Accounts List View
struct ImportantAccountsListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.iPadEditImportantAccountAction) private var iPadEditImportantAccountAction
    @Environment(\.iPadAddImportantAccountAction) private var iPadAddImportantAccountAction

    let profile: Profile

    @StateObject private var viewModel = ImportantAccountsViewModel()
    @State private var showAddAccount = false
    @State private var showEditAccount = false
    @State private var accountToEdit: ImportantAccount?
    @State private var searchText = ""
    @State private var hasSeenSecurityNotice = false
    @State private var selectedAccount: ImportantAccount?
    @State private var isPortrait = false

    /// Whether to use split view (iPad regular width)
    private var useSplitView: Bool {
        horizontalSizeClass == .regular
    }

    /// Whether an account is currently selected
    private var hasSelection: Bool {
        selectedAccount != nil
    }

    /// Whether to use navigation links (iPhone or iPad Portrait)
    private var useNavigationLinks: Bool {
        !useSplitView || isPortrait
    }

    var filteredAccounts: [ImportantAccount] {
        if searchText.isEmpty {
            return viewModel.accounts
        }
        return viewModel.accounts.filter { account in
            account.accountName.localizedCaseInsensitiveContains(searchText) ||
            (account.username?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (account.emailAddress?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let currentlyPortrait = geometry.size.height > geometry.size.width

            Group {
                if useSplitView && !currentlyPortrait {
                    // iPad Landscape mode: Split view with inline detail
                    landscapeLayout(geometry: geometry)
                } else {
                    // iPhone or iPad Portrait: Full-width list with NavigationLink for detail
                    accountsListContent(useNavigationLinks: true)
                        .frame(width: geometry.size.width)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: hasSelection)
            .onChange(of: currentlyPortrait) { _, newValue in
                isPortrait = newValue
                // Clear selection when switching to portrait (navigation takes over)
                if newValue {
                    selectedAccount = nil
                }
            }
            .onAppear {
                isPortrait = currentlyPortrait
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackground)
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showAddAccount) {
            AddEditImportantAccountView(
                profile: profile,
                mode: .add,
                onDismiss: { showAddAccount = false }
            ) { newAccount in
                viewModel.accounts.append(newAccount)
                // Sort by account name
                viewModel.accounts.sort { $0.accountName.localizedCaseInsensitiveCompare($1.accountName) == .orderedAscending }
                // Auto-select the new account on iPad landscape with animation
                if useSplitView && !isPortrait {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedAccount = newAccount
                    }
                }
            }
        }
        .sidePanel(isPresented: $showEditAccount) {
            if let account = accountToEdit {
                AddEditImportantAccountView(
                    profile: profile,
                    mode: .edit(account),
                    onDismiss: {
                        showEditAccount = false
                        accountToEdit = nil
                    }
                ) { updatedAccount in
                    // Update in viewModel
                    if let index = viewModel.accounts.firstIndex(where: { $0.id == updatedAccount.id }) {
                        viewModel.accounts[index] = updatedAccount
                    }
                    // Update selectedAccount if it's the same
                    if selectedAccount?.id == updatedAccount.id {
                        selectedAccount = updatedAccount
                    }
                }
            }
        }
        .task {
            await viewModel.loadAccounts(profileId: profile.id, appState: appState)
        }
        .refreshable {
            await viewModel.loadAccounts(profileId: profile.id, appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .importantAccountsDidChange)) { notification in
            // Reload when important accounts change (e.g., added via iPad overlay)
            if let profileId = notification.userInfo?["profileId"] as? UUID, profileId == profile.id {
                Task {
                    await viewModel.loadAccounts(profileId: profile.id, appState: appState)
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

    // MARK: - Landscape Layout (Split View)
    @ViewBuilder
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left panel - List (full width when no selection, 50% when selected on iPad)
            accountsListContent(useNavigationLinks: false)
                .frame(width: hasSelection ? geometry.size.width * 0.5 : geometry.size.width)

            // Right panel - Detail (iPad only, when account selected)
            if let account = selectedAccount {
                // Divider
                Rectangle()
                    .fill(Color.cardBackgroundLight)
                    .frame(width: 1)

                // Detail panel with scale + opacity animation like To Do List
                ImportantAccountDetailPanel(
                    account: Binding(
                        get: { account },
                        set: { newValue in
                            selectedAccount = newValue
                            // Update in viewModel
                            if let index = viewModel.accounts.firstIndex(where: { $0.id == newValue.id }) {
                                viewModel.accounts[index] = newValue
                            }
                        }
                    ),
                    profile: profile,
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedAccount = nil
                        }
                    },
                    onDelete: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            viewModel.accounts.removeAll { $0.id == account.id }
                            selectedAccount = nil
                        }
                    },
                    onUpdate: { updatedAccount in
                        if let index = viewModel.accounts.firstIndex(where: { $0.id == updatedAccount.id }) {
                            viewModel.accounts[index] = updatedAccount
                        }
                        selectedAccount = updatedAccount
                    },
                    onEditTapped: {
                        // Use full-screen overlay action if available
                        if let editAction = iPadEditImportantAccountAction {
                            editAction(account, profile)
                        } else {
                            accountToEdit = account
                            showEditAccount = true
                        }
                    }
                )
                .frame(width: geometry.size.width * 0.5 - 1)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
    }

    // MARK: - Accounts List Content
    @ViewBuilder
    private func accountsListContent(useNavigationLinks: Bool) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header scrolls with content
                ImportantAccountsHeaderView(
                    profile: profile,
                    onBack: { dismiss() },
                    onAdd: {
                        // Use full-screen overlay action if available
                        if let addAction = iPadAddImportantAccountAction {
                            addAction(profile)
                        } else {
                            showAddAccount = true
                        }
                    }
                )

                // Content
                VStack(spacing: AppDimensions.cardSpacing) {
                    // Section header card
                    //SectionHeaderCard(
                    //    title: "Important Accounts",
                    //    icon: "key.fill"
                    //)

                    // Security Notice Card (resets each session)
                    SecurityNoticeCard(hasSeenNotice: $hasSeenSecurityNotice)

                    // Search bar (if more than 5 accounts)
                    if viewModel.accounts.count > 5 {
                        SearchBar(text: $searchText, placeholder: "Search accounts...")
                    }

                    // Accounts List
                    if viewModel.isLoading {
                        LoadingView(message: "Loading accounts...")
                            .padding(.top, 40)
                    } else if filteredAccounts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.textSecondary)

                            Text("No accounts yet")
                                .font(.appCardTitle)
                                .foregroundColor(.textPrimary)

                            Text("Add important account details to help keep track of online services.")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: AppDimensions.cardSpacing) {
                            ForEach(filteredAccounts) { account in
                                if useNavigationLinks {
                                    // iPhone or iPad Portrait: NavigationLink to detail view
                                    NavigationLink(destination: ImportantAccountDetailView(account: account, profile: profile, onDelete: {
                                        viewModel.accounts.removeAll { $0.id == account.id }
                                    }, onUpdate: { updatedAccount in
                                        if let index = viewModel.accounts.firstIndex(where: { $0.id == updatedAccount.id }) {
                                            viewModel.accounts[index] = updatedAccount
                                        }
                                    })) {
                                        ImportantAccountCard(account: account)
                                    }
                                } else {
                                    // iPad Landscape: Button that selects account for detail panel
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedAccount = account
                                        }
                                    } label: {
                                        ImportantAccountCard(
                                            account: account,
                                            isSelected: selectedAccount?.id == account.id
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }

                    // Bottom spacing for nav bar
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, AppDimensions.screenPadding(for: horizontalSizeClass))
                .padding(.top, AppDimensions.cardSpacing)
            }
        }
    }
}

// MARK: - Empty Detail View for iPad
struct ImportantAccountsEmptyDetailView: View {
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        ZStack {
            Color.appBackground

            VStack(spacing: 16) {
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.textSecondary.opacity(0.3))

                Text("Select an account")
                    .font(.appTitle)
                    .foregroundColor(.textSecondary)

                Text("Choose an account from the list to view its details")
                    .font(.appBody)
                    .foregroundColor(.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Important Account Detail Panel (for iPad split view)
struct ImportantAccountDetailPanel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var account: ImportantAccount
    let profile: Profile
    let onClose: () -> Void
    let onDelete: () -> Void
    let onUpdate: (ImportantAccount) -> Void
    let onEditTapped: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Compact header for detail panel
                AccountDetailPanelHeader(
                    accountName: account.accountName,
                    category: account.category,
                    onClose: onClose,
                    onEdit: onEditTapped
                )

                // Detail Cards
                VStack(spacing: AppDimensions.cardSpacing) {
                    // Website
                    if let website = account.websiteURL, !website.isEmpty {
                        DetailRowCard(
                            label: "Website",
                            value: website,
                            icon: "globe",
                            copyable: true
                        )
                    }

                    // Username
                    if let username = account.username, !username.isEmpty {
                        DetailRowCard(
                            label: "Username",
                            value: username,
                            icon: "person.fill",
                            copyable: true
                        )
                    }

                    // Email
                    if let email = account.emailAddress, !email.isEmpty {
                        DetailRowCard(
                            label: "Email Address",
                            value: email,
                            icon: "envelope.fill",
                            copyable: true
                        )
                    }

                    // Phone
                    if let phone = account.phoneNumber, !phone.isEmpty {
                        DetailRowCard(
                            label: "Phone Number",
                            value: phone,
                            icon: "phone.fill",
                            copyable: true
                        )
                    }

                    // Security Question Hint
                    if let hint = account.securityQuestionHint, !hint.isEmpty {
                        DetailRowCard(
                            label: "Security Question Hint",
                            value: hint,
                            icon: "questionmark.circle.fill",
                            copyable: false
                        )
                    }

                    // Recovery Hint
                    if let hint = account.recoveryHint, !hint.isEmpty {
                        DetailRowCard(
                            label: "Recovery Hint",
                            value: hint,
                            icon: "lightbulb.fill",
                            copyable: false,
                            isHint: true
                        )
                    }

                    // Notes
                    if let notes = account.notes, !notes.isEmpty {
                        DetailRowCard(
                            label: "Notes",
                            value: notes,
                            icon: "note.text",
                            copyable: false
                        )
                    }

                    // Category
                    if let category = account.category {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(category.color)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Category")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                Text(category.displayName)
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                            }

                            Spacer()
                        }
                        .padding(AppDimensions.cardPadding)
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                    }

                    // Delete Button
                    Button(action: { showDeleteConfirmation = true }) {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .tint(.red)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text("Delete Account")
                        }
                        .font(.appBody)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(AppDimensions.cardCornerRadius)
                    }
                    .disabled(isDeleting)
                    .padding(.top, 20)

                    // Bottom spacing
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, AppDimensions.screenPadding(for: horizontalSizeClass))
                .padding(.top, AppDimensions.cardSpacing)
            }
        }
        .background(Color.appBackgroundLight)
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("This will permanently delete the account details for \(account.accountName). This cannot be undone.")
        }
    }

    private func deleteAccount() async {
        isDeleting = true

        do {
            try await appState.importantAccountRepository.deleteAccount(id: account.id)
            onDelete()
        } catch {
            #if DEBUG
            print("Error deleting account: \(error)")
            #endif
        }

        isDeleting = false
    }
}

// MARK: - Account Detail Panel Header
struct AccountDetailPanelHeader: View {
    let accountName: String
    let category: AccountCategory?
    let onClose: () -> Void
    let onEdit: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(HeaderStyleManager.self) private var headerStyleManager

    /// Reduced header height for panel
    private var headerHeight: CGFloat {
        AppDimensions.headerHeight
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image from current theme's default
            GeometryReader { geometry in
                if let uiImage = UIImage(named: headerStyleManager.asset(for: .contacts).fileName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    // Fallback gradient
                    LinearGradient(
                        colors: [
                            (category?.color ?? .accountsTeal).opacity(0.8),
                            (category?.color ?? .accountsTeal)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(height: headerHeight)

            // Overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content
            VStack {
                HStack {
                    // Close button
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    Spacer()
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.top, 16)

                Spacer()

                HStack(spacing: 12) {
                    if let category = category {
                        Image(systemName: category.icon)
                            .font(.title3)
                            .foregroundColor(.white)
                    }

                    Text(accountName)
                        .font(.appTitle)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    // Edit button at bottom right
                    Button(action: onEdit) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Edit")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.bottom, AppDimensions.screenPadding)
            }
        }
        .frame(height: headerHeight)
    }
}

// MARK: - Important Accounts Header View
struct ImportantAccountsHeaderView: View {
    let profile: Profile
    let onBack: () -> Void
    let onAdd: (() -> Void)?

    init(profile: Profile, onBack: @escaping () -> Void, onAdd: (() -> Void)? = nil) {
        self.profile = profile
        self.onBack = onBack
        self.onAdd = onAdd
    }

    var body: some View {
        CustomizableHeaderView(
            pageIdentifier: .profileDetail,
            title: profile.fullName,
            subtitle: "Important Accounts",
            showBackButton: true,
            backAction: onBack,
            showAddButton: onAdd != nil,
            addAction: onAdd
        )
    }
}

// MARK: - Security Notice Card
/// Security notice that resets each app session (not persisted)
struct SecurityNoticeCard: View {
    @Binding var hasSeenNotice: Bool
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        if !hasSeenNotice {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "shield.fill")
                    .foregroundColor(appAccentColor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("For your security")
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    Text("This is for account references only. Please don't enter actual passwords — use the Recovery Hint field for memory aids like \"same as email\" or \"written in notebook\".")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Button(action: { hasSeenNotice = true }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.textSecondary)
                        .font(.caption)
                }
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)

            TextField(placeholder, text: $text)
                .font(.appBody)
                .foregroundColor(.textPrimary)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Important Account Card
struct ImportantAccountCard: View {
    let account: ImportantAccount
    var isSelected: Bool = false
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill((account.category?.color ?? Color.textSecondary).opacity(isSelected ? 0.3 : 0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: account.category?.icon ?? "globe")
                    .foregroundColor(account.category?.color ?? Color.textSecondary)
                    .font(.system(size: 20))
            }

            // Account Info
            VStack(alignment: .leading, spacing: 4) {
                Text(account.accountName)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)

                if let username = account.username, !username.isEmpty {
                    Text(username)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                } else if let email = account.emailAddress, !email.isEmpty {
                    Text(email)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.textSecondary)
                .font(.caption)
        }
        .padding(AppDimensions.cardPadding)
        .background(isSelected ? appAccentColor.opacity(0.1) : Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                .stroke(isSelected ? appAccentColor : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Important Accounts View Model
@MainActor
class ImportantAccountsViewModel: ObservableObject {
    @Published var accounts: [ImportantAccount] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadAccounts(profileId: UUID, appState: AppState) async {
        isLoading = true

        do {
            accounts = try await appState.importantAccountRepository.getAccounts(profileId: profileId)
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ImportantAccountsListView(
            profile: Profile(
                id: UUID(),
                accountId: UUID(),
                type: .primary,
                fullName: "John Doe",
                createdAt: Date(),
                updatedAt: Date()
            )
        )
        .environmentObject(AppState.forPreview())
        .environment(HeaderStyleManager())
    }
}
