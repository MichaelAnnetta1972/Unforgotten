import SwiftUI

// MARK: - Medication List View
struct MedicationListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = MedicationListViewModel()
    @State private var showAddMedication = false
    @State private var showUpgradePrompt = false
    @State private var medicationToDelete: Medication?
    @State private var showDeleteConfirmation = false

    /// Check if user can add more medications
    private var canAddMedication: Bool {
        PremiumLimitsManager.shared.canCreateMedication(
            appState: appState,
            currentCount: viewModel.medications.count
        )
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            mainScrollView
                .ignoresSafeArea(edges: .top)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
        }
        .sidePanel(isPresented: $showAddMedication) {
            AddMedicationView(
                onDismiss: { showAddMedication = false }
            ) { _ in
                Task {
                    await viewModel.loadMedications(appState: appState)
                }
            }
        }
        .task {
            await viewModel.loadMedications(appState: appState)
        }
        .refreshable {
            await viewModel.loadMedications(appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationsDidChange)) { _ in
            Task {
                await viewModel.loadMedications(appState: appState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            Task {
                await viewModel.loadMedications(appState: appState)
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
        .alert("Delete Medication", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                medicationToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let medication = medicationToDelete {
                    Task {
                        await viewModel.deleteMedication(id: medication.id, appState: appState)
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

    // MARK: - View Components

    /// Whether the current user can add/edit medications
    private var canEdit: Bool {
        appState.canEdit
    }

    @ViewBuilder
    private var mainScrollView: some View {
        ScrollView {
                VStack(spacing: 0) {
                    // Header scrolls with content - uses style-based assets from HeaderStyleManager
                    CustomizableHeaderView(
                        pageIdentifier: .medications,
                        title: "Medicines",
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction,
                        showAddButton: canEdit,
                        addAction: canEdit ? {
                            if canAddMedication {
                                showAddMedication = true
                            } else {
                                showUpgradePrompt = true
                            }
                        } : nil
                    )

                // Viewing As Bar (shown when viewing another account)
                ViewingAsBar()

                // Content
                VStack(spacing: AppDimensions.cardSpacing) {
                    // Calendar button
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
                        .padding(AppDimensions.cardPaddingLarge)
                        .background(Color.cardBackgroundLight.opacity(0.8))
                        .cornerRadius(AppDimensions.cardCornerRadius)
                    }

                    // Medications list
                    LazyVStack(spacing: AppDimensions.cardSpacing) {
                        ForEach(viewModel.medications) { medication in
                            MedicationListRow(
                                medication: medication,
                                onDelete: {
                                    medicationToDelete = medication
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                    }

                    // Loading state
                    if viewModel.isLoading && viewModel.medications.isEmpty {
                        LoadingView(message: "Loading medications...")
                            .padding(.top, 40)
                    }

                    // Empty state
                    if viewModel.medications.isEmpty && !viewModel.isLoading {
                        EmptyStateView(
                            icon: "pills.fill",
                            title: "No medications yet",
                            message: "Add medications to track schedules and reminders",
                            buttonTitle: "Add Medication",
                            buttonAction: {
                                if canAddMedication {
                                    showAddMedication = true
                                } else {
                                    showUpgradePrompt = true
                                }
                            }
                        )
                        .padding(.top, 40)
                    }

                    // Premium limit reached banner
                    if !viewModel.medications.isEmpty && !canAddMedication {
                        PremiumFeatureLockBanner(
                            feature: .medications,
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
    }

}

// MARK: - Medication Header View
struct MedicationHeaderView: View {
    let onBack: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background
            Color.medicalRed
                .frame(height: AppDimensions.headerHeight)
            
            // Center icon
            VStack {
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "cross.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                
                Text("Medicines")
                    .font(.appTitle)
                    .foregroundColor(.white)
                    .padding(.top, 12)
                
                Spacer()
                    .frame(height: 20)
            }
            .frame(maxWidth: .infinity)
            
            // Back button
            VStack(alignment: .leading) {
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
                .padding(AppDimensions.screenPadding)
                
                Spacer()
            }
        }
        .frame(height: AppDimensions.headerHeight)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .padding(.horizontal, AppDimensions.screenPadding)
    }
}

// MARK: - Medication List Row
struct MedicationListRow: View {
    let medication: Medication
    let onDelete: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Adaptive padding: larger on iPad for better touch targets
    private var cardPadding: CGFloat {
        horizontalSizeClass == .regular ? 20 : 16
    }

    /// Adaptive thumbnail size: larger on iPad
    private var thumbnailSize: CGFloat {
        horizontalSizeClass == .regular ? 60 : 50
    }

    /// Minimum row height for better touch targets on iPad
    private var minRowHeight: CGFloat {
        horizontalSizeClass == .regular ? 80 : 60
    }

    var body: some View {
        HStack {
            NavigationLink(destination: MedicationDetailView(medication: medication)) {
                HStack {
                    // Photo thumbnail
                    if let localPath = medication.localImagePath,
                       let image = LocalImageService.shared.loadMedicationPhoto(fileName: localPath) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: thumbnailSize, height: thumbnailSize)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "pills.fill")
                            .font(.system(size: horizontalSizeClass == .regular ? 28 : 24))
                            .foregroundColor(.medicalRed)
                            .frame(width: thumbnailSize, height: thumbnailSize)
                            .background(Color.cardBackgroundSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(medication.displayName)
                                .font(.appCardTitle)
                                .foregroundColor(medication.isPaused ? .textSecondary : .textPrimary)

                            if medication.isPaused {
                                Text("PAUSED")
                                    .font(.appCaptionSmall)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.badgeGrey)
                                    .cornerRadius(4)
                            }
                        }

                        if let reason = medication.reason {
                            Text(reason)
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }

                        if let instruction = medication.intakeInstruction {
                            Text(instruction.displayName)
                                .font(.appCaptionSmall)
                                .foregroundColor(.accentYellow)
                        }
                    }

                    Spacer()
                }
                .frame(minHeight: minRowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: horizontalSizeClass == .regular ? 18 : 16))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(width: horizontalSizeClass == .regular ? 52 : 44, height: horizontalSizeClass == .regular ? 52 : 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .contentShape(Rectangle())
        .opacity(medication.isPaused ? 0.7 : 1.0)
    }
}

// MARK: - Medication List View Model
@MainActor
class MedicationListViewModel: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadMedications(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            medications = try await appState.medicationRepository.getMedications(accountId: account.id)
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    func deleteMedication(id: UUID, appState: AppState) async {
        do {
            try await appState.medicationRepository.deleteMedication(id: id)
            medications.removeAll { $0.id == id }
        } catch {
            self.error = "Failed to delete medication: \(error.localizedDescription)"
        }
    }

    func togglePause(medication: Medication, appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        var updatedMedication = medication
        updatedMedication.isPaused = !medication.isPaused
        updatedMedication.pausedAt = updatedMedication.isPaused ? Date() : nil

        do {
            let saved = try await appState.medicationRepository.updateMedication(updatedMedication)

            // Update local array
            if let index = medications.firstIndex(where: { $0.id == medication.id }) {
                medications[index] = saved
            }

            // If pausing, delete future scheduled logs
            if saved.isPaused {
                try await appState.medicationRepository.deleteFutureScheduledLogs(medicationId: medication.id)
            } else {
                // If resuming, regenerate today's logs
                try await appState.medicationRepository.regenerateTodaysLogs(
                    medicationId: medication.id,
                    accountId: account.id
                )
            }
        } catch {
            self.error = "Failed to update medication: \(error.localizedDescription)"
        }
    }

    func moveMedication(from source: IndexSet, to destination: Int) {
        medications.move(fromOffsets: source, toOffset: destination)
    }

    func saveSortOrder(appState: AppState) async {
        let updates = medications.enumerated().map { index, medication in
            SortOrderUpdate(id: medication.id, sortOrder: index)
        }

        do {
            try await appState.medicationRepository.updateMedicationSortOrders(updates)
        } catch {
            self.error = "Failed to save order: \(error.localizedDescription)"
        }
    }
}

// MARK: - Reorderable Medication List
struct ReorderableMedicationList: View {
    @Binding var medications: [Medication]
    let onReorder: (IndexSet, Int) -> Void

    var body: some View {
        VStack(spacing: AppDimensions.cardSpacing) {
            ForEach(medications) { medication in
                ReorderableMedicationRow(
                    medication: medication,
                    onMoveUp: {
                        if let index = medications.firstIndex(where: { $0.id == medication.id }), index > 0 {
                            onReorder(IndexSet(integer: index), index - 1)
                        }
                    },
                    onMoveDown: {
                        if let index = medications.firstIndex(where: { $0.id == medication.id }), index < medications.count - 1 {
                            onReorder(IndexSet(integer: index), index + 2)
                        }
                    },
                    isFirst: medications.first?.id == medication.id,
                    isLast: medications.last?.id == medication.id
                )
            }
        }
    }
}

// MARK: - Reorderable Medication Row
struct ReorderableMedicationRow: View {
    let medication: Medication
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Reorder buttons
            VStack(spacing: 4) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isFirst ? .textSecondary.opacity(0.3) : .accentYellow)
                        .frame(width: 32, height: 28)
                }
                .disabled(isFirst)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isLast ? .textSecondary.opacity(0.3) : .accentYellow)
                        .frame(width: 32, height: 28)
                }
                .disabled(isLast)
            }
            .padding(.leading, 4)

            // Medication icon
            Image(systemName: "pills.fill")
                .font(.title3)
                .foregroundColor(medication.isPaused ? .textSecondary : .medicalRed)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(medication.displayName)
                    .font(.appCardTitle)
                    .foregroundColor(medication.isPaused ? .textSecondary : .textPrimary)

                if let form = medication.form {
                    Text(form.capitalized)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            if medication.isPaused {
                Text("Paused")
                    .font(.appCaption)
                    .foregroundColor(.badgeGrey)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.badgeGrey.opacity(0.2))
                    .cornerRadius(8)
            }

            // Drag handle indicator
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)
                .frame(width: 44, height: 44)
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Medication Detail View
struct MedicationDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.iPadEditMedicationAction) private var iPadEditMedicationAction

    @State var medication: Medication
    @StateObject private var viewModel = MedicationDetailViewModel()
    @State private var showEditMedication = false
    @State private var showSettings = false
    @State private var isTogglingPause = false
    @State private var showFullscreenImage = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header scrolls with content
                MedicationDetailHeaderView(
                    medication: medication,
                    onBack: { dismiss() },
                    onEdit: {
                        // Use full-screen overlay action if available
                        if let editAction = iPadEditMedicationAction {
                            editAction(medication)
                        } else {
                            showEditMedication = true
                        }
                    }
                )

                // Content
                VStack(spacing: AppDimensions.cardSpacing) {
                        // Photo (if available) - tap to view fullscreen
                        if let localPath = medication.localImagePath,
                           let image = LocalImageService.shared.loadMedicationPhoto(fileName: localPath) {
                            Button {
                                showFullscreenImage = true
                            } label: {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius))
                            }
                            .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        // Pause banner
                        if medication.isPaused {
                            HStack {
                                Image(systemName: "pause.circle.fill")
                                    .foregroundColor(.white)
                                Text("This medication is paused")
                                    .font(.appBodyMedium)
                                    .foregroundColor(.white)
                                Spacer()
                                Button("Resume") {
                                    Task { await togglePause() }
                                }
                                .font(.appCaption)
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentYellow)
                                .cornerRadius(12)
                            }
                            .padding()
                            .background(Color.badgeGrey)
                            .cornerRadius(AppDimensions.cardCornerRadius)
                            .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        // Details
                        VStack(spacing: AppDimensions.cardSpacing) {
                            if let strength = medication.strength {
                                DetailItemCard(label: "Strength", value: strength)
                            }

                            if let form = medication.form {
                                DetailItemCard(label: "Form", value: form.capitalized)
                            }

                            if let reason = medication.reason {
                                DetailItemCard(label: "Reason", value: reason)
                            }

                            if let instruction = medication.intakeInstruction {
                                DetailItemCard(label: "Intake", value: instruction.displayName)
                            }

                            if let notes = medication.notes {
                                DetailItemCard(label: "Notes", value: notes)
                            }
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)

                        // Pause/Resume button
                        if !medication.isPaused {
                            Button {
                                Task { await togglePause() }
                            } label: {
                                HStack {
                                    Image(systemName: "pause.circle")
                                    Text("Pause Medication")
                                }
                                .font(.appBodyMedium)
                                .foregroundColor(.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cardBackgroundSoft)
                                .cornerRadius(AppDimensions.buttonCornerRadius)
                            }
                            .disabled(isTogglingPause)
                            .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        // Schedule section
                        if !viewModel.schedules.isEmpty {
                            VStack(alignment: .leading, spacing: AppDimensions.cardSpacing) {
                                Text("SCHEDULE")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)
                                    .padding(.horizontal, AppDimensions.screenPadding)

                                ForEach(viewModel.schedules) { schedule in
                                    ScheduleCard(schedule: schedule)
                                }
                                .padding(.horizontal, AppDimensions.screenPadding)
                            }
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
        .toolbar(.hidden, for: .navigationBar)
        .sidePanel(isPresented: $showSettings) {
            SettingsPanelView(onDismiss: { showSettings = false })
        }
        .sidePanel(isPresented: $showEditMedication) {
            EditMedicationView(
                medication: medication,
                onDismiss: { showEditMedication = false }
            ) { updatedMedication in
                medication = updatedMedication
                Task {
                    await viewModel.loadSchedules(medicationId: medication.id, appState: appState)
                }
            }
        }
        .fullScreenCover(isPresented: $showFullscreenImage) {
            if let localPath = medication.localImagePath,
               let image = LocalImageService.shared.loadMedicationPhoto(fileName: localPath) {
                FullscreenImageView(image: image, title: medication.displayName)
            }
        }
        .task {
            await viewModel.loadSchedules(medicationId: medication.id, appState: appState)
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

    private func togglePause() async {
        guard let account = appState.currentAccount else { return }

        isTogglingPause = true

        var updatedMedication = medication
        updatedMedication.isPaused = !medication.isPaused
        updatedMedication.pausedAt = updatedMedication.isPaused ? Date() : nil

        do {
            let saved = try await appState.medicationRepository.updateMedication(updatedMedication)
            medication = saved

            if saved.isPaused {
                try await appState.medicationRepository.deleteFutureScheduledLogs(medicationId: medication.id)
            } else {
                try await appState.medicationRepository.regenerateTodaysLogs(
                    medicationId: medication.id,
                    accountId: account.id
                )
            }
        } catch {
            viewModel.error = "Failed to update medication: \(error.localizedDescription)"
        }

        isTogglingPause = false
    }
}

// MARK: - Medication Detail Header
struct MedicationDetailHeaderView: View {
    let medication: Medication
    let onBack: () -> Void
    let onEdit: (() -> Void)?

    init(medication: Medication, onBack: @escaping () -> Void, onEdit: (() -> Void)? = nil) {
        self.medication = medication
        self.onBack = onBack
        self.onEdit = onEdit
    }

    var body: some View {
        CustomizableHeaderView(
            pageIdentifier: .medicationDetail,
            title: medication.displayName,
            showBackButton: true,
            backAction: onBack,
            showEditButton: onEdit != nil,
            editAction: onEdit,
            editButtonPosition: .bottomRight
        )
    }
}

// MARK: - Schedule Card
struct ScheduleCard: View {
    let schedule: MedicationSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(schedule.scheduleType.displayName)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                Spacer()
            }

            if let dose = schedule.doseDescription {
                Text(dose)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            // Show schedule entries if available
            if let entries = schedule.scheduleEntries, !entries.isEmpty {
                ForEach(entries) { entry in
                    ScheduleEntryDisplayRow(entry: entry)
                }
            } else if let times = schedule.times {
                // Legacy times display
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.accentYellow)
                    Text(times.joined(separator: ", "))
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                if let days = schedule.daysOfWeek {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.accentYellow)
                        Text(daysTextFromArray(days))
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    private func daysTextFromArray(_ days: [Int]) -> String {
        if days.count == 7 { return "Every day" }
        if days == [1, 2, 3, 4, 5] { return "Weekdays" }
        if days == [0, 6] { return "Weekends" }
        return days.map { Calendar.daysOfWeek[$0] }.joined(separator: ", ")
    }
}

// MARK: - Schedule Entry Display Row
struct ScheduleEntryDisplayRow: View {
    let entry: ScheduleEntry

    private var daysText: String {
        let days = entry.daysOfWeek.sorted()
        if days.count == 7 { return "Daily" }
        if days == [1, 2, 3, 4, 5] { return "Weekdays" }
        if days == [0, 6] { return "Weekends" }
        return days.compactMap { $0 < Calendar.daysOfWeek.count ? Calendar.daysOfWeek[$0] : nil }.joined(separator: ", ")
    }

    private var durationText: String? {
        guard let value = entry.durationValue else { return nil }
        let unit = entry.durationUnit
        let unitName = value == 1 ? unit.singularName : unit.displayName.lowercased()
        return "\(value) \(unitName)"
    }

    var body: some View {
        HStack(spacing: 8) {
            // Time
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .foregroundColor(.accentYellow)
                    .font(.system(size: 10))
                Text(entry.time)
                    .font(.appCaption)
                    .foregroundColor(.textPrimary)
            }

            // Dosage (if present)
            if let dosage = entry.dosage {
                Text("•")
                    .foregroundColor(.textMuted)
                Text(dosage)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            // Days
            Text("•")
                .foregroundColor(.textMuted)
            Text(daysText)
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            // Duration (if present)
            if let duration = durationText {
                Text("•")
                    .foregroundColor(.textMuted)
                Text(duration)
                    .font(.appCaption)
                    .foregroundColor(.accentYellow)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.cardBackgroundSoft)
        .cornerRadius(8)
    }
}

// MARK: - Medication Detail View Model
@MainActor
class MedicationDetailViewModel: ObservableObject {
    @Published var schedules: [MedicationSchedule] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadSchedules(medicationId: UUID, appState: AppState) async {
        isLoading = true

        do {
            schedules = try await appState.medicationRepository.getSchedules(medicationId: medicationId)
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - Medication Calendar View
struct MedicationCalendarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = MedicationCalendarViewModel()
    @State private var selectedDate: Date?
    @State private var showDayDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header scrolls with content
                HeaderImageView(
                    imageName: "header-medications",
                    title: "Medicine Calendar",
                    showBackButton: true,
                    backAction: { dismiss() }
                )

                // Content
                VStack(spacing: AppDimensions.cardSpacing) {
                        // Streak Counter
                        if viewModel.currentStreak > 0 {
                            StreakBanner(streak: viewModel.currentStreak)
                                .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        // Month Navigation
                        MonthNavigationHeader(
                            currentMonth: viewModel.currentMonth,
                            onPreviousMonth: { viewModel.goToPreviousMonth() },
                            onNextMonth: { viewModel.goToNextMonth() },
                            onToday: { viewModel.goToToday() }
                        )
                        .padding(.horizontal, AppDimensions.screenPadding)

                        // Medication Filter
                        if !viewModel.medications.isEmpty {
                            MedicationFilterPicker(
                                medications: viewModel.medications,
                                selectedMedicationId: $viewModel.selectedMedicationId
                            )
                            .padding(.horizontal, AppDimensions.screenPadding)
                        }

                        // Calendar Grid
                        CalendarGridView(
                            currentMonth: viewModel.currentMonth,
                            dayStatuses: viewModel.filteredDayStatuses,
                            selectedDate: $selectedDate,
                            onDateSelected: { date in
                                selectedDate = date
                                showDayDetail = true
                            }
                        )
                        .padding(.horizontal, AppDimensions.screenPadding)

                        // Legend
                        CalendarLegend()
                            .padding(.horizontal, AppDimensions.screenPadding)

                        // Monthly Summary
                        if let summary = viewModel.monthlySummary {
                            MonthlySummaryCard(summary: summary)
                                .padding(.horizontal, AppDimensions.screenPadding)
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
        .task {
            await viewModel.loadData(appState: appState)
        }
        .onChange(of: viewModel.currentMonth) { _, _ in
            Task {
                await viewModel.loadMonthData(appState: appState)
            }
        }
        .onChange(of: viewModel.selectedMedicationId) { _, _ in
            viewModel.updateFilteredStatuses()
        }
        .sheet(isPresented: $showDayDetail) {
            if let date = selectedDate {
                DayDetailSheet(
                    date: date,
                    logs: viewModel.getLogsForDate(date),
                    medications: viewModel.medications,
                    futureScheduledItems: viewModel.isFutureDate(date) ? viewModel.getScheduledMedicationsForDate(date) : []
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Streak Banner
struct StreakBanner: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak) day streak!")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                Text("Keep up the great work")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()
        }
        .padding(AppDimensions.cardPadding)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.2), Color.accentYellow.opacity(0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(AppDimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Month Navigation Header
struct MonthNavigationHeader: View {
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
                    .foregroundColor(isCurrentMonth ? .textSecondary.opacity(0.3) : .accentYellow)
                    .frame(width: 44, height: 44)
            }
            .disabled(isCurrentMonth)
        }
    }
}

// MARK: - Medication Filter Picker
struct MedicationFilterPicker: View {
    let medications: [Medication]
    @Binding var selectedMedicationId: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All medications option
                FilterChip(
                    title: "All",
                    isSelected: selectedMedicationId == nil,
                    action: { selectedMedicationId = nil }
                )

                ForEach(medications) { medication in
                    FilterChip(
                        title: medication.displayName,
                        isSelected: selectedMedicationId == medication.id,
                        action: { selectedMedicationId = medication.id }
                    )
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(isSelected ? .black : .textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentYellow : Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.pillCornerRadius)
        }
    }
}

// MARK: - Calendar Grid View
struct CalendarGridView: View {
    let currentMonth: Date
    let dayStatuses: [Date: DayAdherenceStatus]
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
                        CalendarDayCell(
                            date: date,
                            status: dayStatuses[calendar.startOfDay(for: date)],
                            isToday: calendar.isDateInToday(date),
                            isFuture: date > Date(),
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

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let date: Date
    let status: DayAdherenceStatus?
    let isToday: Bool
    let isFuture: Bool
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
                    .foregroundColor(textColor)

                // Status dot - show for past days and future scheduled days
                if let status = status {
                    Circle()
                        .fill(status.color)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.accentYellow : Color.clear, lineWidth: 2)
            )
        }
    }

    private var textColor: Color {
        if isFuture && status != .scheduled {
            return .textSecondary.opacity(0.4)
        } else if isFuture && status == .scheduled {
            return .textSecondary.opacity(0.7)
        } else if isToday {
            return .accentYellow
        } else {
            return .textPrimary
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentYellow.opacity(0.2)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Day Adherence Status
enum DayAdherenceStatus {
    case allTaken      // 100% adherence
    case partialTaken  // Some taken
    case noneTaken     // 0% adherence (all missed/skipped)
    case noMedications // No medications scheduled
    case scheduled     // Future date with scheduled medications

    var color: Color {
        switch self {
        case .allTaken: return .badgeGreen
        case .partialTaken: return .accentYellow
        case .noneTaken: return .medicalRed
        case .noMedications: return .textSecondary.opacity(0.3)
        case .scheduled: return .accentYellow.opacity(0.6)
        }
    }

    var label: String {
        switch self {
        case .allTaken: return "All taken"
        case .partialTaken: return "Partial"
        case .noneTaken: return "Missed"
        case .noMedications: return "None scheduled"
        case .scheduled: return "Scheduled"
        }
    }
}

// MARK: - Calendar Legend
struct CalendarLegend: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                LegendItem(color: .badgeGreen, label: "All taken")
                LegendItem(color: .accentYellow, label: "Partial")
                LegendItem(color: .medicalRed, label: "Missed")
            }
            HStack(spacing: 16) {
                LegendItem(color: .accentYellow.opacity(0.6), label: "Scheduled")
            }
        }
        .padding(.vertical, 8)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.appCaptionSmall)
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Monthly Summary Card
struct MonthlySummaryCard: View {
    let summary: MonthlySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MONTHLY SUMMARY")
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            HStack(spacing: 16) {
                SummaryStatView(
                    value: "\(summary.adherencePercentage)%",
                    label: "Adherence",
                    color: summary.adherencePercentage >= 80 ? .badgeGreen : (summary.adherencePercentage >= 50 ? .accentYellow : .medicalRed)
                )

                Divider()
                    .frame(height: 40)

                SummaryStatView(
                    value: "\(summary.takenCount)",
                    label: "Taken",
                    color: .badgeGreen
                )

                Divider()
                    .frame(height: 40)

                SummaryStatView(
                    value: "\(summary.missedCount)",
                    label: "Missed",
                    color: .medicalRed
                )

                Divider()
                    .frame(height: 40)

                SummaryStatView(
                    value: "\(summary.skippedCount)",
                    label: "Skipped",
                    color: .textSecondary
                )
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

struct SummaryStatView: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.appTitle)
                .foregroundColor(color)

            Text(label)
                .font(.appCaptionSmall)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Monthly Summary Model
struct MonthlySummary {
    let takenCount: Int
    let missedCount: Int
    let skippedCount: Int
    let scheduledCount: Int

    var adherencePercentage: Int {
        let total = takenCount + missedCount + skippedCount
        guard total > 0 else { return 0 }
        return Int((Double(takenCount) / Double(total)) * 100)
    }
}

// MARK: - Day Detail Sheet
struct DayDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let date: Date
    let logs: [MedicationLog]
    let medications: [Medication]
    var futureScheduledItems: [(medication: Medication, entry: ScheduleEntry)] = []

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

    private func medication(for log: MedicationLog) -> Medication? {
        medications.first { $0.id == log.medicationId }
    }

    private var isFutureDate: Bool {
        !futureScheduledItems.isEmpty
    }

    private var hasContent: Bool {
        !logs.isEmpty || !futureScheduledItems.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if !hasContent {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 48))
                            .foregroundColor(.textSecondary)

                        Text("No medications scheduled")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: AppDimensions.cardSpacing) {
                            // For future dates, show scheduled medications
                            if isFutureDate {
                                // Future date banner
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundColor(.accentYellow)
                                    Text("\(futureScheduledItems.count) medication\(futureScheduledItems.count == 1 ? "" : "s") scheduled")
                                        .font(.appBodyMedium)
                                        .foregroundColor(.textPrimary)
                                    Spacer()
                                }
                                .padding(AppDimensions.cardPadding)
                                .background(Color.accentYellow.opacity(0.15))
                                .cornerRadius(AppDimensions.cardCornerRadius)
                                .padding(.horizontal, AppDimensions.screenPadding)

                                // Future scheduled items
                                ForEach(Array(futureScheduledItems.enumerated()), id: \.offset) { _, item in
                                    FutureScheduleCard(medication: item.medication, entry: item.entry)
                                        .padding(.horizontal, AppDimensions.screenPadding)
                                }
                            } else {
                                // Summary for the day (past dates with logs)
                                DaySummaryBanner(logs: logs)
                                    .padding(.horizontal, AppDimensions.screenPadding)

                                // Individual logs
                                ForEach(logs) { log in
                                    if let med = medication(for: log) {
                                        DayLogCard(medication: med, log: log, timeFormatter: timeFormatter)
                                            .padding(.horizontal, AppDimensions.screenPadding)
                                    }
                                }
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

// MARK: - Future Schedule Card
struct FutureScheduleCard: View {
    let medication: Medication
    let entry: ScheduleEntry

    var body: some View {
        HStack {
            // Clock icon
            Image(systemName: "clock")
                .font(.title3)
                .foregroundColor(.accentYellow)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(medication.displayName)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                HStack(spacing: 8) {
                    Text(entry.time)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    if let dosage = entry.dosage {
                        Text("•")
                            .foregroundColor(.textMuted)
                        Text(dosage)
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }

                if let instruction = medication.intakeInstruction {
                    Text(instruction.displayName)
                        .font(.appCaptionSmall)
                        .foregroundColor(.accentYellow)
                }
            }

            Spacer()

            // Scheduled badge
            Text("Scheduled")
                .font(.appCaption)
                .foregroundColor(.accentYellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentYellow.opacity(0.15))
                .cornerRadius(AppDimensions.pillCornerRadius)
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Day Summary Banner
struct DaySummaryBanner: View {
    let logs: [MedicationLog]

    private var takenCount: Int {
        logs.filter { $0.status == .taken }.count
    }

    private var totalCount: Int {
        logs.count
    }

    private var percentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(takenCount) / Double(totalCount)) * 100)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(takenCount) of \(totalCount) taken")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                Text("\(percentage)% adherence")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.cardBackgroundSoft, lineWidth: 4)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: CGFloat(percentage) / 100)
                    .stroke(percentage >= 80 ? Color.badgeGreen : (percentage >= 50 ? Color.accentYellow : Color.medicalRed), lineWidth: 4)
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Text("\(percentage)%")
                    .font(.appCaptionSmall)
                    .foregroundColor(.textPrimary)
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Day Log Card
struct DayLogCard: View {
    let medication: Medication
    let log: MedicationLog
    let timeFormatter: DateFormatter

    var body: some View {
        HStack {
            // Status icon
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundColor(statusColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(medication.displayName)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                Text(timeFormatter.string(from: log.scheduledAt))
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Status badge
            Text(log.status.displayName)
                .font(.appCaption)
                .foregroundColor(statusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.15))
                .cornerRadius(AppDimensions.pillCornerRadius)
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    private var statusIcon: String {
        switch log.status {
        case .taken: return "checkmark.circle.fill"
        case .missed: return "xmark.circle.fill"
        case .skipped: return "forward.fill"
        case .scheduled: return "clock"
        }
    }

    private var statusColor: Color {
        switch log.status {
        case .taken: return .badgeGreen
        case .missed: return .medicalRed
        case .skipped: return .textSecondary
        case .scheduled: return .accentYellow
        }
    }
}

// MARK: - Medication Calendar View Model
@MainActor
class MedicationCalendarViewModel: ObservableObject {
    @Published var currentMonth: Date = Date()
    @Published var medications: [Medication] = []
    @Published var medicationSchedules: [UUID: [MedicationSchedule]] = [:]
    @Published var allLogs: [MedicationLog] = []
    @Published var dayStatuses: [Date: DayAdherenceStatus] = [:]
    @Published var filteredDayStatuses: [Date: DayAdherenceStatus] = [:]
    @Published var selectedMedicationId: UUID?
    @Published var currentStreak: Int = 0
    @Published var monthlySummary: MonthlySummary?
    @Published var isLoading = false
    @Published var error: String?

    private let calendar = Calendar.current

    func loadData(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            // Load medications
            medications = try await appState.medicationRepository.getMedications(accountId: account.id)

            // Load schedules for all medications
            for medication in medications {
                let schedules = try await appState.medicationRepository.getSchedules(medicationId: medication.id)
                medicationSchedules[medication.id] = schedules
            }

            // Load month data
            await loadMonthData(appState: appState)

            // Calculate streak
            await calculateStreak(appState: appState)
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    func loadMonthData(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth)!

        do {
            allLogs = try await appState.medicationRepository.getLogsForAccount(
                accountId: account.id,
                from: startOfMonth,
                to: endOfMonth
            )

            calculateDayStatuses()
            calculateMonthlySummary()
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }
    }

    func calculateDayStatuses() {
        var statuses: [Date: DayAdherenceStatus] = [:]

        // Group logs by day
        let groupedLogs = Dictionary(grouping: allLogs) { log in
            calendar.startOfDay(for: log.scheduledAt)
        }

        for (day, logs) in groupedLogs {
            let status = calculateStatusForDay(logs: logs)
            statuses[day] = status
        }

        // Calculate future scheduled dates
        let today = calendar.startOfDay(for: Date())
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        // Iterate through future days of the month
        var checkDate = max(today, startOfMonth)
        if checkDate == today {
            // Skip today since it might already have logs
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
        }

        while checkDate <= endOfMonth {
            // Check if any medication is scheduled for this date
            if hasMedicationsScheduledFor(date: checkDate) {
                let dayStart = calendar.startOfDay(for: checkDate)
                if statuses[dayStart] == nil {
                    statuses[dayStart] = .scheduled
                }
            }
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? endOfMonth
        }

        dayStatuses = statuses
        updateFilteredStatuses()
    }

    /// Check if any medication is scheduled for a specific future date
    private func hasMedicationsScheduledFor(date: Date) -> Bool {
        let dayOfWeek = calendar.component(.weekday, from: date) - 1 // Convert to 0-6 (Sunday = 0)

        for medication in medications {
            // Skip paused medications
            if medication.isPaused { continue }

            guard let schedules = medicationSchedules[medication.id] else { continue }

            for schedule in schedules {
                // Only check scheduled type (not as-needed)
                guard schedule.scheduleType == .scheduled else { continue }

                // Check if schedule has started
                guard date >= schedule.startDate else { continue }

                // Check if schedule has ended
                if let endDate = schedule.endDate, date > endDate { continue }

                // Check schedule entries
                if let entries = schedule.scheduleEntries, !entries.isEmpty {
                    // Use sequential duration logic
                    if isEntryActiveForDate(entries: entries, scheduleStartDate: schedule.startDate, targetDate: date, dayOfWeek: dayOfWeek) {
                        return true
                    }
                } else if let legacyDays = schedule.daysOfWeek, legacyDays.contains(dayOfWeek) {
                    // Legacy: check days of week
                    return true
                } else if schedule.daysOfWeek == nil {
                    // No days specified = every day
                    return true
                }
            }
        }

        return false
    }

    /// Check if any schedule entry is active for a specific date using sequential duration logic
    private func isEntryActiveForDate(entries: [ScheduleEntry], scheduleStartDate: Date, targetDate: Date, dayOfWeek: Int) -> Bool {
        let sortedEntries = entries.sorted { $0.sortOrder < $1.sortOrder }
        let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: scheduleStartDate), to: calendar.startOfDay(for: targetDate)).day ?? 0

        var cumulativeDays = 0

        for entry in sortedEntries {
            let entryDuration = entry.durationDays ?? Int.max

            let entryStartDay = cumulativeDays
            let entryEndDay = entryDuration == Int.max ? Int.max : cumulativeDays + entryDuration - 1

            if daysSinceStart >= entryStartDay && daysSinceStart <= entryEndDay {
                // This entry is active - check if target day of week is included
                if entry.daysOfWeek.contains(dayOfWeek) {
                    return true
                }
            }

            if entryDuration != Int.max {
                cumulativeDays += entryDuration
            } else {
                break
            }
        }

        return false
    }

    func updateFilteredStatuses() {
        if let medicationId = selectedMedicationId {
            // Filter logs for selected medication
            let filteredLogs = allLogs.filter { $0.medicationId == medicationId }
            var statuses: [Date: DayAdherenceStatus] = [:]

            let groupedLogs = Dictionary(grouping: filteredLogs) { log in
                calendar.startOfDay(for: log.scheduledAt)
            }

            for (day, logs) in groupedLogs {
                let status = calculateStatusForDay(logs: logs)
                statuses[day] = status
            }

            // Add future scheduled dates for the selected medication
            if let medication = medications.first(where: { $0.id == medicationId }) {
                addFutureScheduledDates(for: medication, to: &statuses)
            }

            filteredDayStatuses = statuses
        } else {
            filteredDayStatuses = dayStatuses
        }

        // Also update monthly summary based on filter
        calculateMonthlySummary()
    }

    /// Add future scheduled dates for a specific medication
    private func addFutureScheduledDates(for medication: Medication, to statuses: inout [Date: DayAdherenceStatus]) {
        guard !medication.isPaused,
              let schedules = medicationSchedules[medication.id] else { return }

        let today = calendar.startOfDay(for: Date())
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        var checkDate = max(today, startOfMonth)
        if checkDate == today {
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
        }

        while checkDate <= endOfMonth {
            let dayOfWeek = calendar.component(.weekday, from: checkDate) - 1

            for schedule in schedules {
                // Only check scheduled type (not as-needed)
                guard schedule.scheduleType == .scheduled else { continue }

                // Check if schedule has started
                guard checkDate >= schedule.startDate else { continue }

                // Check if schedule has ended
                if let endDate = schedule.endDate, checkDate > endDate { continue }

                var isScheduled = false

                if let entries = schedule.scheduleEntries, !entries.isEmpty {
                    isScheduled = isEntryActiveForDate(entries: entries, scheduleStartDate: schedule.startDate, targetDate: checkDate, dayOfWeek: dayOfWeek)
                } else if let legacyDays = schedule.daysOfWeek, legacyDays.contains(dayOfWeek) {
                    isScheduled = true
                } else if schedule.daysOfWeek == nil {
                    isScheduled = true
                }

                if isScheduled {
                    let dayStart = calendar.startOfDay(for: checkDate)
                    if statuses[dayStart] == nil {
                        statuses[dayStart] = .scheduled
                    }
                    break // No need to check other schedules for this day
                }
            }

            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? endOfMonth
        }
    }

    private func calculateStatusForDay(logs: [MedicationLog]) -> DayAdherenceStatus {
        guard !logs.isEmpty else { return .noMedications }

        let takenCount = logs.filter { $0.status == .taken }.count
        let totalCount = logs.count

        if takenCount == totalCount {
            return .allTaken
        } else if takenCount > 0 {
            return .partialTaken
        } else {
            return .noneTaken
        }
    }

    func calculateMonthlySummary() {
        let logsToUse = selectedMedicationId != nil
            ? allLogs.filter { $0.medicationId == selectedMedicationId }
            : allLogs

        let takenCount = logsToUse.filter { $0.status == .taken }.count
        let missedCount = logsToUse.filter { $0.status == .missed }.count
        let skippedCount = logsToUse.filter { $0.status == .skipped }.count
        let scheduledCount = logsToUse.filter { $0.status == .scheduled }.count

        monthlySummary = MonthlySummary(
            takenCount: takenCount,
            missedCount: missedCount,
            skippedCount: skippedCount,
            scheduledCount: scheduledCount
        )
    }

    func calculateStreak(appState: AppState) async {
        guard let account = appState.currentAccount else { return }

        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Go back day by day checking for 100% adherence
        while true {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate)!

            do {
                let dayLogs = try await appState.medicationRepository.getLogsForAccount(
                    accountId: account.id,
                    from: checkDate,
                    to: nextDay
                )

                // If no medications scheduled, skip this day but don't break streak
                if dayLogs.isEmpty {
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                    // Limit how far back we go to find scheduled days
                    if streak == 0 && calendar.dateComponents([.day], from: checkDate, to: Date()).day ?? 0 > 30 {
                        break
                    }
                    continue
                }

                let allTaken = dayLogs.allSatisfy { $0.status == .taken }

                if allTaken {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                } else {
                    break
                }

                // Safety limit
                if streak > 365 { break }
            } catch {
                break
            }
        }

        currentStreak = streak
    }

    func getLogsForDate(_ date: Date) -> [MedicationLog] {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        var logs = allLogs.filter { log in
            log.scheduledAt >= dayStart && log.scheduledAt < dayEnd
        }

        // Apply medication filter if selected
        if let medicationId = selectedMedicationId {
            logs = logs.filter { $0.medicationId == medicationId }
        }

        return logs.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    /// Get scheduled medications for a future date (no logs exist yet)
    func getScheduledMedicationsForDate(_ date: Date) -> [(medication: Medication, entry: ScheduleEntry)] {
        let dayOfWeek = calendar.component(.weekday, from: date) - 1

        var scheduledItems: [(medication: Medication, entry: ScheduleEntry)] = []

        for medication in medications {
            // Skip paused medications
            if medication.isPaused { continue }

            // Apply filter if selected
            if let filterMedId = selectedMedicationId, medication.id != filterMedId {
                continue
            }

            guard let schedules = medicationSchedules[medication.id] else { continue }

            for schedule in schedules {
                guard schedule.scheduleType == .scheduled else { continue }
                guard date >= schedule.startDate else { continue }
                if let endDate = schedule.endDate, date > endDate { continue }

                if let entries = schedule.scheduleEntries, !entries.isEmpty {
                    // Check each entry with sequential duration logic
                    let activeEntries = getActiveScheduleEntries(
                        entries: entries,
                        scheduleStartDate: schedule.startDate,
                        targetDate: date,
                        dayOfWeek: dayOfWeek
                    )
                    for entry in activeEntries {
                        scheduledItems.append((medication: medication, entry: entry))
                    }
                } else if let legacyDays = schedule.daysOfWeek, legacyDays.contains(dayOfWeek) {
                    // Legacy schedule - create a virtual entry
                    if let times = schedule.legacyTimes {
                        for time in times {
                            let entry = ScheduleEntry(
                                time: time,
                                dosage: schedule.doseDescription,
                                daysOfWeek: legacyDays
                            )
                            scheduledItems.append((medication: medication, entry: entry))
                        }
                    }
                } else if schedule.daysOfWeek == nil {
                    // Every day - create entries from legacy times
                    if let times = schedule.legacyTimes {
                        for time in times {
                            let entry = ScheduleEntry(
                                time: time,
                                dosage: schedule.doseDescription,
                                daysOfWeek: [0, 1, 2, 3, 4, 5, 6]
                            )
                            scheduledItems.append((medication: medication, entry: entry))
                        }
                    }
                }
            }
        }

        // Sort by time
        return scheduledItems.sorted { $0.entry.time < $1.entry.time }
    }

    /// Get active schedule entries for a date using sequential duration logic
    private func getActiveScheduleEntries(entries: [ScheduleEntry], scheduleStartDate: Date, targetDate: Date, dayOfWeek: Int) -> [ScheduleEntry] {
        let sortedEntries = entries.sorted { $0.sortOrder < $1.sortOrder }
        let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: scheduleStartDate), to: calendar.startOfDay(for: targetDate)).day ?? 0

        var cumulativeDays = 0
        var activeEntries: [ScheduleEntry] = []

        for entry in sortedEntries {
            let entryDuration = entry.durationDays ?? Int.max

            let entryStartDay = cumulativeDays
            let entryEndDay = entryDuration == Int.max ? Int.max : cumulativeDays + entryDuration - 1

            if daysSinceStart >= entryStartDay && daysSinceStart <= entryEndDay {
                if entry.daysOfWeek.contains(dayOfWeek) {
                    activeEntries.append(entry)
                }
            }

            if entryDuration != Int.max {
                cumulativeDays += entryDuration
            } else {
                break
            }
        }

        return activeEntries
    }

    /// Check if a date is in the future (past today)
    func isFutureDate(_ date: Date) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        return checkDate > today
    }

    func goToPreviousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    func goToNextMonth() {
        let today = Date()
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth),
           newMonth <= today {
            currentMonth = newMonth
        }
    }

    func goToToday() {
        currentMonth = Date()
    }
}

// MARK: - Add Medication View
struct AddMedicationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    var onDismiss: (() -> Void)? = nil
    let onSave: (Medication) -> Void

    @State private var name = ""
    @State private var strength = ""
    @State private var form = ""
    @State private var reason = ""
    @State private var notes = ""
    @State private var intakeInstruction: IntakeInstruction?
    @State private var scheduleType: ScheduleType = .scheduled
    @State private var scheduleEntries: [ScheduleEntry] = [ScheduleEntry(time: "08:00")]
    @State private var selectedImage: UIImage?
    @State private var doseDescription = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let forms = ["Tablet", "Capsule", "Liquid", "Injection", "Inhaler", "Patch", "Cream", "Drops", "Spray", "Other"]

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

                    Text("Add Medication")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        Task { await saveMedication() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(name.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                            )
                    }
                    .disabled(name.isBlank || isLoading)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 24) {

                        // Photo picker
                        HStack {
                            Spacer()
                            ImageSourcePicker(
                                selectedImage: $selectedImage,
                                currentImagePath: nil,
                                onImageSelected: { _ in }
                            )
                            Spacer()
                        }

                        // Basic info
                        VStack(spacing: 16) {
                            AppTextField(placeholder: "Medication Name *", text: $name)
                            AppTextField(placeholder: "Strength (e.g., 10mg)", text: $strength)

                            // Form picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Form")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(forms, id: \.self) { formOption in
                                            Button {
                                                form = formOption.lowercased()
                                            } label: {
                                                Text(formOption)
                                                    .font(.appCaption)
                                                    .foregroundColor(form == formOption.lowercased() ? .black : .textPrimary)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .background(form == formOption.lowercased() ? appAccentColor : Color.cardBackgroundSoft)
                                                    .cornerRadius(20)
                                            }
                                        }
                                    }
                                }
                            }

                            AppTextField(placeholder: "Reason for taking", text: $reason)

                            // Intake instruction picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Intake Instructions")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        // None option
                                        Button {
                                            intakeInstruction = nil
                                        } label: {
                                            Text("None")
                                                .font(.appCaption)
                                                .foregroundColor(intakeInstruction == nil ? .black : .textPrimary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(intakeInstruction == nil ? appAccentColor : Color.cardBackgroundSoft)
                                                .cornerRadius(20)
                                        }

                                        ForEach(IntakeInstruction.allCases, id: \.self) { instruction in
                                            Button {
                                                intakeInstruction = instruction
                                            } label: {
                                                Text(instruction.displayName)
                                                    .font(.appCaption)
                                                    .foregroundColor(intakeInstruction == instruction ? .black : .textPrimary)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .background(intakeInstruction == instruction ? appAccentColor : Color.cardBackgroundSoft)
                                                    .cornerRadius(20)
                                            }
                                        }
                                    }
                                }
                            }

                            AppTextField(placeholder: "Notes (optional)", text: $notes)
                        }

                        // Schedule section
                        VStack(alignment: .leading, spacing: 16) {
                            // Schedule type
                            HStack(spacing: 12) {
                                ForEach(ScheduleType.allCases, id: \.self) { type in
                                    Button {
                                        scheduleType = type
                                    } label: {
                                        Text(type.displayName)
                                            .font(.appCaption)
                                            .foregroundColor(scheduleType == type ? .black : .textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(scheduleType == type ? appAccentColor : Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }

                            if scheduleType == .scheduled {
                                // Schedule entries list with modal
                                ScheduleEntriesListView(entries: $scheduleEntries)
                            }

                            if scheduleType == .asNeeded {
                                AppTextField(placeholder: "Dose (e.g., 2 tablets)", text: $doseDescription)
                            }
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

    private func saveMedication() async {
        guard let account = appState.currentAccount else { return }

        guard let primaryProfile = try? await appState.profileRepository.getPrimaryProfile(accountId: account.id) else {
            errorMessage = "No primary profile found"
            return
        }

        isLoading = true
        errorMessage = nil

        // Save photo locally if selected
        var localImagePath: String?
        let tempMedicationId = UUID()
        if let image = selectedImage {
            localImagePath = LocalImageService.shared.saveMedicationPhoto(image, medicationId: tempMedicationId)
        }

        let medicationInsert = MedicationInsert(
            accountId: account.id,
            profileId: primaryProfile.id,
            name: name,
            strength: strength.isBlank ? nil : strength,
            form: form.isBlank ? nil : form,
            reason: reason.isBlank ? nil : reason,
            notes: notes.isBlank ? nil : notes,
            localImagePath: localImagePath,
            intakeInstruction: intakeInstruction
        )

        do {
            var medication = try await appState.medicationRepository.createMedication(medicationInsert)

            // If we saved a photo with temp ID, rename it with actual medication ID
            if let oldPath = localImagePath {
                LocalImageService.shared.deleteMedicationPhoto(fileName: oldPath)
                if let image = selectedImage {
                    let newPath = LocalImageService.shared.saveMedicationPhoto(image, medicationId: medication.id)
                    medication.localImagePath = newPath
                    medication = try await appState.medicationRepository.updateMedication(medication)
                }
            }

            // Create schedule if needed
            if scheduleType == .scheduled && !scheduleEntries.isEmpty {
                let scheduleInsert = MedicationScheduleInsert(
                    accountId: account.id,
                    medicationId: medication.id,
                    scheduleType: scheduleType,
                    scheduleEntries: scheduleEntries,
                    doseDescription: nil
                )
                _ = try await appState.medicationRepository.createSchedule(scheduleInsert)

                // Schedule notifications for each entry
                for entry in scheduleEntries {
                    if let scheduledTime = timeStringToDate(entry.time) {
                        await NotificationService.shared.scheduleMedicationReminder(
                            medicationId: medication.id,
                            medicationName: medication.name,
                            scheduledTime: scheduledTime,
                            doseDescription: entry.dosage
                        )
                    }
                }
            } else if scheduleType == .asNeeded {
                let scheduleInsert = MedicationScheduleInsert(
                    accountId: account.id,
                    medicationId: medication.id,
                    scheduleType: scheduleType,
                    doseDescription: doseDescription.isBlank ? nil : doseDescription
                )
                _ = try await appState.medicationRepository.createSchedule(scheduleInsert)
            }

            // Generate today's logs
            try await appState.medicationRepository.regenerateTodaysLogs(
                medicationId: medication.id,
                accountId: account.id
            )

            onSave(medication)
            dismissView()
        } catch {
            errorMessage = "Failed to save medication: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func timeStringToDate(_ timeString: String) -> Date? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count >= 2 else { return nil }

        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = components[0]
        dateComponents.minute = components[1]

        return calendar.date(from: dateComponents)
    }
}

// MARK: - Edit Medication View
struct EditMedicationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let medication: Medication
    var onDismiss: (() -> Void)? = nil
    let onSave: (Medication) -> Void

    @State private var name: String
    @State private var strength: String
    @State private var form: String
    @State private var reason: String
    @State private var notes: String
    @State private var intakeInstruction: IntakeInstruction?
    @State private var scheduleType: ScheduleType = .scheduled
    @State private var scheduleEntries: [ScheduleEntry] = []
    @State private var doseDescription: String = ""
    @State private var existingSchedule: MedicationSchedule?
    @State private var selectedImage: UIImage?

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    private let forms = ["Tablet", "Capsule", "Liquid", "Injection", "Inhaler", "Patch", "Cream", "Drops", "Spray", "Other"]

    init(medication: Medication, onDismiss: (() -> Void)? = nil, onSave: @escaping (Medication) -> Void) {
        self.medication = medication
        self.onDismiss = onDismiss
        self.onSave = onSave
        _name = State(initialValue: medication.name)
        _strength = State(initialValue: medication.strength ?? "")
        _form = State(initialValue: medication.form ?? "")
        _reason = State(initialValue: medication.reason ?? "")
        _notes = State(initialValue: medication.notes ?? "")
        _intakeInstruction = State(initialValue: medication.intakeInstruction)
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

                    Text("Edit Medication")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        Task { await saveMedication() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(name.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                            )
                    }
                    .disabled(name.isBlank || isLoading)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 24) {
                        // Photo picker
                        HStack {
                            Spacer()
                            ImageSourcePicker(
                                selectedImage: $selectedImage,
                                currentImagePath: medication.localImagePath,
                                onImageSelected: { _ in }
                            )
                            Spacer()
                        }

                        // Basic info
                        VStack(spacing: 16) {
                            AppTextField(placeholder: "Medication Name *", text: $name)
                            AppTextField(placeholder: "Strength (e.g., 10mg)", text: $strength)

                            // Form picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Form")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(forms, id: \.self) { formOption in
                                            Button {
                                                form = formOption.lowercased()
                                            } label: {
                                                Text(formOption)
                                                    .font(.appCaption)
                                                    .foregroundColor(form == formOption.lowercased() ? .black : .textPrimary)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .background(form == formOption.lowercased() ? appAccentColor : Color.cardBackgroundSoft)
                                                    .cornerRadius(20)
                                            }
                                        }
                                    }
                                }
                            }

                            AppTextField(placeholder: "Reason for taking", text: $reason)

                            // Intake instruction picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Intake Instructions")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        Button {
                                            intakeInstruction = nil
                                        } label: {
                                            Text("None")
                                                .font(.appCaption)
                                                .foregroundColor(intakeInstruction == nil ? .black : .textPrimary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(intakeInstruction == nil ? appAccentColor : Color.cardBackgroundSoft)
                                                .cornerRadius(20)
                                        }

                                        ForEach(IntakeInstruction.allCases, id: \.self) { instruction in
                                            Button {
                                                intakeInstruction = instruction
                                            } label: {
                                                Text(instruction.displayName)
                                                    .font(.appCaption)
                                                    .foregroundColor(intakeInstruction == instruction ? .black : .textPrimary)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .background(intakeInstruction == instruction ? appAccentColor : Color.cardBackgroundSoft)
                                                    .cornerRadius(20)
                                            }
                                        }
                                    }
                                }
                            }

                            AppTextField(placeholder: "Notes (optional)", text: $notes)
                        }

                        // Schedule section
                        VStack(alignment: .leading, spacing: 16) {
                            // Schedule type
                            HStack(spacing: 12) {
                                ForEach(ScheduleType.allCases, id: \.self) { type in
                                    Button {
                                        scheduleType = type
                                    } label: {
                                        Text(type.displayName)
                                            .font(.appCaption)
                                            .foregroundColor(scheduleType == type ? .black : .textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(scheduleType == type ? appAccentColor : Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }

                            if scheduleType == .scheduled {
                                ScheduleEntriesListView(entries: $scheduleEntries)
                            }

                            if scheduleType == .asNeeded {
                                AppTextField(placeholder: "Dose (e.g., 2 tablets)", text: $doseDescription)
                            }
                        }

                        // Delete button
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Medication")
                            }
                            .font(.appBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.medicalRed)
                            .cornerRadius(AppDimensions.buttonCornerRadius)
                        }
                        .padding(.top, 16)

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
            .task {
                await loadSchedule()
            }
            .alert("Delete Medication", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await deleteMedication() }
                }
            } message: {
                Text("Are you sure you want to delete this medication? This action cannot be undone.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.clear, for: .navigationBar)
        .containerBackground(.clear, for: .navigation)
    }

    private func loadSchedule() async {
        do {
            let schedules = try await appState.medicationRepository.getSchedules(medicationId: medication.id)
            if let schedule = schedules.first {
                existingSchedule = schedule
                scheduleType = schedule.scheduleType

                // Load schedule entries or convert legacy times
                if let entries = schedule.scheduleEntries, !entries.isEmpty {
                    scheduleEntries = entries
                } else if let times = schedule.times {
                    // Convert legacy times to schedule entries
                    scheduleEntries = times.enumerated().map { index, time in
                        ScheduleEntry(
                            time: time,
                            dosage: schedule.doseDescription,
                            daysOfWeek: schedule.daysOfWeek ?? [0, 1, 2, 3, 4, 5, 6],
                            sortOrder: index
                        )
                    }
                }

                doseDescription = schedule.doseDescription ?? ""
            }

            if scheduleEntries.isEmpty {
                scheduleEntries = [ScheduleEntry(time: "08:00")]
            }
        } catch {
            scheduleEntries = [ScheduleEntry(time: "08:00")]
        }
    }

    private func saveMedication() async {
        guard let account = appState.currentAccount else { return }

        isLoading = true
        errorMessage = nil

        // Update photo if changed
        var localImagePath = medication.localImagePath
        if let image = selectedImage {
            // Delete old photo if exists
            if let oldPath = medication.localImagePath {
                LocalImageService.shared.deleteMedicationPhoto(fileName: oldPath)
            }
            localImagePath = LocalImageService.shared.saveMedicationPhoto(image, medicationId: medication.id)
        }

        // Create updated medication
        var updatedMedication = medication
        updatedMedication.name = name
        updatedMedication.strength = strength.isBlank ? nil : strength
        updatedMedication.form = form.isBlank ? nil : form
        updatedMedication.reason = reason.isBlank ? nil : reason
        updatedMedication.notes = notes.isBlank ? nil : notes
        updatedMedication.intakeInstruction = intakeInstruction
        updatedMedication.localImagePath = localImagePath

        do {
            let savedMedication = try await appState.medicationRepository.updateMedication(updatedMedication)

            // Update or create schedule
            if let existingSchedule = existingSchedule {
                var updatedSchedule = existingSchedule
                updatedSchedule.scheduleType = scheduleType
                updatedSchedule.scheduleEntries = scheduleType == .scheduled ? scheduleEntries : nil
                updatedSchedule.doseDescription = scheduleType == .asNeeded && !doseDescription.isBlank ? doseDescription : nil
                _ = try await appState.medicationRepository.updateSchedule(updatedSchedule)
            } else if scheduleType == .scheduled && !scheduleEntries.isEmpty {
                let scheduleInsert = MedicationScheduleInsert(
                    accountId: account.id,
                    medicationId: medication.id,
                    scheduleType: scheduleType,
                    scheduleEntries: scheduleEntries,
                    doseDescription: nil
                )
                _ = try await appState.medicationRepository.createSchedule(scheduleInsert)
            } else if scheduleType == .asNeeded {
                let scheduleInsert = MedicationScheduleInsert(
                    accountId: account.id,
                    medicationId: medication.id,
                    scheduleType: scheduleType,
                    doseDescription: doseDescription.isBlank ? nil : doseDescription
                )
                _ = try await appState.medicationRepository.createSchedule(scheduleInsert)
            }

            // Regenerate today's logs with new schedule
            try await appState.medicationRepository.regenerateTodaysLogs(
                medicationId: medication.id,
                accountId: account.id
            )

            onSave(savedMedication)
            dismissView()
        } catch {
            errorMessage = "Failed to save medication: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func deleteMedication() async {
        isLoading = true

        do {
            // Delete local photo if exists
            if let localPath = medication.localImagePath {
                LocalImageService.shared.deleteMedicationPhoto(fileName: localPath)
            }

            try await appState.medicationRepository.deleteMedication(id: medication.id)
            dismissView()
        } catch {
            errorMessage = "Failed to delete medication: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        MedicationListView()
            .environmentObject(AppState())
    }
}
