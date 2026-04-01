import SwiftUI

// MARK: - Recently Deleted Panel Content
/// Wrapper for use inside the SettingsPanelView split layout
struct RecentlyDeletedPanelContent: View {
    var body: some View {
        RecentlyDeletedView()
    }
}

// MARK: - Recently Deleted View
struct RecentlyDeletedView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sidePanelDismiss) private var sidePanelDismiss

    @State private var deletedProfiles: [Profile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var profileToDelete: Profile?
    @State private var showPermanentDeleteConfirm = false
    @State private var actionInProgress = false
    @State private var isCheckmarkPressed = false

    private func dismissView() {
        if let sidePanelDismiss {
            sidePanelDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundColor(appAccentColor)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(appAccentColor.opacity(0.15))
                        )

                    Text("Recently Deleted")
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
                        dismissView()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.appBody.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(15)
                        .background(Circle().fill(.white.opacity(0.15)))
                        .scaleEffect(isCheckmarkPressed ? 0.85 : 1.0)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

            ScrollView {
            VStack(spacing: 24) {
                // Header explanation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Deleted profiles are kept for 30 days before being permanently removed. You can restore them at any time during this period.")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: appAccentColor))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let error = errorMessage {
                    Text(error)
                        .font(.appCaption)
                        .foregroundColor(.medicalRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if deletedProfiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "trash.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.textSecondary)
                        Text("No recently deleted profiles")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 12) {
                        ForEach(deletedProfiles) { profile in
                            DeletedProfileRow(
                                profile: profile,
                                accentColor: appAccentColor,
                                actionInProgress: actionInProgress
                            ) {
                                Task { await restore(profile) }
                            } onPermanentDelete: {
                                profileToDelete = profile
                                showPermanentDeleteConfirm = true
                            }
                        }
                    }
                }

                Spacer().frame(height: 80)
            }
            .padding(AppDimensions.screenPadding)
        }
            .background(Color.appBackground)
        } // end VStack
        .background(Color.appBackground)
        .task { await loadDeletedProfiles() }
        .alert("Permanently Delete?", isPresented: $showPermanentDeleteConfirm, presenting: profileToDelete) { profile in
            Button("Delete Permanently", role: .destructive) {
                Task { await permanentlyDelete(profile) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { profile in
            Text("\"\(profile.displayName)\" will be permanently deleted and cannot be recovered.")
        }
    }

    private func loadDeletedProfiles() async {
        guard let account = appState.currentAccount else {
            isLoading = false
            return
        }
        do {
            deletedProfiles = try await appState.profileRepository.getDeletedProfiles(accountId: account.id)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load deleted profiles: \(error.localizedDescription)"
        }
    }

    private func restore(_ profile: Profile) async {
        actionInProgress = true
        do {
            _ = try await appState.profileRepository.restoreProfile(id: profile.id)
            deletedProfiles.removeAll { $0.id == profile.id }
            NotificationCenter.default.post(name: .profilesDidChange, object: nil)
        } catch {
            errorMessage = "Failed to restore profile: \(error.localizedDescription)"
        }
        actionInProgress = false
    }

    private func permanentlyDelete(_ profile: Profile) async {
        actionInProgress = true
        do {
            try await appState.profileRepository.permanentlyDeleteProfile(id: profile.id)
            deletedProfiles.removeAll { $0.id == profile.id }
        } catch {
            errorMessage = "Failed to delete profile: \(error.localizedDescription)"
        }
        actionInProgress = false
    }
}

// MARK: - Deleted Profile Row
private struct DeletedProfileRow: View {
    let profile: Profile
    let accentColor: Color
    let actionInProgress: Bool
    let onRestore: () -> Void
    let onPermanentDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName)
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    if let days = profile.daysUntilPermanentDeletion {
                        Text(days == 0 ? "Deletes today" : "Deletes in \(days) day\(days == 1 ? "" : "s")")
                            .font(.appCaption)
                            .foregroundColor(days <= 3 ? .medicalRed : .textSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onRestore) {
                        Text("Restore")
                            .font(.appCaption.weight(.semibold))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(accentColor.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .disabled(actionInProgress)
                    .buttonStyle(.plain)

                    Button(action: onPermanentDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.medicalRed)
                            .padding(6)
                            .background(Color.medicalRed.opacity(0.12))
                            .cornerRadius(8)
                    }
                    .disabled(actionInProgress)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}
