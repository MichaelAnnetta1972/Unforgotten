import SwiftUI

// MARK: - Birthdays View
struct BirthdaysView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @StateObject private var viewModel = BirthdaysViewModel()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header at the top - fully interactive
                HeaderImageView(
                    imageName: "header-birthdays",
                    title: "Birthdays",
                    showBackButton: true,
                    backAction: { dismiss() }
                )

                // Content scrolls below header
                ScrollView {
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
                            LoadingView(message: "Loading birthdays...")
                                .padding(.top, 40)
                        }

                        // Empty state
                        if viewModel.upcomingBirthdays.isEmpty && !viewModel.isLoading {
                            EmptyStateView(
                                icon: "gift.fill",
                                title: "No upcoming birthdays",
                                message: "Add birthdays to profiles to see them here"
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
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .task {
            await viewModel.loadBirthdays(appState: appState)
        }
        .refreshable {
            await viewModel.loadBirthdays(appState: appState)
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

    private var countdownText: String {
        if birthday.daysUntil == 0 {
            return "Today! 🎉"
        } else if birthday.daysUntil == 1 {
            return "Tomorrow"
        } else {
            return "in \(birthday.daysUntil) days"
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(birthday.profile.displayName)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)

                if let bday = birthday.profile.birthday {
                    Text(bday.formattedBirthday())
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let age = birthday.profile.age {
                    Text("Turning \(age + 1)")
                        .font(.appCaption)
                        .foregroundColor(birthday.daysUntil <= 30 ? .accentYellow : .textSecondary)
                }

                Text(countdownText)
                    .font(.appCaption)
                    .fontWeight(birthday.daysUntil <= 30 ? .semibold : .regular)
                    .foregroundColor(birthday.daysUntil <= 30 ? .accentYellow : .textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(birthday.daysUntil == 0 ? Color.accentYellow.opacity(0.2) :
                       birthday.daysUntil <= 30 ? Color.accentYellow.opacity(0.1) : Color.cardBackgroundSoft)
            .cornerRadius(AppDimensions.pillCornerRadius)
        }
        .padding(AppDimensions.cardPadding)
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

    func loadBirthdays(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            let profiles = try await appState.profileRepository.getUpcomingBirthdays(accountId: account.id, days: 365)
            upcomingBirthdays = profiles.compactMap { profile in
                guard let birthday = profile.birthday else { return nil }
                let daysUntil = birthday.daysUntilNextOccurrence()
                return UpcomingBirthday(profile: profile, daysUntil: daysUntil)
            }
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        BirthdaysView()
            .environmentObject(AppState())
    }
}
