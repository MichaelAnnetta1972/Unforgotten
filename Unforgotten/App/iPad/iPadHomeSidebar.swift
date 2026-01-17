//
//  iPadHomeSidebar.swift
//  Unforgotten
//
//  iPad sidebar components including home sidebar, today card, and navigation items
//

import SwiftUI

// MARK: - iPad Home Sidebar
/// Displays the iPhone HomeView style content as a persistent sidebar
struct iPadHomeSidebar: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @Binding var selectedContent: iPadContentSelection
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(FeatureVisibilityManager.self) private var featureVisibility
    @State private var showAccountSwitcher = false

    /// Helper/Viewer roles only see limited features
    private var isLimitedAccess: Bool {
        appState.currentUserRole == .helper || appState.currentUserRole == .viewer
    }

    /// Check if user has premium access (subscription or complimentary)
    private var isPremiumUser: Bool {
        appState.hasPremiumAccess
    }

    /// Check if a feature should be visible based on role AND user preferences
    private func shouldShowFeature(_ feature: Feature) -> Bool {
        // First check user's feature visibility preferences
        guard featureVisibility.isVisible(feature) else { return false }

        // For limited access roles, only show specific features
        if isLimitedAccess {
            switch feature {
            case .aboutMe, .medications, .appointments, .moodTracker, .usefulContacts, .stickyReminders:
                return true
            default:
                return false
            }
        }

        return true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with video/image
                    CustomizableHeaderView(
                        pageIdentifier: .home,
                        title: "Unforgotten",
                        showAccountSwitcherButton: appState.allAccounts.count > 1,
                        accountSwitcherAction: { showAccountSwitcher = true },
                        showSettingsButton: true,
                        settingsAction: { selectedContent = .settings },
                        roundedTopRightCorner: true,
                        useLogo: true,
                        logoImageName: "unforgotten-logo"
                    )

                    // Viewing As Bar (shown when viewing another account) - only on Home page for iPad
                    ViewingAsBar(showOnIPad: true)

                    // Content
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Today Card (if there are items)
                        if viewModel.hasTodayItems(showBirthdays: !isLimitedAccess) {
                            iPadSidebarTodayCard(viewModel: viewModel, showBirthdays: !isLimitedAccess)
                        }

                        // Navigation Items
                        VStack(spacing: AppDimensions.cardSpacing) {
                            if shouldShowFeature(.aboutMe) {
                                iPadSidebarNavItem(
                                    title: "About Me",
                                    icon: "person.crop.circle",
                                    isSelected: selectedContent == .myCard
                                ) {
                                    selectedContent = .myCard
                                }
                            }

                            if shouldShowFeature(.familyAndFriends) {
                                iPadSidebarNavItem(
                                    title: "Family and Friends",
                                    icon: "person.2",
                                    isSelected: selectedContent == .profiles
                                ) {
                                    selectedContent = .profiles
                                }
                            }

                            if shouldShowFeature(.medications) {
                                iPadSidebarNavItem(
                                    title: "Medications",
                                    icon: "pill",
                                    isSelected: selectedContent == .medications
                                ) {
                                    selectedContent = .medications
                                }
                            }

                            if shouldShowFeature(.appointments) {
                                iPadSidebarNavItem(
                                    title: "Appointments",
                                    icon: "calendar",
                                    isSelected: selectedContent == .appointments
                                ) {
                                    selectedContent = .appointments
                                }
                            }

                            if shouldShowFeature(.stickyReminders) {
                                iPadSidebarNavItem(
                                    title: "Sticky Reminders",
                                    icon: "pin.fill",
                                    isSelected: selectedContent == .stickyReminders
                                ) {
                                    selectedContent = .stickyReminders
                                }
                            }

                            if shouldShowFeature(.todoLists) {
                                iPadSidebarNavItem(
                                    title: "To Do Lists",
                                    icon: "checklist",
                                    isSelected: selectedContent == .todoLists
                                ) {
                                    selectedContent = .todoLists
                                }
                            }

                            if shouldShowFeature(.notes) {
                                iPadSidebarNavItem(
                                    title: "Notes",
                                    icon: "note.text",
                                    isSelected: selectedContent == .notes
                                ) {
                                    selectedContent = .notes
                                }
                            }


                            if shouldShowFeature(.birthdays) {
                                iPadSidebarNavItem(
                                    title: "Birthdays and Countdowns",
                                    icon: "gift",
                                    isSelected: selectedContent == .birthdays
                                ) {
                                    selectedContent = .birthdays
                                }
                            }

                            if shouldShowFeature(.usefulContacts) {
                                iPadSidebarNavItem(
                                    title: "Useful Contacts",
                                    icon: "phone",
                                    isSelected: selectedContent == .contacts
                                ) {
                                    selectedContent = .contacts
                                }
                            }

                            if shouldShowFeature(.moodTracker) {
                                iPadSidebarNavItem(
                                    title: "Mood Tracker",
                                    icon: "face.smiling",
                                    isSelected: selectedContent == .mood
                                ) {
                                    selectedContent = .mood
                                }
                            }
                        }

                        // Upgrade banner (only show for free users on their own account)
                        if !isPremiumUser && !appState.isViewingOtherAccount {
                            iPadSidebarUpgradeBanner()
                        }

                        // Bottom spacing for gradient
                        Spacer()
                            .frame(height: 140)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Bottom gradient overlay (matches right panel)
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.5),
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .bottom)
        }
        .background(Color.appBackgroundLight)
        .refreshable {
            await viewModel.loadData(appState: appState)
            await appState.generateTodaysMedicationLogs()
            await viewModel.loadData(appState: appState)
        }
        .task {
            await viewModel.loadData(appState: appState)
            await appState.generateTodaysMedicationLogs()
            await viewModel.loadData(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationsDidChange)) { _ in
            Task {
                await appState.generateTodaysMedicationLogs()
                await viewModel.loadData(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appointmentsDidChange)) { _ in
            Task {
                await viewModel.loadData(appState: appState)
            }
        }
        .overlay {
            if showAccountSwitcher {
                // Tap-to-dismiss background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showAccountSwitcher = false
                    }
                    .transition(.opacity)
                    .zIndex(99)
            }
        }
        .overlay(alignment: .topLeading) {
            if showAccountSwitcher {
                iPadAccountSwitcherPopover(isPresented: $showAccountSwitcher)
                    .environmentObject(appState)
                    .transition(.scale(scale: 0.8, anchor: .topLeading).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAccountSwitcher)
        .onChange(of: appState.currentAccount?.id) { _, _ in
            // Reload data when account changes
            Task {
                await viewModel.loadData(appState: appState)
                await appState.generateTodaysMedicationLogs()
                await viewModel.loadData(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            // Reload sidebar data when account changes from elsewhere
            Task {
                await viewModel.loadData(appState: appState)
                await appState.generateTodaysMedicationLogs()
                await viewModel.loadData(appState: appState)
            }
        }
    }
}

// MARK: - iPad Account Switcher Popover
struct iPadAccountSwitcherPopover: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Switch Account")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding()

            Divider()
                .background(Color.textSecondary.opacity(0.3))

            // Account List - sizes to fit content, scrolls if too many accounts
            VStack(spacing: 8) {
                ForEach(appState.allAccounts) { accountWithRole in
                    iPadAccountSwitcherRow(
                        accountWithRole: accountWithRole,
                        isSelected: appState.currentAccount?.id == accountWithRole.account.id,
                        onSelect: {
                            Task {
                                await appState.switchAccount(to: accountWithRole)
                                isPresented = false
                            }
                        }
                    )
                }
            }
            .padding()
        }
        .frame(width: 400)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(.top, 70) // Position below header
        .padding(.leading, 16)
    }
}

// MARK: - iPad Account Switcher Row
struct iPadAccountSwitcherRow: View {
    let accountWithRole: AccountWithRole
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Account icon
                ZStack {
                    Circle()
                        .fill(accountWithRole.isOwner ? appAccentColor : Color.cardBackgroundSoft)
                        .frame(width: 40, height: 40)

                    Image(systemName: accountWithRole.isOwner ? "house.fill" : "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(accountWithRole.isOwner ? .black : .textSecondary)
                }

                // Account info
                VStack(alignment: .leading, spacing: 2) {
                    Text(accountWithRole.displayName)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Text(accountWithRole.role.displayName)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Selected indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(appAccentColor)
                }
            }
            .padding(12)
            .background(isSelected ? appAccentColor.opacity(0.1) : Color.cardBackgroundSoft)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? appAccentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - iPad Sidebar Navigation Item
struct iPadSidebarNavItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : appAccentColor)
                    .frame(width: 28)

                Text(title)
                    .font(.appCardTitle)
                    .foregroundColor(isSelected ? .white : .textPrimary)

                Spacer()

                if !isSelected {
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(AppDimensions.cardPaddingLarge)
            .background(isSelected ? appAccentColor : Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }
}

// MARK: - iPad Sidebar Upgrade Banner
struct iPadSidebarUpgradeBanner: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var showUpgradeSheet = false

    var body: some View {
        Button {
            showUpgradeSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundColor(appAccentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Plan")
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    Text("Tap to upgrade")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Text("Upgrade")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appBackground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(appAccentColor)
                    .cornerRadius(12)
            }
            .padding(AppDimensions.cardPadding)
            .background(
                LinearGradient(
                    colors: [
                        appAccentColor.opacity(0.12),
                        appAccentColor.opacity(0.04)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(appAccentColor.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
        }
    }
}

// MARK: - iPad Sidebar Today Card
struct iPadSidebarTodayCard: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @ObservedObject var viewModel: HomeViewModel
    @State private var isExpanded = false

    /// Whether to show birthdays (false for Helper/Viewer roles)
    var showBirthdays: Bool = true

    private var filteredItems: [TodayItem] {
        viewModel.allTodayItems(includeBirthdays: showBirthdays)
    }

    private var visibleItems: [TodayItem] {
        let allItems = filteredItems
        if isExpanded {
            return allItems
        } else {
            return Array(allItems.prefix(1))
        }
    }

    private var hasMoreItems: Bool {
        filteredItems.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TODAY")
                    .font(.appCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(appAccentColor)

                Spacer()
            }
            .padding(.horizontal, AppDimensions.cardPadding)
            .padding(.top, AppDimensions.cardPadding)
            .padding(.bottom, 12)

            // Items
            ForEach(visibleItems) { item in
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    switch item {
                    case .medication(let log):
                        iPadSidebarMedicationRow(log: log, viewModel: viewModel)
                    case .appointment(let appointment):
                        iPadSidebarAppointmentRow(appointment: appointment, viewModel: viewModel)
                    case .birthday(let profile):
                        iPadSidebarBirthdayRow(profile: profile)
                    case .countdown(let countdown):
                        iPadSidebarCountdownRow(countdown: countdown)
                    }
                }
            }

            // See all button
            if hasMoreItems {
                Divider()
                    .background(Color.white.opacity(0.1))

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(isExpanded ? "Show less" : "See all \(filteredItems.count) items")
                            .font(.appBody)
                            .foregroundColor(appAccentColor)

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(appAccentColor)
                    }
                    .padding(AppDimensions.cardPadding)
                }
            }
        }
        .background(Color.cardBackgroundLight.opacity(0.8))
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - iPad Sidebar Medication Row
struct iPadSidebarMedicationRow: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    let log: MedicationLog
    @ObservedObject var viewModel: HomeViewModel
    @State private var isUpdating = false
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pill.fill")
                .font(.system(size: 18))
                .foregroundColor(.medicalRed)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.medicationName(for: log))
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(log.scheduledAt.formatted(date: .omitted, time: .shortened))
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if log.status == .scheduled {
                Button {
                    Task {
                        isUpdating = true
                        await viewModel.markMedicationTaken(log: log, appState: appState)
                        isUpdating = false
                    }
                } label: {
                    if isUpdating {
                        ProgressView()
                            .tint(.appBackground)
                            .frame(width: 50, height: 28)
                            .background(appAccentColor)
                            .cornerRadius(6)
                    } else {
                        Text("Take")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.appBackground)
                            .frame(width: 50, height: 28)
                            .background(appAccentColor)
                            .cornerRadius(6)
                    }
                }
                .disabled(isUpdating)
            } else {
                Text("Taken")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(appAccentColor)
            }

            Button {
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, AppDimensions.cardPadding)
        .padding(.vertical, 10)
        .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
            if log.status == .scheduled {
                Button("Skip medication") {
                    Task {
                        await viewModel.skipMedication(log: log, appState: appState)
                    }
                }
            } else if log.status == .taken {
                Button("Mark as not taken") {
                    Task {
                        await viewModel.markMedicationNotTaken(log: log, appState: appState)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - iPad Sidebar Appointment Row
struct iPadSidebarAppointmentRow: View {
    let appointment: Appointment
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 18))
                .foregroundColor(.calendarBlue)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(appointment.title)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                if let time = appointment.time {
                    Text(time.formatted(date: .omitted, time: .shortened))
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                } else {
                    Text("All day")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Button {
                viewModel.toggleAppointmentCompleted(appointmentId: appointment.id, appState: appState)
            } label: {
                Image(systemName: appointment.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 22))
                    .foregroundColor(appointment.isCompleted ? appAccentColor : .textSecondary.opacity(0.4))
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, AppDimensions.cardPadding)
        .padding(.vertical, 10)
        .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
            Button("View details") { }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - iPad Sidebar Birthday Row
struct iPadSidebarBirthdayRow: View {
    let profile: Profile
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 18))
                .foregroundColor(.calendarPink)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(profile.displayName)'s Birthday")
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                if let age = profile.age {
                    Text("Turning \(age + 1)")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Button {
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, AppDimensions.cardPadding)
        .padding(.vertical, 10)
        .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
            Button("View profile") { }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - iPad Sidebar Countdown Row
struct iPadSidebarCountdownRow: View {
    let countdown: Countdown
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: countdown.type.icon)
                .font(.system(size: 18))
                .foregroundColor(countdown.type.color)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(countdown.title)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(countdown.displayTypeName)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Button {
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, AppDimensions.cardPadding)
        .padding(.vertical, 10)
        .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
            Button("View details") { }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - iPad Empty Content View
struct iPadEmptyContentView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background image with 30% opacity
            Image("splash-background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.6)

            // Dark overlay for better readability
            Color.appBackground.opacity(0.3)

            // Stacked logo with animation and tagline
            VStack(spacing: 20) {
                Image("unforgotten-logo-stacked")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 250)
                    .opacity(logoOpacity * 0.6)
                    .scaleEffect(logoScale)

                Text("Because the important things in life\nshould stay Unforgotten.")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(logoOpacity * 0.6)
            }
            .zIndex(1000)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .zIndex(1000)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}
