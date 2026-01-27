//
//  AppointmentListContainerView.swift
//  Unforgotten
//
//  Container for Appointments - uses iPhone view for both platforms
//  iPad layout is handled by iPadRootView with the Home sidebar
//

import SwiftUI

/// Container for Appointments
/// Returns the iPhone AppointmentListView for both platforms
struct AppointmentListContainerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        AppointmentListView()
    }
}

// MARK: - iPad Appointment List View
struct iPadAppointmentListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AppointmentListViewModel()
    @State private var selectedAppointment: Appointment?
    @State private var searchText = ""
    @State private var showAddAppointment = false
    @State private var selectedTypeFilter: AppointmentType?
    @State private var appointmentToDelete: Appointment?
    @State private var showDeleteConfirmation = false
    @Environment(\.appAccentColor) private var appAccentColor

    private var filteredAppointments: [Appointment] {
        var apts = viewModel.appointments

        if let typeFilter = selectedTypeFilter {
            apts = apts.filter { $0.type == typeFilter }
        }

        if !searchText.isEmpty {
            apts = apts.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.location?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return apts
    }

    // Group appointments by date
    private var groupedAppointments: [(String, [Appointment])] {
        let grouped = Dictionary(grouping: filteredAppointments) { appointment in
            appointment.date.formatted(date: .abbreviated, time: .omitted)
        }
        return grouped.sorted { first, second in
            guard let firstDate = first.value.first?.date,
                  let secondDate = second.value.first?.date else { return false }
            return firstDate < secondDate
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
        .navigationTitle("Appointments")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddAppointment) {
            AddAppointmentView { _ in
                Task {
                    await viewModel.loadAppointments(appState: appState)
                }
            }
            .presentationBackground(Color.appBackgroundLight)
        }
        .task {
            await viewModel.loadAppointments(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appointmentsDidChange)) { notification in
            // Try to handle locally first for instant updates
            if notification.userInfo != nil {
                viewModel.handleAppointmentChange(notification: notification)
                // Update selected appointment if it was changed
                if let selected = selectedAppointment,
                   let updated = viewModel.appointments.first(where: { $0.id == selected.id }) {
                    selectedAppointment = updated
                }
            }
            // Also reload to ensure we have fresh data
            Task {
                await viewModel.loadAppointments(appState: appState)
                if let selected = selectedAppointment,
                   let updated = viewModel.appointments.first(where: { $0.id == selected.id }) {
                    selectedAppointment = updated
                }
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
                        if selectedAppointment?.id == appointment.id {
                            selectedAppointment = nil
                        }
                        appointmentToDelete = nil
                    }
                }
            }
        } message: {
            if let appointment = appointmentToDelete {
                Text("Are you sure you want to delete \"\(appointment.title)\"?")
            }
        }
    }

    // MARK: - Left Pane
    private var leftPane: some View {
        VStack(spacing: 0) {
            searchAndFilterBar
            calendarButton
            appointmentListScrollView
        }
        .frame(width: 320)
        .background(Color.appBackground)
    }

    // MARK: - Search and Filter Bar
    private var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            searchField
            filterMenu
            addButton
        }
        .padding(16)
    }

    private var searchField: some View {
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
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(10)
    }

    private var filterMenu: some View {
        Menu {
            Button {
                selectedTypeFilter = nil
            } label: {
                Label("All Types", systemImage: selectedTypeFilter == nil ? "checkmark" : "")
            }

            Divider()

            ForEach(AppointmentType.allCases, id: \.self) { type in
                Button {
                    selectedTypeFilter = type
                } label: {
                    Label(type.displayName, systemImage: selectedTypeFilter == type ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: selectedTypeFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 20))
                .foregroundColor(selectedTypeFilter != nil ? appAccentColor : .textSecondary)
                .frame(width: 44, height: 44)
                .background(Color.cardBackground)
                .cornerRadius(10)
        }
    }

    private var addButton: some View {
        Button {
            showAddAppointment = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(appAccentColor)
                .cornerRadius(10)
        }
    }

    // MARK: - Calendar Button
    private var calendarButton: some View {
        NavigationLink(destination: AppointmentCalendarView()) {
            HStack {
                Image(systemName: "calendar")
                    .font(.appCardTitle)
                    .foregroundColor(.white)

                Text("Calendar")
                    .font(.appCardTitle)
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(16)
            .background(Color.cardBackgroundLight.opacity(0.8))
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Appointment List
    private var appointmentListScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(groupedAppointments, id: \.0) { dateString, appointments in
                    Section {
                        ForEach(appointments) { appointment in
                            iPadAppointmentRowView(
                                appointment: appointment,
                                isSelected: selectedAppointment?.id == appointment.id,
                                onSelect: { selectedAppointment = appointment },
                                onToggleCompleted: {
                                    viewModel.toggleAppointmentCompleted(appointmentId: appointment.id, appState: appState)
                                },
                                onDelete: {
                                    appointmentToDelete = appointment
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                    } header: {
                        sectionHeader(dateString: dateString)
                    }
                }

                if filteredAppointments.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 40))
                            .foregroundColor(.textSecondary)
                        Text("No appointments")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func sectionHeader(dateString: String) -> some View {
        HStack {
            Text(dateString)
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
        if let appointment = selectedAppointment {
            AppointmentDetailView(appointment: appointment)
                .id(appointment.id)
        } else {
            emptyDetailPane
        }
    }

    private var emptyDetailPane: some View {
        VStack {
            Spacer()
            ContentUnavailableView(
                "Select an Appointment",
                systemImage: "calendar",
                description: Text("Choose an appointment to view its details")
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - iPad Appointment Row View
struct iPadAppointmentRowView: View {
    let appointment: Appointment
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleCompleted: () -> Void
    let onDelete: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Completion checkbox
                Button(action: onToggleCompleted) {
                    Image(systemName: appointment.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(appointment.isCompleted ? appAccentColor : .textSecondary)
                }
                .buttonStyle(.plain)

                // Appointment type icon
                Image(systemName: appointment.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(appointment.type.color)
                    .frame(width: 36, height: 36)
                    .background(appointment.type.color.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(appointment.title)
                        .font(.appCardTitle)
                        .foregroundColor(appointment.isCompleted ? .textSecondary : .textPrimary)
                        .strikethrough(appointment.isCompleted)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let time = appointment.time {
                            Text(time.formatted(date: .omitted, time: .shortened))
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }

                        if let location = appointment.location {
                            Text(location)
                                .font(.appCaptionSmall)
                                .foregroundColor(.textMuted)
                                .lineLimit(1)
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
        .contextMenu {
            Button {
                onToggleCompleted()
            } label: {
                Label(appointment.isCompleted ? "Mark Incomplete" : "Mark Complete", systemImage: appointment.isCompleted ? "circle" : "checkmark.circle")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview
#Preview("iPad Appointments") {
    iPadAppointmentListView()
        .environmentObject(AppState.forPreview())
}
