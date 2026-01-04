import SwiftUI

// MARK: - Sync Status Indicator
/// Shows the current sync status with subtle animation
struct SyncStatusIndicator: View {
    let status: SyncServiceStatus
    var showLabel: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            statusIcon
                .font(.system(size: 14))
                .foregroundColor(statusColor)

            if showLabel {
                Text(statusLabel)
                    .font(.system(size: 12))
                    .foregroundColor(.noteSecondaryText)
            }
        }
        .accessibilityLabel(statusLabel)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .idle:
            Image(systemName: "checkmark.icloud")

        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .symbolEffect(.rotate, options: .repeat(.continuous))

        case .completed:
            Image(systemName: "checkmark.icloud.fill")

        case .failed:
            Image(systemName: "exclamationmark.icloud")
        }
    }

    private var statusColor: Color {
        switch status {
        case .idle: return .secondary
        case .syncing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }

    private var statusLabel: String {
        switch status {
        case .idle:
            return "Synced"
        case .syncing(let progress):
            if progress > 0 {
                return "Syncing \(Int(progress * 100))%"
            }
            return "Syncing..."
        case .completed(let count):
            return "\(count) note\(count == 1 ? "" : "s") synced"
        case .failed(let error):
            return "Sync failed: \(error)"
        }
    }
}

// MARK: - Note Sync Badge
/// Small badge showing individual note sync status
struct NoteSyncBadge: View {
    let isSynced: Bool

    var body: some View {
        Image(systemName: isSynced ? "checkmark.icloud.fill" : "icloud.slash")
            .font(.system(size: 10))
            .foregroundColor(isSynced ? .green.opacity(0.7) : .secondary.opacity(0.5))
    }
}

// MARK: - Preview
#Preview("Sync Status Indicator") {
    VStack(spacing: 24) {
        Group {
            SyncStatusIndicator(status: .idle, showLabel: true)
            SyncStatusIndicator(status: .syncing(progress: 0.5), showLabel: true)
            SyncStatusIndicator(status: .completed(syncedCount: 3), showLabel: true)
            SyncStatusIndicator(status: .failed(error: "No connection"), showLabel: true)
        }

        Divider()

        HStack(spacing: 16) {
            NoteSyncBadge(isSynced: true)
            Text("Synced")

            NoteSyncBadge(isSynced: false)
            Text("Pending")
        }
        .font(.caption)
    }
    .padding()
}
