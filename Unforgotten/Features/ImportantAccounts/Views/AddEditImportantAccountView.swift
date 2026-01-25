import SwiftUI

// MARK: - Add/Edit Important Account View
struct AddEditImportantAccountView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let profile: Profile
    let mode: Mode
    var onDismiss: (() -> Void)? = nil
    let onSave: (ImportantAccount) -> Void

    enum Mode {
        case add
        case edit(ImportantAccount)

        var title: String {
            switch self {
            case .add: return "Add Account"
            case .edit: return "Edit Account"
            }
        }
    }

    // Form fields
    @State private var accountName: String = ""
    @State private var websiteURL: String = ""
    @State private var username: String = ""
    @State private var emailAddress: String = ""
    @State private var phoneNumber: String = ""
    @State private var securityQuestionHint: String = ""
    @State private var recoveryHint: String = ""
    @State private var notes: String = ""
    @State private var selectedCategory: AccountCategory? = nil

    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    var isValid: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
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

                Text(mode.title)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    Task { await saveAccount() }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(!isValid || isSaving ? Color.gray.opacity(0.3) : appAccentColor)
                        )
                }
                .disabled(!isValid || isSaving)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackgroundLight)

            ZStack {
                Color.appBackgroundLight.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Required Section
                        VStack(alignment: .leading, spacing: AppDimensions.cardSpacing) {
                            AccountFormSectionHeader(title: "ACCOUNT NAME", required: true)

                            AccountFormTextField(
                                placeholder: "e.g., Netflix, Gmail, Chase Bank",
                                text: $accountName,
                                icon: "textformat"
                            )
                        }

                        // Category Section
                        VStack(alignment: .leading, spacing: AppDimensions.cardSpacing) {
                            AccountFormSectionHeader(title: "CATEGORY")

                            AccountCategoryPicker(selection: $selectedCategory)
                        }

                        // Login Details Section
                        VStack(alignment: .leading, spacing: AppDimensions.cardSpacing) {
                            AccountFormSectionHeader(title: "LOGIN DETAILS")

                            AccountFormTextField(
                                placeholder: "Website URL",
                                text: $websiteURL,
                                icon: "globe",
                                keyboardType: .URL,
                                autocapitalization: .never
                            )

                            AccountFormTextField(
                                placeholder: "Username",
                                text: $username,
                                icon: "person.fill",
                                autocapitalization: .never
                            )

                            AccountFormTextField(
                                placeholder: "Email Address",
                                text: $emailAddress,
                                icon: "envelope.fill",
                                keyboardType: .emailAddress,
                                autocapitalization: .never
                            )

                            AccountFormTextField(
                                placeholder: "Phone Number",
                                text: $phoneNumber,
                                icon: "phone.fill",
                                keyboardType: .phonePad
                            )
                        }

                        // Recovery Section
                        VStack(alignment: .leading, spacing: AppDimensions.cardSpacing) {
                            AccountFormSectionHeader(title: "RECOVERY HINTS")

                            Text("Don't enter actual passwords or security answers here. Use helpful hints to help you remember.")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, AppDimensions.screenPadding)

                            AccountFormTextField(
                                placeholder: "Security question hint (e.g., \"pet's name\")",
                                text: $securityQuestionHint,
                                icon: "questionmark.circle.fill"
                            )

                            AccountFormTextField(
                                placeholder: "Recovery hint (e.g., \"same as email\", \"blue notebook\")",
                                text: $recoveryHint,
                                icon: "lightbulb.fill"
                            )
                        }

                        // Notes Section
                        VStack(alignment: .leading, spacing: AppDimensions.cardSpacing) {
                            AccountFormSectionHeader(title: "NOTES")

                            AccountFormTextEditor(
                                placeholder: "Any additional notes...",
                                text: $notes
                            )
                        }

                        Spacer()
                            .frame(height: 50)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .background(Color.appBackgroundLight)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if case .edit(let account) = mode {
                populateFields(from: account)
            }
        }
    }

    private func populateFields(from account: ImportantAccount) {
        accountName = account.accountName
        websiteURL = account.websiteURL ?? ""
        username = account.username ?? ""
        emailAddress = account.emailAddress ?? ""
        phoneNumber = account.phoneNumber ?? ""
        securityQuestionHint = account.securityQuestionHint ?? ""
        recoveryHint = account.recoveryHint ?? ""
        notes = account.notes ?? ""
        selectedCategory = account.category
    }

    private func saveAccount() async {
        isSaving = true

        do {
            let savedAccount: ImportantAccount

            if case .edit(let existingAccount) = mode {
                // Update existing account
                let updatedAccount = ImportantAccount(
                    id: existingAccount.id,
                    profileId: profile.id,
                    accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
                    websiteURL: websiteURL.isEmpty ? nil : websiteURL,
                    username: username.isEmpty ? nil : username,
                    emailAddress: emailAddress.isEmpty ? nil : emailAddress,
                    phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                    securityQuestionHint: securityQuestionHint.isEmpty ? nil : securityQuestionHint,
                    recoveryHint: recoveryHint.isEmpty ? nil : recoveryHint,
                    notes: notes.isEmpty ? nil : notes,
                    category: selectedCategory,
                    createdAt: existingAccount.createdAt,
                    updatedAt: Date()
                )
                savedAccount = try await appState.importantAccountRepository.updateAccount(updatedAccount)
            } else {
                // Create new account
                let insert = ImportantAccountInsert(
                    profileId: profile.id,
                    accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
                    websiteURL: websiteURL.isEmpty ? nil : websiteURL,
                    username: username.isEmpty ? nil : username,
                    emailAddress: emailAddress.isEmpty ? nil : emailAddress,
                    phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                    securityQuestionHint: securityQuestionHint.isEmpty ? nil : securityQuestionHint,
                    recoveryHint: recoveryHint.isEmpty ? nil : recoveryHint,
                    notes: notes.isEmpty ? nil : notes,
                    category: selectedCategory
                )
                savedAccount = try await appState.importantAccountRepository.createAccount(insert)
            }

            await MainActor.run {
                onSave(savedAccount)
                NotificationCenter.default.post(name: .importantAccountsDidChange, object: nil, userInfo: ["profileId": profile.id])
                dismissView()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isSaving = false
            }
        }
    }
}

// MARK: - Supporting Components

struct AccountFormSectionHeader: View {
    let title: String
    var required: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            if required {
                Text("*")
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, AppDimensions.screenPadding)
    }
}

struct AccountFormTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.textSecondary)
                    .frame(width: 20)
            }

            TextField(placeholder, text: $text)
                .font(.appBody)
                .foregroundColor(.textPrimary)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .padding(.horizontal, AppDimensions.screenPadding)
    }
}

struct AccountFormTextEditor: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
            }

            TextEditor(text: $text)
                .font(.appBody)
                .foregroundColor(.textPrimary)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .padding(.horizontal, AppDimensions.screenPadding)
    }
}

struct AccountCategoryPicker: View {
    @Binding var selection: AccountCategory?
    @Environment(\.appAccentColor) private var appAccentColor

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AccountCategory.allCases, id: \.self) { category in
                AccountCategoryChip(
                    category: category,
                    isSelected: selection == category
                ) {
                    if selection == category {
                        selection = nil
                    } else {
                        selection = category
                    }
                }
            }
        }
        .padding(.horizontal, AppDimensions.screenPadding)
    }
}

struct AccountCategoryChip: View {
    let category: AccountCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 20))

                Text(category.displayName)
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? category.color.opacity(0.3) : Color.cardBackground)
            .foregroundColor(isSelected ? category.color : .textSecondary)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Preview
#Preview {
    AddEditImportantAccountView(
        profile: Profile(
            id: UUID(),
            accountId: UUID(),
            type: .primary,
            fullName: "John Doe",
            createdAt: Date(),
            updatedAt: Date()
        ),
        mode: .add
    ) { _ in }
    .environmentObject(AppState())
}
