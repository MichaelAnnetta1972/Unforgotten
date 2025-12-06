import SwiftUI

// MARK: - Home Destinations
enum HomeDestination: Hashable {
    case myCard
    case profiles
    case medications
    case appointments
    case birthdays
    case contacts
    case mood
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @State private var showSettings = false
    @Environment(\.navNamespace) private var namespace

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header at the top - fully interactive
                HeaderImageView(
                    imageName: "header-home",
                    title: "Unforgotten",
                    showSettingsButton: true,
                    settingsAction: { showSettings = true }
                )

                // Content scrolls below header
                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Today Card (if there are items)
                        if viewModel.hasTodayItems {
                            TodayCard(viewModel: viewModel)
                        }

                        // Navigation Cards
                        VStack(spacing: AppDimensions.cardSpacing) {
                            NavigationLink(value: HomeDestination.myCard) {
                                NavigationCardContent(title: "My Card", icon: "person.crop.circle")
                            }
                            .matchedTransitionSource(id: HomeDestination.myCard, in: namespace)

                            NavigationLink(value: HomeDestination.profiles) {
                                NavigationCardContent(title: "Family and Friends", icon: "person.2")
                            }
                            .matchedTransitionSource(id: HomeDestination.profiles, in: namespace)

                            NavigationLink(value: HomeDestination.medications) {
                                NavigationCardContent(title: "Medicines", icon: "pill")
                            }
                            .matchedTransitionSource(id: HomeDestination.medications, in: namespace)

                            NavigationLink(value: HomeDestination.appointments) {
                                NavigationCardContent(title: "Appointments", icon: "calendar")
                            }
                            .matchedTransitionSource(id: HomeDestination.appointments, in: namespace)

                            NavigationLink(value: HomeDestination.birthdays) {
                                NavigationCardContent(title: "Birthdays", icon: "gift")
                            }
                            .matchedTransitionSource(id: HomeDestination.birthdays, in: namespace)

                            NavigationLink(value: HomeDestination.contacts) {
                                NavigationCardContent(title: "Useful Contacts", icon: "phone")
                            }
                            .matchedTransitionSource(id: HomeDestination.contacts, in: namespace)

                            NavigationLink(value: HomeDestination.mood) {
                                NavigationCardContent(title: "Mood Tracker", icon: "face.smiling")
                            }
                            .matchedTransitionSource(id: HomeDestination.mood, in: namespace)
                        }

                        // Bottom spacing
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
            await viewModel.loadData(appState: appState)
        }
        .refreshable {
            await viewModel.loadData(appState: appState)
        }
    }
}

// MARK: - Navigation Card Content
struct NavigationCardContent: View {
    let title: String
    let icon: String?

    var body: some View {
        HStack(spacing: 14) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.accentYellow)
                    .frame(width: 28)
            }

            Text(title)
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(.textSecondary)
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Today Card
struct TodayCard: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: HomeViewModel
    @State private var isExpanded = false

    private var visibleItems: [TodayItem] {
        let allItems = viewModel.allTodayItems
        if isExpanded {
            return allItems
        } else {
            return Array(allItems.prefix(3))
        }
    }

    private var hasMoreItems: Bool {
        viewModel.allTodayItems.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TODAY")
                    .font(.appCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentYellow)

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
                        TodayMedicationRow(log: log, viewModel: viewModel)
                    case .appointment(let appointment):
                        TodayAppointmentRow(appointment: appointment)
                    case .birthday(let profile):
                        TodayBirthdayRow(profile: profile)
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
                        Text(isExpanded ? "Show less" : "See all \(viewModel.allTodayItems.count) items")
                            .font(.appBody)
                            .foregroundColor(.accentYellow)

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(.accentYellow)
                    }
                    .padding(AppDimensions.cardPadding)
                }
            }
        }
        .background(Color.cardBackgroundLight.opacity(0.8))
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Today Item Enum
enum TodayItem: Identifiable {
    case medication(MedicationLog)
    case appointment(Appointment)
    case birthday(Profile)

    var id: String {
        switch self {
        case .medication(let log): return "med-\(log.id)"
        case .appointment(let apt): return "apt-\(apt.id)"
        case .birthday(let profile): return "bday-\(profile.id)"
        }
    }
}

// MARK: - Today Medication Row
struct TodayMedicationRow: View {
    @EnvironmentObject var appState: AppState
    let log: MedicationLog
    @ObservedObject var viewModel: HomeViewModel
    @State private var isUpdating = false
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "pill.fill")
                .font(.system(size: 18))
                .foregroundColor(.medicalRed)
                .frame(width: 32, height: 32)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.medicationName(for: log))
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)

                Text(log.scheduledAt.formatted(date: .omitted, time: .shortened))
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Action button
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
                            .frame(width: 60, height: 32)
                            .background(Color.accentYellow)
                            .cornerRadius(8)
                    } else {
                        Text("Take")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appBackground)
                            .frame(width: 60, height: 32)
                            .background(Color.accentYellow)
                            .cornerRadius(8)
                    }
                }
                .disabled(isUpdating)
            } else {
                Text("Taken")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.badgeGreen)
                    .frame(width: 60, height: 32)
            }

            // Options button (vertical dots)
            Button {
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppDimensions.cardPadding)
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

// MARK: - Today Appointment Row
struct TodayAppointmentRow: View {
    let appointment: Appointment
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "calendar")
                .font(.system(size: 18))
                .foregroundColor(.calendarBlue)
                .frame(width: 32, height: 32)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(appointment.title)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)

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

            // Options button (vertical dots)
            Button {
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppDimensions.cardPadding)
        .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
            Button("View details") {
                // Navigate to appointment details
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Today Birthday Row
struct TodayBirthdayRow: View {
    let profile: Profile
    @State private var showOptions = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "gift.fill")
                .font(.system(size: 18))
                .foregroundColor(.calendarPink)
                .frame(width: 32, height: 32)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text("\(profile.displayName)'s Birthday")
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)

                if let age = profile.age {
                    Text("Turning \(age + 1)")
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
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppDimensions.cardPadding)
        .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
            Button("View profile") {
                // Navigate to profile
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Home View Model
@MainActor
class HomeViewModel: ObservableObject {
    @Published var todayMedications: [MedicationLog] = []
    @Published var todayAppointments: [Appointment] = []
    @Published var todayBirthdays: [Profile] = []
    @Published var medications: [Medication] = []
    @Published var isLoading = false
    @Published var error: String?

    var hasTodayItems: Bool {
        !todayMedications.isEmpty || !todayAppointments.isEmpty || !todayBirthdays.isEmpty
    }

    var allTodayItems: [TodayItem] {
        var items: [TodayItem] = []
        items.append(contentsOf: todayMedications.map { .medication($0) })
        items.append(contentsOf: todayAppointments.map { .appointment($0) })
        items.append(contentsOf: todayBirthdays.map { .birthday($0) })
        return items
    }

    func medicationName(for log: MedicationLog) -> String {
        medications.first { $0.id == log.medicationId }?.name ?? "Medication"
    }

    func loadData(appState: AppState) async {
        guard let accountId = appState.currentAccount?.id else { return }

        isLoading = true

        do {
            // Load medications for name lookup
            medications = try await appState.medicationRepository.getMedications(accountId: accountId)

            // Load today's medication logs
            todayMedications = try await appState.medicationRepository.getTodaysLogs(accountId: accountId)
                .filter { $0.status == .scheduled || $0.status == .taken }

            // Load today's appointments
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            todayAppointments = try await appState.appointmentRepository.getAppointments(accountId: accountId)
                .filter { $0.date >= startOfDay && $0.date < endOfDay }

            // Load today's birthdays
            let allProfiles = try await appState.profileRepository.getProfiles(accountId: accountId)
            todayBirthdays = allProfiles.filter { profile in
                guard let birthday = profile.birthday else { return false }
                return birthday.daysUntilNextOccurrence() == 0
            }

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func markMedicationTaken(log: MedicationLog, appState: AppState) async {
        do {
            try await appState.medicationRepository.updateLogStatus(logId: log.id, status: .taken)
            // Update local state
            if let index = todayMedications.firstIndex(where: { $0.id == log.id }) {
                todayMedications[index].status = .taken
                todayMedications[index].takenAt = Date()
            }
        } catch {
            self.error = "Failed to update medication: \(error.localizedDescription)"
        }
    }

    func skipMedication(log: MedicationLog, appState: AppState) async {
        do {
            try await appState.medicationRepository.updateLogStatus(logId: log.id, status: .skipped)
            // Remove from list
            todayMedications.removeAll { $0.id == log.id }
        } catch {
            self.error = "Failed to skip medication: \(error.localizedDescription)"
        }
    }

    func markMedicationNotTaken(log: MedicationLog, appState: AppState) async {
        do {
            try await appState.medicationRepository.updateLogStatus(logId: log.id, status: .scheduled)
            // Update local state
            if let index = todayMedications.firstIndex(where: { $0.id == log.id }) {
                todayMedications[index].status = .scheduled
                todayMedications[index].takenAt = nil
            }
        } catch {
            self.error = "Failed to update medication: \(error.localizedDescription)"
        }
    }
}
