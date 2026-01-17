//
//  ProfileListContainerView.swift
//  Unforgotten
//
//  Container for Profiles - uses iPhone view for both platforms
//  iPad layout is handled by iPadRootView with the Home sidebar
//

import SwiftUI

/// Container for Profiles (Family & Friends)
/// Returns the iPhone ProfileListView for both platforms
struct ProfileListContainerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ProfileListView()
    }
}

// MARK: - iPad Profile List View
struct iPadProfileListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProfileListViewModel()
    @State private var selectedProfile: Profile?
    @State private var searchText = ""
    @State private var showAddProfile = false
    @State private var showUpgradePrompt = false
    @State private var profileToDelete: Profile?
    @State private var showDeleteConfirmation = false
    @Environment(\.appAccentColor) private var appAccentColor

    /// Check if user can add more friend profiles
    private var canAddProfile: Bool {
        PremiumLimitsManager.shared.canCreateFriendProfile(
            appState: appState,
            currentCount: viewModel.profiles.count
        )
    }

    private var filteredProfiles: [Profile] {
        if searchText.isEmpty {
            return viewModel.profiles
        }
        return viewModel.profiles.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.relationship?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            leftPane

            Rectangle()
                .fill(Color.cardBackgroundLight)
                .frame(width: 1)

            rightPane
        }
        .background(Color.appBackgroundLight)
        .navigationTitle("Family and Friends")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddProfile) {
            AddProfileView { _ in
                Task {
                    await viewModel.loadProfiles(appState: appState)
                }
            }
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
        }
        .task {
            await viewModel.loadProfiles(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilesDidChange)) { _ in
            Task {
                await viewModel.loadProfiles(appState: appState)
                if let selected = selectedProfile,
                   let updated = viewModel.profiles.first(where: { $0.id == selected.id }) {
                    selectedProfile = updated
                }
            }
        }
        .alert("Delete Profile", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                profileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    Task {
                        await viewModel.deleteProfile(id: profile.id, appState: appState)
                        if selectedProfile?.id == profile.id {
                            selectedProfile = nil
                        }
                        profileToDelete = nil
                    }
                }
            }
        } message: {
            if let profile = profileToDelete {
                Text("Are you sure you want to delete \(profile.displayName)? This action cannot be undone.")
            }
        }
    }

    // MARK: - Left Pane
    private var leftPane: some View {
        VStack(spacing: 0) {
            searchAndAddBar
            profileListScrollView
        }
        .frame(width: 320)
        .background(Color.appBackground)
    }

    // MARK: - Search and Add Bar
    private var searchAndAddBar: some View {
        HStack(spacing: 12) {
            searchField
            addButton
        }
        .padding(16)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)
            TextField("Search people", text: $searchText)
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

    private var addButton: some View {
        Button {
            if canAddProfile {
                showAddProfile = true
            } else {
                showUpgradePrompt = true
            }
        } label: {
            Image(systemName: canAddProfile ? "plus" : "crown.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(canAddProfile ? appAccentColor : appAccentColor.opacity(0.6))
                .cornerRadius(10)
        }
    }

    // MARK: - Profile List
    private var profileListScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredProfiles) { profile in
                    iPadProfileRowView(
                        profile: profile,
                        isSelected: selectedProfile?.id == profile.id,
                        onSelect: { selectedProfile = profile },
                        onDelete: {
                            profileToDelete = profile
                            showDeleteConfirmation = true
                        }
                    )
                }

                if viewModel.profiles.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.textSecondary)
                        Text("No family or friends yet")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Right Pane
    @ViewBuilder
    private var rightPane: some View {
        if let profile = selectedProfile {
            iPadProfileDetailPane(profile: profile)
                // Use hashValue to force refresh when any profile data changes (including isDeceased)
                .id("\(profile.id)-\(profile.hashValue)")
        } else {
            emptyDetailPane
        }
    }

    private var emptyDetailPane: some View {
        VStack {
            Spacer()
            ContentUnavailableView(
                "Select a Person",
                systemImage: "person.crop.circle",
                description: Text("Choose someone to view their details")
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - iPad Profile Row View
struct iPadProfileRowView: View {
    let profile: Profile
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                profileImage

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(profile.displayName)
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)

                        if profile.isFavourite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(appAccentColor)
                        }
                    }

                    HStack(spacing: 8) {
                        if let relationship = profile.relationship {
                            Text(relationship)
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                                .lineLimit(1)
                        }

                        if profile.isDeceased {
                            Text("In Memory")
                                .font(.appCaptionSmall)
                                .foregroundColor(.textMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cardBackgroundLight.opacity(0.6))
                                .cornerRadius(4)
                        }
                    }

                    if let birthday = profile.birthday, !profile.isDeceased {
                        Text(birthday.formattedBirthday())
                            .font(.appCaptionSmall)
                            .foregroundColor(.textMuted)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(12)
            .background(isSelected ? appAccentColor.opacity(0.15) : Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? appAccentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var profileImage: some View {
        ZStack(alignment: .bottomTrailing) {
            if let photoUrl = profile.photoUrl, !photoUrl.isEmpty {
                AsyncImage(url: URL(string: photoUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .opacity(profile.isDeceased ? 0.7 : 1.0)
                    default:
                        defaultProfileImage
                    }
                }
            } else {
                defaultProfileImage
            }

            if profile.isDeceased {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .background(
                        Circle()
                            .fill(Color.cardBackground)
                            .frame(width: 16, height: 16)
                    )
                    .offset(x: 2, y: 2)
            }
        }
    }

    private var defaultProfileImage: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 40))
            .foregroundColor(.textSecondary)
            .frame(width: 50, height: 50)
            .opacity(profile.isDeceased ? 0.7 : 1.0)
    }
}

// MARK: - iPad Profile Detail Pane
struct iPadProfileDetailPane: View {
    let profile: Profile
    @EnvironmentObject var appState: AppState
    @State private var showEditProfile = false
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadEditProfileAction) private var iPadEditProfileAction

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile header
                profileHeader

                // Show different content based on deceased status
                if profile.isDeceased {
                    // Simplified memorial view
                    deceasedContent
                } else {
                    // Full profile view
                    // Contact actions
                    contactActions

                    // Details sections
                    detailsSections
                }

                // Edit button
                editButton

                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(profile: profile) { _ in
                NotificationCenter.default.post(name: .profilesDidChange, object: nil)
            }
        }
    }

    // MARK: - Deceased Content
    private var deceasedContent: some View {
        VStack(spacing: 12) {
            // Memorial indicator
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.textSecondary)

                Text("In Loving Memory")
                    .font(.appCardTitle)
                    .foregroundColor(.textSecondary)

                Spacer()
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(12)

            // Birthday with age at death
            if let birthday = profile.birthday {
                HStack {
                    Image(systemName: "gift")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Birthday")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        Text(birthday.formattedBirthday())
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                    }

                    Spacer()

                    if let ageAtDeath = profile.ageAtDeath {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(ageAtDeath)")
                                .font(.appTitle)
                                .foregroundColor(.textSecondary)
                            Text("years old")
                                .font(.appCaption)
                                .foregroundColor(.textMuted)
                        }
                    }
                }
                .padding(16)
                .background(Color.cardBackground)
                .cornerRadius(12)
            }

            // Date of Death
            if let deathDate = profile.dateOfDeath {
                detailRow(label: "Date of Passing", value: deathDate.formattedBirthday(), icon: "calendar")
            }

            // Family Connection
            if profile.includeInFamilyTree && profile.connectedToProfileId != nil {
                HStack(spacing: 12) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Family Connection")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        Text("Included in Family Tree")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                    }

                    Spacer()
                }
                .padding(16)
                .background(Color.cardBackground)
                .cornerRadius(12)
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let photoUrl = profile.photoUrl, !photoUrl.isEmpty {
                    AsyncImage(url: URL(string: photoUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .opacity(profile.isDeceased ? 0.7 : 1.0)
                        default:
                            defaultLargeProfileImage
                        }
                    }
                } else {
                    defaultLargeProfileImage
                }

                if profile.isDeceased {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                        .background(
                            Circle()
                                .fill(Color.cardBackground)
                                .frame(width: 24, height: 24)
                        )
                        .offset(x: 4, y: 4)
                }
            }

            VStack(spacing: 4) {
                HStack {
                    Text(profile.displayName)
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)

                    if profile.isFavourite {
                        Image(systemName: "star.fill")
                            .foregroundColor(appAccentColor)
                    }
                }

                HStack(spacing: 8) {
                    if let relationship = profile.relationship {
                        Text(relationship)
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                    }

                    if profile.isDeceased {
                        Text("In Memory")
                            .font(.appCaption)
                            .foregroundColor(.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.cardBackgroundLight.opacity(0.6))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(.top, 16)
    }

    private var defaultLargeProfileImage: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 80))
            .foregroundColor(.textSecondary)
            .frame(width: 100, height: 100)
    }

    private var contactActions: some View {
        HStack(spacing: 16) {
            if let phone = profile.phone {
                contactActionButton(icon: "phone.fill", title: "Call", color: .badgeGreen) {
                    let cleaned = phone.replacingOccurrences(of: " ", with: "")
                    if let url = URL(string: "tel://\(cleaned)") {
                        UIApplication.shared.open(url)
                    }
                }
            }

            if let email = profile.email {
                contactActionButton(icon: "envelope.fill", title: "Email", color: .clothingBlue) {
                    if let url = URL(string: "mailto:\(email)") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    private func contactActionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
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

    private var detailsSections: some View {
        VStack(spacing: 12) {
            if let birthday = profile.birthday {
                detailRow(label: "Birthday", value: birthday.formattedBirthday(), icon: "gift")
            }

            if let phone = profile.phone {
                detailRow(label: "Phone", value: phone, icon: "phone")
            }

            if let email = profile.email {
                detailRow(label: "Email", value: email, icon: "envelope")
            }

            if let address = profile.address {
                detailRow(label: "Address", value: address, icon: "map")
            }

            if let notes = profile.notes, !notes.isEmpty {
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
    }

    private func detailRow(label: String, value: String, icon: String) -> some View {
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
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    private var editButton: some View {
        Button {
            // Use full-screen overlay action if available
            if let editAction = iPadEditProfileAction {
                editAction(profile)
            } else {
                showEditProfile = true
            }
        } label: {
            Label("Edit Profile", systemImage: "square.and.pencil")
                .font(.appButtonText)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(appAccentColor)
                .cornerRadius(12)
        }
        .hoverEffect(.lift)
        .padding(.top, 16)
    }
}

// MARK: - Preview
#Preview("iPad Profiles") {
    iPadProfileListView()
        .environmentObject(AppState())
}
