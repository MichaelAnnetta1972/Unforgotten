import SwiftUI

// MARK: - Appointment List View
struct AppointmentListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @StateObject private var viewModel = AppointmentListViewModel()
    @State private var showAddAppointment = false
    @State private var showUpgradePrompt = false
    @State private var appointmentToDelete: Appointment?
    @State private var showDeleteConfirmation = false
    @State private var selectedTypeFilter: AppointmentType? = nil
    @State private var showingTypeFilter = false
    @State private var activeOptionsMenuItemId: UUID?
    @State private var cardFrames: [UUID: CGRect] = [:]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Check if we're in iPad mode (regular size class)
    private var isiPad: Bool {
        horizontalSizeClass == .regular
    }

    /// Check if user can add more appointments
    private var canAddAppointment: Bool {
        PremiumLimitsManager.shared.canCreateAppointment(
            appState: appState,
            currentCount: viewModel.appointments.count
        )
    }

    private var activeAppointment: Appointment? {
        guard let activeId = activeOptionsMenuItemId else { return nil }
        return viewModel.appointments.first(where: { $0.id == activeId })
    }

    private var activeFrame: CGRect? {
        guard let activeId = activeOptionsMenuItemId else { return nil }
        return cardFrames[activeId]
    }

    private var filteredAppointments: [Appointment] {
        guard let typeFilter = selectedTypeFilter else {
            return viewModel.appointments
        }
        return viewModel.appointments.filter { $0.type == typeFilter }
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
                    showHomeButton: iPadHomeAction != nil,
                    homeAction: iPadHomeAction,
                    showAddButton: canEdit,
                    addAction: canEdit ? {
                        if canAddAppointment {
                            showAddAppointment = true
                        } else {
                            showUpgradePrompt = true
                        }
                    } : nil
                )

                // Viewing As Bar (shown when viewing another account)
                ViewingAsBar()

                // Content
                VStack(spacing: AppDimensions.cardSpacing) {
                        // Calendar button with filter icon
                        HStack(spacing: 12) {
                            NavigationLink(destination: AppointmentCalendarView()) {
                                HStack {
                                    Text("Calendar")
                                        .font(.appCardTitle)
                                        .foregroundColor(.white)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white)
                                }
                                .padding(AppDimensions.cardPaddingLarge)
                                .background(Color.cardBackgroundLight.opacity(0.8))
                                .cornerRadius(AppDimensions.cardCornerRadius)
                            }

                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showingTypeFilter = true
                                }
                            }) {
                                Image(systemName: selectedTypeFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedTypeFilter != nil ? appAccentColor : .textSecondary)
                                    .frame(width: 44, height: 44)
                                    .background(Color.cardBackground)
                                    .cornerRadius(AppDimensions.cardCornerRadius)
                            }
                        }

                        // Appointments list
                        LazyVStack(spacing: AppDimensions.cardSpacing) {
                            ForEach(filteredAppointments) { appointment in
                                AppointmentListRow(
                                    appointment: appointment,
                                    isCompleted: appointment.isCompleted,
                                    onToggleCompleted: {
                                        viewModel.toggleAppointmentCompleted(appointmentId: appointment.id, appState: appState)
                                    },
                                    onOptionsMenu: {
                                        activeOptionsMenuItemId = appointment.id
                                    },
                                    onDelete: {
                                        appointmentToDelete = appointment
                                        showDeleteConfirmation = true
                                    }
                                )
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: AppointmentCardFramePreferenceKey.self,
                                            value: [appointment.id: geo.frame(in: .global)]
                                        )
                                    }
                                )
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

                                Text(selectedTypeFilter != nil ? "No \(selectedTypeFilter!.displayName.lowercased()) appointments" : "No Appointments")
                                    .font(.appTitle)
                                    .foregroundColor(.textPrimary)

                                Text(selectedTypeFilter != nil ? "Try selecting a different filter" : "Keep track of upcoming appointments and events")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)

                                if selectedTypeFilter == nil && canEdit {
                                    PrimaryButton(
                                        title: "Add Appointment",
                                        backgroundColor: appAccentColor
                                    ) {
                                        if canAddAppointment {
                                            showAddAppointment = true
                                        } else {
                                            showUpgradePrompt = true
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

                        // Premium limit reached banner
                        if !viewModel.appointments.isEmpty && !canAddAppointment {
                            PremiumFeatureLockBanner(
                                feature: .appointments,
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
        .navigationBarHidden(true)
        .onPreferenceChange(AppointmentCardFramePreferenceKey.self) { frames in
            cardFrames = frames
        }

            // Options menu overlay
            if let appointment = activeAppointment, let frame = activeFrame {
                AppointmentOptionsOverlay(
                    appointment: appointment,
                    frame: frame,
                    onToggleCompleted: {
                        viewModel.toggleAppointmentCompleted(appointmentId: appointment.id, appState: appState)
                    },
                    onDelete: {
                        appointmentToDelete = appointment
                        showDeleteConfirmation = true
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            activeOptionsMenuItemId = nil
                        }
                    }
                )
                .zIndex(20)
                .transition(.opacity)
            }

            // Type filter overlay when modal is shown
            if showingTypeFilter {
                ZStack {
                    Color.cardBackgroundLight.opacity(0.9)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingTypeFilter = false
                            }
                        }

                    AppointmentTypeFilterOverlay(
                        selectedType: $selectedTypeFilter,
                        isShowing: showingTypeFilter,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingTypeFilter = false
                            }
                        }
                    )
                }
                .zIndex(10)
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
        }
        .sidePanel(isPresented: $showAddAppointment) {
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
    let onToggleCompleted: () -> Void
    let onOptionsMenu: () -> Void
    let onDelete: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Adaptive padding: larger on iPad for better touch targets
    private var cardPadding: CGFloat {
        horizontalSizeClass == .regular ? 20 : 16
    }

    /// Adaptive icon size: larger on iPad
    private var iconSize: CGFloat {
        horizontalSizeClass == .regular ? 48 : 40
    }

    /// Minimum row height for better touch targets on iPad
    private var minRowHeight: CGFloat {
        horizontalSizeClass == .regular ? 80 : 60
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
            // Navigation to detail - takes up most of the card
            NavigationLink(destination: AppointmentDetailView(appointment: appointment)) {
                HStack {
                    // Type icon with background
                    Image(systemName: appointment.type.icon)
                        .font(.system(size: horizontalSizeClass == .regular ? 22 : 18))
                        .foregroundColor(appAccentColor)
                        .frame(width: iconSize, height: iconSize)
                        .background(appAccentColor.opacity(0.15))
                        .cornerRadius(8)

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
                    }

                    Spacer()
                }
                .frame(minHeight: minRowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Toggleable check icon
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

            // Options button (vertical dots)
            Button {
                onOptionsMenu()
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
                    .foregroundColor(.textSecondary)
                    .frame(width: buttonSize, height: buttonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(cardPadding)
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
            appointments = try await appState.appointmentRepository.getUpcomingAppointments(accountId: account.id, days: 365)
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
                    showEditButton: true,
                    editAction: {
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

                            // Delete button
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
    }

    private func deleteAppointment() async {
        isDeleting = true
        do {
            try await appState.appointmentRepository.deleteAppointment(id: appointment.id)
            await NotificationService.shared.cancelAppointmentReminder(appointmentId: appointment.id)
            dismiss()
        } catch {
            // Error handling - could show an alert here
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
    @State private var reminderMinutes = 60
    
    @State private var selectedType: AppointmentType = .general
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let reminderOptions = [
        (0, "At time of event"),
        (15, "15 minutes before"),
        (30, "30 minutes before"),
        (60, "1 hour before"),
        (120, "2 hours before"),
        (1440, "1 day before")
    ]

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
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

                        AppTextField(placeholder: "Title *", text: $title)

                        // Type selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            AppointmentTypePicker(selectedType: $selectedType)
                        }

                        // Date picker
                        VStack(spacing: 8) {
                            Text("Date")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)

                            DatePicker(
                                "Date",
                                selection: $date,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .tint(appAccentColor)
                            .labelsHidden()
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
                        VStack(spacing: 8) {
                            Text("Reminder")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)

                            Picker("Reminder", selection: $reminderMinutes) {
                                ForEach(reminderOptions, id: \.0) { option in
                                    Text(option.1).tag(option.0)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(appAccentColor)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .background(Color.clear)
            .navigationBarHidden(true)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.clear, for: .navigationBar)
        .containerBackground(.clear, for: .navigation)
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
            reminderOffsetMinutes: reminderMinutes
        )

        do {
            let appointment = try await appState.appointmentRepository.createAppointment(insert)

            // Schedule notification reminder
            await NotificationService.shared.scheduleAppointmentReminder(
                appointmentId: appointment.id,
                title: appointment.title,
                appointmentDate: appointment.date,
                appointmentTime: hasTime ? time : nil,
                location: appointment.location,
                reminderMinutesBefore: reminderMinutes
            )

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
    @State private var reminderMinutes: Int
    @State private var selectedType: AppointmentType

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let reminderOptions = [
        (0, "At time of event"),
        (15, "15 minutes before"),
        (30, "30 minutes before"),
        (60, "1 hour before"),
        (120, "2 hours before"),
        (1440, "1 day before")
    ]

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
        self._reminderMinutes = State(initialValue: appointment.reminderOffsetMinutes ?? 60)
        self._selectedType = State(initialValue: appointment.type)
    }

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
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

                    // Type selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        AppointmentTypePicker(selectedType: $selectedType)
                    }

                    // Date picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        DatePicker(
                            "",
                            selection: $date,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(appAccentColor)
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
                    .cornerRadius(AppDimensions.buttonCornerRadius)

                    AppTextField(placeholder: "Location", text: $location)
                    AppTextField(placeholder: "Notes", text: $notes)

                    // Reminder picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reminder")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        Picker("Reminder", selection: $reminderMinutes) {
                            ForEach(reminderOptions, id: \.0) { option in
                                Text(option.1).tag(option.0)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(appAccentColor)
                    }

                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .background(Color.clear)
            .navigationBarHidden(true)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.clear, for: .navigationBar)
        .containerBackground(.clear, for: .navigation)
    }

    private func updateAppointment() async {
        isLoading = true
        errorMessage = nil

        var updatedAppointment = appointment
        updatedAppointment.title = title
        updatedAppointment.date = date
        updatedAppointment.time = hasTime ? time : nil
        updatedAppointment.location = location.isBlank ? nil : location
        updatedAppointment.notes = notes.isBlank ? nil : notes
        updatedAppointment.reminderOffsetMinutes = reminderMinutes
        updatedAppointment.type = selectedType

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

            onSave(saved)
            dismissView()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isLoading = false
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
                            .frame(height: 44)
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
            .frame(height: 44)
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

// MARK: - Appointment Type Filter Overlay
private struct AppointmentTypeFilterOverlay: View {
    @Binding var selectedType: AppointmentType?
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
                Text("Filter by Type")
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
                        selectedType = nil
                        onDismiss()
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 16))
                                .foregroundColor(selectedType == nil ? appAccentColor : .textSecondary)
                                .frame(width: 24)

                            Text("All")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                            Spacer()
                            if selectedType == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(appAccentColor)
                            }
                        }
                        .padding(AppDimensions.cardPadding)
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Type options in grid
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(AppointmentType.allCases, id: \.self) { type in
                            Button {
                                selectedType = type
                                onDismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedType == type ? appAccentColor : .textSecondary)

                                    Text(type.displayName)
                                        .font(.caption)
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(selectedType == type ? appAccentColor.opacity(0.15) : Color.cardBackgroundSoft)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedType == type ? appAccentColor : Color.clear, lineWidth: 2)
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

// MARK: - Appointment Card Frame Preference Key
struct AppointmentCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Highlighted Appointment Card
struct HighlightedAppointmentCard: View {
    let appointment: Appointment
    let frame: CGRect
    let overlayFrame: CGRect
    let panelSize: CGSize
    let cardWidth: CGFloat
    let isCompleted: Bool
    let onToggleCompleted: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

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
        // Convert the captured global Y to local Y by subtracting overlay's global origin
        let localCardY = (frame.minY - overlayFrame.minY) + frame.height / 2

        HStack {
            // Type icon with background
            Image(systemName: appointment.type.icon)
                .font(.system(size: 18))
                .foregroundColor(appAccentColor)
                .frame(width: 40, height: 40)
                .background(appAccentColor.opacity(0.15))
                .cornerRadius(8)

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

            // Ellipsis icon to match original card
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

// MARK: - Appointment Options Overlay
struct AppointmentOptionsOverlay: View {
    let appointment: Appointment
    let frame: CGRect
    let onToggleCompleted: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var menuScale: CGFloat = 0.8
    @State private var menuOpacity: Double = 0
    @State private var menuHeight: CGFloat = 0

    private let menuWidth: CGFloat = 200

    private var isCompleted: Bool {
        appointment.isCompleted
    }

    var body: some View {
        GeometryReader { geometry in
            let overlayFrame = geometry.frame(in: .global)
            let panelSize = geometry.size
            let adaptiveScreenPadding = AppDimensions.screenPadding(for: horizontalSizeClass)
            let cardWidth = panelSize.width - (adaptiveScreenPadding * 2)
            // Convert global Y to local Y
            let localCardMinY = frame.minY - overlayFrame.minY
            let localCardMaxY = frame.maxY - overlayFrame.minY
            let menuYPosition = calculateMenuYPosition(localCardMinY: localCardMinY, localCardMaxY: localCardMaxY, screenHeight: panelSize.height)

            ZStack(alignment: .topLeading) {
                // Dark overlay
                Color.cardBackgroundLight.opacity(0.9)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onDismiss()
                    }

                // Highlighted card at captured position
                HighlightedAppointmentCard(
                    appointment: appointment,
                    frame: frame,
                    overlayFrame: overlayFrame,
                    panelSize: panelSize,
                    cardWidth: cardWidth,
                    isCompleted: isCompleted,
                    onToggleCompleted: onToggleCompleted
                )

                // Options menu - positioned above or below card based on available space
                VStack(spacing: 0) {
                    Button(action: {
                        onDelete()
                        onDismiss()
                    }) {
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

                    Button(action: onDismiss) {
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
                .scaleEffect(menuScale)
                .opacity(menuOpacity)
                .position(
                    x: panelSize.width - menuWidth / 2 - adaptiveScreenPadding,
                    y: menuYPosition
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                menuScale = 1.0
                menuOpacity = 1.0
            }
        }
    }

    private func calculateMenuYPosition(localCardMinY: CGFloat, localCardMaxY: CGFloat, screenHeight: CGFloat) -> CGFloat {
        // Estimate menu height based on number of buttons (Delete and Cancel)
        let estimatedMenuHeight: CGFloat = 52 * 2

        let menuGap: CGFloat = 12
        let topSafeArea: CGFloat = 60 // Account for header/safe area

        // Try to position above the card first
        let aboveCardY = localCardMinY - menuGap - (estimatedMenuHeight / 2)

        // Check if there's enough room above
        if aboveCardY - (estimatedMenuHeight / 2) > topSafeArea {
            return aboveCardY
        } else {
            // Not enough room above, position below
            return localCardMaxY + menuGap + (estimatedMenuHeight / 2)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AppointmentListView()
            .environmentObject(AppState())
    }
}
