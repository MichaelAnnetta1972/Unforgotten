import SwiftUI

// MARK: - Add Useful Contact View
struct AddUsefulContactView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    var onDismiss: (() -> Void)? = nil
    let onSave: (UsefulContact) -> Void

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

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
            VStack(spacing: 0) {
                // Custom header with icons
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

                    Text("Add Contact")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        Task { await saveContact() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(name.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                            )
                    }
                    .disabled(name.isBlank || isLoading)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)

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
                                            .background(category == cat ? appAccentColor : Color.cardBackgroundSoft)
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
            .background(Color.clear)
            .navigationBarHidden(true)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.clear, for: .navigationBar)
        .containerBackground(.clear, for: .navigation)
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
            dismissView()
        } catch {
            errorMessage = "Failed to save contact"
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    AddUsefulContactView { _ in }
        .environmentObject(AppState.forPreview())
}
