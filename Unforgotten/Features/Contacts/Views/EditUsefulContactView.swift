import SwiftUI

// MARK: - Edit Useful Contact View
struct EditUsefulContactView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let contact: UsefulContact
    let onSave: (UsefulContact) -> Void

    @State private var name: String
    @State private var category: ContactCategory
    @State private var companyName: String
    @State private var phone: String
    @State private var email: String
    @State private var website: String
    @State private var address: String
    @State private var notes: String

    @State private var isLoading = false
    @State private var errorMessage: String?

    init(contact: UsefulContact, onSave: @escaping (UsefulContact) -> Void) {
        self.contact = contact
        self.onSave = onSave
        self._name = State(initialValue: contact.name)
        self._category = State(initialValue: contact.category)
        self._companyName = State(initialValue: contact.companyName ?? "")
        self._phone = State(initialValue: contact.phone ?? "")
        self._email = State(initialValue: contact.email ?? "")
        self._website = State(initialValue: contact.website ?? "")
        self._address = State(initialValue: contact.address ?? "")
        self._notes = State(initialValue: contact.notes ?? "")
    }

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
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await updateContact() }
                    }
                    .foregroundColor(.accentYellow)
                    .disabled(name.isBlank || isLoading)
                }
            }
        }
    }

    private func updateContact() async {
        isLoading = true
        errorMessage = nil

        var updatedContact = contact
        updatedContact.name = name
        updatedContact.category = category
        updatedContact.companyName = companyName.isBlank ? nil : companyName
        updatedContact.phone = phone.isBlank ? nil : phone
        updatedContact.email = email.isBlank ? nil : email
        updatedContact.website = website.isBlank ? nil : website
        updatedContact.address = address.isBlank ? nil : address
        updatedContact.notes = notes.isBlank ? nil : notes

        do {
            let saved = try await appState.usefulContactRepository.updateContact(updatedContact)
            onSave(saved)
            dismiss()
        } catch {
            errorMessage = "Failed to save contact"
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    EditUsefulContactView(
        contact: UsefulContact(
            id: UUID(),
            accountId: UUID(),
            name: "Dr. Smith",
            category: .doctor,
            companyName: nil,
            phone: "555-1234",
            email: nil,
            website: nil,
            address: nil,
            notes: nil,
            isFavourite: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    ) { _ in }
    .environmentObject(AppState())
}
