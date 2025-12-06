import SwiftUI

// MARK: - Appointment List View
struct AppointmentListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @StateObject private var viewModel = AppointmentListViewModel()
    @State private var showAddAppointment = false
    @State private var showSettings = false
    @State private var appointmentToDelete: Appointment?
    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header at the top - fully interactive
                HeaderImageView(
                    imageName: "header-appointments",
                    title: "Appointments",
                    showSettingsButton: true,
                    settingsAction: { showSettings = true }
                )

                // Content scrolls below header
                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Calendar button
                        NavigationLink(destination: AppointmentCalendarView()) {
                            HStack {
                                Text("Calendar")
                                    .font(.appCardTitle)
                                    .foregroundColor(.white)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.textSecondary)
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(Color.calendarBlue.opacity(0.6))
                            .cornerRadius(AppDimensions.cardCornerRadius)
                        }

                        // Appointments list
                        LazyVStack(spacing: AppDimensions.cardSpacing) {
                            ForEach(viewModel.appointments) { appointment in
                                AppointmentListRow(
                                    appointment: appointment,
                                    isCompleted: viewModel.isAppointmentCompleted(appointmentId: appointment.id),
                                    onToggleCompleted: {
                                        viewModel.toggleAppointmentCompleted(appointmentId: appointment.id)
                                    },
                                    onDelete: {
                                        appointmentToDelete = appointment
                                        showDeleteConfirmation = true
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
                        if viewModel.appointments.isEmpty && !viewModel.isLoading {
                            VStack(spacing: 12) {
                                Text("No appointments yet")
                                    .font(.appCardTitle)
                                    .foregroundColor(.textPrimary)

                                Text("Tap + to add the first one")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
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
        .sheet(isPresented: $showAddAppointment) {
            AddAppointmentView { _ in
                Task {
                    await viewModel.loadAppointments(appState: appState)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .task {
            await viewModel.loadAppointments(appState: appState)
        }
        .refreshable {
            await viewModel.loadAppointments(appState: appState)
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
                    .background(Color.accentYellow)
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
    let onDelete: () -> Void

    @State private var showOptions = false

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
        NavigationLink(destination: AppointmentDetailView(appointment: appointment)) {
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

                // Toggleable check icon
                Button {
                    onToggleCompleted()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundColor(isCompleted ? .accentYellow : .textSecondary.opacity(0.4))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

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
    @Published var completedAppointmentIds: Set<UUID> = []
    @Published var isLoading = false
    @Published var error: String?

    func toggleAppointmentCompleted(appointmentId: UUID) {
        if completedAppointmentIds.contains(appointmentId) {
            completedAppointmentIds.remove(appointmentId)
        } else {
            completedAppointmentIds.insert(appointmentId)
        }
    }

    func isAppointmentCompleted(appointmentId: UUID) -> Bool {
        completedAppointmentIds.contains(appointmentId)
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

    @State var appointment: Appointment
    @State private var showEditAppointment = false
    @State private var showDeleteConfirmation = false
    @State private var showSettings = false
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
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header at the top - fully interactive
                HeaderImageView(
                    imageName: "header-appointment-detail",
                    title: appointment.title,
                    showBackButton: true,
                    backAction: { dismiss() },
                    showEditButton: true,
                    editAction: { showEditAppointment = true }
                )

                // Content scrolls below header
                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Details
                        VStack(spacing: AppDimensions.cardSpacing) {
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
                                            .foregroundColor(.accentYellow)
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

                        Spacer()
                            .frame(height: 140)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .sheet(isPresented: $showEditAppointment) {
            EditAppointmentView(appointment: appointment) { updatedAppointment in
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
    
    let onSave: (Appointment) -> Void
    
    @State private var title = ""
    @State private var date = Date()
    @State private var hasTime = true
    @State private var time = Date()
    @State private var location = ""
    @State private var notes = ""
    @State private var reminderMinutes = 60
    
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        HeaderImageView(
                            imageName: "header-add-appointment",
                            title: "Add Appointment"
                        )
                        .padding(.horizontal, AppDimensions.screenPadding)

                        AppTextField(placeholder: "Title *", text: $title)

                        // Date picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                            
                            DatePicker(
                                "Date",
                                selection: $date,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .tint(.accentYellow)
                            .labelsHidden()
                        }
                        
                        // Time toggle and picker
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Include time", isOn: $hasTime)
                                .tint(.accentYellow)
                            
                            if hasTime {
                                DatePicker(
                                    "Time",
                                    selection: $time,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.compact)
                                .tint(.accentYellow)
                                .labelsHidden()
                            }
                        }
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                        
                        AppTextField(placeholder: "Location (optional)", text: $location)
                        AppTextField(placeholder: "Notes (optional)", text: $notes)
                        
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
                            .tint(.accentYellow)
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
            .navigationTitle("Add Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveAppointment() }
                    }
                    .foregroundColor(.accentYellow)
                    .disabled(title.isBlank || isLoading)
                }
            }
        }
    }
    
    private func saveAppointment() async {
        guard let account = appState.currentAccount else { return }
        
        // Get primary profile
        guard let primaryProfile = try? await appState.profileRepository.getPrimaryProfile(accountId: account.id) else {
            errorMessage = "No primary profile found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let insert = AppointmentInsert(
            accountId: account.id,
            profileId: primaryProfile.id,
            title: title,
            date: date,
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
            dismiss()
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

    let appointment: Appointment
    let onSave: (Appointment) -> Void

    @State private var title: String
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var location: String
    @State private var notes: String
    @State private var reminderMinutes: Int

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

    init(appointment: Appointment, onSave: @escaping (Appointment) -> Void) {
        self.appointment = appointment
        self.onSave = onSave
        self._title = State(initialValue: appointment.title)
        self._date = State(initialValue: appointment.date)
        self._hasTime = State(initialValue: appointment.time != nil)
        self._time = State(initialValue: appointment.time ?? Date())
        self._location = State(initialValue: appointment.location ?? "")
        self._notes = State(initialValue: appointment.notes ?? "")
        self._reminderMinutes = State(initialValue: appointment.reminderOffsetMinutes ?? 60)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        AppTextField(placeholder: "Title *", text: $title)

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
                            .tint(.accentYellow)
                        }

                        // Time toggle and picker
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Include Time", isOn: $hasTime)
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .tint(.accentYellow)

                            if hasTime {
                                DatePicker(
                                    "",
                                    selection: $time,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(.accentYellow)
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
                            .tint(.accentYellow)
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
            .navigationTitle("Edit Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await updateAppointment() }
                    }
                    .foregroundColor(.accentYellow)
                    .disabled(title.isBlank || isLoading)
                }
            }
        }
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
            dismiss()
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
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header at the top - fully interactive
                HeaderImageView(
                    imageName: "header-appointments",
                    title: "Appointment Calendar",
                    showBackButton: true,
                    backAction: { dismiss() }
                )

                // Content scrolls below header
                ScrollView {
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

                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
        }
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
                    onToggleCompleted: { viewModel.toggleAppointmentCompleted(appointmentId: $0) },
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
                    .foregroundColor(.accentYellow)
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
                        .foregroundColor(.accentYellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentYellow.opacity(0.2))
                        .cornerRadius(AppDimensions.pillCornerRadius)
                }
            }

            Button(action: onNextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.accentYellow)
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
                    .foregroundColor(isToday ? .accentYellow : .textPrimary)

                // Appointment indicator dot
                Circle()
                    .fill(hasAppointments ? Color.calendarBlue : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isSelected ? Color.accentYellow.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.accentYellow : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Appointment Calendar Card
struct AppointmentCalendarCard: View {
    let appointment: Appointment

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
                        .foregroundColor(.calendarBlue)

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
                    .foregroundColor(.accentYellow)
                }
            }
        }
    }
}

// MARK: - Appointment Day Card
struct AppointmentDayCard: View {
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
                        .foregroundColor(.calendarBlue)
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
                    .foregroundColor(isCompleted ? .accentYellow : .textSecondary.opacity(0.4))
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
    @Published var completedAppointmentIds: Set<UUID> = []
    @Published var isLoading = false
    @Published var error: String?

    private let calendar = Calendar.current

    func toggleAppointmentCompleted(appointmentId: UUID) {
        if completedAppointmentIds.contains(appointmentId) {
            completedAppointmentIds.remove(appointmentId)
        } else {
            completedAppointmentIds.insert(appointmentId)
        }
    }

    func isAppointmentCompleted(appointmentId: UUID) -> Bool {
        completedAppointmentIds.contains(appointmentId)
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
            monthAppointments = try await appState.appointmentRepository.getAppointmentsInRange(
                accountId: account.id,
                startDate: startOfMonth,
                endDate: endOfMonth
            )

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

// MARK: - Preview
#Preview {
    NavigationStack {
        AppointmentListView()
            .environmentObject(AppState())
    }
}
