//
//  UsefulContactsContainerView.swift
//  Unforgotten
//
//  Container for Useful Contacts - uses iPhone view for both platforms
//  iPad layout is handled by iPadRootView with the Home sidebar
//

import SwiftUI

/// Container for Useful Contacts
/// Returns the iPhone UsefulContactsListView for both platforms
struct UsefulContactsContainerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        UsefulContactsListView()
    }
}

// MARK: - iPad Useful Contacts View
struct iPadUsefulContactsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = UsefulContactsViewModel()
    @State private var selectedContact: UsefulContact?
    @State private var searchText = ""
    @State private var selectedCategory: ContactCategory? = nil
    @State private var showAddContact = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    var filteredContacts: [UsefulContact] {
        var contacts = viewModel.contacts

        if let category = selectedCategory {
            contacts = contacts.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            contacts = contacts.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.companyName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.category.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return contacts.sorted { $0.name < $1.name }
    }

    // Group contacts by first letter
    var groupedContacts: [(String, [UsefulContact])] {
        let grouped = Dictionary(grouping: filteredContacts) { contact in
            String(contact.name.prefix(1).uppercased())
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        HStack(spacing: 0) {
            leftPane

            Rectangle()
                .fill(Color.cardBackgroundLight)
                .frame(width: 1)

            rightPane
        }
        .background(Color.appBackground)
        .navigationTitle("Useful Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddContact) {
            AddUsefulContactView { newContact in
                Task {
                    await viewModel.loadContacts(appState: appState)
                    selectedContact = newContact
                }
            }
            .presentationBackground(Color.appBackgroundLight)
        }
        .task {
            await viewModel.loadContacts(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsDidChange)) { _ in
            Task {
                await viewModel.loadContacts(appState: appState)
            }
        }
    }

    // MARK: - Left Pane
    private var leftPane: some View {
        VStack(spacing: 0) {
            searchAndFilterBar
            contactListScrollView
        }
        .frame(width: 320)
        .background(Color.appBackground)
    }

    // MARK: - Search and Filter Bar
    private var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            searchField
            filterMenu
            addButton
        }
        .padding(16)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)
            TextField("Search contacts", text: $searchText)
                .font(.appBody)
                .foregroundColor(.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(10)
    }

    private var filterMenu: some View {
        Menu {
            Button {
                selectedCategory = nil
            } label: {
                Label("All Categories", systemImage: selectedCategory == nil ? "checkmark" : "")
            }

            Divider()

            ForEach(ContactCategory.allCases, id: \.self) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Label(category.displayName, systemImage: selectedCategory == category ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: selectedCategory != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 20))
                .foregroundColor(selectedCategory != nil ? appAccentColor : .textSecondary)
                .frame(width: 44, height: 44)
                .background(Color.cardBackground)
                .cornerRadius(10)
        }
    }

    private var addButton: some View {
        Button {
            showAddContact = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(appAccentColor)
                .cornerRadius(10)
        }
    }

    // MARK: - Contact List
    private var contactListScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(groupedContacts, id: \.0) { letter, contacts in
                    Section {
                        ForEach(contacts) { contact in
                            iPadContactRowView(
                                contact: contact,
                                isSelected: selectedContact?.id == contact.id,
                                onSelect: { selectedContact = contact }
                            )
                        }
                    } header: {
                        sectionHeader(letter: letter)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func sectionHeader(letter: String) -> some View {
        HStack {
            Text(letter)
                .font(.appCaption)
                .foregroundColor(.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.appBackground)
    }

    // MARK: - Right Pane
    @ViewBuilder
    private var rightPane: some View {
        if let contact = selectedContact {
            iPadContactDetailPane(
                contact: contact,
                onEdit: {
                    Task {
                        await viewModel.loadContacts(appState: appState)
                        if let updated = viewModel.contacts.first(where: { $0.id == contact.id }) {
                            selectedContact = updated
                        }
                    }
                },
                onDelete: {
                    Task {
                        await viewModel.deleteContact(id: contact.id, appState: appState)
                        selectedContact = nil
                    }
                }
            )
            .id(contact.id)
        } else {
            emptyDetailPane
        }
    }

    private var emptyDetailPane: some View {
        VStack {
            Spacer()
            ContentUnavailableView(
                "Select a Contact",
                systemImage: "person.crop.circle",
                description: Text("Choose a contact to view their details")
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - iPad Contact Row View
struct iPadContactRowView: View {
    let contact: UsefulContact
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Category icon
                Image(systemName: contact.category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(appAccentColor)
                    .frame(width: 36, height: 36)
                    .background(appAccentColor.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    if let company = contact.companyName {
                        Text(company)
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(12)
            .background(isSelected ? appAccentColor.opacity(0.15) : Color.cardBackground)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - iPad Contact Detail Pane
struct iPadContactDetailPane: View {
    let contact: UsefulContact
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    // Category icon
                    Image(systemName: contact.category.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(appAccentColor)
                        .clipShape(Circle())

                    Text(contact.name)
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)

                    Text(contact.category.displayName)
                        .font(.appCaption)
                        .foregroundColor(appAccentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(appAccentColor.opacity(0.15))
                        .cornerRadius(8)
                }
                .padding(.top, 32)

                // Quick actions
                HStack(spacing: 16) {
                    if let phone = contact.phone {
                        iPadContactActionButton(
                            icon: "phone.fill",
                            title: "Call",
                            color: .badgeGreen
                        ) {
                            let cleaned = phone.replacingOccurrences(of: " ", with: "")
                            if let url = URL(string: "tel://\(cleaned)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }

                    if let email = contact.email {
                        iPadContactActionButton(
                            icon: "envelope.fill",
                            title: "Email",
                            color: .clothingBlue
                        ) {
                            if let url = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }

                    if let website = contact.website {
                        iPadContactActionButton(
                            icon: "safari.fill",
                            title: "Website",
                            color: .giftPurple
                        ) {
                            var urlString = website
                            if !urlString.hasPrefix("http") {
                                urlString = "https://\(urlString)"
                            }
                            if let url = URL(string: urlString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Details section
                VStack(spacing: 12) {
                    if let company = contact.companyName {
                        iPadContactDetailRow(label: "Company", value: company, icon: "building.2")
                    }

                    if let phone = contact.phone {
                        iPadContactDetailRow(label: "Phone", value: phone, icon: "phone")
                    }

                    if let email = contact.email {
                        iPadContactDetailRow(label: "Email", value: email, icon: "envelope")
                    }

                    if let address = contact.address {
                        Button {
                            let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            if let url = URL(string: "maps://?q=\(encoded)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            iPadContactDetailRow(label: "Address", value: address, icon: "map", showChevron: true)
                        }
                        .buttonStyle(.plain)
                    }

                    if let notes = contact.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notes", systemImage: "note.text")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            Text(notes)
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)

                // Edit and Delete buttons
                HStack(spacing: 16) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Contact", systemImage: "pencil")
                            .font(.appButtonText)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(appAccentColor)
                            .cornerRadius(12)
                    }
                    .hoverEffect(.lift)

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.appButtonText)
                            .foregroundColor(.badgeRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                    }
                    .hoverEffect(.lift)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer(minLength: 40)
            }
        }
        .background(Color.appBackground)
        .sidePanel(isPresented: $showEditSheet) {
            EditUsefulContactView(
                contact: contact,
                onDismiss: { showEditSheet = false }
            ) { _ in
                onEdit()
            }
        }
        .alert("Delete Contact", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \(contact.name)?")
        }
    }
}

// MARK: - iPad Contact Action Button
struct iPadContactActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(color)
                    .clipShape(Circle())

                Text(title)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }
}

// MARK: - iPad Contact Detail Row
struct iPadContactDetailRow: View {
    let label: String
    let value: String
    let icon: String
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                Text(value)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview
#Preview("iPad Contacts") {
    iPadUsefulContactsView()
        .environmentObject(AppState.forPreview())
}
