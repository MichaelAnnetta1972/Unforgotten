import SwiftUI

// MARK: - Useful Contacts List View
struct UsefulContactsListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @StateObject private var viewModel = UsefulContactsViewModel()
    @State private var showAddContact = false
    @State private var showSettings = false
    @State private var selectedCategory: ContactCategory? = nil
    @State private var contactToDelete: UsefulContact?
    @State private var showDeleteConfirmation = false

    var filteredContacts: [UsefulContact] {
        if let category = selectedCategory {
            return viewModel.contacts.filter { $0.category == category }
        }
        return viewModel.contacts
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header at the top - fully interactive
                HeaderImageView(
                    imageName: "header-contacts",
                    title: "Useful Contacts",
                    showBackButton: true,
                    backAction: { dismiss() },
                    showSettingsButton: true,
                    settingsAction: { showSettings = true }
                )

                // Content scrolls below header
                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Category filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                CategoryFilterButton(
                                    title: "All",
                                    isSelected: selectedCategory == nil,
                                    action: { selectedCategory = nil }
                                )

                                ForEach(ContactCategory.allCases, id: \.self) { category in
                                    CategoryFilterButton(
                                        title: category.displayName,
                                        isSelected: selectedCategory == category,
                                        action: { selectedCategory = category }
                                    )
                                }
                            }
                            .padding(.vertical, 12)
                        }

                        // Contacts list
                        LazyVStack(spacing: AppDimensions.cardSpacing) {
                            ForEach(filteredContacts) { contact in
                                UsefulContactRow(
                                    contact: contact,
                                    onDelete: {
                                        contactToDelete = contact
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }

                        // Loading state
                        if viewModel.isLoading && viewModel.contacts.isEmpty {
                            LoadingView(message: "Loading contacts...")
                                .padding(.top, 40)
                        }

                        // Empty state
                        if filteredContacts.isEmpty && !viewModel.isLoading {
                            if viewModel.contacts.isEmpty {
                                // No contacts at all
                                EmptyStateView(
                                    icon: "phone.fill",
                                    title: "No contacts yet",
                                    message: "Add useful contacts like doctors, plumbers, and services",
                                    buttonTitle: "Add Contact",
                                    buttonAction: { showAddContact = true }
                                )
                                .padding(.top, 40)
                            } else {
                                // No contacts for the selected category
                                Text("No contacts in this category")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                            }
                        }

                        Spacer()
                            .frame(height: 140)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddContact) {
            AddUsefulContactView { _ in
                Task {
                    await viewModel.loadContacts(appState: appState)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .task {
            await viewModel.loadContacts(appState: appState)
        }
        .refreshable {
            await viewModel.loadContacts(appState: appState)
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .alert("Delete Contact", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                contactToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let contact = contactToDelete {
                    Task {
                        await viewModel.deleteContact(id: contact.id, appState: appState)
                        contactToDelete = nil
                    }
                }
            }
        } message: {
            if let contact = contactToDelete {
                Text("Are you sure you want to delete \(contact.name)? This action cannot be undone.")
            }
        }
    }
}

// MARK: - Category Filter Button
struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(isSelected ? .black : .textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentYellow : Color.cardBackgroundSoft)
                .cornerRadius(20)
        }
    }
}

// MARK: - Useful Contact Row
struct UsefulContactRow: View {
    let contact: UsefulContact
    let onDelete: () -> Void

    @State private var showOptions = false

    var body: some View {
        NavigationLink(destination: UsefulContactDetailView(contact: contact)) {
            HStack {
                // Icon
                Image(systemName: contact.category.icon)
                    .font(.title3)
                    .foregroundColor(.accentYellow)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.name)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)

                    Text(contact.category.displayName)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Quick call button
                if let phone = contact.phone {
                    Button {
                        callPhone(phone)
                    } label: {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.badgeGreen)
                            .padding(10)
                            .background(Color.badgeGreen.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Options button (vertical dots)
                Button {
                    showOptions = true
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
        .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
            Button("Delete item", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func callPhone(_ number: String) {
        let cleaned = number.replacingOccurrences(of: " ", with: "")
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Useful Contacts View Model
@MainActor
class UsefulContactsViewModel: ObservableObject {
    @Published var contacts: [UsefulContact] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadContacts(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            contacts = try await appState.usefulContactRepository.getContacts(accountId: account.id)
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    func deleteContact(id: UUID, appState: AppState) async {
        do {
            try await appState.usefulContactRepository.deleteContact(id: id)
            contacts.removeAll { $0.id == id }
        } catch {
            self.error = "Failed to delete contact: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        UsefulContactsListView()
            .environmentObject(AppState())
    }
}
