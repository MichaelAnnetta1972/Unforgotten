import SwiftUI

struct ImportUsefulContactsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let imported: [ImportedContact]
    let existingNames: Set<String>
    let onComplete: (Int) -> Void

    /// Per-row state. Mirrors `imported` 1:1 by index.
    @State private var rows: [Row] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    struct Row: Identifiable, Equatable {
        let id: UUID
        var name: String
        var category: ContactCategory
        var phone: String?
        var email: String?
        var address: String?
        var isSelected: Bool
        var isDuplicate: Bool
    }

    private var selectedCount: Int {
        rows.filter { $0.isSelected && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundLight.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Text("Choose a category for each contact, then tap Import. Tap a row to include or exclude it.")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppDimensions.screenPadding)
                            .padding(.top, 8)

                        ForEach($rows) { $row in
                            ContactRowCard(row: $row, accentColor: appAccentColor)
                                .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        Spacer().frame(height: 80)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Review Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Import (\(selectedCount))")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(selectedCount == 0 || isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear { hydrateRows() }
        }
    }

    private func hydrateRows() {
        guard rows.isEmpty else { return }
        rows = imported.map { contact in
            let isDup = existingNames.contains(contact.fullName.lowercased())
            return Row(
                id: contact.id,
                name: contact.fullName,
                category: .other,
                phone: contact.phone,
                email: contact.email,
                address: contact.address,
                isSelected: !isDup,
                isDuplicate: isDup
            )
        }
    }

    private func save() async {
        guard let account = appState.currentAccount else {
            errorMessage = "No account found."
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        var savedCount = 0
        for row in rows where row.isSelected {
            let trimmed = row.name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            do {
                _ = try await appState.usefulContactRepository.createContact(
                    accountId: account.id,
                    name: trimmed,
                    category: row.category,
                    companyName: nil,
                    phone: row.phone,
                    email: row.email,
                    website: nil,
                    address: row.address,
                    notes: nil,
                    isFavourite: false
                )
                savedCount += 1
            } catch {
                #if DEBUG
                print("Failed to import contact \(trimmed): \(error)")
                #endif
            }
        }

        onComplete(savedCount)
        dismiss()
    }
}

private struct ContactRowCard: View {
    @Binding var row: ImportUsefulContactsView.Row
    let accentColor: Color

    var body: some View {
        VStack(spacing: 0) {
            // Header with selection toggle and name
            HStack(spacing: 12) {
                Button {
                    row.isSelected.toggle()
                } label: {
                    Image(systemName: row.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(row.isSelected ? accentColor : .textSecondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    if row.name.isEmpty {
                        Text("(No name)")
                            .font(.appCardTitle)
                            .foregroundColor(.medicalRed)
                    } else {
                        Text(row.name)
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)
                    }

                    if row.isDuplicate {
                        Text("The name already exists. Select if it is another contact with the same name.")
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, AppDimensions.cardPadding)
            .padding(.top, AppDimensions.cardPadding)

            if row.isSelected {
                Divider()
                    .background(Color.cardBackgroundSoft)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Category")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Picker("", selection: $row.category) {
                            ForEach(ContactCategory.allCases, id: \.self) { cat in
                                Text(cat.displayName).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(accentColor)
                    }

                    if let phone = row.phone, !phone.isEmpty {
                        InfoLine(icon: "phone.fill", text: phone)
                    }
                    if let email = row.email, !email.isEmpty {
                        InfoLine(icon: "envelope.fill", text: email)
                    }
                    if let address = row.address, !address.isEmpty {
                        InfoLine(icon: "mappin.and.ellipse", text: address)
                    }
                }
                .padding(AppDimensions.cardPadding)
            } else {
                Spacer().frame(height: AppDimensions.cardPadding)
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .opacity(row.isSelected ? 1.0 : 0.55)
    }
}

private struct InfoLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
                .frame(width: 16)
            Text(text)
                .font(.appCaption)
                .foregroundColor(.textPrimary)
                .lineLimit(2)
        }
    }
}
