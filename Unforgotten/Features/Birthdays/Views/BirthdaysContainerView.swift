//
//  BirthdaysContainerView.swift
//  Unforgotten
//
//  Container for Birthdays - uses iPhone view for both platforms
//  iPad layout is handled by iPadRootView with the Home sidebar
//

import SwiftUI

/// Container for Birthdays
/// Returns the iPhone BirthdaysView for both platforms
struct BirthdaysContainerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        BirthdaysView()
    }
}

// MARK: - iPad Birthdays View
struct iPadBirthdaysView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = BirthdaysViewModel()
    @State private var selectedBirthday: UpcomingBirthday?
    @State private var searchText = ""
    @Environment(\.appAccentColor) private var appAccentColor

    private var filteredBirthdays: [UpcomingBirthday] {
        if searchText.isEmpty {
            return viewModel.upcomingBirthdays
        }
        return viewModel.upcomingBirthdays.filter {
            $0.profile.displayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.profile.relationship?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    // Group birthdays by time period
    private var groupedBirthdays: [(String, [UpcomingBirthday])] {
        let grouped = Dictionary(grouping: filteredBirthdays) { birthday -> String in
            if birthday.daysUntil == 0 {
                return "Today"
            } else if birthday.daysUntil == 1 {
                return "Tomorrow"
            } else if birthday.daysUntil <= 7 {
                return "This Week"
            } else if birthday.daysUntil <= 30 {
                return "This Month"
            } else if birthday.daysUntil <= 90 {
                return "Next 3 Months"
            } else {
                return "Later This Year"
            }
        }

        let order = ["Today", "Tomorrow", "This Week", "This Month", "Next 3 Months", "Later This Year"]
        return order.compactMap { key in
            guard let birthdays = grouped[key], !birthdays.isEmpty else { return nil }
            return (key, birthdays.sorted { $0.daysUntil < $1.daysUntil })
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
        .background(Color.appBackground)
        .navigationTitle("Birthdays & Countdowns")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadBirthdays(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilesDidChange)) { _ in
            Task {
                await viewModel.loadBirthdays(appState: appState)
                if let selected = selectedBirthday,
                   let updated = viewModel.upcomingBirthdays.first(where: { $0.id == selected.id }) {
                    selectedBirthday = updated
                }
            }
        }
    }

    // MARK: - Left Pane
    private var leftPane: some View {
        VStack(spacing: 0) {
            searchBar
            birthdayListScrollView
        }
        .frame(width: 320)
        .background(Color.appBackground)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            searchField
        }
        .padding(16)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)
            TextField("Search birthdays", text: $searchText)
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

    // MARK: - Birthday List
    private var birthdayListScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(groupedBirthdays, id: \.0) { sectionTitle, birthdays in
                    Section {
                        ForEach(birthdays) { birthday in
                            iPadBirthdayRowView(
                                birthday: birthday,
                                isSelected: selectedBirthday?.id == birthday.id,
                                onSelect: { selectedBirthday = birthday }
                            )
                        }
                    } header: {
                        sectionHeader(title: sectionTitle)
                    }
                }

                if filteredBirthdays.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.textSecondary)
                        Text("No upcoming birthdays")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
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
        if let birthday = selectedBirthday {
            iPadBirthdayDetailPane(birthday: birthday)
                .id(birthday.id)
        } else {
            emptyDetailPane
        }
    }

    private var emptyDetailPane: some View {
        VStack {
            Spacer()
            ContentUnavailableView(
                "Select a Birthday",
                systemImage: "gift.fill",
                description: Text("Choose a birthday to view their profile")
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - iPad Birthday Row View
struct iPadBirthdayRowView: View {
    let birthday: UpcomingBirthday
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    private var countdownText: String {
        if birthday.daysUntil == 0 {
            return "Today!"
        } else if birthday.daysUntil == 1 {
            return "Tomorrow"
        } else {
            return "\(birthday.daysUntil) days"
        }
    }

    private var turningAge: Int? {
        guard let age = birthday.profile.age else { return nil }
        return age + 1
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                profileImage

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(birthday.profile.displayName)
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)

                        if birthday.daysUntil == 0 {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundColor(appAccentColor)
                        }
                    }

                    if let relationship = birthday.profile.relationship {
                        Text(relationship)
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Text(countdownText)
                            .font(.appCaptionSmall)
                            .foregroundColor(birthday.daysUntil == 0 ? appAccentColor : .textMuted)

                        if let age = turningAge {
                            Text("Turns \(age)")
                                .font(.appCaptionSmall)
                                .foregroundColor(.textMuted)
                        }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var profileImage: some View {
        if let photoUrl = birthday.profile.photoUrl, !photoUrl.isEmpty {
            AsyncImage(url: URL(string: photoUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                default:
                    defaultProfileImage
                }
            }
        } else {
            defaultProfileImage
        }
    }

    private var defaultProfileImage: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 40))
            .foregroundColor(.textSecondary)
            .frame(width: 50, height: 50)
    }
}

// MARK: - iPad Birthday Detail Pane
struct iPadBirthdayDetailPane: View {
    let birthday: UpcomingBirthday
    @EnvironmentObject var appState: AppState
    @State private var showEditProfile = false
    @Environment(\.appAccentColor) private var appAccentColor

    private var turningAge: Int? {
        guard let age = birthday.profile.age else { return nil }
        return age + 1
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                birthdayHeader
                countdownCard
                contactActions
                detailsSections
                editButton

                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(profile: birthday.profile) { _ in
                NotificationCenter.default.post(name: .profilesDidChange, object: nil)
            }
        }
    }

    private var birthdayHeader: some View {
        VStack(spacing: 12) {
            if let photoUrl = birthday.profile.photoUrl, !photoUrl.isEmpty {
                AsyncImage(url: URL(string: photoUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    default:
                        defaultLargeProfileImage
                    }
                }
            } else {
                defaultLargeProfileImage
            }

            VStack(spacing: 4) {
                Text(birthday.profile.displayName)
                    .font(.appLargeTitle)
                    .foregroundColor(.textPrimary)

                if let relationship = birthday.profile.relationship {
                    Text(relationship)
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }

                if let bday = birthday.profile.birthday {
                    Text(bday.formattedBirthdayWithOrdinal())
                        .font(.appCaption)
                        .foregroundColor(.textMuted)
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

    private var countdownCard: some View {
        HStack(spacing: 24) {
            // Days until
            VStack(spacing: 4) {
                if birthday.daysUntil == 0 {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(appAccentColor)
                    Text("Today!")
                        .font(.appCardTitle)
                        .foregroundColor(appAccentColor)
                } else {
                    Text("\(birthday.daysUntil)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    Text(birthday.daysUntil == 1 ? "day away" : "days away")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.cardBackground)
            .cornerRadius(12)

            // Turning age
            if let age = turningAge {
                VStack(spacing: 4) {
                    Text("\(age)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(appAccentColor)
                    Text("Turning")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.cardBackground)
                .cornerRadius(12)
            }
        }
    }

    private var contactActions: some View {
        HStack(spacing: 16) {
            if let phone = birthday.profile.phone {
                contactActionButton(icon: "phone.fill", title: "Call", color: .badgeGreen) {
                    let cleaned = phone.replacingOccurrences(of: " ", with: "")
                    if let url = URL(string: "tel://\(cleaned)") {
                        UIApplication.shared.open(url)
                    }
                }
            }

            if let email = birthday.profile.email {
                contactActionButton(icon: "envelope.fill", title: "Email", color: .clothingBlue) {
                    if let url = URL(string: "mailto:\(email)") {
                        UIApplication.shared.open(url)
                    }
                }
            }

            // Gift ideas
            contactActionButton(icon: "gift.fill", title: "Gift Ideas", color: .giftPurple) {
                // Navigate to profile gifts section
                showEditProfile = true
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
            if let phone = birthday.profile.phone {
                detailRow(label: "Phone", value: phone, icon: "phone")
            }

            if let email = birthday.profile.email {
                detailRow(label: "Email", value: email, icon: "envelope")
            }

            if let address = birthday.profile.address {
                detailRow(label: "Address", value: address, icon: "map")
            }

            if let notes = birthday.profile.notes, !notes.isEmpty {
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
            showEditProfile = true
        } label: {
            Label("View Full Profile", systemImage: "person.crop.circle")
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
#Preview("iPad Birthdays") {
    iPadBirthdaysView()
        .environmentObject(AppState())
}
