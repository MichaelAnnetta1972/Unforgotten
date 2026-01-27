import SwiftUI

// MARK: - Birthdays View
struct BirthdaysView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.appAccentColor) private var appAccentColor
    @StateObject private var viewModel = BirthdaysViewModel()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header scrolls with content
                    CustomizableHeaderView(
                        pageIdentifier: .birthdays,
                        title: "Birthdays",
                        showBackButton: iPadHomeAction == nil,
                        backAction: { dismiss() },
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction
                    )

                    // Content
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Birthday list
                        LazyVStack(spacing: AppDimensions.cardSpacing) {
                            ForEach(viewModel.upcomingBirthdays) { birthday in
                                NavigationLink(destination: ProfileDetailView(profile: birthday.profile)) {
                                    BirthdayCard(birthday: birthday)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        // Loading state
                        if viewModel.isLoading && viewModel.upcomingBirthdays.isEmpty {
                            LoadingView(message: "Loading...")
                                .padding(.top, 40)
                        }

                        // Empty state
                        if viewModel.upcomingBirthdays.isEmpty && !viewModel.isLoading {
                            VStack(spacing: 16) {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.textSecondary)

                                Text("No Upcoming Birthdays")
                                    .font(.appTitle)
                                    .foregroundColor(.textPrimary)

                                Text("Add birthdays to your family and friends profiles to see them here")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
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
        }
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showSettings) {
            SettingsPanelView(onDismiss: { showSettings = false })
        }
        .task {
            await viewModel.loadData(appState: appState)
        }
        .refreshable {
            await viewModel.loadData(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            Task {
                await viewModel.loadData(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilesDidChange)) { _ in
            Task {
                await viewModel.loadData(appState: appState)
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
    }
}

// MARK: - Birthday Card
struct BirthdayCard: View {
    let birthday: UpcomingBirthday
    @Environment(\.appAccentColor) private var appAccentColor

    private var countdownText: String {
        if birthday.daysUntil == 0 {
            return "Today!"
        } else if birthday.daysUntil == 1 {
            return "1 day"
        } else {
            return "\(birthday.daysUntil) days"
        }
    }

    private var turningAge: Int? {
        guard let age = birthday.profile.age else { return nil }
        return age + 1
    }

    var body: some View {
        HStack(alignment: .center) {
            // Left side - Birthday icon
            Image(systemName: "gift.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(8)

            // Middle - Name with days badge, and date below
            VStack(alignment: .leading, spacing: 4) {
                // Name and days badge on same line
                HStack(spacing: 12) {
                    Text(birthday.profile.displayName)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)

                    // Memorial heart icon if deceased
                    if birthday.profile.isDeceased {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.textMuted)
                    }

                    // Days countdown pill
                    Text(countdownText)
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cardBackgroundLight)
                        .cornerRadius(16)
                }

                // Type label and date below
                HStack(spacing: 8) {
                    Text("Birthday")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    if let bday = birthday.profile.birthday {
                        Text(bday.formattedBirthdayWithOrdinal())
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }
            }

            Spacer()

            // Right side - Age badge (show "Would be" for deceased)
            if let age = turningAge {
                VStack(spacing: 1) {
                    Text(birthday.profile.isDeceased ? "Would be" : "Turns")
                        .font(.appCaption)
                        .foregroundColor(appAccentColor)

                    Text("\(age)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cardBackgroundLight.opacity(0.4))
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Birthdays View Model
@MainActor
class BirthdaysViewModel: ObservableObject {
    @Published var upcomingBirthdays: [UpcomingBirthday] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadData(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            // Load birthdays
            let profiles = try await appState.profileRepository.getUpcomingBirthdays(accountId: account.id, days: 365)
            upcomingBirthdays = profiles.compactMap { profile in
                guard let birthday = profile.birthday else { return nil }
                let daysUntil = birthday.daysUntilNextOccurrence()
                return UpcomingBirthday(profile: profile, daysUntil: daysUntil)
            }.sorted { $0.daysUntil < $1.daysUntil }

        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    func loadBirthdays(appState: AppState) async {
        await loadData(appState: appState)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        BirthdaysView()
            .environmentObject(AppState.forPreview())
    }
}
