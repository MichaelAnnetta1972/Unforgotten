import SwiftUI

// MARK: - Profile List View (Family and Friends)
struct ProfileListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @StateObject private var viewModel = ProfileListViewModel()
    @State private var showAddProfile = false
    @State private var showSettings = false
    @State private var profileToDelete: Profile?
    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header at the top - fully interactive
                HeaderImageView(
                    imageName: "header-family-and-friends",
                    title: "Family and Friends",
                    showSettingsButton: true,
                    settingsAction: { showSettings = true }
                )

                // Content scrolls below header
                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Profile list
                        LazyVStack(spacing: AppDimensions.cardSpacing) {
                            ForEach(viewModel.profiles) { profile in
                                ProfileListRow(
                                    profile: profile,
                                    onDelete: {
                                        profileToDelete = profile
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }

                        // Loading state
                        if viewModel.isLoading && viewModel.profiles.isEmpty {
                            LoadingView(message: "Loading profiles...")
                                .padding(.top, 40)
                        }

                        // Empty state
                        if viewModel.profiles.isEmpty && !viewModel.isLoading {
                            EmptyStateView(
                                icon: "person.2.fill",
                                title: "No family or friends yet",
                                message: "Add your first family member or friend",
                                buttonTitle: "Add Person",
                                buttonAction: { showAddProfile = true }
                            )
                            .padding(.top, 40)
                        }

                        Spacer()
                            .frame(height: 140)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
        }
        .sheet(isPresented: $showAddProfile) {
            AddProfileView { newProfile in
                Task {
                    await viewModel.loadProfiles(appState: appState)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadProfiles(appState: appState)
        }
        .refreshable {
            await viewModel.loadProfiles(appState: appState)
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
        .alert("Delete Profile", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                profileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    Task {
                        await viewModel.deleteProfile(id: profile.id, appState: appState)
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
}

// MARK: - Profile List Row
struct ProfileListRow: View {
    let profile: Profile
    let onDelete: () -> Void

    @State private var showOptions = false

    var body: some View {
        NavigationLink(destination: ProfileDetailView(profile: profile)) {
            HStack(spacing: 12) {
                // Profile photo
                AsyncProfileImage(url: profile.photoUrl, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.fullName)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)

                    if let subtitle = profile.relationship {
                        Text(subtitle)
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

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
}

// MARK: - Profile List Header
struct ProfileListHeaderView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "1a237e"),
                    Color(hex: "4a148c")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: AppDimensions.headerHeight)
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Back button
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Home")
                    }
                    .font(.appBodyMedium)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentYellow)
                    .cornerRadius(20)
                }
                
                Spacer()
                
                Text("Family and Friends")
                    .font(.appTitle)
                    .foregroundColor(.accentYellow)
            }
            .padding(AppDimensions.screenPadding)
        }
        .frame(height: AppDimensions.headerHeight)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .padding(.horizontal, AppDimensions.screenPadding)
    }
}

// MARK: - Profile List View Model
@MainActor
class ProfileListViewModel: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadProfiles(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            profiles = try await appState.profileRepository.getProfiles(accountId: account.id)
            // Filter out primary profile for family list
            profiles = profiles.filter { $0.type != .primary }
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    func deleteProfile(id: UUID, appState: AppState) async {
        do {
            try await appState.profileRepository.deleteProfile(id: id)
            profiles.removeAll { $0.id == id }
        } catch {
            self.error = "Failed to delete profile: \(error.localizedDescription)"
        }
    }

    func moveProfile(from source: IndexSet, to destination: Int) {
        profiles.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Profile Detail View
struct ProfileDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot

    @State var profile: Profile
    @StateObject private var viewModel = ProfileDetailViewModel()
    @State private var showEditProfile = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header at the top - fully interactive
                ProfileDetailHeaderView(
                    profile: profile,
                    imageName: profile.type == .primary ? "header-my-card" : "header-profile-detail",
                    onBack: { dismiss() },
                    onEdit: { showEditProfile = true }
                )

                // Content scrolls below header
                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Category cards
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // Medical
                                NavigationLink(destination: ProfileCategoryListView(
                                    profile: profile,
                                    category: .medical,
                                    details: viewModel.medicalConditions + viewModel.allergies
                                )) {
                                    CategoryCardView(
                                        title: "Medical",
                                        imageName: "category-medical"
                                    )
                                }

                                // Gift Ideas
                                NavigationLink(destination: ProfileCategoryListView(
                                    profile: profile,
                                    category: .gifts,
                                    details: viewModel.giftIdeas
                                )) {
                                    CategoryCardView(
                                        title: "Gift Ideas",
                                        imageName: "category-gifts"
                                    )
                                }

                                // Clothing Sizes
                                NavigationLink(destination: ProfileCategoryListView(
                                    profile: profile,
                                    category: .clothing,
                                    details: viewModel.clothingSizes
                                )) {
                                    CategoryCardView(
                                        title: "Clothing Sizes",
                                        imageName: "category-clothing"
                                    )
                                }

                                // Connections
                                NavigationLink(destination: ConnectionsListView(profile: profile)) {
                                    CategoryCardView(
                                        title: "Connections",
                                        imageName: "category-connections"
                                    )
                                }
                            }
                            .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        // Key Information
                        VStack(alignment: .leading, spacing: AppDimensions.cardSpacing) {
                            Text("KEY INFORMATION")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            VStack(spacing: AppDimensions.cardSpacing) {
                                if let relationship = profile.relationship {
                                    DetailItemCard(label: "Relationship", value: relationship)
                                }

                                if let address = profile.address {
                                    DetailItemCard(label: "Address", value: address)
                                }

                                if let phone = profile.phone {
                                    DetailItemCard(label: "Phone", value: phone)
                                }

                                if let email = profile.email {
                                    DetailItemCard(label: "Email", value: email)
                                }

                                if let birthday = profile.birthday {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Birthday")
                                                .font(.appCaption)
                                                .foregroundColor(.textSecondary)

                                            Text(birthday.formattedBirthday())
                                                .font(.appCardTitle)
                                                .foregroundColor(.textPrimary)
                                        }

                                        Spacer()

                                        if let age = profile.age {
                                            Text("\(age)")
                                                .font(.appTitle)
                                                .foregroundColor(.textSecondary)
                                        }
                                    }
                                    .padding(AppDimensions.cardPadding)
                                    .background(Color.cardBackground)
                                    .cornerRadius(AppDimensions.cardCornerRadius)
                                }

                                // Custom Fields (Additional Information)
                                ForEach(viewModel.customFields) { field in
                                    DetailItemCard(label: field.label, value: field.value)
                                }
                            }
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)

                        Spacer()
                            .frame(height: 140)
                    }
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(profile: profile) { updatedProfile in
                profile = updatedProfile
                Task {
                    await viewModel.loadDetails(profile: profile, appState: appState)
                }
            }
        }
        .task {
            await viewModel.loadDetails(profile: profile, appState: appState)
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
    }
}

// MARK: - Profile Detail Header
struct ProfileDetailHeaderView: View {
    let profile: Profile
    let imageName: String?
    let onBack: () -> Void
    let onEdit: (() -> Void)?

    init(profile: Profile, imageName: String? = nil, onBack: @escaping () -> Void, onEdit: (() -> Void)? = nil) {
        self.profile = profile
        self.imageName = imageName
        self.onBack = onBack
        self.onEdit = onEdit
    }

    var body: some View {
        HeaderImageView(
            imageName: imageName,
            title: profile.fullName,
            showBackButton: true,
            backAction: onBack,
            showEditButton: onEdit != nil,
            editAction: onEdit
        )
        .overlay(alignment: .bottomLeading) {
            // Circular profile photo above the name
            if let photoUrl = profile.photoUrl, !photoUrl.isEmpty {
                AsyncProfileImage(url: photoUrl, size: 70)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .padding(.leading, AppDimensions.screenPadding)
                    .padding(.bottom, 70) // Position above the name text
            }
        }
    }
}

// MARK: - Category Card View
struct CategoryCardView: View {
    let title: String
    let imageName: String

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background image
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: AppDimensions.categoryCardWidth, height: AppDimensions.categoryCardHeight)
                .clipped()

            // Gradient overlay for text readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Title
            Text(title)
                .font(.appBody)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
        }
        .frame(width: AppDimensions.categoryCardWidth, height: AppDimensions.categoryCardHeight)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Profile Detail View Model
@MainActor
class ProfileDetailViewModel: ObservableObject {
    @Published var clothingSizes: [ProfileDetail] = []
    @Published var giftIdeas: [ProfileDetail] = []
    @Published var medicalConditions: [ProfileDetail] = []
    @Published var allergies: [ProfileDetail] = []
    @Published var customFields: [ProfileDetail] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadDetails(profile: Profile, appState: AppState) async {
        isLoading = true

        do {
            let allDetails = try await appState.profileRepository.getProfileDetails(profileId: profile.id)

            clothingSizes = allDetails.filter { $0.category == .clothing }
            giftIdeas = allDetails.filter { $0.category == .giftIdea }
            medicalConditions = allDetails.filter { $0.category == .medicalCondition }
            allergies = allDetails.filter { $0.category == .allergy }
            customFields = allDetails.filter { $0.category == .note }
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - My Card View (Primary Profile)
struct MyCardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = MyCardViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            if let profile = viewModel.primaryProfile {
                ProfileDetailView(profile: profile)
            } else if viewModel.isLoading {
                LoadingView()
            } else {
                EmptyStateView(
                    icon: "person.circle",
                    title: "No profile found",
                    message: "Your primary profile hasn't been set up yet."
                )
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadPrimaryProfile(appState: appState)
        }
    }
}

@MainActor
class MyCardViewModel: ObservableObject {
    @Published var primaryProfile: Profile?
    @Published var isLoading = false
    
    func loadPrimaryProfile(appState: AppState) async {
        guard let account = appState.currentAccount else { return }
        
        isLoading = true
        
        do {
            primaryProfile = try await appState.profileRepository.getPrimaryProfile(accountId: account.id)
        } catch {
            print("Error loading primary profile: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Preview
#Preview("Profile List") {
    NavigationStack {
        ProfileListView()
            .environmentObject(AppState())
    }
}
