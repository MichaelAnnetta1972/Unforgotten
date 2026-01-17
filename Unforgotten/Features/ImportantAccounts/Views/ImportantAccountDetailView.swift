import SwiftUI

// MARK: - Important Account Detail View
struct ImportantAccountDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State var account: ImportantAccount
    let profile: Profile
    let onDelete: () -> Void
    let onUpdate: (ImportantAccount) -> Void

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                AccountDetailHeaderView(
                    accountName: account.accountName,
                    category: account.category,
                    onBack: { dismiss() },
                    onEdit: { showEditSheet = true }
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

                    // Bottom spacing for nav bar
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.top, AppDimensions.cardSpacing)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackground)
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showEditSheet) {
            AddEditImportantAccountView(
                profile: profile,
                mode: .edit(account),
                onDismiss: { showEditSheet = false }
            ) { updatedAccount in
                account = updatedAccount
                onUpdate(updatedAccount)
            }
        }
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
            dismiss()
        } catch {
            #if DEBUG
            print("Error deleting account: \(error)")
            #endif
        }

        isDeleting = false
    }
}

// MARK: - Detail Row Card
struct DetailRowCard: View {
    let label: String
    let value: String
    let icon: String
    let copyable: Bool
    var isHint: Bool = false
    @Environment(\.appAccentColor) private var appAccentColor

    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.textSecondary)
                    .frame(width: 20)

                Text(label)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                Spacer()

                if copyable {
                    Button(action: copyToClipboard) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .foregroundColor(showCopied ? .green : .textSecondary)
                            .font(.caption)
                    }
                }
            }

            Text(value)
                .font(.appBody)
                .foregroundColor(isHint ? appAccentColor : .textPrimary)
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = value
        showCopied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
    }
}

// MARK: - Account Detail Header
struct AccountDetailHeaderView: View {
    let accountName: String
    let category: AccountCategory?
    let onBack: () -> Void
    let onEdit: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(HeaderStyleManager.self) private var headerStyleManager

    /// Reduced header height (50% of standard)
    private var headerHeight: CGFloat {
        AppDimensions.headerHeight / 1.5
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
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    Spacer()
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.top, 60)

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

// MARK: - Preview
#Preview {
    NavigationStack {
        ImportantAccountDetailView(
            account: ImportantAccount(
                profileId: UUID(),
                accountName: "Netflix",
                websiteURL: "netflix.com",
                username: "john.doe@email.com",
                emailAddress: "john.doe@email.com",
                recoveryHint: "Same as main email password",
                category: .entertainment
            ),
            profile: Profile(
                id: UUID(),
                accountId: UUID(),
                type: .primary,
                fullName: "John Doe",
                createdAt: Date(),
                updatedAt: Date()
            ),
            onDelete: {},
            onUpdate: { _ in }
        )
        .environmentObject(AppState())
        .environment(HeaderStyleManager())
    }
}
