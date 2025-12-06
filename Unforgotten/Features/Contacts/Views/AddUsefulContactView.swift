import SwiftUI

// MARK: - Add Useful Contact View
struct AddUsefulContactView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let onSave: (UsefulContact) -> Void

    @State private var name = ""
    @State private var category: ContactCategory = .other
    @State private var companyName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var address = ""
    @State private var notes = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        AppTextField(placeholder: "Name / Company *", text: $name)

                        // Category picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(ContactCategory.allCases, id: \.self) { cat in
                                    Button {
                                        category = cat
                                    } label: {
                                        Text(cat.displayName)
                                            .font(.appCaption)
                                            .foregroundColor(category == cat ? .black : .textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(category == cat ? Color.accentYellow : Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }

                        AppTextField(placeholder: "Company Name (if different)", text: $companyName)
                        AppTextField(placeholder: "Phone", text: $phone, keyboardType: .phonePad)
                        AppTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                        AppTextField(placeholder: "Website", text: $website, keyboardType: .URL)
                        AppTextField(placeholder: "Address", text: $address)
                        AppTextField(placeholder: "Notes", text: $notes)

                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveContact() }
                    }
                    .foregroundColor(.accentYellow)
                    .disabled(name.isBlank || isLoading)
                }
            }
        }
    }

    private func saveContact() async {
        guard let account = appState.currentAccount else { return }

        isLoading = true
        errorMessage = nil

        let insert = UsefulContactInsert(
            accountId: account.id,
            name: name,
            category: category,
            companyName: companyName.isBlank ? nil : companyName,
            phone: phone.isBlank ? nil : phone,
            email: email.isBlank ? nil : email,
            website: website.isBlank ? nil : website,
            address: address.isBlank ? nil : address,
            notes: notes.isBlank ? nil : notes
        )

        do {
            let contact = try await appState.usefulContactRepository.createContact(insert)
            onSave(contact)
            dismiss()
        } catch {
            errorMessage = "Failed to save contact"
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    AddUsefulContactView { _ in }
        .environmentObject(AppState())
}
