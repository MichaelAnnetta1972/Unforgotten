import SwiftUI

// MARK: - Family Sharing Sheet
/// A sheet that allows users to select which family members can see an event in the family calendar
struct FamilySharingSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    @Binding var isEnabled: Bool
    @Binding var selectedMemberIds: Set<UUID>
    var onDismiss: (() -> Void)? = nil

    @State private var members: [AccountMemberWithUser] = []
    @State private var isLoading = true
    @State private var error: String?

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                            )
                    }

                    Spacer()

                    Text("Share to Family")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(appAccentColor)
                            )
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        // Enable sharing toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add to Family Calendar")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Text("Share this event with family members")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            Toggle("", isOn: $isEnabled)
                                .labelsHidden()
                                .tint(appAccentColor)
                        }
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)

                        // Member selection (shown when enabled)
                        if isEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Who can see this event?")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                                    .padding(.horizontal, 4)

                                if isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .tint(appAccentColor)
                                        Spacer()
                                    }
                                    .padding(.vertical, 20)
                                } else if let errorMessage = error {
                                    Text(errorMessage)
                                        .font(.appCaption)
                                        .foregroundColor(.medicalRed)
                                        .padding()
                                } else if members.isEmpty {
                                    Text("No other family members to share with.")
                                        .font(.appBody)
                                        .foregroundColor(.textSecondary)
                                        .padding()
                                } else {
                                    // Quick actions
                                    HStack(spacing: 12) {
                                        Button {
                                            selectedMemberIds = Set(members.map { $0.userId })
                                        } label: {
                                            Text("Select All")
                                                .font(.appCaption)
                                                .foregroundColor(.textPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.cardBackgroundSoft)
                                                .cornerRadius(AppDimensions.pillCornerRadius)
                                        }

                                        Button {
                                            selectedMemberIds = []
                                        } label: {
                                            Text("Clear")
                                                .font(.appCaption)
                                                .foregroundColor(.textPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.cardBackgroundSoft)
                                                .cornerRadius(AppDimensions.pillCornerRadius)
                                        }

                                        Spacer()
                                    }

                                    // Member list
                                    ForEach(members) { member in
                                        FamilyMemberRow(
                                            member: member,
                                            isSelected: selectedMemberIds.contains(member.userId),
                                            accentColor: appAccentColor
                                        ) {
                                            toggleMember(member.userId)
                                        }
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .background(Color.appBackground)
            .navigationBarHidden(true)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackgroundLight)
        .toolbarBackground(.clear, for: .navigationBar)
        .containerBackground(.clear, for: .navigation)
        .task {
            await loadMembers()
        }
    }

    // MARK: - Actions

    private func toggleMember(_ userId: UUID) {
        if selectedMemberIds.contains(userId) {
            selectedMemberIds.remove(userId)
        } else {
            selectedMemberIds.insert(userId)
        }
    }

    private func loadMembers() async {
        guard let account = appState.currentAccount else {
            error = "No account found"
            isLoading = false
            return
        }

        do {
            let allMembers = try await appState.accountRepository.getAccountMembersWithUsers(accountId: account.id)

            // Get current user ID to exclude from the list
            let currentUserId = await SupabaseManager.shared.currentUserId

            // Filter out current user
            members = allMembers.filter { $0.userId != currentUserId }
            isLoading = false
        } catch {
            self.error = "Failed to load members: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Family Member Row
struct FamilyMemberRow: View {
    let member: AccountMemberWithUser
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(accentColor.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(member.displayName.prefix(1).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(accentColor)
                    )

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)

                    Text(member.role.displayName)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? accentColor : .textSecondary)
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// MARK: - Preview
#Preview {
    FamilySharingSheet(
        isEnabled: .constant(true),
        selectedMemberIds: .constant([])
    )
    .environmentObject(AppState.forPreview())
}
