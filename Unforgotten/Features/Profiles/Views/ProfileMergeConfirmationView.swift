import SwiftUI

// MARK: - Profile Merge Confirmation View
/// Shown when an incoming synced profile matches an existing local profile by email
/// Allows the user to choose which fields to sync from the source profile
struct ProfileMergeConfirmationView: View {
    let existingProfile: Profile
    let incomingProfileData: Profile
    let onConfirm: ([String]) -> Void
    let onCancel: () -> Void

    @State private var selectedFields: Set<String> = []
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.dismiss) private var dismiss

    /// Fields that can be synced
    private let syncableFields: [(key: String, label: String)] = [
        ("full_name", "Full Name"),
        ("preferred_name", "Preferred Name"),
        ("birthday", "Birthday"),
        ("phone", "Phone"),
        ("email", "Email"),
        ("address", "Address")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header explanation
                    headerSection

                    // Field comparison list
                    VStack(spacing: 12) {
                        ForEach(syncableFields, id: \.key) { field in
                            FieldComparisonRow(
                                fieldKey: field.key,
                                fieldLabel: field.label,
                                existingValue: getValue(for: field.key, from: existingProfile),
                                incomingValue: getValue(for: field.key, from: incomingProfileData),
                                isSelected: selectedFields.contains(field.key),
                                onToggle: { toggleField(field.key) }
                            )
                            .environment(\.appAccentColor, appAccentColor)
                        }
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)

                    // Info note
                    infoNote

                    Spacer()
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Profile Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Merge") {
                        onConfirm(Array(selectedFields))
                        dismiss()
                    }
                    .disabled(selectedFields.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(appAccentColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 32))
                    .foregroundColor(appAccentColor)
            }

            // Title and description
            VStack(spacing: 8) {
                Text("Profile Already Exists")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                Text("A profile for \(existingProfile.displayName) already exists. Choose which fields to sync from their connected account.")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, AppDimensions.screenPadding)
    }

    // MARK: - Info Note
    private var infoNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(appAccentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Selected fields will stay in sync")
                    .font(.appCaption)
                    .foregroundColor(.textPrimary)

                Text("When they update their profile, your copy will update too.")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(appAccentColor.opacity(0.1))
        .cornerRadius(AppDimensions.smallCornerRadius)
        .padding(.horizontal, AppDimensions.screenPadding)
    }

    // MARK: - Helper Methods
    private func getValue(for field: String, from profile: Profile) -> String? {
        switch field {
        case "full_name": return profile.fullName
        case "preferred_name": return profile.preferredName
        case "birthday":
            return profile.birthday?.formatted(date: .abbreviated, time: .omitted)
        case "phone": return profile.phone
        case "email": return profile.email
        case "address": return profile.address
        default: return nil
        }
    }

    private func toggleField(_ field: String) {
        if selectedFields.contains(field) {
            selectedFields.remove(field)
        } else {
            selectedFields.insert(field)
        }
    }
}

// MARK: - Field Comparison Row
/// Shows the existing and incoming values for a field with a selection toggle
struct FieldComparisonRow: View {
    let fieldKey: String
    let fieldLabel: String
    let existingValue: String?
    let incomingValue: String?
    let isSelected: Bool
    let onToggle: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    /// Whether there's a difference between existing and incoming values
    var hasChange: Bool {
        existingValue != incomingValue && incomingValue != nil
    }

    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    // Field label
                    Text(fieldLabel)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    // Value comparison
                    if hasChange {
                        // Show old -> new transition
                        HStack(spacing: 8) {
                            Text(existingValue ?? "Not set")
                                .font(.appBody)
                                .foregroundColor(.textMuted)
                                .strikethrough(true, color: .textMuted)

                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.textSecondary)

                            Text(incomingValue ?? "")
                                .font(.appBodyMedium)
                                .foregroundColor(.textPrimary)
                        }
                    } else {
                        // No change - show current value
                        Text(existingValue ?? "Not set")
                            .font(.appBody)
                            .foregroundColor(existingValue != nil ? .textPrimary : .textMuted)
                    }
                }

                Spacer()

                // Selection toggle (only for fields with changes)
                if hasChange {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? appAccentColor : .textSecondary)
                }
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(isSelected ? appAccentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!hasChange)
        .opacity(hasChange ? 1 : 0.6)
    }
}

// MARK: - Profile Merge Summary View
/// Shown after merge to summarize what was updated
struct ProfileMergeSummaryView: View {
    let sourceName: String
    let updatedFields: [(label: String, oldValue: String?, newValue: String?)]
    let onDismiss: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        VStack(spacing: 24) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.badgeGreen.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.badgeGreen)
            }

            // Title
            VStack(spacing: 8) {
                Text("Profile Updated")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                Text("Some fields were updated from \(sourceName)'s profile.")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Updated fields list
            VStack(spacing: 12) {
                ForEach(updatedFields, id: \.label) { field in
                    HStack {
                        Text(field.label)
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        Spacer()

                        HStack(spacing: 6) {
                            if let oldValue = field.oldValue {
                                Text(oldValue)
                                    .font(.appCaption)
                                    .foregroundColor(.textMuted)
                                    .strikethrough()
                            }

                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.textSecondary)

                            Text(field.newValue ?? "")
                                .font(.appCaption)
                                .foregroundColor(.textPrimary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, AppDimensions.screenPadding)

            Spacer()

            // Got it button
            Button(action: onDismiss) {
                Text("Got it")
                    .font(.appBodyMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDimensions.buttonHeight)
                    .background(appAccentColor)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Preview
#if DEBUG
#Preview("Merge Confirmation") {
    ProfileMergeConfirmationView(
        existingProfile: Profile(
            id: UUID(),
            accountId: UUID(),
            type: .relative,
            fullName: "John Smith",
            preferredName: nil,
            birthday: Date().addingTimeInterval(-60 * 60 * 24 * 365 * 60),
            phone: "+1 555 123 4567",
            email: "john@example.com",
            createdAt: Date(),
            updatedAt: Date()
        ),
        incomingProfileData: Profile(
            id: UUID(),
            accountId: UUID(),
            type: .relative,
            fullName: "John Robert Smith",
            preferredName: "Johnny",
            birthday: Date().addingTimeInterval(-60 * 60 * 24 * 365 * 61),
            phone: "+1 555 987 6543",
            email: "john@example.com",
            createdAt: Date(),
            updatedAt: Date()
        ),
        onConfirm: { fields in
            print("Selected fields: \(fields)")
        },
        onCancel: {}
    )
}

#Preview("Merge Summary") {
    ProfileMergeSummaryView(
        sourceName: "John Smith",
        updatedFields: [
            ("Phone", "+1 555 123 4567", "+1 555 987 6543"),
            ("Birthday", "Jan 15, 1964", "Jan 15, 1963")
        ],
        onDismiss: {}
    )
}
#endif
