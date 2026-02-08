import SwiftUI

// MARK: - Sync Indicator
/// A small indicator dot that shows a field is synced from another user's profile
/// Tapping it shows a tooltip explaining the sync relationship
struct SyncIndicator: View {
    let sourceName: String

    @Environment(\.appAccentColor) private var appAccentColor
    @State private var showTooltip = false

    var body: some View {
        Button {
            showTooltip = true
        } label: {
            Circle()
                .fill(appAccentColor)
                .frame(width: 8, height: 8)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Synced field")
        .accessibilityHint("Tap to learn more about this synced field")
        .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
            SyncTooltipContent(sourceName: sourceName)
                .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Sync Tooltip Content
/// Content shown in the popover when tapping a sync indicator
struct SyncTooltipContent: View {
    let sourceName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(appAccentColor)

                Text("Synced Field")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
            }

            // Explanation
            Text("This info comes from \(sourceName)'s profile. Only they can update it.")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Got it button
            Button {
                dismiss()
            } label: {
                Text("Got it")
                    .font(.appCaption)
                    .foregroundColor(appAccentColor)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .frame(maxWidth: 280)
        .background(Color.cardBackground)
    }
}

// MARK: - Sync Badge
/// A more prominent badge showing sync status, used in profile headers
struct SyncBadge: View {
    let sourceName: String
    let isLocalOnly: Bool

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isLocalOnly ? "link.badge.plus" : "arrow.triangle.2.circlepath")
                .font(.system(size: 12))

            Text(isLocalOnly ? "Previously synced" : "Synced from \(sourceName)")
                .font(.appCaption)
        }
        .foregroundColor(isLocalOnly ? .textSecondary : appAccentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isLocalOnly ? Color.cardBackgroundSoft : appAccentColor.opacity(0.15))
        )
    }
}

// MARK: - Synced Field Label
/// A label component that shows a sync indicator next to field labels
struct SyncedFieldLabel: View {
    let label: String
    let isSynced: Bool
    let sourceName: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            if isSynced, let name = sourceName {
                SyncIndicator(sourceName: name)
            }
        }
    }
}

// MARK: - Locked Field Overlay
/// An overlay that shows when a user tries to tap on a synced field
struct LockedFieldMessage: View {
    let sourceName: String

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("This field is synced")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                Text("Only \(sourceName) can edit this information")
                    .font(.appCaption)
                    .foregroundColor(.textMuted)
            }
        }
        .padding(12)
        .background(Color.cardBackgroundSoft)
        .cornerRadius(AppDimensions.smallCornerRadius)
    }
}

// MARK: - Preview
#if DEBUG
#Preview("Sync Indicator") {
    VStack(spacing: 20) {
        HStack {
            Text("Birthday")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
            SyncIndicator(sourceName: "John")
        }

        SyncBadge(sourceName: "John Smith", isLocalOnly: false)
        SyncBadge(sourceName: "John Smith", isLocalOnly: true)

        SyncedFieldLabel(label: "Phone", isSynced: true, sourceName: "Jane")
        SyncedFieldLabel(label: "Notes", isSynced: false, sourceName: nil)

        LockedFieldMessage(sourceName: "John Smith")
    }
    .padding()
    .background(Color.appBackground)
}
#endif
