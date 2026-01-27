import SwiftUI

// MARK: - Account Switcher View
/// A dropdown-style view for switching between accounts the user has access to
struct AccountSwitcherView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Switch Account")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding()
            .background(Color.cardBackground)

            Divider()
                .background(Color.textSecondary.opacity(0.3))

            // Account List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(appState.allAccounts) { accountWithRole in
                        AccountRow(
                            accountWithRole: accountWithRole,
                            isSelected: appState.currentAccount?.id == accountWithRole.account.id,
                            onSelect: {
                                Task {
                                    await appState.switchAccount(to: accountWithRole)
                                    isPresented = false
                                }
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .background(Color.appBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Account Row
/// A single account row in the account switcher
struct AccountRow: View {
    let accountWithRole: AccountWithRole
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

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
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)


                    }

                    // Role badge
                    RoleBadge(role: accountWithRole.role)
                }

                Spacer()

                // Selected indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(appAccentColor)
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

// MARK: - Role Badge
/// A small badge showing the user's role in an account
struct RoleBadge: View {
    let role: MemberRole

    @Environment(\.appAccentColor) private var appAccentColor

    var badgeColor: Color {
        switch role {
        case .owner:
            return appAccentColor
        case .admin:
            return .blue
        case .helper:
            return .green
        case .viewer:
            return .gray
        }
    }

    var body: some View {
        Text(role.displayName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(role == .owner ? .black : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor)
            .cornerRadius(4)
    }
}

// MARK: - Account Header Button
/// A tappable header showing current account with dropdown indicator
struct AccountHeaderButton: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor

    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Account name
                VStack(alignment: .leading, spacing: 2) {
                    if appState.isViewingOtherAccount {
                        Text("Viewing")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }

                    Text(appState.currentAccount?.displayName ?? "Account")
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)
                }

                // Role badge (only show when viewing other account)
                if appState.isViewingOtherAccount, let role = appState.currentUserRole {
                    RoleBadge(role: role)
                }

                // Dropdown indicator (only show if multiple accounts)
                if appState.allAccounts.count > 1 {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Viewing As Bar
/// A persistent bar shown when viewing someone else's account
struct ViewingAsBar: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Whether to show this bar on iPad (regular width). Defaults to false.
    var showOnIPad: Bool = false

    var body: some View {
        // On iPad (regular width), only show if explicitly enabled
        let isIPad = horizontalSizeClass == .regular
        if appState.isViewingOtherAccount && (!isIPad || showOnIPad) {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 12))

                Text("Viewing \(appState.currentAccount?.displayName ?? "Account")")
                    .font(.system(size: 13, weight: .medium))

                if let role = appState.currentUserRole {
                    Text("as \(role.displayName)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Button {
                    Task {
                        await appState.switchToOwnAccount()
                    }
                } label: {
                    Text("Switch Back")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.9), Color.purple.opacity(0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }
}

// MARK: - Access Denied View
/// Shown when a user tries to access content they don't have permission for
struct AccessDeniedView: View {
    let title: String
    let message: String

    @Environment(\.appAccentColor) private var appAccentColor

    init(
        title: String = "Access Restricted",
        message: String = "You do not have access to view this content. You must be an Admin on this account."
    ) {
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Lock icon
            ZStack {
                Circle()
                    .fill(Color.cardBackground)
                    .frame(width: 100, height: 100)

                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.textSecondary)
            }

            // Title and message
            VStack(spacing: 12) {
                Text(title)
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                Text(message)
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - Account Switcher Modal
/// A modal sheet for switching between accounts
struct AccountSwitcherModal: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var isPresented: Bool

    /// Preferred width on iPad - matches typical content width
    private var preferredWidth: CGFloat {
        horizontalSizeClass == .regular ? 650 : .infinity
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header icon
                        VStack(spacing: 12) {


                            Text("Select which account you would like to view")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)

                        // Account List
                        VStack(spacing: 8) {
                            ForEach(appState.allAccounts) { accountWithRole in
                                AccountRow(
                                    accountWithRole: accountWithRole,
                                    isSelected: appState.currentAccount?.id == accountWithRole.account.id,
                                    onSelect: {
                                        Task {
                                            await appState.switchAccount(to: accountWithRole)
                                            isPresented = false
                                            dismiss()
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
            }
            .navigationTitle("Switch Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                        dismiss()
                    }
                    .foregroundColor(appAccentColor)
                }
            }
        }
        .frame(minWidth: horizontalSizeClass == .regular ? 650 : nil)
        .presentationDetents([.medium, .large])
        .presentationSizing(.fitted)
    }
}

// MARK: - Preview
#Preview("Account Switcher") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        AccountSwitcherView(isPresented: .constant(true))
            .padding()
    }
    .environmentObject(AppState.forPreview())
}

#Preview("Viewing As Bar") {
    VStack {
        ViewingAsBar()
        Spacer()
    }
    .environmentObject(AppState.forPreview())
}

#Preview("Access Denied") {
    AccessDeniedView()
}
