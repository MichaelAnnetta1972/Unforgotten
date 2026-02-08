import SwiftUI

// MARK: - Synced Detail Item Card
/// A card that displays a detail field with optional sync indicator
/// For synced fields, shows a lock icon and prevents editing
struct SyncedDetailItemCard: View {
    let label: String
    let value: String
    let isSynced: Bool
    let sourceName: String?
    let showChevron: Bool
    let action: (() -> Void)?

    @Environment(\.appAccentColor) private var appAccentColor
    @State private var showLockedMessage = false

    init(
        label: String,
        value: String,
        isSynced: Bool = false,
        sourceName: String? = nil,
        showChevron: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.label = label
        self.value = value
        self.isSynced = isSynced
        self.sourceName = sourceName
        self.showChevron = showChevron
        self.action = action
    }

    var body: some View {
        Group {
            if isSynced {
                // Synced fields show locked state when tapped
                Button {
                    showLockedMessage = true
                } label: {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showLockedMessage, arrowEdge: .bottom) {
                    if let name = sourceName {
                        SyncTooltipContent(sourceName: name)
                            .presentationCompactAdaptation(.popover)
                    }
                }
            } else if let action = action {
                // Non-synced fields with action
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Non-synced fields without action
                cardContent
            }
        }
    }

    private var cardContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Label with optional sync indicator
                HStack(spacing: 6) {
                    Text(label)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    if isSynced, let name = sourceName {
                        SyncIndicator(sourceName: name)
                    }
                }

                // Value
                Text(value)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            // Right side indicator
            if isSynced {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            } else if showChevron {
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Synced Value Pill Card
/// A pill-style card for displaying synced values (like in grids)
struct SyncedValuePillCard: View {
    let label: String
    let value: String
    let isSynced: Bool
    let sourceName: String?
    let color: Color

    @State private var showSyncTooltip = false

    init(
        label: String,
        value: String,
        isSynced: Bool = false,
        sourceName: String? = nil,
        color: Color = .textPrimary
    ) {
        self.label = label
        self.value = value
        self.isSynced = isSynced
        self.sourceName = sourceName
        self.color = color
    }

    var body: some View {
        Button {
            if isSynced {
                showSyncTooltip = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    if isSynced, let name = sourceName {
                        SyncIndicator(sourceName: name)
                    }
                }

                Text(value)
                    .font(.appBodyMedium)
                    .foregroundColor(color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.smallCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isSynced)
        .popover(isPresented: $showSyncTooltip, arrowEdge: .bottom) {
            if let name = sourceName {
                SyncTooltipContent(sourceName: name)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }
}

// MARK: - Profile Field Row (for edit forms)
/// A form row that handles synced vs editable fields
struct ProfileFieldRow: View {
    let label: String
    @Binding var value: String
    let placeholder: String
    let isSynced: Bool
    let sourceName: String?
    let keyboardType: UIKeyboardType

    @Environment(\.appAccentColor) private var appAccentColor

    init(
        label: String,
        value: Binding<String>,
        placeholder: String = "",
        isSynced: Bool = false,
        sourceName: String? = nil,
        keyboardType: UIKeyboardType = .default
    ) {
        self.label = label
        self._value = value
        self.placeholder = placeholder
        self.isSynced = isSynced
        self.sourceName = sourceName
        self.keyboardType = keyboardType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label with sync indicator
            HStack(spacing: 6) {
                Text(label)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                if isSynced, let name = sourceName {
                    SyncIndicator(sourceName: name)
                }
            }

            // Input or locked display
            if isSynced {
                // Show locked value for synced fields
                HStack {
                    Text(value.isEmpty ? placeholder : value)
                        .font(.appBody)
                        .foregroundColor(value.isEmpty ? .textMuted : .textPrimary)

                    Spacer()

                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.smallCornerRadius)
            } else {
                // Editable text field
                TextField(placeholder, text: $value)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)
                    .keyboardType(keyboardType)
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.smallCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.smallCornerRadius)
                            .stroke(Color.textMuted.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview("Synced Detail Cards") {
    ScrollView {
        VStack(spacing: 16) {
            Text("Non-synced field")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            SyncedDetailItemCard(
                label: "Notes",
                value: "Remember to bring flowers",
                isSynced: false,
                showChevron: true,
                action: {}
            )

            Text("Synced field")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            SyncedDetailItemCard(
                label: "Birthday",
                value: "July 15, 1955",
                isSynced: true,
                sourceName: "John Smith"
            )

            Text("Synced pill")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            SyncedValuePillCard(
                label: "Phone",
                value: "+1 (555) 123-4567",
                isSynced: true,
                sourceName: "John Smith"
            )
        }
        .padding()
    }
    .background(Color.appBackground)
}
#endif
