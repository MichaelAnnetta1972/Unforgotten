import SwiftUI

// MARK: - Admin Panel View
struct AdminPanelView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    @StateObject private var viewModel = AdminPanelViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar
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
                        userList
                    }
                }
            }
            .navigationTitle("Admin Panel")
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
    }

    // MARK: - Search Bar
    private var searchBar: some View {
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
    }

    // MARK: - User List
    private var userList: some View {
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

    // MARK: - Filtered Users
    private var filteredUsers: [AppUser] {
        if searchText.isEmpty {
            return viewModel.users
        }
        return viewModel.users.filter { user in
            user.email.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Admin User Row
struct AdminUserRow: View {
    @Environment(\.appAccentColor) private var appAccentColor

    let user: AppUser
    let onToggleAdmin: () -> Void
    let onToggleComplimentary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(user.isAppAdmin ? appAccentColor : Color.cardBackgroundSoft)
                        .frame(width: 44, height: 44)

                    Image(systemName: user.isAppAdmin ? "crown.fill" : "person.fill")
                        .font(.system(size: 18))
                        .foregroundColor(user.isAppAdmin ? .black : .textSecondary)
                }

                // Email
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.email)
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    // Status badges
                    HStack(spacing: 6) {
                        if user.isAppAdmin {
                            StatusBadge(text: "App Admin", color: appAccentColor)
                        }
                        if user.hasComplimentaryAccess {
                            StatusBadge(text: "Complimentary", color: .badgeGreen)
                        }
                    }
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 12) {
                // Toggle Admin
                Button {
                    onToggleAdmin()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: user.isAppAdmin ? "crown.fill" : "crown")
                            .font(.system(size: 14))
                        Text(user.isAppAdmin ? "Remove Admin" : "Make Admin")
                            .font(.appCaption)
                    }
                    .foregroundColor(user.isAppAdmin ? .medicalRed : appAccentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(user.isAppAdmin ? Color.medicalRed : appAccentColor, lineWidth: 1)
                    )
                }

                // Toggle Complimentary
                Button {
                    onToggleComplimentary()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: user.hasComplimentaryAccess ? "gift.fill" : "gift")
                            .font(.system(size: 14))
                        Text(user.hasComplimentaryAccess ? "Revoke Pass" : "Give Pass")
                            .font(.appCaption)
                    }
                    .foregroundColor(user.hasComplimentaryAccess ? .medicalRed : .badgeGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(user.hasComplimentaryAccess ? Color.medicalRed : .badgeGreen, lineWidth: 1)
                    )
                }

                Spacer()
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

// MARK: - Admin Panel View Model
@MainActor
class AdminPanelViewModel: ObservableObject {
    @Published var users: [AppUser] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?

    func loadUsers(appState: AppState) async {
        isLoading = true

        do {
            users = try await appState.appUserRepository.getAllUsers()
        } catch {
            errorMessage = "Failed to load users: \(error.localizedDescription)"
            showError = true
            print("Error loading users: \(error)")
        }

        isLoading = false
    }

    func toggleAppAdmin(user: AppUser, appState: AppState) async {
        do {
            let updatedUser = try await appState.appUserRepository.setAppAdmin(
                userId: user.id,
                isAdmin: !user.isAppAdmin
            )
            // Update in local list
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index] = updatedUser
            }
        } catch {
            errorMessage = "Failed to update admin status: \(error.localizedDescription)"
            showError = true
            print("Error toggling admin: \(error)")
        }
    }

    func toggleComplimentaryAccess(user: AppUser, appState: AppState) async {
        do {
            let updatedUser = try await appState.appUserRepository.setComplimentaryAccess(
                userId: user.id,
                hasAccess: !user.hasComplimentaryAccess
            )
            // Update in local list
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index] = updatedUser
            }
            // Also update appState.currentAppUser if this is the current user
            // (in case the admin is granting access to themselves or viewing user just logged in)
            if appState.currentAppUser?.id == user.id {
                appState.currentAppUser = updatedUser
            }
        } catch {
            errorMessage = "Failed to update complimentary access: \(error.localizedDescription)"
            showError = true
            print("Error toggling complimentary access: \(error)")
        }
    }
}

// MARK: - Preview
#Preview {
    AdminPanelView()
        .environmentObject(AppState())
}
