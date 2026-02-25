import SwiftUI

// MARK: - Reminder Unit
enum ReminderUnit: String, CaseIterable, Identifiable {
    case minutes, hours, days, months

    var id: String { rawValue }

    var singularLabel: String {
        switch self {
        case .minutes: return "minute"
        case .hours: return "hour"
        case .days: return "day"
        case .months: return "month"
        }
    }

    var pluralLabel: String {
        switch self {
        case .minutes: return "minutes"
        case .hours: return "hours"
        case .days: return "days"
        case .months: return "months"
        }
    }

    var minuteMultiplier: Int {
        switch self {
        case .minutes: return 1
        case .hours: return 60
        case .days: return 1440
        case .months: return 43200 // 30 days
        }
    }

    static func fromMinutes(_ totalMinutes: Int) -> (number: Int, unit: ReminderUnit) {
        if totalMinutes <= 0 { return (1, .hours) }
        if totalMinutes % 43200 == 0 { return (totalMinutes / 43200, .months) }
        if totalMinutes % 1440 == 0 { return (totalMinutes / 1440, .days) }
        if totalMinutes % 60 == 0 { return (totalMinutes / 60, .hours) }
        return (totalMinutes, .minutes)
    }
}

// MARK: - Repeat Unit
enum RepeatUnit: String, CaseIterable, Identifiable {
    case day, week, fortnight, month, year

    var id: String { rawValue }

    var singularLabel: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .fortnight: return "fortnight"
        case .month: return "month"
        case .year: return "year"
        }
    }

    var pluralLabel: String {
        switch self {
        case .day: return "days"
        case .week: return "weeks"
        case .fortnight: return "fortnights"
        case .month: return "months"
        case .year: return "years"
        }
    }
}

// MARK: - Appointment List View
struct AppointmentListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.iPadAddAppointmentAction) private var iPadAddAppointmentAction
    @Environment(\.iPadAppointmentFilterBinding) private var iPadAppointmentFilterBinding
    @StateObject private var viewModel = AppointmentListViewModel()
    @State private var showAddAppointment = false
    @State private var showUpgradePrompt = false
    @State private var appointmentToDelete: Appointment?
    @State private var showDeleteConfirmation = false
    @State private var sharedAppointmentToRemove: Appointment?
    @State private var showRemoveSharedConfirmation = false
    @State private var selectedTypeFilter: AppointmentType? = nil
    @State private var searchText = ""
    @State private var listContentHeight: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Check if we're in iPad mode (regular size class)
    private var isiPad: Bool {
        horizontalSizeClass == .regular
    }

    /// Check if user has premium access for unlimited appointments
    /// Note: Free tier users can still add appointments but only within 30 days
    private var hasPremiumAppointments: Bool {
        PremiumLimitsManager.shared.hasPremiumAccess(appState: appState)
    }

    /// Get the active type filter - uses iPad binding if available, otherwise local state
    private var activeTypeFilter: AppointmentType? {
        iPadAppointmentFilterBinding?.wrappedValue ?? selectedTypeFilter
    }

    private var filteredAppointments: [Appointment] {
        var result = viewModel.appointments
        if let typeFilter = activeTypeFilter {
            result = result.filter { $0.type == typeFilter }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.location?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.type.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    /// Types that are actually used in the current appointments list
    private var availableTypes: [AppointmentType] {
        let usedTypes = Set(viewModel.appointments.map { $0.type })
        return AppointmentType.allCases.filter { usedTypes.contains($0) }
    }

    /// Whether the current user can add/edit appointments
    private var canEdit: Bool {
        appState.canEdit
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 0) {
                // Header scrolls with content - uses style-based assets from HeaderStyleManager
                CustomizableHeaderView(
                    pageIdentifier: .appointments,
                    title: "Appointments",
                    showBackButton: iPadHomeAction == nil,
                    backAction: { dismiss() },
                    showHomeButton: iPadHomeAction != nil,
                    homeAction: iPadHomeAction,
                    showAddButton: canEdit,
                    addAction: canEdit ? {
                        // On iPad, use the environment action to trigger the root-level panel
                        if let iPadAddAction = iPadAddAppointmentAction {
                            iPadAddAction()
                        } else {
                            // On iPhone, use local state
                            showAddAppointment = true
                        }
                    } : nil
                )

                // Viewing As Bar (shown when viewing another account)
                ViewingAsBar()

                // Content
                VStack(spacing: AppDimensions.cardSpacing) {
                        // Search bar with filter icon
                        HStack(spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.textSecondary)

                                TextField("Search appointments", text: $searchText)
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

                            Menu {
                                Button {
                                    selectedTypeFilter = nil
                                    iPadAppointmentFilterBinding?.wrappedValue = nil
                                } label: {
                                    if activeTypeFilter == nil {
                                        Label("All", systemImage: "checkmark")
                                    } else {
                                        Text("All")
                                    }
                                }

                                ForEach(availableTypes, id: \.self) { type in
                                    Button {
                                        selectedTypeFilter = type
                                        iPadAppointmentFilterBinding?.wrappedValue = type
                                    } label: {
                                        if activeTypeFilter == type {
                                            Label(type.displayName, systemImage: "checkmark")
                                        } else {
                                            Label(type.displayName, systemImage: type.icon)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: activeTypeFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(activeTypeFilter != nil ? appAccentColor : .textSecondary)
                                    .frame(width: 44, height: 44)
                                    .background(Color.cardBackground)
                                    .cornerRadius(AppDimensions.cardCornerRadius)
                            }
                            .tint(appAccentColor)
                        }

                        // Appointments list
                        if !filteredAppointments.isEmpty {
                            List {
                                ForEach(filteredAppointments) { appointment in
                                    ZStack {
                                        NavigationLink(destination: AppointmentDetailView(appointment: appointment)) {
                                            EmptyView()
                                        }
                                        .opacity(0)

                                        AppointmentListRow(
                                            appointment: appointment,
                                            isCompleted: appointment.isCompleted,
                                            isShared: appointment.accountId != appState.currentAccount?.id,
                                            onToggleCompleted: {
                                                viewModel.toggleAppointmentCompleted(appointmentId: appointment.id, appState: appState)
                                            }
                                        )
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        if canEdit && appointment.accountId == appState.currentAccount?.id {
                                            Button(role: .destructive) {
                                                appointmentToDelete = appointment
                                                showDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        } else if appointment.accountId != appState.currentAccount?.id {
                                            // Shared appointment - allow removing from user's view
                                            Button(role: .destructive) {
                                                sharedAppointmentToRemove = appointment
                                                showRemoveSharedConfirmation = true
                                            } label: {
                                                Label("Remove", systemImage: "eye.slash")
                                            }
                                        }
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: AppDimensions.cardSpacing / 2, leading: 0, bottom: AppDimensions.cardSpacing / 2, trailing: 0))
                                }
                            }
                            .listStyle(.plain)
                            .scrollDisabled(true)
                            .scrollContentBackground(.hidden)
                            .frame(height: listContentHeight)
                            .onChange(of: filteredAppointments.count) { _, count in
                                let rowHeight: CGFloat = 76
                                let spacing: CGFloat = AppDimensions.cardSpacing
                                listContentHeight = CGFloat(count) * (rowHeight + spacing)
                            }
                            .onAppear {
                                let rowHeight: CGFloat = 76
                                let spacing: CGFloat = AppDimensions.cardSpacing
                                listContentHeight = CGFloat(filteredAppointments.count) * (rowHeight + spacing)
                            }
                        }

                        // Loading state
                        if viewModel.isLoading && viewModel.appointments.isEmpty {
                            LoadingView(message: "Loading appointments...")
                                .padding(.top, 40)
                        }

                        // Empty state
                        if filteredAppointments.isEmpty && !viewModel.isLoading {
                            VStack(spacing: 16) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 60))
                                    .foregroundColor(.textSecondary)

                                Text(activeTypeFilter.map { "No \($0.displayName.lowercased()) appointments" } ?? "No Appointments")
                                    .font(.appTitle)
                                    .foregroundColor(.textPrimary)

                                Text(activeTypeFilter != nil ? "Try selecting a different filter" : "Keep track of upcoming appointments and events")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)

                                if activeTypeFilter == nil && canEdit {
                                    PrimaryButton(
                                        title: "Add Appointment",
                                        backgroundColor: appAccentColor
                                    ) {
                                        // On iPad, use the environment action to trigger the root-level panel
                                        if let iPadAddAction = iPadAddAppointmentAction {
                                            iPadAddAction()
                                        } else {
                                            // On iPhone, use local state
                                            showAddAppointment = true
                                        }
                                    }
                                    .padding(.horizontal, 32)
                                    .padding(.top, 8)
                                }
                            }
                            .frame(maxWidth: isiPad ? 400 : .infinity)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        }

                        // Info banner for free users about 30-day limit
                        if !hasPremiumAppointments && !viewModel.appointments.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(appAccentColor)

                                Text("Free plan: appointments limited to next 30 days")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                Spacer()

                                Button {
                                    showUpgradePrompt = true
                                } label: {
                                    Text("Upgrade")
                                        .font(.appCaption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(appAccentColor)
                                        .cornerRadius(16)
                                }
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(Color.cardBackground)
                            .cornerRadius(AppDimensions.cardCornerRadius)
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
        .navigationBarHidden(true)
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
                .presentationBackground(Color.appBackgroundLight)
        }
        // Only show sidePanel on iPhone - iPad handles this at iPadRootView level
        .sidePanel(isPresented: iPadAddAppointmentAction == nil ? $showAddAppointment : .constant(false)) {
            AddAppointmentView(
                onDismiss: { showAddAppointment = false }
            ) { _ in
                Task {
                    await viewModel.loadAppointments(appState: appState)
                }
            }
        }
        .task {
            await viewModel.loadAppointments(appState: appState)
        }
        .refreshable {
            await viewModel.loadAppointments(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appointmentsDidChange)) { notification in
            // Try to handle locally first for instant updates
            if notification.userInfo != nil {
                viewModel.handleAppointmentChange(notification: notification)
            }
            // Also reload to ensure we have fresh data
            Task {
                await viewModel.loadAppointments(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            Task {
                await viewModel.loadAppointments(appState: appState)
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
        .alert("Delete Appointment", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                appointmentToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let appointment = appointmentToDelete {
                    Task {
                        await viewModel.deleteAppointment(id: appointment.id, appState: appState)
                        appointmentToDelete = nil
                    }
                }
            }
        } message: {
            if let appointment = appointmentToDelete {
                Text("Are you sure you want to delete \(appointment.title)? This action cannot be undone.")
            }
        }
        .alert("Remove Shared Appointment", isPresented: $showRemoveSharedConfirmation) {
            Button("Cancel", role: .cancel) {
                sharedAppointmentToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let appointment = sharedAppointmentToRemove {
                    Task {
                        await viewModel.removeSharedAppointment(id: appointment.id, appState: appState)
                        sharedAppointmentToRemove = nil
                    }
                }
            }
        } message: {
            if let appointment = sharedAppointmentToRemove {
                Text("Remove \"\(appointment.title)\" from your appointments? The original owner will still have this appointment.")
            }
        }
    }
}

// MARK: - Appointment Header View
struct AppointmentHeaderView: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let onBack: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(hex: "1a237e"),
                    Color(hex: "4a148c")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: AppDimensions.headerHeight)
            
            LinearGradient(
                colors: [.clear, .black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Home")
                    }
                    .font(.appBodyMedium)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(appAccentColor)
                    .cornerRadius(20)
                }
                
                Spacer()
                
                Text("Appointments")
                    .font(.appLargeTitle)
                    .foregroundColor(.white)
            }
            .padding(AppDimensions.screenPadding)
        }
        .frame(height: AppDimensions.headerHeight)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .padding(.horizontal, AppDimensions.screenPadding)
    }
}

// MARK: - Appointment List Row
struct AppointmentListRow: View {
    let appointment: Appointment
    let isCompleted: Bool
    var isShared: Bool = false
    let onToggleCompleted: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Adaptive icon size: larger on iPad
    private var iconSize: CGFloat {
        horizontalSizeClass == .regular ? 48 : 40
    }

    /// Adaptive button size for iPad
    private var buttonSize: CGFloat {
        horizontalSizeClass == .regular ? 52 : 44
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        HStack {
            // Type icon with background
            Image(systemName: appointment.type.icon)
                .font(.system(size: horizontalSizeClass == .regular ? 22 : 18))
                .foregroundColor(appAccentColor)
                .frame(width: iconSize, height: iconSize)
                .background(appAccentColor.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(appointment.title)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)

                    if isShared {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.textMuted)
                    }
                }

                HStack(spacing: 8) {
                    Text(dateFormatter.string(from: appointment.date))
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    if let time = appointment.time {
                        Text("at \(timeFormatter.string(from: time))")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }
            }

            Spacer()

            // Toggleable check icon (disabled for shared appointments)
            if !isShared {
                Button {
                    onToggleCompleted()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: horizontalSizeClass == .regular ? 28 : 24))
                        .foregroundColor(isCompleted ? appAccentColor : .textSecondary.opacity(0.4))
                        .frame(width: buttonSize, height: buttonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .contentShape(Rectangle())
    }
}

// MARK: - Appointment List Card (Legacy)
struct AppointmentListCard: View {
    let appointment: Appointment

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.title)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)

                HStack(spacing: 8) {
                    Text(dateFormatter.string(from: appointment.date))
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    if let time = appointment.time {
                        Text("at \(timeFormatter.string(from: time))")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }

                if let location = appointment.location {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(location)
                            .font(.appCaption)
                    }
                    .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.textSecondary)
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Appointment List View Model
@MainActor
class AppointmentListViewModel: ObservableObject {
    @Published var appointments: [Appointment] = []
    @Published var isLoading = false
    @Published var error: String?

    func toggleAppointmentCompleted(appointmentId: UUID, appState: AppState) {
        guard let index = appointments.firstIndex(where: { $0.id == appointmentId }) else { return }
        let newStatus = !appointments[index].isCompleted

        // Update locally first for immediate UI feedback
        appointments[index].isCompleted = newStatus
        let updatedAppointment = appointments[index]

        // Persist to database and update notification
        Task {
            do {
                let saved = try await appState.appointmentRepository.toggleAppointmentCompletion(id: appointmentId, isCompleted: newStatus)

                // Cancel or reschedule notification based on completion status
                if newStatus {
                    // Completed - cancel the notification
                    await NotificationService.shared.cancelAppointmentReminder(appointmentId: appointmentId)
                } else {
                    // Uncompleted - reschedule the notification if in the future
                    if updatedAppointment.dateTime > Date() {
                        await NotificationService.shared.scheduleAppointmentReminder(
                            appointmentId: appointmentId,
                            title: updatedAppointment.title,
                            appointmentDate: updatedAppointment.date,
                            appointmentTime: updatedAppointment.time,
                            location: updatedAppointment.location,
                            reminderMinutesBefore: updatedAppointment.reminderOffsetMinutes ?? 60
                        )
                    }
                }

                // Post notification with appointment data so other views can update locally
                NotificationCenter.default.post(
                    name: .appointmentsDidChange,
                    object: nil,
                    userInfo: [
                        NotificationUserInfoKey.appointmentId: appointmentId,
                        NotificationUserInfoKey.action: AppointmentChangeAction.completionToggled,
                        NotificationUserInfoKey.appointment: saved
                    ]
                )
            } catch {
                // Revert on error
                if let idx = appointments.firstIndex(where: { $0.id == appointmentId }) {
                    appointments[idx].isCompleted = !newStatus
                }
                self.error = "Failed to update: \(error.localizedDescription)"
            }
        }
    }

    /// Handle appointment change notifications from other views
    func handleAppointmentChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let appointmentId = userInfo[NotificationUserInfoKey.appointmentId] as? UUID,
              let action = userInfo[NotificationUserInfoKey.action] as? AppointmentChangeAction else {
            return
        }

        switch action {
        case .completionToggled, .updated:
            if let appointment = userInfo[NotificationUserInfoKey.appointment] as? Appointment {
                // Update locally if we have this appointment
                if let index = appointments.firstIndex(where: { $0.id == appointmentId }) {
                    appointments[index] = appointment
                }
            }
        case .deleted:
            // Remove from local list
            appointments.removeAll { $0.id == appointmentId }
        case .created:
            // For new appointments, we'll reload to get the new data
            break
        }
    }

    func isAppointmentCompleted(appointmentId: UUID) -> Bool {
        appointments.first(where: { $0.id == appointmentId })?.isCompleted ?? false
    }

    func loadAppointments(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            // Load own appointments
            var allAppointments = try await appState.appointmentRepository.getUpcomingAppointments(accountId: account.id, days: 365)

            // Also load shared appointments from other accounts (via RPC to bypass RLS)
            let ownIds = Set(allAppointments.map { $0.id })
            if let shared = try? await appState.appointmentRepository.getSharedAppointments() {
                let newShared = shared.filter { !ownIds.contains($0.id) }
                if !newShared.isEmpty {
                    allAppointments.append(contentsOf: newShared)
                    allAppointments.sort { $0.date < $1.date }
                }
            }

            appointments = allAppointments
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    func deleteAppointment(id: UUID, appState: AppState) async {
        do {
            try await appState.appointmentRepository.deleteAppointment(id: id)
            // Cancel the notification for this appointment
            await NotificationService.shared.cancelAppointmentReminder(appointmentId: id)
            appointments.removeAll { $0.id == id }
        } catch {
            self.error = "Failed to delete appointment: \(error.localizedDescription)"
        }
    }

    /// Remove a shared appointment from the current user's view by unsubscribing from the share
    func removeSharedAppointment(id: UUID, appState: AppState) async {
        do {
            try await appState.familyCalendarRepository.removeSelfFromShare(
                eventType: .appointment, eventId: id
            )
            appointments.removeAll { $0.id == id }
        } catch {
            self.error = "Failed to remove shared appointment: \(error.localizedDescription)"
        }
    }
}

// MARK: - Appointment Detail View
struct AppointmentDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadEditAppointmentAction) private var iPadEditAppointmentAction

    @State var appointment: Appointment
    @State private var showEditAppointment = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showFullscreenPhoto = false
    @State private var sharedByName: String?
    @State private var isSharedByMe = false
    @State private var showRemoveSharedConfirmation = false

    /// Whether this appointment belongs to another account (shared via family calendar)
    private var isSharedFromOtherAccount: Bool {
        guard let currentAccountId = appState.currentAccount?.id else { return false }
        return appointment.accountId != currentAccountId
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header scrolls with content
                CustomizableHeaderView(
                    pageIdentifier: .appointmentDetail,
                    title: appointment.title,
                    showBackButton: true,
                    backAction: { dismiss() },
                    showEditButton: !isSharedFromOtherAccount,
                    editAction: isSharedFromOtherAccount ? nil : {
                        // Use full-screen overlay action if available
                        if let editAction = iPadEditAppointmentAction {
                            editAction(appointment)
                        } else {
                            showEditAppointment = true
                        }
                    },
                    editButtonPosition: .bottomRight
                )

                // Content
                VStack(spacing: AppDimensions.cardSpacing) {
                        // Shared event banner
                        if isSharedFromOtherAccount {
                            sharedEventBanner
                        }

                        // Details
                        VStack(spacing: AppDimensions.cardSpacing) {
                            // Type badge
                            HStack {
                                Image(systemName: appointment.type.icon)
                                    .font(.title3)
                                    .foregroundColor(appAccentColor)
                                Text(appointment.type.displayName)
                                    .font(.appBodyMedium)
                                    .foregroundColor(appAccentColor)
                                Spacer()

                                if isSharedByMe || isSharedFromOtherAccount {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 10))
                                        Text("Shared")
                                            .font(.appCaption)
                                    }
                                    .foregroundColor(appAccentColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(appAccentColor.opacity(0.25))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(appAccentColor.opacity(0.15))
                            .cornerRadius(AppDimensions.cardCornerRadius)

                            DetailItemCard(label: "Date", value: dateFormatter.string(from: appointment.date))

                            if let time = appointment.time {
                                DetailItemCard(label: "Time", value: timeFormatter.string(from: time))
                            }

                            if let location = appointment.location {
                                Button {
                                    openInMaps(location: location)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Location")
                                                .font(.appCaption)
                                                .foregroundColor(.textSecondary)

                                            Text(location)
                                                .font(.appCardTitle)
                                                .foregroundColor(.textPrimary)
                                        }

                                        Spacer()

                                        Image(systemName: "map")
                                            .foregroundColor(appAccentColor)
                                    }
                                    .padding(AppDimensions.cardPadding)
                                    .background(Color.cardBackground)
                                    .cornerRadius(AppDimensions.cardCornerRadius)
                                }
                            }

                            if let notes = appointment.notes {
                                DetailItemCard(label: "Notes", value: notes)
                            }

                            if let interval = appointment.repeatInterval,
                               let unitStr = appointment.repeatUnit,
                               let unit = RepeatUnit(rawValue: unitStr) {
                                DetailItemCard(
                                    label: "Repeats",
                                    value: interval == 1
                                        ? "Every \(unit.singularLabel)"
                                        : "Every \(interval) \(unit.pluralLabel)"
                                )
                            }

                            // Photo
                            if let urlString = appointment.imageUrl, let url = URL(string: urlString) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Photo")
                                        .font(.appCaption)
                                        .foregroundColor(.textSecondary)

                                    Button {
                                        showFullscreenPhoto = true
                                    } label: {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 200)
                                                    .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius))
                                            case .empty:
                                                ProgressView()
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 200)
                                            default:
                                                EmptyView()
                                            }
                                        }
                                    }
                                }
                                .padding(AppDimensions.cardPadding)
                                .background(Color.cardBackground)
                                .cornerRadius(AppDimensions.cardCornerRadius)
                                .fullScreenCover(isPresented: $showFullscreenPhoto) {
                                    RemoteFullscreenImageView(imageUrl: urlString, title: appointment.title)
                                }
                            }

                            // Delete button for own appointments
                            if !isSharedFromOtherAccount {
                                Button {
                                    showDeleteConfirmation = true
                                } label: {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Delete Appointment")
                                    }
                                    .font(.appBodyMedium)
                                    .foregroundColor(.medicalRed)
                                    .frame(maxWidth: .infinity)
                                    .padding(AppDimensions.cardPadding)
                                    .background(Color.medicalRed.opacity(0.1))
                                    .cornerRadius(AppDimensions.cardCornerRadius)
                                }
                                .disabled(isDeleting)
                            }

                            // Remove button for shared appointments
                            if isSharedFromOtherAccount {
                                Button {
                                    showRemoveSharedConfirmation = true
                                } label: {
                                    HStack {
                                        Image(systemName: "eye.slash")
                                        Text("Remove from My Appointments")
                                    }
                                    .font(.appBodyMedium)
                                    .foregroundColor(.medicalRed)
                                    .frame(maxWidth: .infinity)
                                    .padding(AppDimensions.cardPadding)
                                    .background(Color.medicalRed.opacity(0.1))
                                    .cornerRadius(AppDimensions.cardCornerRadius)
                                }
                                .disabled(isDeleting)
                            }
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)

                        // Bottom spacing for nav bar
                        Spacer()
                            .frame(height: 120)
                }
                .padding(.top, AppDimensions.cardSpacing)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackground)
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showEditAppointment) {
            EditAppointmentView(
                appointment: appointment,
                onDismiss: { showEditAppointment = false }
            ) { updatedAppointment in
                appointment = updatedAppointment
            }
        }
        .task {
            if isSharedFromOtherAccount {
                await loadSharedByName()
            } else {
                if let _ = try? await appState.familyCalendarRepository.getShareForEvent(
                    eventType: .appointment, eventId: appointment.id
                ) {
                    isSharedByMe = true
                }
            }
        }
        .alert("Delete Appointment", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteAppointment()
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(appointment.title)\"? This action cannot be undone.")
        }
        .alert("Remove Shared Appointment", isPresented: $showRemoveSharedConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    await removeSharedAppointment()
                }
            }
        } message: {
            Text("Remove \"\(appointment.title)\" from your appointments? The original owner will still have this appointment.")
        }
    }

    // MARK: - Shared Event Banner
    private var sharedEventBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 14))
                .foregroundColor(appAccentColor)

            Text("Shared by \(sharedByName ?? "a family member")")
                .font(.appBodyMedium)
                .foregroundColor(.textPrimary)

            Spacer()

            Text("View Only")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.cardBackgroundSoft)
                .cornerRadius(12)
        }
        .padding(AppDimensions.cardPadding)
        .background(appAccentColor.opacity(0.1))
        .cornerRadius(AppDimensions.cardCornerRadius)
        .padding(.horizontal, AppDimensions.screenPadding)
    }

    private func loadSharedByName() async {
        guard let accountId = appState.currentAccount?.id else { return }
        do {
            let share = try await appState.familyCalendarRepository.getShareForEvent(
                eventType: .appointment, eventId: appointment.id
            )
            guard let sharerUserId = share?.sharedByUserId else { return }

            let profiles = try await appState.profileRepository.getProfiles(accountId: accountId)
            if let sharerProfile = profiles.first(where: { $0.sourceUserId == sharerUserId }) {
                sharedByName = sharerProfile.displayName
            }
        } catch {
            #if DEBUG
            print("Failed to load shared-by name: \(error)")
            #endif
        }
    }

    private func deleteAppointment() async {
        isDeleting = true
        do {
            // Delete photo from Supabase Storage if it exists
            if appointment.imageUrl != nil {
                let storagePath = "appointments/\(appointment.id.uuidString)/photo.jpg"
                try? await ImageUploadService.shared.deleteImage(bucket: SupabaseConfig.appointmentPhotosBucket, path: storagePath)
            }
            try await appState.appointmentRepository.deleteAppointment(id: appointment.id)
            await NotificationService.shared.cancelAppointmentReminder(appointmentId: appointment.id)
            dismiss()
        } catch {
            // Error handling - could show an alert here
            isDeleting = false
        }
    }

    private func removeSharedAppointment() async {
        isDeleting = true
        do {
            try await appState.familyCalendarRepository.removeSelfFromShare(
                eventType: .appointment, eventId: appointment.id
            )
            // Post notification so the appointment list refreshes
            NotificationCenter.default.post(
                name: .appointmentsDidChange,
                object: nil,
                userInfo: [
                    NotificationUserInfoKey.appointmentId: appointment.id,
                    NotificationUserInfoKey.action: AppointmentChangeAction.deleted
                ]
            )
            dismiss()
        } catch {
            isDeleting = false
        }
    }

    private func openInMaps(location: String) {
        let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Add Appointment View
struct AddAppointmentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    var onDismiss: (() -> Void)? = nil
    let onSave: (Appointment) -> Void
    
    @State private var title = ""
    @State private var date = Date()
    @State private var hasTime = false
    @State private var time = Date()
    @State private var location = ""
    @State private var notes = ""
    @State private var reminderAtEvent = false
    @State private var reminderNumber = 1
    @State private var reminderUnit: ReminderUnit = .hours
    @State private var repeatEnabled = false
    @State private var repeatNumber = 1
    @State private var selectedRepeatUnit: RepeatUnit = .week

    @State private var selectedType: AppointmentType = .general
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Bool

    // Family sharing state
    @State private var shareToFamily = false
    @State private var selectedMemberIds: Set<UUID> = []
    @State private var showFamilySharingSheet = false

    // Premium check for date restrictions
    private var hasPremiumAccess: Bool {
        PremiumLimitsManager.shared.hasPremiumAccess(appState: appState)
    }

    // Family Plus check for family sharing
    private var hasFamilyAccess: Bool {
        appState.hasFamilyAccess
    }

    // Maximum allowed date for appointments (unlimited for premium, 30 days for free)
    private var maximumDate: Date {
        if hasPremiumAccess {
            // Far future date for premium users
            return Calendar.current.date(byAdding: .year, value: 10, to: Date()) ?? Date()
        } else {
            // 30 days from today for free users
            return Calendar.current.date(byAdding: .day, value: PremiumLimitsManager.FreeTierLimits.appointmentDaysLimit, to: Date().startOfDay) ?? Date()
        }
    }

    private var reminderMinutes: Int {
        if reminderAtEvent { return 0 }
        return reminderNumber * reminderUnit.minuteMultiplier
    }

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with icons
            HStack {
                Button {
                    dismissView()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.5))
                        )
                }

                Spacer()

                Text("Add Appointment")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    Task { await saveAppointment() }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(title.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                        )
                }
                .disabled(title.isBlank || isLoading)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)

            ScrollView {
                VStack(spacing: 20) {

                    // Photo picker
                    HStack {
                        Spacer()
                        ImageSourcePicker(
                            selectedImage: $selectedImage,
                            onImageSelected: { _ in }
                        )
                        Spacer()
                    }

                    AppTextField(placeholder: "Title *", text: $title)
                        .focused($focusedField)

                    // Family Calendar Sharing
                    familySharingSection

                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                    }

                    // Type selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        AppointmentTypePicker(selectedType: $selectedType)
                    }

                    // Date picker
                    VStack(alignment: .leading, spacing: 4) {
                        VStack(spacing: 0) {
                            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                                .font(.appBodyMedium)
                                .foregroundColor(.accentYellow)
                                .padding(.top, 12)

                            DatePicker(
                                "",
                                selection: $date,
                                in: Date()...maximumDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .tint(appAccentColor)
                            .frame(maxWidth: .infinity)
                            .clipped()
                        }
                        .padding(.horizontal)
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)

                        // Show limit info for free users
                        if !hasPremiumAccess {
                            Text("Free plan: limited to next 30 days")
                                .font(.appCaption)
                                .foregroundColor(.textMuted)
                                .padding(.horizontal, 4)
                        }
                    }

                    // Time toggle and picker
                    HStack {
                        Toggle("Include time", isOn: $hasTime)
                            .tint(appAccentColor)

                        if hasTime {
                            Spacer()
                            DatePicker(
                                "",
                                selection: $time,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.compact)
                            .tint(appAccentColor)
                            .labelsHidden()
                        }
                    }
                    .padding()
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.cardCornerRadius)

                    AppTextField(placeholder: "Location (optional)", text: $location)
                    AppTextField(placeholder: "Notes (optional)", text: $notes)

                    // Reminder picker
                    VStack(spacing: 12) {
                        Toggle(isOn: $reminderAtEvent) {
                            Text("Remind at time of event")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                        }
                        .tint(appAccentColor)

                        if !reminderAtEvent {
                            HStack(spacing: 12) {
                                Text("Remind me")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Picker("Number", selection: $reminderNumber) {
                                    ForEach(1...60, id: \.self) { num in
                                        Text("\(num)").tag(num)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(appAccentColor)

                                Picker("Unit", selection: $reminderUnit) {
                                    ForEach(ReminderUnit.allCases) { unit in
                                        Text(reminderNumber == 1 ? unit.singularLabel : unit.pluralLabel).tag(unit)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(appAccentColor)

                                Text("before")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.cardCornerRadius)

                    // Repeat appointment
                    VStack(spacing: 12) {
                        Toggle(isOn: $repeatEnabled) {
                            Text("Repeat appointment")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                        }
                        .tint(appAccentColor)

                        if repeatEnabled {
                            HStack(spacing: 12) {
                                Text("Every")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Picker("Number", selection: $repeatNumber) {
                                    ForEach(1...60, id: \.self) { num in
                                        Text("\(num)").tag(num)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(appAccentColor)

                                Picker("Unit", selection: $selectedRepeatUnit) {
                                    ForEach(RepeatUnit.allCases) { unit in
                                        Text(repeatNumber == 1 ? unit.singularLabel : unit.pluralLabel).tag(unit)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(appAccentColor)
                                .fixedSize(horizontal: true, vertical: false)

                            }
                        }
                    }
                    .padding()
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.cardCornerRadius)


                }
                .padding(AppDimensions.screenPadding)
            }
        }
        .background(Color.appBackgroundLight)
        .onChange(of: selectedType) { _, _ in
            focusedField = false
        }
        .onChange(of: date) { _, _ in
            focusedField = false
        }
        .onChange(of: time) { _, _ in
            focusedField = false
        }
        .onChange(of: hasTime) { _, _ in
            focusedField = false
        }
        .sheet(isPresented: $showFamilySharingSheet) {
            FamilySharingSheet(
                isEnabled: $shareToFamily,
                selectedMemberIds: $selectedMemberIds,
                onDismiss: { showFamilySharingSheet = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
    }

    // MARK: - Family Sharing Section

    @ViewBuilder
    private var familySharingSection: some View {
        if hasFamilyAccess {
            // Family Plus user - show full controls
            Button {
                showFamilySharingSheet = true
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(shareToFamily ? appAccentColor : .textSecondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Family Calendar")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        Text(shareToFamily ? "\(selectedMemberIds.count) member(s) selected" : "Not shared")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.cardCornerRadius)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            // Free user - show upgrade prompt
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Family Calendar")
                        .font(.appBody)
                        .foregroundColor(.textPrimary)

                    Text("Upgrade to Family Plus to share events")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentYellow)
            }
            .padding()
            .background(Color.cardBackgroundSoft)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .opacity(0.7)
        }
    }

    private func saveAppointment() async {
        guard let account = appState.currentAccount else {
            errorMessage = "No account found"
            return
        }

        isLoading = true
        errorMessage = nil

        // Get primary profile
        let primaryProfile: Profile?
        do {
            primaryProfile = try await appState.profileRepository.getPrimaryProfile(accountId: account.id)
        } catch {
            errorMessage = "Failed to get profile: \(error.localizedDescription)"
            isLoading = false
            return
        }

        guard let profile = primaryProfile else {
            errorMessage = "No primary profile found. Please create a profile first."
            isLoading = false
            return
        }

        // Validate date against premium limits
        if !PremiumLimitsManager.shared.canCreateAppointment(appState: appState, forDate: date) {
            errorMessage = "Free plan appointments are limited to the next 30 days. Upgrade to Premium for unlimited scheduling."
            isLoading = false
            return
        }

        let insert = AppointmentInsert(
            accountId: account.id,
            profileId: profile.id,
            title: title,
            date: date,
            withProfileId: nil,
            type: selectedType,
            time: hasTime ? time : nil,
            location: location.isBlank ? nil : location,
            notes: notes.isBlank ? nil : notes,
            reminderOffsetMinutes: reminderMinutes,
            repeatInterval: repeatEnabled ? repeatNumber : nil,
            repeatUnit: repeatEnabled ? selectedRepeatUnit.rawValue : nil
        )

        do {
            // When sharing is enabled, create on Supabase first so the event_id exists for the share
            var appointment: Appointment
            if shareToFamily && !selectedMemberIds.isEmpty {
                appointment = try await appState.appointmentRepository.createAppointmentRemoteFirst(insert)
            } else {
                appointment = try await appState.appointmentRepository.createAppointment(insert)
            }

            // Upload photo to Supabase Storage after creation (so we have the real ID)
            if let image = selectedImage {
                let photoURL = try await ImageUploadService.shared.uploadAppointmentPhoto(image: image, appointmentId: appointment.id)
                appointment.imageUrl = photoURL
                appointment = try await appState.appointmentRepository.updateAppointment(appointment)
            }

            // Schedule notification reminder
            await NotificationService.shared.scheduleAppointmentReminder(
                appointmentId: appointment.id,
                title: appointment.title,
                appointmentDate: appointment.date,
                appointmentTime: hasTime ? time : nil,
                location: appointment.location,
                reminderMinutesBefore: reminderMinutes
            )

            // Create family calendar share if enabled
            if shareToFamily && !selectedMemberIds.isEmpty {
                do {
                    _ = try await appState.familyCalendarRepository.createShare(
                        accountId: account.id,
                        eventType: .appointment,
                        eventId: appointment.id,
                        memberUserIds: Array(selectedMemberIds)
                    )
                } catch {
                    #if DEBUG
                    print("Failed to create family share: \(error)")
                    #endif
                }
            }

            onSave(appointment)
            dismissView()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Edit Appointment View
struct EditAppointmentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let appointment: Appointment
    var onDismiss: (() -> Void)? = nil
    let onSave: (Appointment) -> Void

    @State private var title: String
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var location: String
    @State private var notes: String
    @State private var reminderAtEvent: Bool
    @State private var reminderNumber: Int
    @State private var reminderUnit: ReminderUnit
    @State private var repeatEnabled: Bool
    @State private var repeatNumber: Int
    @State private var selectedRepeatUnit: RepeatUnit
    @State private var selectedType: AppointmentType
    @State private var selectedImage: UIImage?
    @State private var removePhoto = false

    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Bool

    // Family sharing state
    @State private var shareToFamily = false
    @State private var selectedMemberIds: Set<UUID> = []
    @State private var showFamilySharingSheet = false

    // Premium check for date restrictions
    private var hasPremiumAccess: Bool {
        PremiumLimitsManager.shared.hasPremiumAccess(appState: appState)
    }

    // Maximum allowed date for appointments (unlimited for premium, 30 days for free)
    private var maximumDate: Date {
        if hasPremiumAccess {
            return Calendar.current.date(byAdding: .year, value: 10, to: Date()) ?? Date()
        } else {
            return Calendar.current.date(byAdding: .day, value: PremiumLimitsManager.FreeTierLimits.appointmentDaysLimit, to: Date().startOfDay) ?? Date()
        }
    }

    // Family Plus check for family sharing
    private var hasFamilyAccess: Bool {
        appState.hasFamilyAccess
    }

    private var reminderMinutes: Int {
        if reminderAtEvent { return 0 }
        return reminderNumber * reminderUnit.minuteMultiplier
    }

    init(appointment: Appointment, onDismiss: (() -> Void)? = nil, onSave: @escaping (Appointment) -> Void) {
        self.appointment = appointment
        self.onDismiss = onDismiss
        self.onSave = onSave
        self._title = State(initialValue: appointment.title)
        self._date = State(initialValue: appointment.date)
        self._hasTime = State(initialValue: appointment.time != nil)
        self._time = State(initialValue: appointment.time ?? Date())
        self._location = State(initialValue: appointment.location ?? "")
        self._notes = State(initialValue: appointment.notes ?? "")
        self._selectedType = State(initialValue: appointment.type)

        let minutes = appointment.reminderOffsetMinutes ?? 60
        let parsed = ReminderUnit.fromMinutes(minutes)
        self._reminderAtEvent = State(initialValue: minutes == 0)
        self._reminderNumber = State(initialValue: parsed.number)
        self._reminderUnit = State(initialValue: parsed.unit)

        let hasRepeat = appointment.repeatInterval != nil && appointment.repeatUnit != nil
        self._repeatEnabled = State(initialValue: hasRepeat)
        self._repeatNumber = State(initialValue: appointment.repeatInterval ?? 1)
        self._selectedRepeatUnit = State(initialValue: RepeatUnit(rawValue: appointment.repeatUnit ?? "week") ?? .week)
    }

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with icons
            HStack {
                Button {
                    dismissView()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.5))
                        )
                }

                Spacer()

                Text("Edit Appointment")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    Task { await updateAppointment() }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(title.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                        )
                }
                .disabled(title.isBlank || isLoading)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)

            ScrollView {
                VStack(spacing: 20) {


                    AppTextField(placeholder: "Title *", text: $title)
                        .focused($focusedField)
                // Family Calendar Sharing
                editFamilySharingSection

                if let error = errorMessage {
                    Text(error)
                        .font(.appCaption)
                        .foregroundColor(.medicalRed)
                }
                // Type selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    AppointmentTypePicker(selectedType: $selectedType)
                }

                // Date picker
                VStack(alignment: .leading, spacing: 4) {
                    VStack(spacing: 0) {
                        Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                            .font(.appBodyMedium)
                            .foregroundColor(.accentYellow)
                            .padding(.top, 12)

                        DatePicker(
                            "",
                            selection: $date,
                            in: Date()...maximumDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .tint(appAccentColor)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .padding(.horizontal)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.cardCornerRadius)

                    // Show limit info for free users
                    if !hasPremiumAccess {
                        Text("Free plan: limited to next 30 days")
                            .font(.appCaption)
                            .foregroundColor(.textMuted)
                            .padding(.horizontal, 4)
                    }
                }

                // Time toggle and picker
                HStack {
                    Toggle("Include Time", isOn: $hasTime)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                        .tint(appAccentColor)

                    if hasTime {
                        Spacer()
                        DatePicker(
                            "",
                            selection: $time,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(appAccentColor)
                    }
                }
                .padding()
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.cardCornerRadius)

                AppTextField(placeholder: "Location", text: $location)
                AppTextField(placeholder: "Notes", text: $notes)

                // Reminder picker
                VStack(spacing: 12) {
                    Toggle(isOn: $reminderAtEvent) {
                        Text("At time of event")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                    }
                    .tint(appAccentColor)
                    .padding(.horizontal)

                    if !reminderAtEvent {
                        HStack(spacing: 0) {
                            Text("Remind")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .fixedSize()

                            Picker("Number", selection: $reminderNumber) {
                                ForEach(1...60, id: \.self) { num in
                                    Text("\(num)").tag(num)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(appAccentColor)

                            Picker("Unit", selection: $reminderUnit) {
                                ForEach(ReminderUnit.allCases) { unit in
                                    Text(reminderNumber == 1 ? unit.singularLabel : unit.pluralLabel).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(appAccentColor)
                            .fixedSize()

                            Text("before")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .fixedSize()

                            Spacer(minLength: 0)
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 4)
                    }
                }
                .padding(.vertical)
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.cardCornerRadius)

                // Repeat appointment
                VStack(spacing: 12) {
                    Toggle(isOn: $repeatEnabled) {
                        Text("Repeat appointment")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                    }
                    .tint(appAccentColor)

                    if repeatEnabled {
                        HStack(spacing: 12) {
                            Text("Every")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)

                            Picker("Number", selection: $repeatNumber) {
                                ForEach(1...60, id: \.self) { num in
                                    Text("\(num)").tag(num)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(appAccentColor)

                            Picker("Unit", selection: $selectedRepeatUnit) {
                                ForEach(RepeatUnit.allCases) { unit in
                                    Text(repeatNumber == 1 ? unit.singularLabel : unit.pluralLabel).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(appAccentColor)
                        }
                    }
                }
                .padding()
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.cardCornerRadius)



                // Photo picker
                HStack {
                    Spacer()
                    ImageSourcePicker(
                        selectedImage: $selectedImage,
                        currentImageUrl: appointment.imageUrl,
                        onImageSelected: { _ in removePhoto = false },
                        onRemove: { removePhoto = true }
                    )
                    Spacer()
                }

                }
                .padding(AppDimensions.screenPadding)
            }
        }
        .background(Color.appBackgroundLight)
        .onChange(of: selectedType) { _, _ in
            focusedField = false
        }
        .onChange(of: date) { _, _ in
            focusedField = false
        }
        .onChange(of: time) { _, _ in
            focusedField = false
        }
        .onChange(of: hasTime) { _, _ in
            focusedField = false
        }
        .sheet(isPresented: $showFamilySharingSheet) {
            FamilySharingSheet(
                isEnabled: $shareToFamily,
                selectedMemberIds: $selectedMemberIds,
                onDismiss: { showFamilySharingSheet = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBackgroundLight)
        }
        .task {
            await loadExistingFamilyShare()
        }
    }

    // MARK: - Family Sharing Section

    @ViewBuilder
    private var editFamilySharingSection: some View {
        if hasFamilyAccess {
            // Family Plus user - show full controls
            Button {
                showFamilySharingSheet = true
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(shareToFamily ? appAccentColor : .textSecondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Family Calendar")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        Text(shareToFamily ? "\(selectedMemberIds.count) member(s) selected" : "Not shared")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.cardCornerRadius)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            // Free user - show upgrade prompt
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Family Calendar")
                        .font(.appBody)
                        .foregroundColor(.textPrimary)

                    Text("Upgrade to Family Plus to share events")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentYellow)
            }
            .padding()
            .background(Color.cardBackgroundSoft)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .opacity(0.7)
        }
    }

    private func loadExistingFamilyShare() async {
        do {
            if let share = try await appState.familyCalendarRepository.getShareForEvent(
                eventType: .appointment,
                eventId: appointment.id
            ) {
                let members = try await appState.familyCalendarRepository.getMembersForShare(shareId: share.id)
                shareToFamily = true
                selectedMemberIds = Set(members.map { $0.memberUserId })
            }
        } catch {
            #if DEBUG
            print("Failed to load existing family share: \(error)")
            #endif
        }
    }

    private func updateAppointment() async {
        isLoading = true
        errorMessage = nil

        // Validate date against premium limits
        if !PremiumLimitsManager.shared.canCreateAppointment(appState: appState, forDate: date) {
            errorMessage = "Free plan appointments are limited to the next 30 days. Upgrade to Premium for unlimited scheduling."
            isLoading = false
            return
        }

        var updatedAppointment = appointment
        updatedAppointment.title = title
        updatedAppointment.date = date
        updatedAppointment.time = hasTime ? time : nil
        updatedAppointment.location = location.isBlank ? nil : location
        updatedAppointment.notes = notes.isBlank ? nil : notes
        updatedAppointment.reminderOffsetMinutes = reminderMinutes
        updatedAppointment.repeatInterval = repeatEnabled ? repeatNumber : nil
        updatedAppointment.repeatUnit = repeatEnabled ? selectedRepeatUnit.rawValue : nil
        updatedAppointment.type = selectedType

        // Handle photo changes - upload to Supabase Storage
        if let image = selectedImage {
            do {
                let photoURL = try await ImageUploadService.shared.uploadAppointmentPhoto(image: image, appointmentId: appointment.id)
                updatedAppointment.imageUrl = photoURL
            } catch {
                #if DEBUG
                print("Failed to upload appointment photo: \(error)")
                #endif
            }
        } else if removePhoto {
            // User explicitly removed the photo
            if appointment.imageUrl != nil {
                let storagePath = "appointments/\(appointment.id.uuidString)/photo.jpg"
                try? await ImageUploadService.shared.deleteImage(bucket: SupabaseConfig.appointmentPhotosBucket, path: storagePath)
            }
            updatedAppointment.imageUrl = nil
        }

        do {
            let saved = try await appState.appointmentRepository.updateAppointment(updatedAppointment)

            // Update notification reminder
            await NotificationService.shared.cancelAppointmentReminder(appointmentId: appointment.id)
            await NotificationService.shared.scheduleAppointmentReminder(
                appointmentId: saved.id,
                title: saved.title,
                appointmentDate: saved.date,
                appointmentTime: hasTime ? time : nil,
                location: saved.location,
                reminderMinutesBefore: reminderMinutes
            )

            // Update family calendar sharing
            if let account = appState.currentAccount {
                await updateFamilyCalendarSharing(accountId: account.id, appointmentId: saved.id)
            }

            onSave(saved)
            dismissView()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func updateFamilyCalendarSharing(accountId: UUID, appointmentId: UUID) async {
        do {
            // First, delete existing share for this appointment
            try await appState.familyCalendarRepository.deleteShareForEvent(
                eventType: .appointment,
                eventId: appointmentId
            )

            // Then create new share if sharing is enabled
            if shareToFamily && !selectedMemberIds.isEmpty {
                _ = try await appState.familyCalendarRepository.createShare(
                    accountId: accountId,
                    eventType: .appointment,
                    eventId: appointmentId,
                    memberUserIds: Array(selectedMemberIds)
                )
            }
        } catch {
            #if DEBUG
            print("Failed to update family calendar sharing: \(error)")
            #endif
        }
    }
}

// MARK: - Appointment Calendar View
struct AppointmentCalendarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AppointmentCalendarViewModel()
    @State private var selectedDate: Date?
    @State private var showDayDetail = false
    @State private var selectedAppointment: Appointment?
    @State private var navigateToDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header scrolls with content
                CustomizableHeaderView(
                    pageIdentifier: .appointments,
                    title: "Appointment Calendar",
                    showBackButton: true,
                    backAction: { dismiss() }
                )

                // Content
                VStack(spacing: AppDimensions.cardSpacing) {
                        // Month Navigation
                        AppointmentMonthHeader(
                            currentMonth: viewModel.currentMonth,
                            onPreviousMonth: { viewModel.goToPreviousMonth() },
                            onNextMonth: { viewModel.goToNextMonth() },
                            onToday: { viewModel.goToToday() }
                        )
                        .padding(.horizontal, AppDimensions.screenPadding)

                        // Calendar Grid
                        AppointmentCalendarGrid(
                            currentMonth: viewModel.currentMonth,
                            appointmentDays: viewModel.appointmentDays,
                            selectedDate: $selectedDate,
                            onDateSelected: { date in
                                selectedDate = date
                                showDayDetail = true
                            }
                        )
                        .padding(.horizontal, AppDimensions.screenPadding)

                        // Upcoming appointments for this month
                        if !viewModel.monthAppointments.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("THIS MONTH")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                                    .padding(.horizontal, AppDimensions.screenPadding)

                                ForEach(viewModel.monthAppointments) { appointment in
                                    AppointmentCalendarCard(appointment: appointment)
                                        .padding(.horizontal, AppDimensions.screenPadding)
                                }
                            }
                            .padding(.top, 8)
                        }

                        // Bottom spacing for nav bar
                        Spacer()
                            .frame(height: 120)
                }
                .padding(.top, AppDimensions.cardSpacing)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackground)
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: Group {
                    if let appointment = selectedAppointment {
                        AppointmentDetailView(appointment: appointment)
                    }
                },
                isActive: $navigateToDetail
            ) {
                EmptyView()
            }
        )
        .task {
            await viewModel.loadData(appState: appState)
        }
        .onChange(of: viewModel.currentMonth) { _, _ in
            Task {
                await viewModel.loadMonthData(appState: appState)
            }
        }
        .sheet(isPresented: $showDayDetail) {
            if let date = selectedDate {
                AppointmentDayDetailSheet(
                    date: date,
                    appointments: viewModel.getAppointmentsForDate(date),
                    isAppointmentCompleted: { viewModel.isAppointmentCompleted(appointmentId: $0) },
                    onToggleCompleted: { viewModel.toggleAppointmentCompleted(appointmentId: $0, appState: appState) },
                    onSelectAppointment: { appointment in
                        selectedAppointment = appointment
                        navigateToDetail = true
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.appBackgroundLight)
            }
        }
    }
}

// MARK: - Appointment Month Header
struct AppointmentMonthHeader: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let currentMonth: Date
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onToday: () -> Void

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        HStack {
            Button(action: onPreviousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(appAccentColor)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(monthFormatter.string(from: currentMonth))
                .font(.appTitle)
                .foregroundColor(.textPrimary)

            Spacer()

            if !isCurrentMonth {
                Button(action: onToday) {
                    Text("Today")
                        .font(.appCaption)
                        .foregroundColor(appAccentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(appAccentColor.opacity(0.2))
                        .cornerRadius(AppDimensions.pillCornerRadius)
                }
            }

            Button(action: onNextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(appAccentColor)
                    .frame(width: 44, height: 44)
            }
        }
    }
}

// MARK: - Appointment Calendar Grid
struct AppointmentCalendarGrid: View {
    let currentMonth: Date
    let appointmentDays: Set<Date>
    @Binding var selectedDate: Date?
    let onDateSelected: (Date) -> Void

    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthDays: [Date?] {
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1

        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let numberOfDays = range.count

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        // Pad to complete the last week
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    var body: some View {
        VStack(spacing: 8) {
            // Day of week headers
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.appCaption)
                        .fontWeight(.medium)
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        AppointmentDayCell(
                            date: date,
                            hasAppointments: appointmentDays.contains(calendar.startOfDay(for: date)),
                            isToday: calendar.isDateInToday(date),
                            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                            onTap: { onDateSelected(date) }
                        )
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Appointment Day Cell
struct AppointmentDayCell: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let date: Date
    let hasAppointments: Bool
    let isToday: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(dayNumber)
                    .font(.appBody)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(isToday ? appAccentColor : .textPrimary)

                // Appointment indicator dot
                Circle()
                    .fill(hasAppointments ? appAccentColor : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(isSelected ? appAccentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? appAccentColor : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Appointment Calendar Card
struct AppointmentCalendarCard: View {
    let appointment: Appointment
    @Environment(\.appAccentColor) private var appAccentColor

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        NavigationLink(destination: AppointmentDetailView(appointment: appointment)) {
            HStack(spacing: 12) {
                // Date badge
                VStack(spacing: 2) {
                    Text(dayNumber)
                        .font(.appTitle)
                        .foregroundColor(appAccentColor)

                    Text(monthAbbrev)
                        .font(.appCaptionSmall)
                        .foregroundColor(.textSecondary)
                }
                .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appointment.title)
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    HStack(spacing: 8) {
                        if let time = appointment.time {
                            Text(timeFormatter.string(from: time))
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }

                        if let location = appointment.location {
                            HStack(spacing: 2) {
                                Image(systemName: "mappin")
                                    .font(.caption2)
                                Text(location)
                                    .font(.appCaption)
                            }
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: appointment.date)
    }

    private var monthAbbrev: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: appointment.date).uppercased()
    }
}

// MARK: - Appointment Day Detail Sheet
struct AppointmentDayDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    let date: Date
    let appointments: [Appointment]
    let isAppointmentCompleted: (UUID) -> Bool
    let onToggleCompleted: (UUID) -> Void
    let onSelectAppointment: (Appointment) -> Void

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if appointments.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundColor(.textSecondary)

                        Text("No appointments")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: AppDimensions.cardSpacing) {
                            // Summary
                            HStack {
                                Text("\(appointments.count) appointment\(appointments.count == 1 ? "" : "s")")
                                    .font(.appBodyMedium)
                                    .foregroundColor(.textPrimary)

                                Spacer()
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(Color.cardBackground)
                            .cornerRadius(AppDimensions.cardCornerRadius)
                            .padding(.horizontal, AppDimensions.screenPadding)

                            // Individual appointments
                            ForEach(appointments) { appointment in
                                AppointmentDayCard(
                                    appointment: appointment,
                                    timeFormatter: timeFormatter,
                                    isCompleted: isAppointmentCompleted(appointment.id),
                                    onToggleCompleted: { onToggleCompleted(appointment.id) },
                                    onTap: {
                                        dismiss()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            onSelectAppointment(appointment)
                                        }
                                    }
                                )
                                .padding(.horizontal, AppDimensions.screenPadding)
                            }
                        }
                        .padding(.vertical, AppDimensions.screenPadding)
                    }
                }
            }
            .navigationTitle(dateFormatter.string(from: date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(appAccentColor)
                }
            }
        }
    }
}

// MARK: - Appointment Day Card
struct AppointmentDayCard: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let appointment: Appointment
    let timeFormatter: DateFormatter
    let isCompleted: Bool
    let onToggleCompleted: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack {
            // Card content - tappable to view details
            Button {
                onTap()
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundColor(appAccentColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(appointment.title)
                            .font(.appBodyMedium)
                            .foregroundColor(.textPrimary)

                        if let time = appointment.time {
                            Text(timeFormatter.string(from: time))
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }

                        if let location = appointment.location {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.caption2)
                                Text(location)
                                    .font(.appCaption)
                            }
                            .foregroundColor(.textSecondary)
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Toggleable check icon
            Button {
                onToggleCompleted()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 24))
                    .foregroundColor(isCompleted ? appAccentColor : .textSecondary.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Appointment Calendar View Model
@MainActor
class AppointmentCalendarViewModel: ObservableObject {
    @Published var currentMonth: Date = Date()
    @Published var monthAppointments: [Appointment] = []
    @Published var appointmentDays: Set<Date> = []
    @Published var isLoading = false
    @Published var error: String?

    private let calendar = Calendar.current

    func toggleAppointmentCompleted(appointmentId: UUID, appState: AppState) {
        guard let index = monthAppointments.firstIndex(where: { $0.id == appointmentId }) else { return }
        let newStatus = !monthAppointments[index].isCompleted

        // Update locally first for immediate UI feedback
        monthAppointments[index].isCompleted = newStatus
        let updatedAppointment = monthAppointments[index]

        // Persist to database and update notification
        Task {
            do {
                let saved = try await appState.appointmentRepository.toggleAppointmentCompletion(id: appointmentId, isCompleted: newStatus)

                // Cancel or reschedule notification based on completion status
                if newStatus {
                    // Completed - cancel the notification
                    await NotificationService.shared.cancelAppointmentReminder(appointmentId: appointmentId)
                } else {
                    // Uncompleted - reschedule the notification if in the future
                    if updatedAppointment.dateTime > Date() {
                        await NotificationService.shared.scheduleAppointmentReminder(
                            appointmentId: appointmentId,
                            title: updatedAppointment.title,
                            appointmentDate: updatedAppointment.date,
                            appointmentTime: updatedAppointment.time,
                            location: updatedAppointment.location,
                            reminderMinutesBefore: updatedAppointment.reminderOffsetMinutes ?? 60
                        )
                    }
                }

                // Post notification with appointment data so other views can update locally
                NotificationCenter.default.post(
                    name: .appointmentsDidChange,
                    object: nil,
                    userInfo: [
                        NotificationUserInfoKey.appointmentId: appointmentId,
                        NotificationUserInfoKey.action: AppointmentChangeAction.completionToggled,
                        NotificationUserInfoKey.appointment: saved
                    ]
                )
            } catch {
                // Revert on error
                if let idx = monthAppointments.firstIndex(where: { $0.id == appointmentId }) {
                    monthAppointments[idx].isCompleted = !newStatus
                }
                self.error = "Failed to update: \(error.localizedDescription)"
            }
        }
    }

    func isAppointmentCompleted(appointmentId: UUID) -> Bool {
        monthAppointments.first(where: { $0.id == appointmentId })?.isCompleted ?? false
    }

    func loadData(appState: AppState) async {
        isLoading = true
        await loadMonthData(appState: appState)
        isLoading = false
    }

    func loadMonthData(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        do {
            // Load all appointments for the month
            let appointments = try await appState.appointmentRepository.getAppointmentsInRange(
                accountId: account.id,
                startDate: startOfMonth,
                endDate: endOfMonth
            )

            // Sort in descending order (most recent first)
            monthAppointments = appointments.sorted { a, b in
                if a.date != b.date {
                    return a.date > b.date
                }
                // If same date, sort by time (later time first)
                if let timeA = a.time, let timeB = b.time {
                    return timeA > timeB
                }
                return a.title < b.title
            }

            // Build set of days that have appointments
            var days: Set<Date> = []
            for appointment in monthAppointments {
                let day = calendar.startOfDay(for: appointment.date)
                days.insert(day)
            }
            appointmentDays = days

        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }
    }

    func getAppointmentsForDate(_ date: Date) -> [Appointment] {
        let dayStart = calendar.startOfDay(for: date)

        return monthAppointments.filter { appointment in
            calendar.isDate(appointment.date, inSameDayAs: dayStart)
        }.sorted { a, b in
            // Sort by time if available
            if let timeA = a.time, let timeB = b.time {
                return timeA < timeB
            }
            return a.title < b.title
        }
    }

    func goToPreviousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    func goToNextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    func goToToday() {
        currentMonth = Date()
    }
}


// MARK: - Appointment Type Filter
struct AppointmentTypeFilter: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var selectedType: AppointmentType?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" filter button
                AppointmentTypeFilterButton(
                    title: "All",
                    icon: "calendar",
                    color: appAccentColor,
                    isSelected: selectedType == nil,
                    onTap: { selectedType = nil }
                )

                // Type filter buttons
                ForEach(AppointmentType.allCases, id: \.self) { type in
                    AppointmentTypeFilterButton(
                        title: type.displayName,
                        icon: type.icon,
                        color: appAccentColor,
                        isSelected: selectedType == type,
                        onTap: { selectedType = type }
                    )
                }
            }
        }
    }
}

// MARK: - Appointment Type Filter Button
struct AppointmentTypeFilterButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.appCaption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.3) : Color.cardBackgroundSoft)
            .foregroundColor(isSelected ? color : .textSecondary)
            .cornerRadius(AppDimensions.pillCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.pillCornerRadius)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Appointment Type Picker
struct AppointmentTypePicker: View {
    @Binding var selectedType: AppointmentType

    private let columns = [
        GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(AppointmentType.allCases, id: \.self) { type in
                AppointmentTypeBadge(
                    type: type,
                    isSelected: selectedType == type,
                    onTap: { selectedType = type }
                )
            }
        }
    }
}

// MARK: - Appointment Type Badge
struct AppointmentTypeBadge: View {
    let type: AppointmentType
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.caption)
                Text(type.displayName)
                    .font(.appCaption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? appAccentColor.opacity(0.3) : Color.cardBackgroundSoft)
            .foregroundColor(isSelected ? appAccentColor : .textSecondary)
            .cornerRadius(AppDimensions.pillCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.pillCornerRadius)
                    .stroke(isSelected ? appAccentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AppointmentListView()
            .environmentObject(AppState.forPreview())
    }
}
