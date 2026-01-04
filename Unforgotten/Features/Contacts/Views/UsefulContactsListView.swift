import SwiftUI

// MARK: - Useful Contacts List View
struct UsefulContactsListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = UsefulContactsViewModel()
    @State private var showAddContact = false
    @State private var showUpgradePrompt = false
    @State private var selectedCategory: ContactCategory? = nil
    @State private var contactToDelete: UsefulContact?
    @State private var showDeleteConfirmation = false
    @State private var activeOptionsMenuItemId: UUID?
    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var searchText = ""
    @State private var showingCategoryFilter = false

    /// Check if user can add more useful contacts
    private var canAddContact: Bool {
        PremiumLimitsManager.shared.canCreateUsefulContact(
            appState: appState,
            currentCount: viewModel.contacts.count
        )
    }

    private var activeContact: UsefulContact? {
        guard let activeId = activeOptionsMenuItemId else { return nil }
        return viewModel.contacts.first(where: { $0.id == activeId })
    }

    private var activeFrame: CGRect? {
        guard let activeId = activeOptionsMenuItemId else { return nil }
        return cardFrames[activeId]
    }

    private var activeIndex: Int? {
        guard let activeId = activeOptionsMenuItemId else { return nil }
        return viewModel.contacts.firstIndex(where: { $0.id == activeId })
    }

    var filteredContacts: [UsefulContact] {
        var contacts = viewModel.contacts

        // Filter by category
        if let category = selectedCategory {
            contacts = contacts.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            contacts = contacts.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.companyName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.category.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return contacts
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 0) {
                // Header scrolls with content - uses style-based assets from HeaderStyleManager
                CustomizableHeaderView(
                    pageIdentifier: .contacts,
                    title: "Useful Contacts",
                    showBackButton: iPadHomeAction == nil,
                    backAction: { dismiss() },
                    showHomeButton: iPadHomeAction != nil,
                    homeAction: iPadHomeAction,
                    showAddButton: true,
                    addAction: {
                        if canAddContact {
                            showAddContact = true
                        } else {
                            showUpgradePrompt = true
                        }
                    }
                )

                // Content
                VStack(spacing: AppDimensions.cardSpacing) {
                    // Search bar with filter icon
                    HStack(spacing: 12) {
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
                        .padding(AppDimensions.cardPadding)
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingCategoryFilter = true
                            }
                        }) {
                            Image(systemName: selectedCategory != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 20))
                                .foregroundColor(selectedCategory != nil ? appAccentColor : .textSecondary)
                                .frame(width: 44, height: 44)
                                .background(Color.cardBackground)
                                .cornerRadius(AppDimensions.cardCornerRadius)
                        }
                    }

                    // Contacts list
                    LazyVStack(spacing: AppDimensions.cardSpacing) {
                        ForEach(Array(filteredContacts.enumerated()), id: \.element.id) { index, contact in
                            let globalIndex = viewModel.contacts.firstIndex(where: { $0.id == contact.id }) ?? index
                            UsefulContactRow(
                                contact: contact,
                                onOptionsMenu: {
                                    activeOptionsMenuItemId = contact.id
                                },
                                onDelete: {
                                    contactToDelete = contact
                                    showDeleteConfirmation = true
                                },
                                onMoveUp: globalIndex > 0 && selectedCategory == nil ? {
                                    viewModel.moveContact(from: IndexSet(integer: globalIndex), to: globalIndex - 1)
                                    Task {
                                        await viewModel.saveSortOrder(appState: appState)
                                    }
                                } : nil,
                                onMoveDown: globalIndex < viewModel.contacts.count - 1 && selectedCategory == nil ? {
                                    viewModel.moveContact(from: IndexSet(integer: globalIndex), to: globalIndex + 2)
                                    Task {
                                        await viewModel.saveSortOrder(appState: appState)
                                    }
                                } : nil
                            )
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: ContactCardFramePreferenceKey.self,
                                        value: [contact.id: geo.frame(in: .global)]
                                    )
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
                                buttonAction: {
                                    if canAddContact {
                                        showAddContact = true
                                    } else {
                                        showUpgradePrompt = true
                                    }
                                }
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

                    // Premium limit reached banner
                    if !viewModel.contacts.isEmpty && !canAddContact {
                        PremiumFeatureLockBanner(
                            feature: .usefulContacts,
                            onUpgrade: { showUpgradePrompt = true }
                        )
                    }

                    // Bottom spacing for nav bar
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.top, AppDimensions.cardSpacing)
            }
        }
        .ignoresSafeArea(edges: .top)
        .onPreferenceChange(ContactCardFramePreferenceKey.self) { frames in
            cardFrames = frames
        }

        // Overlay: Dark background + Highlighted card + Options menu
        if let contact = activeContact,
           let frame = activeFrame {
            contactOverlay(contact: contact, frame: frame)
        }

        // Category filter overlay
        if showingCategoryFilter {
            ZStack {
                Color.cardBackgroundLight.opacity(0.9)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showingCategoryFilter = false
                        }
                    }

                ContactCategoryFilterOverlay(
                    selectedCategory: $selectedCategory,
                    isShowing: showingCategoryFilter,
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showingCategoryFilter = false
                        }
                    }
                )
            }
            .zIndex(10)
            .transition(.opacity)
        }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
        }
        .sidePanel(isPresented: $showAddContact) {
            AddUsefulContactView(
                onDismiss: { showAddContact = false }
            ) { _ in
                Task {
                    await viewModel.loadContacts(appState: appState)
                }
            }
        }
        .task {
            await viewModel.loadContacts(appState: appState)
        }
        .refreshable {
            await viewModel.loadContacts(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsDidChange)) { _ in
            Task {
                await viewModel.loadContacts(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            Task {
                await viewModel.loadContacts(appState: appState)
            }
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

    // MARK: - Helper Methods

    @ViewBuilder
    private func contactOverlay(contact: UsefulContact, frame: CGRect) -> some View {
        GeometryReader { geometry in
            let overlayFrame = geometry.frame(in: .global)
            let panelSize = geometry.size
            let adaptiveScreenPadding = AppDimensions.screenPadding(for: horizontalSizeClass)
            let cardWidth = panelSize.width - (adaptiveScreenPadding * 2)

            ZStack {
                // Dark overlay background
                Color.cardBackgroundLight.opacity(0.9)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissOverlay()
                    }

                // Highlighted contact card
                HighlightedContactCard(
                    contact: contact,
                    frame: frame,
                    overlayFrame: overlayFrame,
                    panelSize: panelSize,
                    cardWidth: cardWidth
                )

                // Options menu
                ContactOptionsMenu(
                    contact: contact,
                    frame: frame,
                    overlayFrame: overlayFrame,
                    panelSize: panelSize,
                    onMoveUp: moveUpAction(),
                    onMoveDown: moveDownAction(),
                    onDelete: {
                        handleDelete(contact: contact)
                    },
                    onCancel: {
                        dismissOverlay()
                    }
                )
            }
        }
        .ignoresSafeArea()
        .zIndex(100)
        .transition(.opacity)
    }

    private func dismissOverlay() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            activeOptionsMenuItemId = nil
        }
    }

    private func moveUpAction() -> (() -> Void)? {
        guard let index = activeIndex, index > 0, selectedCategory == nil else { return nil }
        return {
            viewModel.moveContact(from: IndexSet(integer: index), to: index - 1)
            Task {
                await viewModel.saveSortOrder(appState: appState)
            }
            dismissOverlay()
        }
    }

    private func moveDownAction() -> (() -> Void)? {
        guard let index = activeIndex, index < viewModel.contacts.count - 1, selectedCategory == nil else { return nil }
        return {
            viewModel.moveContact(from: IndexSet(integer: index), to: index + 2)
            Task {
                await viewModel.saveSortOrder(appState: appState)
            }
            dismissOverlay()
        }
    }

    private func handleDelete(contact: UsefulContact) {
        contactToDelete = contact
        showDeleteConfirmation = true
        activeOptionsMenuItemId = nil
    }
}

// MARK: - Contact Card Frame Preference Key
struct ContactCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Category Filter Button
struct CategoryFilterButton: View {
    @Environment(\.appAccentColor) private var appAccentColor
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
                .background(isSelected ? appAccentColor : Color.cardBackgroundSoft)
                .cornerRadius(20)
        }
    }
}

// MARK: - Useful Contact Row
struct UsefulContactRow: View {
    let contact: UsefulContact
    let onOptionsMenu: () -> Void
    let onDelete: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?

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
                    onOptionsMenu()
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

    func moveContact(from source: IndexSet, to destination: Int) {
        contacts.move(fromOffsets: source, toOffset: destination)
    }

    func saveSortOrder(appState: AppState) async {
        let updates = contacts.enumerated().map { index, contact in
            SortOrderUpdate(id: contact.id, sortOrder: index)
        }

        do {
            try await appState.usefulContactRepository.updateContactSortOrders(updates)
        } catch {
            self.error = "Failed to save order: \(error.localizedDescription)"
        }
    }
}

// MARK: - Highlighted Contact Card
struct HighlightedContactCard: View {
    let contact: UsefulContact
    let frame: CGRect
    let overlayFrame: CGRect
    let panelSize: CGSize
    let cardWidth: CGFloat

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        // Convert the captured global Y to local Y by subtracting overlay's global origin
        let localCardY = (frame.minY - overlayFrame.minY) + frame.height / 2

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

            // Options button (vertical dots)
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)
                .frame(width: 44, height: 44)
        }
        .padding(AppDimensions.cardPadding)
        .frame(width: cardWidth, height: frame.height)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .fill(Color.cardBackground)
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(appAccentColor, lineWidth: 3)
            }
        )
        .position(x: panelSize.width / 2, y: localCardY)
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }
}

// MARK: - Contact Options Menu
struct ContactOptionsMenu: View {
    let contact: UsefulContact
    let frame: CGRect
    let overlayFrame: CGRect
    let panelSize: CGSize
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    let onDelete: () -> Void
    let onCancel: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    @State private var menuHeight: CGFloat = 0

    private let menuWidth: CGFloat = 225

    var body: some View {
        let adaptiveScreenPadding = AppDimensions.screenPadding(for: horizontalSizeClass)
        // Convert global Y to local Y
        let localCardMinY = frame.minY - overlayFrame.minY
        let localCardMaxY = frame.maxY - overlayFrame.minY
        let menuYPosition = calculateMenuYPosition(localCardMinY: localCardMinY, localCardMaxY: localCardMaxY, screenHeight: panelSize.height)

        VStack(spacing: 0) {
            // Move Up
            if let moveUp = onMoveUp {
                Button(action: moveUp) {
                    HStack {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(.textPrimary)
                            .frame(width: 24)
                        Text("Move Up")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, AppDimensions.cardPadding)
                    .padding(.vertical, 16)
                    .background(Color.cardBackground)
                }

                Divider()
                    .background(Color.textSecondary.opacity(0.2))
            }

            // Move Down
            if let moveDown = onMoveDown {
                Button(action: moveDown) {
                    HStack {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 16))
                            .foregroundColor(.textPrimary)
                            .frame(width: 24)
                        Text("Move Down")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, AppDimensions.cardPadding)
                    .padding(.vertical, 16)
                    .background(Color.cardBackground)
                }

                Divider()
                    .background(Color.textSecondary.opacity(0.2))
            }

            // Delete
            Button(action: onDelete) {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("Delete")
                        .font(.appBody)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, AppDimensions.cardPadding)
                .padding(.vertical, 16)
                .background(Color.cardBackground)
            }

            Divider()
                .background(Color.textSecondary.opacity(0.2))

            // Cancel
            Button(action: onCancel) {
                HStack {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                        .frame(width: 24)
                    Text("Cancel")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, AppDimensions.cardPadding)
                .padding(.vertical, 16)
                .background(Color.cardBackground)
            }
        }
        .frame(width: menuWidth)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .scaleEffect(scale)
        .opacity(opacity)
        .position(x: panelSize.width - menuWidth / 2 - adaptiveScreenPadding, y: menuYPosition)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }

    private func calculateMenuYPosition(localCardMinY: CGFloat, localCardMaxY: CGFloat, screenHeight: CGFloat) -> CGFloat {
        // Estimate menu height based on number of buttons
        var estimatedMenuHeight: CGFloat = 52 * 2 // Delete and Cancel buttons always present
        if onMoveUp != nil {
            estimatedMenuHeight += 52
        }
        if onMoveDown != nil {
            estimatedMenuHeight += 52
        }

        let menuGap: CGFloat = 12
        let topSafeArea: CGFloat = 60 // Account for header/safe area

        // Try to position above the card first
        let aboveCardY = localCardMinY - menuGap - (estimatedMenuHeight / 2)

        // Check if there's enough room above
        if aboveCardY - (estimatedMenuHeight / 2) > topSafeArea {
            return aboveCardY
        }

        // Otherwise position below the card
        let belowCardY = localCardMaxY + menuGap + (estimatedMenuHeight / 2)

        // Check if there's enough room below
        if belowCardY + (estimatedMenuHeight / 2) < screenHeight - 100 {
            return belowCardY
        }

        // Fallback: center vertically on screen
        return screenHeight / 2
    }
}

// MARK: - Contact Category Filter Overlay
private struct ContactCategoryFilterOverlay: View {
    @Binding var selectedCategory: ContactCategory?
    let isShowing: Bool
    let onDismiss: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Filter by Category")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            .padding(.top, AppDimensions.cardPadding)
            .padding(.horizontal, AppDimensions.cardPadding)

            ScrollView {
                VStack(spacing: 8) {
                    // All option - full width
                    Button {
                        selectedCategory = nil
                        onDismiss()
                    } label: {
                        HStack {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 16))
                                .foregroundColor(selectedCategory == nil ? appAccentColor : .textSecondary)
                                .frame(width: 24)

                            Text("All")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                            Spacer()
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(appAccentColor)
                            }
                        }
                        .padding(AppDimensions.cardPadding)
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Category options in grid
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(ContactCategory.allCases, id: \.self) { category in
                            Button {
                                selectedCategory = category
                                onDismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedCategory == category ? appAccentColor : .textSecondary)

                                    Text(category.displayName)
                                        .font(.caption)
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(selectedCategory == category ? appAccentColor.opacity(0.15) : Color.cardBackgroundSoft)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedCategory == category ? appAccentColor : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 320)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .shadow(color: .black.opacity(0.3), radius: 12, y: 8)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
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
