//
//  MedicationListContainerView.swift
//  Unforgotten
//
//  Container for Medications - uses iPhone view for both platforms
//  iPad layout is handled by iPadRootView with the Home sidebar
//

import SwiftUI

/// Container for Medications
/// Returns the iPhone MedicationListView for both platforms
struct MedicationListContainerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        MedicationListView()
    }
}

// MARK: - iPad Medication List View
struct iPadMedicationListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = MedicationListViewModel()
    @State private var selectedMedication: Medication?
    @State private var searchText = ""
    @State private var showAddMedication = false
    @State private var showPausedOnly = false
    @State private var medicationToDelete: Medication?
    @State private var showDeleteConfirmation = false
    @Environment(\.appAccentColor) private var appAccentColor

    private var filteredMedications: [Medication] {
        var meds = viewModel.medications

        if showPausedOnly {
            meds = meds.filter { $0.isPaused }
        }

        if !searchText.isEmpty {
            meds = meds.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.reason?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return meds
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
        .navigationTitle("Medicines")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddMedication) {
            AddMedicationView { _ in
                Task {
                    await viewModel.loadMedications(appState: appState)
                }
            }
        }
        .task {
            await viewModel.loadMedications(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationsDidChange)) { _ in
            Task {
                await viewModel.loadMedications(appState: appState)
                // Refresh selected medication if it was updated
                if let selected = selectedMedication,
                   let updated = viewModel.medications.first(where: { $0.id == selected.id }) {
                    selectedMedication = updated
                }
            }
        }
        .alert("Delete Medication", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                medicationToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let medication = medicationToDelete {
                    Task {
                        await viewModel.deleteMedication(id: medication.id, appState: appState)
                        if selectedMedication?.id == medication.id {
                            selectedMedication = nil
                        }
                        medicationToDelete = nil
                    }
                }
            }
        } message: {
            if let medication = medicationToDelete {
                Text("Are you sure you want to delete \(medication.displayName)? This action cannot be undone.")
            }
        }
    }

    // MARK: - Left Pane
    private var leftPane: some View {
        VStack(spacing: 0) {
            searchAndFilterBar
            calendarButton
            medicationListScrollView
        }
        .frame(width: 320)
        .background(Color.appBackground)
    }

    // MARK: - Search and Filter Bar
    private var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            searchField
            filterButton
            addButton
        }
        .padding(16)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)
            TextField("Search medicines", text: $searchText)
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

    private var filterButton: some View {
        Button {
            showPausedOnly.toggle()
        } label: {
            Image(systemName: showPausedOnly ? "pause.circle.fill" : "pause.circle")
                .font(.system(size: 20))
                .foregroundColor(showPausedOnly ? appAccentColor : .textSecondary)
                .frame(width: 44, height: 44)
                .background(Color.cardBackground)
                .cornerRadius(10)
        }
    }

    private var addButton: some View {
        Button {
            showAddMedication = true
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
        NavigationLink(destination: MedicationCalendarView()) {
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

    // MARK: - Medication List
    private var medicationListScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredMedications) { medication in
                    iPadMedicationRowView(
                        medication: medication,
                        isSelected: selectedMedication?.id == medication.id,
                        onSelect: { selectedMedication = medication },
                        onDelete: {
                            medicationToDelete = medication
                            showDeleteConfirmation = true
                        },
                        onTogglePause: {
                            Task {
                                await viewModel.togglePause(medication: medication, appState: appState)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Right Pane
    @ViewBuilder
    private var rightPane: some View {
        if let medication = selectedMedication {
            MedicationDetailView(medication: medication)
                .id(medication.id)
        } else {
            emptyDetailPane
        }
    }

    private var emptyDetailPane: some View {
        VStack {
            Spacer()
            ContentUnavailableView(
                "Select a Medicine",
                systemImage: "pills.fill",
                description: Text("Choose a medicine to view its details and schedule")
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - iPad Medication Row View
struct iPadMedicationRowView: View {
    let medication: Medication
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onTogglePause: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                medicationImage

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(medication.displayName)
                            .font(.appCardTitle)
                            .foregroundColor(medication.isPaused ? .textSecondary : .textPrimary)
                            .lineLimit(1)

                        if medication.isPaused {
                            Image(systemName: "pause.circle.fill")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    if let strength = medication.strength {
                        Text(strength)
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }

                    if let reason = medication.reason {
                        Text(reason)
                            .font(.appCaptionSmall)
                            .foregroundColor(.textMuted)
                            .lineLimit(1)
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
        .contextMenu {
            Button {
                onTogglePause()
            } label: {
                Label(medication.isPaused ? "Resume" : "Pause", systemImage: medication.isPaused ? "play.circle" : "pause.circle")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var medicationImage: some View {
        if let localPath = medication.localImagePath,
           let image = LocalImageService.shared.loadMedicationPhoto(fileName: localPath) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: "pills.fill")
                .font(.system(size: 24))
                .foregroundColor(.medicalRed)
                .frame(width: 50, height: 50)
                .background(Color.cardBackgroundSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Preview
#Preview("iPad Medications") {
    iPadMedicationListView()
        .environmentObject(AppState())
}
