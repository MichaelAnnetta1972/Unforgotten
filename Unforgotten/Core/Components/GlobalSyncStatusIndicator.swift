import SwiftUI

// MARK: - Global Sync Status Indicator
/// Shows the current sync status for the entire app with subtle animation
struct GlobalSyncStatusIndicator: View {
    @ObservedObject var syncEngine: SyncEngine
    var showLabel: Bool = false
    var showLastSync: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            statusIcon
                .font(.system(size: 14))
                .foregroundColor(syncEngine.status.color)

            if showLabel {
                VStack(alignment: .leading, spacing: 2) {
                    Text(syncEngine.status.displayText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if showLastSync, let lastSync = syncEngine.lastSyncDate {
                        Text("Last synced: \(lastSync.relativeTimeString)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
        }
        .accessibilityLabel(syncEngine.status.displayText)
    }

    @ViewBuilder
    private var statusIcon: some View {
        Image(systemName: syncEngine.status.icon)
            .symbolEffect(.rotate, options: .repeat(.continuous), isActive: syncEngine.status.isActive)
    }
}

// MARK: - Sync Status Row
/// Full row view for showing sync status in Settings
struct SyncStatusRow: View {
    @ObservedObject var syncEngine: SyncEngine
    var onSyncNow: (() async -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status indicator
            HStack {
                Image(systemName: syncEngine.status.icon)
                    .font(.system(size: 20))
                    .foregroundColor(syncEngine.status.color)
                    .symbolEffect(.rotate, options: .repeat(.continuous), isActive: syncEngine.status.isActive)

                VStack(alignment: .leading, spacing: 2) {
                    Text(syncEngine.status.displayText)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    if let lastSync = syncEngine.lastSyncDate {
                        Text("Last synced: \(lastSync.relativeTimeString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if syncEngine.pendingChangesCount > 0 {
                    Text("\(syncEngine.pendingChangesCount) pending")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            // Sync now button
            if !syncEngine.status.isActive, let onSyncNow = onSyncNow {
                Button {
                    Task {
                        await onSyncNow()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Now")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.accentColor)
                }
                .disabled(syncEngine.status.isOffline)
            }

            // Progress indicator when syncing
            if case .syncing(_, let progress) = syncEngine.status {
                ProgressView(value: progress)
                    .tint(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Compact Sync Badge
/// Small badge for toolbar or header areas
struct CompactSyncBadge: View {
    @ObservedObject var syncEngine: SyncEngine

    var body: some View {
        Image(systemName: syncEngine.status.icon)
            .font(.system(size: 12))
            .foregroundColor(syncEngine.status.color)
            .symbolEffect(.rotate, options: .repeat(.continuous), isActive: syncEngine.status.isActive)
            .frame(width: 20, height: 20)
            .accessibilityLabel(syncEngine.status.displayText)
    }
}

// MARK: - Offline Banner
/// Banner shown when device is offline
struct OfflineBanner: View {
    @ObservedObject var networkMonitor: NetworkMonitor

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14))

                Text("You're offline. Changes will sync when connected.")
                    .font(.caption)

                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.orange)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Sync Status Settings Row
/// Row component for Settings view that matches app styling
struct SyncStatusSettingsRow: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @ObservedObject var syncEngine: SyncEngine

    var body: some View {
        VStack(spacing: 0) {
            // Main status row
            HStack {
                Image(systemName: syncEngine.status.icon)
                    .foregroundColor(appAccentColor)
                    .frame(width: 30)
                    .symbolEffect(.rotate, options: .repeat(.continuous), isActive: syncEngine.status.isActive)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync Status")
                        .font(.appBody)
                        .foregroundColor(.textPrimary)

                    if let lastSync = syncEngine.lastSyncDate {
                        Text("Last synced: \(lastSync.relativeTimeString)")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if syncEngine.pendingChangesCount > 0 {
                        Text("\(syncEngine.pendingChangesCount) pending")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }

                    Text(syncEngine.status.displayText)
                        .font(.appBody)
                        .foregroundColor(syncEngine.status.color)
                }
            }
            .padding()
            .background(Color.cardBackground)

            // Progress bar when syncing
            if case .syncing(_, let progress) = syncEngine.status {
                ProgressView(value: progress)
                    .tint(.blue)
                    .background(Color.cardBackground)
            }

            // Sync now button
            Button {
                Task {
                    if let accountId = appState.currentAccount?.id {
                        await syncEngine.performFullSync(accountId: accountId)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(appAccentColor)
                        .frame(width: 30)

                    Text("Sync Now")
                        .font(.appBody)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(Color.cardBackground)
            }
            .disabled(syncEngine.status.isActive || syncEngine.status.isOffline)
            .opacity((syncEngine.status.isActive || syncEngine.status.isOffline) ? 0.5 : 1)
        }
    }
}

// MARK: - Date Extension for Relative Time
private extension Date {
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview
#Preview("Sync Status Indicator") {
    // Note: This preview won't work as-is because it needs a real SyncEngine
    // In a real app, you would pass the actual syncEngine from AppState
    VStack(spacing: 24) {
        Text("GlobalSyncStatusIndicator Preview")
            .font(.headline)

        Text("Note: Requires a real SyncEngine to preview")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
