import SwiftUI

// MARK: - Medication List View
struct MedicationListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.iPadAddMedicationAction) private var iPadAddMedicationAction
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appAccentColor) private var appAccentColor
    @StateObject private var viewModel = MedicationListViewModel()
    @State private var showAddMedication = false
    @State private var showUpgradePrompt = false
    @State private var medicationToDelete: Medication?
    @State private var showDeleteConfirmation = false
    @State private var listContentHeight: CGFloat = 0

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
        // Only show sidePanel on iPhone - iPad handles this at iPadRootView level
        .sidePanel(isPresented: iPadHomeAction == nil ? $showAddMedication : .constant(false)) {
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
            await viewModel.loadMedications(appState: appState, forceRefresh: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationsDidChange)) { _ in
            Task {
                await viewModel.loadMedications(appState: appState, forceRefresh: true)
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
                        title: "Medications",
                        showBackButton: iPadHomeAction == nil,
                        backAction: { dismiss() },
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction,
                        showAddButton: canEdit,
                        addAction: canEdit ? {
                            // On iPad, use the environment action to trigger the root-level panel
                            if let iPadAddAction = iPadAddMedicationAction {
                                iPadAddAction()
                            } else {
                                // On iPhone, use local state
                                if canAddMedication {
                                    showAddMedication = true
                                } else {
                                    showUpgradePrompt = true
                                }
                            }
                        } : nil,
                        tutorialVideoURL: "https://unforgottenapp.com/tutorials/Medications.mp4"
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
                                .foregroundColor(appAccentColor)

                            Text("Medication History")
                                .font(.appCardTitle)
                                .foregroundColor(.white)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(AppDimensions.cardPaddingLarge)
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                    }

                    // Medications list with swipe-to-delete
                    if !viewModel.medications.isEmpty {
                        List {
                            ForEach(viewModel.medications) { medication in
                                ZStack {
                                    NavigationLink(destination: MedicationDetailView(medication: medication)) {
                                        EmptyView()
                                    }
                                    .opacity(0)

                                    MedicationListRow(medication: medication)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if canEdit {
                                        Button(role: .destructive) {
                                            medicationToDelete = medication
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.medicalRed)
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
                        .onChange(of: viewModel.medications.count) { _, count in
                            let rowHeight: CGFloat = 80
                            let spacing: CGFloat = AppDimensions.cardSpacing
                            listContentHeight = CGFloat(count) * (rowHeight + spacing)
                        }
                        .onAppear {
                            let rowHeight: CGFloat = 80
                            let spacing: CGFloat = AppDimensions.cardSpacing
                            listContentHeight = CGFloat(viewModel.medications.count) * (rowHeight + spacing)
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
                            //icon: "pills.fill",
                            title: "No medications yet",
                            message: "Add medications to track schedules and reminders",
                            buttonTitle: "Add Medication",
                            buttonAction: {
                                // On iPad, use the environment action to trigger the root-level panel
                                if let iPadAddAction = iPadAddMedicationAction {
                                    iPadAddAction()
                                } else {
                                    // On iPhone, use local state
                                    if canAddMedication {
                                        showAddMedication = true
                                    } else {
                                        showUpgradePrompt = true
                                    }
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
    @Environment(\.appAccentColor) private var appAccentColor

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
                    .background(appAccentColor)
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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appAccentColor) private var appAccentColor

    /// Adaptive thumbnail size: larger on iPad
    private var thumbnailSize: CGFloat {
        horizontalSizeClass == .regular ? 52 : 44
    }

    var body: some View {
        HStack {
                HStack {
                    // Photo thumbnail
                    if let urlString = medication.imageUrl {
                        SignedAsyncImage(reference: urlString) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: thumbnailSize, height: thumbnailSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            default:
                                Image(systemName: "pills.fill")
                                    .font(.system(size: horizontalSizeClass == .regular ? 28 : 24))
                                    .foregroundColor(appAccentColor)
                                    .frame(width: thumbnailSize, height: thumbnailSize)
                                    .background(Color.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    } else {
                        Image(systemName: "pills.fill")
                            .font(.system(size: horizontalSizeClass == .regular ? 28 : 24))
                            .foregroundColor(appAccentColor)
                            .frame(width: thumbnailSize, height: thumbnailSize)
                            .background(Color.cardBackground)
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
                                .foregroundColor(appAccentColor)
                        }
                    }

                    Spacer()
                }
            }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .opacity(medication.isPaused ? 0.7 : 1.0)
    }
}

// MARK: - Medication List View Model
@MainActor
class MedicationListViewModel: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadMedications(appState: AppState, forceRefresh: Bool = false) async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            if forceRefresh {
                medications = try await appState.medicationRepository.refreshMedications(accountId: account.id)
            } else {
                medications = try await appState.medicationRepository.getMedications(accountId: account.id)
            }
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
            NotificationCenter.default.post(name: .medicationsDidChange, object: nil)
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
                .frame(width: 32)

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
    @Environment(\.appAccentColor) private var appAccentColor

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
                        if let urlString = medication.imageUrl {
                            Button {
                                showFullscreenImage = true
                            } label: {
                                SignedAsyncImage(reference: urlString) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius))
                                    case .empty:
                                        ProgressView()
                                            .frame(height: 200)
                                    default:
                                        EmptyView()
                                    }
                                }
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
                                .background(appAccentColor)
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



                        // Schedule section
                        if !viewModel.schedules.isEmpty {
                            VStack(alignment: .leading, spacing: AppDimensions.cardSpacing) {
                                Text("SCHEDULE")
                                    .font(.appCaption)
                                    .foregroundColor(appAccentColor)
                                    .padding(.horizontal, AppDimensions.screenPadding)

                                ForEach(viewModel.schedules) { schedule in
                                    ScheduleCard(schedule: schedule)
                                }
                                .padding(.horizontal, AppDimensions.screenPadding)
                            }
                        }

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
                                //.background(Color.cardBackgroundSoft)
                                .cornerRadius(AppDimensions.cardCornerRadius)
                            }
                            .disabled(isTogglingPause)
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
            if let urlString = medication.imageUrl {
                RemoteFullscreenImageView(imageUrl: urlString, title: medication.displayName)
            }
        }
        .task {
            await viewModel.loadSchedules(medicationId: medication.id, appState: appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationsDidChange)) { _ in
            Task {
                // Reload medication details (iPad edit panel dismisses without updating local state)
                if let updated = try? await appState.medicationRepository.getMedication(id: medication.id) {
                    medication = updated
                }
                await viewModel.loadSchedules(medicationId: medication.id, appState: appState)
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
    @Environment(\.appAccentColor) private var appAccentColor
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
                        .foregroundColor(appAccentColor)
                    Text(times.joined(separator: ", "))
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                if let days = schedule.daysOfWeek {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(appAccentColor)
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
    @Environment(\.appAccentColor) private var appAccentColor

    private var daysText: String {
        let days = entry.daysOfWeek.sorted()
        if days.count == 7 { return "Daily" }
        if days == [1, 2, 3, 4, 5] { return "Weekdays" }
        if days == [0, 6] { return "Weekends" }
        return days.compactMap { $0 < Calendar.daysOfWeek.count ? Calendar.daysOfWeek[$0] : nil }.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 8) {
            // Time
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .foregroundColor(appAccentColor)
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

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.cardBackground)
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
                // Header scrolls with content - uses style-based assets from HeaderStyleManager
                CustomizableHeaderView(
                    pageIdentifier: .medications,
                    title: "Medication History",
                    showBackButton: true,
                    backAction: { dismiss() },
                    showCustomizeButton: false
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
                    futureScheduledItems: viewModel.isFutureDate(date) ? viewModel.getScheduledMedicationsForDate(date) : [],
                    onLogUpdated: {
                        await viewModel.loadMonthData(appState: appState)
                    }
                )
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Streak Banner
struct StreakBanner: View {
    let streak: Int
    @Environment(\.appAccentColor) private var appAccentColor

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
                colors: [Color.orange.opacity(0.2), appAccentColor.opacity(0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(AppDimensions.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                .stroke(Color.orange.opacity(0.3), lineWidth: 0)
        )
    }
}

// MARK: - Month Navigation Header
struct MonthNavigationHeader: View {
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
                    .foregroundColor(isCurrentMonth ? .textSecondary.opacity(0.3) : appAccentColor)
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
    @Environment(\.appAccentColor) private var appAccentColor

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
                .background(isSelected ? appAccentColor : Color.cardBackground)
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

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let date: Date
    let status: DayAdherenceStatus?
    let isToday: Bool
    let isFuture: Bool
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor

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
                        .fill(status.color(accent: appAccentColor))
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? appAccentColor : Color.clear, lineWidth: 0)
            )
        }
    }

    private var textColor: Color {
        if isFuture && status != .scheduled {
            return .textSecondary.opacity(0.4)
        } else if isFuture && status == .scheduled {
            return .textSecondary.opacity(0.7)
        } else if isToday {
            return appAccentColor
        } else {
            return .textPrimary
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return appAccentColor.opacity(0.2)
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

    func color(accent: Color) -> Color {
        switch self {
        case .allTaken: return .badgeGreen
        case .partialTaken: return accent
        case .noneTaken: return .medicalRed
        case .noMedications: return .textSecondary.opacity(0.3)
        case .scheduled: return accent.opacity(0.6)
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
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                LegendItem(color: .badgeGreen, label: "All taken")
                LegendItem(color: .accentYellow, label: "Partial")
                LegendItem(color: .medicalRed, label: "Missed")
            }
            HStack(spacing: 16) {
                LegendItem(color: appAccentColor.opacity(0.6), label: "Scheduled")
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
    @Environment(\.appAccentColor) private var appAccentColor

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
                    color: summary.adherencePercentage >= 80 ? .badgeGreen : (summary.adherencePercentage >= 50 ? appAccentColor : .medicalRed)
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
    @Environment(\.appAccentColor) private var appAccentColor
    @EnvironmentObject var appState: AppState

    let date: Date
    @State var logs: [MedicationLog]
    let medications: [Medication]
    var futureScheduledItems: [(medication: Medication, entry: ScheduleEntry)] = []
    var onLogUpdated: (() async -> Void)?

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

    private func nextStatus(for status: MedicationLogStatus) -> MedicationLogStatus {
        switch status {
        case .scheduled: return .taken
        case .taken: return .skipped
        case .skipped: return .missed
        case .missed: return .taken
        }
    }

    private func updateLogStatus(log: MedicationLog) async {
        let newStatus = nextStatus(for: log.status)
        let takenAt: Date? = newStatus == .taken ? Date() : nil

        do {
            let updated = try await appState.medicationRepository.updateLogStatus(
                logId: log.id,
                status: newStatus,
                takenAt: takenAt
            )
            // Update local state
            if let index = logs.firstIndex(where: { $0.id == log.id }) {
                logs[index].status = updated.status
                logs[index].takenAt = updated.takenAt
            }
            // Notify parent to refresh calendar
            await onLogUpdated?()

            // Only marking meds as taken counts as a moment of value
            if newStatus == .taken {
                ReviewRequestService.shared.recordSignificantEventAndMaybeRequest()
            }
        } catch {
            #if DEBUG
            print("Failed to update log status: \(error)")
            #endif
        }
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
                                        .foregroundColor(appAccentColor)
                                    Text("\(futureScheduledItems.count) medication\(futureScheduledItems.count == 1 ? "" : "s") scheduled")
                                        .font(.appBodyMedium)
                                        .foregroundColor(.textPrimary)
                                    Spacer()
                                }
                                .padding(AppDimensions.cardPadding)
                                .background(appAccentColor.opacity(0.15))
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
                                        DayLogCard(
                                            medication: med,
                                            log: log,
                                            timeFormatter: timeFormatter,
                                            onStatusTap: {
                                                Task {
                                                    await updateLogStatus(log: log)
                                                }
                                            }
                                        )
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
                    .foregroundColor(appAccentColor)
                }
            }
        }
    }
}

// MARK: - Future Schedule Card
struct FutureScheduleCard: View {
    @Environment(\.appAccentColor) private var appAccentColor

    let medication: Medication
    let entry: ScheduleEntry

    var body: some View {
        HStack {
            // Clock icon
            Image(systemName: "clock")
                .font(.title3)
                .foregroundColor(appAccentColor)
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
                        .foregroundColor(appAccentColor)
                }
            }

            Spacer()

            // Scheduled badge
            Text("Scheduled")
                .font(.appCaption)
                .foregroundColor(appAccentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(appAccentColor.opacity(0.15))
                .cornerRadius(AppDimensions.pillCornerRadius)
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Day Summary Banner
struct DaySummaryBanner: View {
    @Environment(\.appAccentColor) private var appAccentColor

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
                    .stroke(Color.cardBackground, lineWidth: 4)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: CGFloat(percentage) / 100)
                    .stroke(percentage >= 80 ? Color.badgeGreen : (percentage >= 50 ? appAccentColor : Color.medicalRed), lineWidth: 4)
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
    var onStatusTap: (() -> Void)?
    @State private var isUpdating = false

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

            // Status badge - tappable if onStatusTap is provided
            if let onStatusTap = onStatusTap {
                Button {
                    onStatusTap()
                } label: {
                    HStack(spacing: 4) {
                        Text(log.status.displayName)
                            .font(.appCaption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(AppDimensions.pillCornerRadius)
                }
                .disabled(isUpdating)
                .opacity(isUpdating ? 0.5 : 1.0)
            } else {
                Text(log.status.displayName)
                    .font(.appCaption)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(AppDimensions.pillCornerRadius)
            }
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
            // First fetch existing logs
            allLogs = try await appState.medicationRepository.getLogsForAccount(
                accountId: account.id,
                from: startOfMonth,
                to: endOfMonth
            )

            // Backfill missed logs for past days that have no records
            let backfilled = try await backfillMissedLogs(appState: appState, startOfMonth: startOfMonth, endOfMonth: endOfMonth)

            // If we backfilled any logs, re-fetch to include them
            if backfilled {
                allLogs = try await appState.medicationRepository.getLogsForAccount(
                    accountId: account.id,
                    from: startOfMonth,
                    to: endOfMonth
                )
            }

            calculateDayStatuses()
            calculateMonthlySummary()
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }
    }

    /// Backfill missed medication logs for past days in the month that have no log records.
    /// Returns true if any logs were backfilled.
    /// Limited to at most 7 days of backfill to avoid excessive DB calls on first load.
    private func backfillMissedLogs(appState: AppState, startOfMonth: Date, endOfMonth: Date) async throws -> Bool {
        guard let account = appState.currentAccount else { return false }

        let today = calendar.startOfDay(for: Date())
        let monthStart = calendar.startOfDay(for: startOfMonth)

        // Only backfill up to yesterday
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return false }

        // Don't backfill if the entire month is in the future
        guard monthStart <= yesterday else { return false }

        // Group existing logs by day to know which days already have logs
        let existingLogDays = Set(allLogs.map { calendar.startOfDay(for: $0.scheduledAt) })

        // Limit backfill to the last 7 days to avoid excessive DB calls
        let maxBackfillStart = calendar.date(byAdding: .day, value: -7, to: today) ?? monthStart
        var checkDate = max(monthStart, maxBackfillStart)
        guard let dayBeforeEndOfMonth = calendar.date(byAdding: .day, value: -1, to: endOfMonth) else { return false }
        let backfillEnd = min(yesterday, dayBeforeEndOfMonth)
        var didBackfill = false

        while checkDate <= backfillEnd {
            let dayStart = calendar.startOfDay(for: checkDate)

            // Only backfill days that have no existing logs AND have scheduled medications
            if !existingLogDays.contains(dayStart) && hasMedicationsScheduledFor(date: checkDate) {
                // Generate log entries for this past day
                try await appState.medicationRepository.generateDailyLogs(accountId: account.id, date: checkDate)

                // Fetch the newly created logs and mark them as missed
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
                let newLogs = try await appState.medicationRepository.getLogsForAccount(
                    accountId: account.id,
                    from: dayStart,
                    to: nextDay
                )

                for log in newLogs where log.status == .scheduled {
                    _ = try await appState.medicationRepository.updateLogStatus(
                        logId: log.id,
                        status: .missed,
                        takenAt: nil
                    )
                }

                didBackfill = true
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
            checkDate = nextDay
        }

        return didBackfill
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
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else {
                dayStatuses = statuses
                updateFilteredStatuses()
                return
            }
            checkDate = nextDay
        }

        while checkDate <= endOfMonth {
            // Check if any medication is scheduled for this date
            if hasMedicationsScheduledFor(date: checkDate) {
                let dayStart = calendar.startOfDay(for: checkDate)
                if statuses[dayStart] == nil {
                    statuses[dayStart] = .scheduled
                }
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
            checkDate = nextDay
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

    /// Check if any schedule entry is active for a specific date
    private func isEntryActiveForDate(entries: [ScheduleEntry], scheduleStartDate: Date, targetDate: Date, dayOfWeek: Int) -> Bool {
        return entries.contains { $0.daysOfWeek.contains(dayOfWeek) }
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
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else { return }
            checkDate = nextDay
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

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
            checkDate = nextDay
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

        let today = calendar.startOfDay(for: Date())

        // Fetch last 60 days of logs in a single query instead of one query per day
        guard let rangeStart = calendar.date(byAdding: .day, value: -60, to: today),
              let rangeEnd = calendar.date(byAdding: .day, value: 1, to: today) else {
            currentStreak = 0
            return
        }

        do {
            let recentLogs = try await appState.medicationRepository.getLogsForAccount(
                accountId: account.id,
                from: rangeStart,
                to: rangeEnd
            )

            // Group logs by day
            let groupedLogs = Dictionary(grouping: recentLogs) { log in
                calendar.startOfDay(for: log.scheduledAt)
            }

            var streak = 0
            var checkDate = today

            // Go back day by day using the pre-fetched data
            while true {
                guard let dayLogs = groupedLogs[checkDate] else {
                    // No logs for this day - skip but don't break streak
                    guard let prevDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                    checkDate = prevDay
                    // Limit how far back we go to find scheduled days
                    if streak == 0 && calendar.dateComponents([.day], from: checkDate, to: today).day ?? 0 > 30 {
                        break
                    }
                    // Don't go past our fetched range
                    if checkDate < rangeStart { break }
                    continue
                }

                let allTaken = dayLogs.allSatisfy { $0.status == .taken }

                if allTaken {
                    streak += 1
                    guard let prevDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                    checkDate = prevDay
                    if checkDate < rangeStart { break }
                } else {
                    break
                }
            }

            currentStreak = streak
        } catch {
            currentStreak = 0
        }
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

    /// Get active schedule entries for a date
    private func getActiveScheduleEntries(entries: [ScheduleEntry], scheduleStartDate: Date, targetDate: Date, dayOfWeek: Int) -> [ScheduleEntry] {
        return entries.filter { $0.daysOfWeek.contains(dayOfWeek) }
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

    // MARK: - Step

    enum Step: Int, CaseIterable {
        case name
        case type
        case strength
        case intake
        case frequency
        case schedule
        case summary
    }

    @State private var step: Step = .name

    // MARK: - Form fields

    @State private var name = ""
    @State private var strengthValue = ""
    @State private var strengthUnit = ""
    @State private var form = ""
    @State private var reason = ""
    @State private var notes = ""
    @State private var intakeInstruction: IntakeInstruction?
    @State private var scheduleType: ScheduleType = .scheduled
    @State private var selectedImage: UIImage?
    @State private var doseDescription = ""

    // Schedule (single inline schedule with per-time dosage)
    @State private var selectedDays: [Int] = [0, 1, 2, 3, 4, 5, 6]
    @State private var timeRows: [TimeDosageRow] = [TimeDosageRow()]
    @State private var startDate: Date = Date()
    @State private var useDuration = false
    @State private var durationValue = 7
    @State private var durationUnit: DurationUnit = .days
    @State private var showEndDate = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    @State private var isLoading = false
    @State private var errorMessage: String?

    /// A time slot paired with its own dosage.
    struct TimeDosageRow: Identifiable, Equatable {
        let id = UUID()
        var time: Date = {
            var dc = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            dc.hour = 8
            dc.minute = 0
            return Calendar.current.date(from: dc) ?? Date()
        }()
        var dosage: String = ""
    }

    private let forms = ["Tablet", "Capsule", "Liquid", "Cream", "Inhaler", "Injection", "Other"]
    private let strengthUnits = ["None", "mg", "mcg", "g", "mL"]

    /// Days ordered Monday-first: [1, 2, 3, 4, 5, 6, 0]
    private let mondayFirstDays = [1, 2, 3, 4, 5, 6, 0]

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    // MARK: - Combined strength string

    private var combinedStrength: String? {
        let value = strengthValue.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        // strengthUnit is empty when "None" is selected — store just the value in that case.
        return strengthUnit.isEmpty ? value : "\(value)\(strengthUnit)"
    }

    // MARK: - Step navigation

    /// The ordered steps for the current flow. The schedule step is skipped when "As Required".
    private var flow: [Step] {
        scheduleType == .scheduled
            ? Step.allCases
            : Step.allCases.filter { $0 != .schedule }
    }

    private var isFirstStep: Bool {
        flow.first == step
    }

    private var isLastStep: Bool {
        flow.last == step
    }

    /// Whether the user can advance from the current step.
    private var canAdvance: Bool {
        switch step {
        case .name:
            return !name.isBlank
        case .schedule:
            return !selectedDays.isEmpty && !timeRows.isEmpty
        default:
            return true
        }
    }

    private func goNext() {
        guard let index = flow.firstIndex(of: step) else { return }
        if index + 1 < flow.count {
            withAnimation { step = flow[index + 1] }
        }
    }

    private func goBack() {
        guard let index = flow.firstIndex(of: step) else { return }
        if index > 0 {
            withAnimation { step = flow[index - 1] }
        } else {
            dismissView()
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    stepContent

                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppDimensions.screenPadding + 12)
                .padding(.top, 48)
                .padding(.bottom, AppDimensions.screenPadding)
            }

            footer
        }
        .background(Color.appBackgroundLight)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Leading slot: back chevron on later steps, otherwise a balancing spacer.
            if isFirstStep {
                Color.clear.frame(width: 48, height: 48)
            } else {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.5))
                        )
                }
            }

            Spacer()

            Text("Add Medication")
                .font(.headline)
                .foregroundColor(.textPrimary)

            Spacer()

            // Trailing slot: cancel icon dismisses the flow on every step.
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
        }
        .padding(.horizontal, AppDimensions.screenPadding + 12)
        .padding(.vertical, 16)
    }

    // MARK: - Footer (Next button)

    @ViewBuilder
    private var footer: some View {
        if isLastStep {
            Button {
                Task { await saveMedication() }
            } label: {
                Text("Done")
                    .font(.appBodyMedium)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(name.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                    .cornerRadius(AppDimensions.cardCornerRadius)
            }
            .disabled(name.isBlank || isLoading)
            .padding(.horizontal, AppDimensions.screenPadding + 12)
            .padding(.vertical, 16)
        } else {
            Button {
                goNext()
            } label: {
                Text("Next")
                    .font(.appBodyMedium)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canAdvance ? appAccentColor : Color.gray.opacity(0.3))
                    .cornerRadius(AppDimensions.cardCornerRadius)
            }
            .disabled(!canAdvance)
            .padding(.horizontal, AppDimensions.screenPadding + 12)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .name:
            nameStep
        case .type:
            typeStep
        case .strength:
            strengthStep
        case .intake:
            intakeStep
        case .frequency:
            frequencyStep
        case .schedule:
            scheduleStep
        case .summary:
            summaryStep
        }
    }

    private func stepTitle(_ text: String) -> some View {
        Text(text)
            .font(.appTitle)
            .foregroundColor(.textPrimary)
    }

    // MARK: Step 1 — Name / Reason / Photo

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Medication Name")
            AppTextField(placeholder: "Add a medication name", text: $name)
            AppTextField(placeholder: "Reason for taking", text: $reason)

            HStack {
                Spacer()
                ImageSourcePicker(
                    selectedImage: $selectedImage,
                    onImageSelected: { _ in }
                )
                Spacer()
            }
            .padding(.top, 8)
        }
    }

    // MARK: Step 2 — Type

    private var typeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Choose a medication type")

            VStack(spacing: 1) {
                ForEach(forms, id: \.self) { formOption in
                    Button {
                        form = formOption.lowercased()
                    } label: {
                        HStack {
                            Text(formOption)
                                .font(.appBody)
                                .foregroundColor(form == formOption.lowercased() ? .black : .textPrimary)
                            Spacer()
                            if form == formOption.lowercased() {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.black)
                            }
                        }
                        .padding()
                        .background(form == formOption.lowercased() ? appAccentColor : Color.cardBackground)
                    }
                }
            }
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }

    // MARK: Step 3 — Strength

    private var strengthStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Strength")
            AppTextField(placeholder: "Add strength", text: $strengthValue)
                .keyboardType(.decimalPad)

            Text("Medication Strength")
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)
                .padding(.top, 8)

            VStack(spacing: 1) {
                ForEach(strengthUnits, id: \.self) { unit in
                    // "None" maps to an empty stored unit (no default selected).
                    let storedUnit = (unit == "None") ? "" : unit
                    let selected = strengthUnit == storedUnit
                    Button {
                        strengthUnit = storedUnit
                    } label: {
                        HStack {
                            Text(unit)
                                .font(.appBody)
                                .foregroundColor(selected ? .black : .textPrimary)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.black)
                            }
                        }
                        .padding()
                        .background(selected ? appAccentColor : Color.cardBackground)
                    }
                }
            }
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }

    // MARK: Step 4 — Intake Instructions

    private var intakeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Intake Instructions")

            VStack(spacing: 1) {
                // None option
                Button {
                    intakeInstruction = nil
                } label: {
                    intakeRow(title: "None", selected: intakeInstruction == nil)
                }

                ForEach(IntakeInstruction.allCases, id: \.self) { instruction in
                    Button {
                        intakeInstruction = instruction
                    } label: {
                        intakeRow(title: instruction.displayName, selected: intakeInstruction == instruction)
                    }
                }
            }
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }

    private func intakeRow(title: String, selected: Bool) -> some View {
        HStack {
            Text(title)
                .font(.appBody)
                .foregroundColor(selected ? .black : .textPrimary)
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundColor(.black)
            }
        }
        .padding()
        .background(selected ? appAccentColor : Color.cardBackground)
    }

    // MARK: Step 5 — Frequency

    private var frequencyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("How often will you take this?")

            VStack(spacing: 1) {
                ForEach(ScheduleType.allCases, id: \.self) { type in
                    Button {
                        scheduleType = type
                    } label: {
                        HStack {
                            Text(type.displayName)
                                .font(.appBody)
                                .foregroundColor(scheduleType == type ? .black : .textPrimary)
                            Spacer()
                            if scheduleType == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.black)
                            }
                        }
                        .padding()
                        .background(scheduleType == type ? appAccentColor : Color.cardBackground)
                    }
                }
            }
            .cornerRadius(AppDimensions.cardCornerRadius)

            if scheduleType == .asNeeded {
                Text("Dosage")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
                    .padding(.top, 8)
                AppTextField(placeholder: "Dose (e.g., 2 tablets)", text: $doseDescription)
            }
        }
    }

    // MARK: Step 6 — Schedule (with per-time dosage)

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepTitle("Set a Schedule")

            // Days
            VStack(alignment: .leading, spacing: 12) {
                Text("When will you take this?")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                HStack(spacing: 8) {
                    ForEach(mondayFirstDays, id: \.self) { day in
                        Button {
                            if selectedDays.contains(day) {
                                selectedDays.removeAll { $0 == day }
                            } else {
                                selectedDays.append(day)
                            }
                        } label: {
                            Text(Calendar.shortDaysOfWeek[day])
                                .font(.appCaptionSmall)
                                .foregroundColor(selectedDays.contains(day) ? .black : .textPrimary)
                                .frame(width: 38, height: 38)
                                .background(selectedDays.contains(day) ? appAccentColor : Color.cardBackground)
                                .cornerRadius(18)
                        }
                    }
                }

                HStack(spacing: 8) {
                    dayPresetRow(title: "Every Day", days: [0, 1, 2, 3, 4, 5, 6])
                    dayPresetRow(title: "Weekdays", days: [1, 2, 3, 4, 5])
                    dayPresetRow(title: "Weekends", days: [0, 6])
                }
            }

            // Times + per-time dosage
            VStack(alignment: .leading, spacing: 8) {
                Text("At What Time?")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                ForEach(timeRows.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        if timeRows.count > 1 {
                            Button {
                                timeRows.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.medicalRed)
                                    .font(.system(size: 22))
                            }
                        }

                        DatePicker(
                            "",
                            selection: $timeRows[index].time,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(appAccentColor)

                        TextField("Dosage", text: $timeRows[index].dosage)
                            .font(.appCaption)
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.cardCornerRadius)
                }

                // Add a time
                Button {
                    var row = TimeDosageRow()
                    if let last = timeRows.last {
                        row.time = Calendar.current.date(byAdding: .hour, value: 1, to: last.time) ?? last.time
                    }
                    timeRows.append(row)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 22))
                        Text("Add a time")
                            .font(.appCaption)
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }

            // Start Date
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Date")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                    .font(.appBody)
                    .foregroundColor(.textPrimary)
                    .tint(appAccentColor)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.cardCornerRadius)
            }

            // End Date / Duration
            VStack(alignment: .leading, spacing: 8) {
                Text("End Date")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $useDuration) {
                        Text("Use Duration")
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                    }
                    .tint(appAccentColor)

                    if useDuration {
                        HStack {
                            Text("Take for")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Stepper("\(durationValue)", value: $durationValue, in: 1...maxDurationValue)
                                .fixedSize()
                            Picker("", selection: $durationUnit) {
                                ForEach(DurationUnit.allCases, id: \.self) { unit in
                                    Text(unit.displayName).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(appAccentColor)
                        }
                    } else {
                        Toggle(isOn: $showEndDate) {
                            Text("Set End Date")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                        }
                        .tint(appAccentColor)

                        if showEndDate {
                            DatePicker(
                                "End Date",
                                selection: $endDate,
                                in: startDate...,
                                displayedComponents: .date
                            )
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                            .tint(appAccentColor)
                        }
                    }
                }
                .padding(AppDimensions.cardPadding)
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
            }
        }
    }

    private func dayPresetRow(title: String, days: [Int]) -> some View {
        let selected = selectedDays.sorted() == days.sorted()
        return Button {
            selectedDays = days
        } label: {
            Text(title)
                .font(.appCaption)
                .foregroundColor(selected ? .black : .textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? appAccentColor : Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }

    private var maxDurationValue: Int {
        switch durationUnit {
        case .days: return 365
        case .weeks: return 52
        case .months: return 12
        }
    }

    // MARK: Step 7 — Summary

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepTitle("Summary")

            summarySection(title: "Medication Details") {
                Text(name.isBlank ? "—" : name)
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                if !form.isBlank {
                    Text(form.capitalized)
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
                if let strength = combinedStrength {
                    Text(strength)
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
            }

            if scheduleType == .scheduled {
                // Days chips
                HStack(spacing: 6) {
                    ForEach(mondayFirstDays, id: \.self) { day in
                        Text(Calendar.shortDaysOfWeek[day])
                            .font(.appCaptionSmall)
                            .foregroundColor(selectedDays.contains(day) ? .black : .textMuted)
                            .frame(width: 32, height: 32)
                            .background(selectedDays.contains(day) ? appAccentColor : Color.cardBackground)
                            .clipShape(Circle())
                    }
                }

                summarySection(title: "Schedule") {
                    Text(daysSummaryText)
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                    ForEach(sortedTimeRows) { row in
                        Text("\(timeString(row.time))\(row.dosage.isBlank ? "" : "  \(row.dosage)")")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                    Text("Start Date: \(dateString(startDate))")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                    Text("End Date: \(endDateSummaryText)")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
            } else {
                summarySection(title: "As Required") {
                    Text(doseDescription.isBlank ? "Take as needed" : doseDescription)
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
            }

            if let instruction = intakeInstruction {
                summarySection(title: "Intake") {
                    Text(instruction.displayName)
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
                AppTextField(placeholder: "Notes (optional)", text: $notes)
            }
        }
    }

    private func summarySection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appBodyMedium)
                .foregroundColor(.textPrimary)
            content()
        }
    }

    private var sortedTimeRows: [TimeDosageRow] {
        timeRows.sorted { $0.time < $1.time }
    }

    private var daysSummaryText: String {
        let sorted = selectedDays.sorted()
        if sorted.count == 7 { return "Every Day" }
        if sorted == [1, 2, 3, 4, 5] { return "Weekdays" }
        if sorted == [0, 6] { return "Weekends" }
        return mondayFirstDays
            .filter { selectedDays.contains($0) }
            .map { Calendar.shortDaysOfWeek[$0] }
            .joined(separator: ", ")
    }

    private var endDateSummaryText: String {
        if useDuration, let end = computedEndDate {
            return dateString(end)
        } else if showEndDate {
            return dateString(endDate)
        }
        return "Ongoing"
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter.string(from: date)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private var computedEndDate: Date? {
        let calendar = Calendar.current
        switch durationUnit {
        case .days:
            return calendar.date(byAdding: .day, value: durationValue, to: startDate)
        case .weeks:
            return calendar.date(byAdding: .day, value: durationValue * 7, to: startDate)
        case .months:
            return calendar.date(byAdding: .month, value: durationValue, to: startDate)
        }
    }

    // MARK: - Save

    private func saveMedication() async {
        guard let account = appState.currentAccount else { return }

        guard let primaryProfile = try? await appState.profileRepository.getPrimaryProfile(accountId: account.id) else {
            errorMessage = "No primary profile found"
            return
        }

        isLoading = true
        errorMessage = nil

        let medicationInsert = MedicationInsert(
            accountId: account.id,
            profileId: primaryProfile.id,
            name: name,
            strength: combinedStrength,
            form: form.isBlank ? nil : form,
            reason: reason.isBlank ? nil : reason,
            notes: notes.isBlank ? nil : notes,
            intakeInstruction: intakeInstruction
        )

        do {
            var medication = try await appState.medicationRepository.createMedication(medicationInsert)

            // Upload photo to Supabase Storage after creation (so we have the real ID)
            if let image = selectedImage {
                let photoURL = try await ImageUploadService.shared.uploadMedicationPhoto(image: image, medicationId: medication.id)
                medication.imageUrl = photoURL
                medication = try await appState.medicationRepository.updateMedication(medication)
            }

            // Create schedule
            if scheduleType == .scheduled && !timeRows.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                let sortedDays = selectedDays.sorted()

                let entries = sortedTimeRows.enumerated().map { index, row in
                    ScheduleEntry(
                        time: formatter.string(from: row.time),
                        dosage: row.dosage.isBlank ? nil : row.dosage,
                        daysOfWeek: sortedDays,
                        durationValue: nil,
                        durationUnit: .days,
                        sortOrder: index
                    )
                }

                let resolvedEndDate: Date?
                if useDuration {
                    resolvedEndDate = computedEndDate
                } else if showEndDate {
                    resolvedEndDate = endDate
                } else {
                    resolvedEndDate = nil
                }

                let scheduleInsert = MedicationScheduleInsert(
                    accountId: account.id,
                    medicationId: medication.id,
                    scheduleType: scheduleType,
                    startDate: startDate,
                    endDate: resolvedEndDate,
                    scheduleEntries: entries,
                    doseDescription: nil
                )
                _ = try await appState.medicationRepository.createSchedule(scheduleInsert)

                // Schedule notifications for each entry
                for entry in entries {
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

            // Notify other views that medications have changed
            NotificationCenter.default.post(name: .medicationsDidChange, object: nil)

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

    // MARK: - Step

    /// The fixed-position steps. Schedule pages are inserted dynamically (one per schedule),
    /// so they are represented as an associated-value case rather than a fixed enum case.
    enum FlowStep: Equatable {
        case name
        case type
        case strength
        case intake
        case frequency
        case schedule(Int)   // index into scheduleDrafts
        case summary
    }

    @State private var step: FlowStep = .name

    // MARK: - Form fields

    @State private var name: String
    @State private var strengthValue: String
    @State private var strengthUnit: String
    @State private var form: String
    @State private var reason: String
    @State private var notes: String
    @State private var intakeInstruction: IntakeInstruction?
    @State private var scheduleType: ScheduleType = .scheduled
    @State private var selectedImage: UIImage?
    @State private var removePhoto = false
    @State private var doseDescription = ""

    /// One draft per schedule. A medication may have several schedules, each shown on its own page.
    @State private var scheduleDrafts: [ScheduleDraft] = [ScheduleDraft()]

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    /// A time slot paired with its own dosage.
    struct TimeDosageRow: Identifiable, Equatable {
        let id = UUID()
        var time: Date = {
            var dc = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            dc.hour = 8
            dc.minute = 0
            return Calendar.current.date(from: dc) ?? Date()
        }()
        var dosage: String = ""
    }

    /// All editable state for a single schedule (its own page in the flow).
    struct ScheduleDraft: Identifiable, Equatable {
        let id = UUID()
        /// Identifier of the existing schedule row, so save updates rather than inserts.
        var existingScheduleId: UUID?
        var selectedDays: [Int] = [0, 1, 2, 3, 4, 5, 6]
        var timeRows: [TimeDosageRow] = [TimeDosageRow()]
        var startDate: Date = Date()
        var useDuration = false
        var durationValue = 7
        var durationUnit: DurationUnit = .days
        var showEndDate = false
        var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    }

    private let forms = ["Tablet", "Capsule", "Liquid", "Cream", "Inhaler", "Injection", "Other"]
    private let strengthUnits = ["None", "mg", "mcg", "g", "mL"]

    /// Days ordered Monday-first: [1, 2, 3, 4, 5, 6, 0]
    private let mondayFirstDays = [1, 2, 3, 4, 5, 6, 0]

    init(medication: Medication, onDismiss: (() -> Void)? = nil, onSave: @escaping (Medication) -> Void) {
        self.medication = medication
        self.onDismiss = onDismiss
        self.onSave = onSave
        _name = State(initialValue: medication.name)
        _form = State(initialValue: medication.form ?? "")
        _reason = State(initialValue: medication.reason ?? "")
        _notes = State(initialValue: medication.notes ?? "")
        _intakeInstruction = State(initialValue: medication.intakeInstruction)

        // Split the stored strength (e.g. "10mg") into value + unit for the strength step.
        let (value, unit) = Self.splitStrength(medication.strength)
        _strengthValue = State(initialValue: value)
        _strengthUnit = State(initialValue: unit)
    }

    /// Splits a stored strength string such as "10mg" into ("10", "mg").
    /// An unrecognised unit (or none) leaves the unit empty and keeps the full value.
    private static func splitStrength(_ stored: String?) -> (value: String, unit: String) {
        guard let stored = stored?.trimmingCharacters(in: .whitespaces), !stored.isEmpty else {
            return ("", "")
        }
        let knownUnits = ["mcg", "mg", "g", "mL"]
        for unit in knownUnits where stored.lowercased().hasSuffix(unit.lowercased()) {
            let value = String(stored.dropLast(unit.count)).trimmingCharacters(in: .whitespaces)
            return (value, unit)
        }
        return (stored, "")
    }

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    // MARK: - Combined strength string

    private var combinedStrength: String? {
        let value = strengthValue.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        // strengthUnit is empty when "None" is selected — store just the value in that case.
        return strengthUnit.isEmpty ? value : "\(value)\(strengthUnit)"
    }

    // MARK: - Step navigation

    /// The ordered steps for the current flow. When "Scheduled", one schedule page is inserted
    /// per draft; when "As Required" the schedule pages are skipped entirely.
    private var flow: [FlowStep] {
        var steps: [FlowStep] = [.name, .type, .strength, .intake, .frequency]
        if scheduleType == .scheduled {
            steps.append(contentsOf: scheduleDrafts.indices.map { FlowStep.schedule($0) })
        }
        steps.append(.summary)
        return steps
    }

    private var isFirstStep: Bool {
        flow.first == step
    }

    private var isLastStep: Bool {
        flow.last == step
    }

    /// Whether the user can advance from the current step.
    private var canAdvance: Bool {
        switch step {
        case .name:
            return !name.isBlank
        case .schedule(let index):
            guard scheduleDrafts.indices.contains(index) else { return true }
            let draft = scheduleDrafts[index]
            return !draft.selectedDays.isEmpty && !draft.timeRows.isEmpty
        default:
            return true
        }
    }

    private func goNext() {
        guard let index = flow.firstIndex(of: step) else { return }
        if index + 1 < flow.count {
            withAnimation { step = flow[index + 1] }
        }
    }

    private func goBack() {
        guard let index = flow.firstIndex(of: step) else { return }
        if index > 0 {
            withAnimation { step = flow[index - 1] }
        } else {
            dismissView()
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    stepContent

                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppDimensions.screenPadding + 12)
                .padding(.top, 48)
                .padding(.bottom, AppDimensions.screenPadding)
            }

            footer
        }
        .background(Color.appBackgroundLight)
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

    // MARK: - Header

    private var header: some View {
        HStack {
            // Leading slot: back chevron on later steps, otherwise a balancing spacer.
            if isFirstStep {
                Color.clear.frame(width: 48, height: 48)
            } else {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.5))
                        )
                }
            }

            Spacer()

            Text("Edit Medication")
                .font(.headline)
                .foregroundColor(.textPrimary)

            Spacer()

            // Trailing slot: cancel icon dismisses the flow on every step.
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
        }
        .padding(.horizontal, AppDimensions.screenPadding + 12)
        .padding(.vertical, 16)
    }

    // MARK: - Footer (Next / Done button)

    @ViewBuilder
    private var footer: some View {
        if isLastStep {
            Button {
                Task { await saveMedication() }
            } label: {
                Text("Done")
                    .font(.appBodyMedium)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(name.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                    .cornerRadius(AppDimensions.cardCornerRadius)
            }
            .disabled(name.isBlank || isLoading)
            .padding(.horizontal, AppDimensions.screenPadding + 12)
            .padding(.vertical, 16)
        } else {
            Button {
                goNext()
            } label: {
                Text("Next")
                    .font(.appBodyMedium)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canAdvance ? appAccentColor : Color.gray.opacity(0.3))
                    .cornerRadius(AppDimensions.cardCornerRadius)
            }
            .disabled(!canAdvance)
            .padding(.horizontal, AppDimensions.screenPadding + 12)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .name:
            nameStep
        case .type:
            typeStep
        case .strength:
            strengthStep
        case .intake:
            intakeStep
        case .frequency:
            frequencyStep
        case .schedule(let index):
            scheduleStep(index)
        case .summary:
            summaryStep
        }
    }

    private func stepTitle(_ text: String) -> some View {
        Text(text)
            .font(.appTitle)
            .foregroundColor(.textPrimary)
    }

    // MARK: Step 1 — Name / Reason / Photo

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Medication Name")
            AppTextField(placeholder: "Add a medication name", text: $name)
            AppTextField(placeholder: "Reason for taking", text: $reason)

            HStack {
                Spacer()
                ImageSourcePicker(
                    selectedImage: $selectedImage,
                    currentImageUrl: removePhoto ? nil : medication.imageUrl,
                    onImageSelected: { _ in removePhoto = false },
                    onRemove: { removePhoto = true }
                )
                Spacer()
            }
            .padding(.top, 8)
        }
    }

    // MARK: Step 2 — Type

    private var typeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Choose a medication type")

            VStack(spacing: 1) {
                ForEach(forms, id: \.self) { formOption in
                    Button {
                        form = formOption.lowercased()
                    } label: {
                        HStack {
                            Text(formOption)
                                .font(.appBody)
                                .foregroundColor(form == formOption.lowercased() ? .black : .textPrimary)
                            Spacer()
                            if form == formOption.lowercased() {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.black)
                            }
                        }
                        .padding()
                        .background(form == formOption.lowercased() ? appAccentColor : Color.cardBackground)
                    }
                }
            }
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }

    // MARK: Step 3 — Strength

    private var strengthStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Strength")
            AppTextField(placeholder: "Add strength", text: $strengthValue)
                .keyboardType(.decimalPad)

            Text("Medication Strength")
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)
                .padding(.top, 8)

            VStack(spacing: 1) {
                ForEach(strengthUnits, id: \.self) { unit in
                    // "None" maps to an empty stored unit (no default selected).
                    let storedUnit = (unit == "None") ? "" : unit
                    let selected = strengthUnit == storedUnit
                    Button {
                        strengthUnit = storedUnit
                    } label: {
                        HStack {
                            Text(unit)
                                .font(.appBody)
                                .foregroundColor(selected ? .black : .textPrimary)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.black)
                            }
                        }
                        .padding()
                        .background(selected ? appAccentColor : Color.cardBackground)
                    }
                }
            }
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }

    // MARK: Step 4 — Intake Instructions

    private var intakeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("Intake Instructions")

            VStack(spacing: 1) {
                // None option
                Button {
                    intakeInstruction = nil
                } label: {
                    intakeRow(title: "None", selected: intakeInstruction == nil)
                }

                ForEach(IntakeInstruction.allCases, id: \.self) { instruction in
                    Button {
                        intakeInstruction = instruction
                    } label: {
                        intakeRow(title: instruction.displayName, selected: intakeInstruction == instruction)
                    }
                }
            }
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }

    private func intakeRow(title: String, selected: Bool) -> some View {
        HStack {
            Text(title)
                .font(.appBody)
                .foregroundColor(selected ? .black : .textPrimary)
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundColor(.black)
            }
        }
        .padding()
        .background(selected ? appAccentColor : Color.cardBackground)
    }

    // MARK: Step 5 — Frequency

    private var frequencyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("How often will you take this?")

            VStack(spacing: 1) {
                ForEach(ScheduleType.allCases, id: \.self) { type in
                    Button {
                        scheduleType = type
                    } label: {
                        HStack {
                            Text(type.displayName)
                                .font(.appBody)
                                .foregroundColor(scheduleType == type ? .black : .textPrimary)
                            Spacer()
                            if scheduleType == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.black)
                            }
                        }
                        .padding()
                        .background(scheduleType == type ? appAccentColor : Color.cardBackground)
                    }
                }
            }
            .cornerRadius(AppDimensions.cardCornerRadius)

            if scheduleType == .asNeeded {
                Text("Dosage")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
                    .padding(.top, 8)
                AppTextField(placeholder: "Dose (e.g., 2 tablets)", text: $doseDescription)
            }
        }
    }

    // MARK: Step 6 — Schedule (with per-time dosage) — one page per schedule

    @ViewBuilder
    private func scheduleStep(_ index: Int) -> some View {
        // Guard against a transient out-of-range index while drafts are being added/removed.
        if scheduleDrafts.indices.contains(index) {
            let draft = $scheduleDrafts[index]

            VStack(alignment: .leading, spacing: 24) {
                stepTitle("Edit Schedule \(index + 1)")

                // Days
                VStack(alignment: .leading, spacing: 12) {
                    Text("When will you take this?")
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    HStack(spacing: 8) {
                        ForEach(mondayFirstDays, id: \.self) { day in
                            Button {
                                if draft.wrappedValue.selectedDays.contains(day) {
                                    draft.wrappedValue.selectedDays.removeAll { $0 == day }
                                } else {
                                    draft.wrappedValue.selectedDays.append(day)
                                }
                            } label: {
                                Text(Calendar.shortDaysOfWeek[day])
                                    .font(.appCaptionSmall)
                                    .foregroundColor(draft.wrappedValue.selectedDays.contains(day) ? .black : .textPrimary)
                                    .frame(width: 38, height: 38)
                                    .background(draft.wrappedValue.selectedDays.contains(day) ? appAccentColor : Color.cardBackground)
                                    .cornerRadius(18)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        dayPresetRow(draft, title: "Every Day", days: [0, 1, 2, 3, 4, 5, 6])
                        dayPresetRow(draft, title: "Weekdays", days: [1, 2, 3, 4, 5])
                        dayPresetRow(draft, title: "Weekends", days: [0, 6])
                    }
                }

                // Times + per-time dosage
                VStack(alignment: .leading, spacing: 8) {
                    Text("At What Time?")
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    ForEach(draft.timeRows.indices, id: \.self) { rowIndex in
                        HStack(spacing: 8) {
                            if draft.wrappedValue.timeRows.count > 1 {
                                Button {
                                    draft.wrappedValue.timeRows.remove(at: rowIndex)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.medicalRed)
                                        .font(.system(size: 22))
                                }
                            }

                            DatePicker(
                                "",
                                selection: draft.timeRows[rowIndex].time,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(appAccentColor)

                            TextField("Dosage", text: draft.timeRows[rowIndex].dosage)
                                .font(.appCaption)
                                .foregroundColor(.textPrimary)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                    }

                    // Add a time
                    Button {
                        var row = TimeDosageRow()
                        if let last = draft.wrappedValue.timeRows.last {
                            row.time = Calendar.current.date(byAdding: .hour, value: 1, to: last.time) ?? last.time
                        }
                        draft.wrappedValue.timeRows.append(row)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 22))
                            Text("Add a time")
                                .font(.appCaption)
                                .foregroundColor(.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                }

                // Start Date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start Date")
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    DatePicker("Start Date", selection: draft.startDate, displayedComponents: .date)
                        .labelsHidden()
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                        .tint(appAccentColor)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                }

                // End Date / Duration
                VStack(alignment: .leading, spacing: 8) {
                    Text("End Date")
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(isOn: draft.useDuration) {
                            Text("Use Duration")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                        }
                        .tint(appAccentColor)

                        if draft.wrappedValue.useDuration {
                            HStack {
                                Text("Take for")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Stepper("\(draft.wrappedValue.durationValue)", value: draft.durationValue, in: 1...maxDurationValue(for: draft.wrappedValue.durationUnit))
                                    .fixedSize()
                                Picker("", selection: draft.durationUnit) {
                                    ForEach(DurationUnit.allCases, id: \.self) { unit in
                                        Text(unit.displayName).tag(unit)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(appAccentColor)
                            }
                        } else {
                            Toggle(isOn: draft.showEndDate) {
                                Text("Set End Date")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                            }
                            .tint(appAccentColor)

                            if draft.wrappedValue.showEndDate {
                                DatePicker(
                                    "End Date",
                                    selection: draft.endDate,
                                    in: draft.wrappedValue.startDate...,
                                    displayedComponents: .date
                                )
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .tint(appAccentColor)
                            }
                        }
                    }
                    .padding(AppDimensions.cardPadding)
                    .background(Color.cardBackground)
                    .cornerRadius(AppDimensions.cardCornerRadius)
                }

                // Add / remove schedule controls
                VStack(spacing: 12) {
                    Button {
                        addSchedule(after: index)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add another schedule")
                        }
                        .font(.appCaption)
                        .foregroundColor(appAccentColor)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(AppDimensions.cardCornerRadius)
                    }

                    if scheduleDrafts.count > 1 {
                        Button {
                            removeSchedule(at: index)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("Remove this schedule")
                            }
                            .font(.appCaption)
                            .foregroundColor(.medicalRed)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(AppDimensions.cardCornerRadius)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func dayPresetRow(_ draft: Binding<ScheduleDraft>, title: String, days: [Int]) -> some View {
        let selected = draft.wrappedValue.selectedDays.sorted() == days.sorted()
        return Button {
            draft.wrappedValue.selectedDays = days
        } label: {
            Text(title)
                .font(.appCaption)
                .foregroundColor(selected ? .black : .textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? appAccentColor : Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }

    private func maxDurationValue(for unit: DurationUnit) -> Int {
        switch unit {
        case .days: return 365
        case .weeks: return 52
        case .months: return 12
        }
    }

    /// Inserts a new blank schedule after the given index and navigates to it.
    private func addSchedule(after index: Int) {
        let newIndex = min(index + 1, scheduleDrafts.count)
        scheduleDrafts.insert(ScheduleDraft(), at: newIndex)
        withAnimation { step = .schedule(newIndex) }
    }

    /// Removes the schedule at the given index and navigates to a sensible neighbouring page.
    private func removeSchedule(at index: Int) {
        guard scheduleDrafts.count > 1, scheduleDrafts.indices.contains(index) else { return }
        scheduleDrafts.remove(at: index)
        let target = min(index, scheduleDrafts.count - 1)
        withAnimation { step = .schedule(target) }
    }

    // MARK: Step 7 — Summary

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepTitle("Summary")

            summarySection(title: "Medication Details") {
                Text(name.isBlank ? "—" : name)
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                if !form.isBlank {
                    Text(form.capitalized)
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
                if let strength = combinedStrength {
                    Text(strength)
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
            }

            if scheduleType == .scheduled {
                ForEach(Array(scheduleDrafts.enumerated()), id: \.element.id) { offset, draft in
                    // Days chips
                    HStack(spacing: 6) {
                        ForEach(mondayFirstDays, id: \.self) { day in
                            Text(Calendar.shortDaysOfWeek[day])
                                .font(.appCaptionSmall)
                                .foregroundColor(draft.selectedDays.contains(day) ? .black : .textMuted)
                                .frame(width: 32, height: 32)
                                .background(draft.selectedDays.contains(day) ? appAccentColor : Color.cardBackground)
                                .clipShape(Circle())
                        }
                    }

                    summarySection(title: "Schedule \(offset + 1)") {
                        Text(daysSummaryText(for: draft))
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                        ForEach(sortedTimeRows(for: draft)) { row in
                            Text("\(timeString(row.time))\(row.dosage.isBlank ? "" : "  \(row.dosage)")")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }
                        Text("Start Date: \(dateString(draft.startDate))")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                        Text("End Date: \(endDateSummaryText(for: draft))")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                    }
                }
            } else {
                summarySection(title: "As Required") {
                    Text(doseDescription.isBlank ? "Take as needed" : doseDescription)
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
            }

            if let instruction = intakeInstruction {
                summarySection(title: "Intake") {
                    Text(instruction.displayName)
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
                AppTextField(placeholder: "Notes (optional)", text: $notes)
            }

            // Delete option lives on the final step.
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
                .cornerRadius(AppDimensions.cardCornerRadius)
            }
            .padding(.top, 8)
        }
    }

    private func summarySection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appBodyMedium)
                .foregroundColor(.textPrimary)
            content()
        }
    }

    private func sortedTimeRows(for draft: ScheduleDraft) -> [TimeDosageRow] {
        draft.timeRows.sorted { $0.time < $1.time }
    }

    private func daysSummaryText(for draft: ScheduleDraft) -> String {
        let sorted = draft.selectedDays.sorted()
        if sorted.count == 7 { return "Every Day" }
        if sorted == [1, 2, 3, 4, 5] { return "Weekdays" }
        if sorted == [0, 6] { return "Weekends" }
        return mondayFirstDays
            .filter { draft.selectedDays.contains($0) }
            .map { Calendar.shortDaysOfWeek[$0] }
            .joined(separator: ", ")
    }

    private func endDateSummaryText(for draft: ScheduleDraft) -> String {
        if draft.useDuration, let end = computedEndDate(for: draft) {
            return dateString(end)
        } else if draft.showEndDate {
            return dateString(draft.endDate)
        }
        return "Ongoing"
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter.string(from: date)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func computedEndDate(for draft: ScheduleDraft) -> Date? {
        let calendar = Calendar.current
        switch draft.durationUnit {
        case .days:
            return calendar.date(byAdding: .day, value: draft.durationValue, to: draft.startDate)
        case .weeks:
            return calendar.date(byAdding: .day, value: draft.durationValue * 7, to: draft.startDate)
        case .months:
            return calendar.date(byAdding: .month, value: draft.durationValue, to: draft.startDate)
        }
    }

    /// Parses an "HH:mm" string into a Date (today) for the schedule time rows.
    private func dateFromTimeString(_ timeString: String) -> Date {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        var dc = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dc.hour = components.count > 0 ? components[0] : 8
        dc.minute = components.count > 1 ? components[1] : 0
        return Calendar.current.date(from: dc) ?? Date()
    }

    // MARK: - Load existing schedule

    private func loadSchedule() async {
        do {
            let loadedSchedules = try await appState.medicationRepository.getSchedules(medicationId: medication.id)
            guard !loadedSchedules.isEmpty else { return }

            scheduleType = loadedSchedules.first?.scheduleType ?? .scheduled
            doseDescription = loadedSchedules.first?.doseDescription ?? ""

            // Build one draft per scheduled schedule. As-needed schedules carry no per-time data.
            let scheduledSchedules = loadedSchedules.filter { $0.scheduleType == .scheduled }
            let drafts: [ScheduleDraft] = scheduledSchedules.map { schedule in
                var draft = ScheduleDraft()
                draft.existingScheduleId = schedule.id
                draft.startDate = schedule.startDate

                // Resolve schedule entries (or convert legacy times) into per-time rows + selected days.
                let entries: [ScheduleEntry]
                if let scheduleEntries = schedule.scheduleEntries, !scheduleEntries.isEmpty {
                    entries = scheduleEntries
                } else if let times = schedule.times {
                    entries = times.enumerated().map { index, time in
                        ScheduleEntry(
                            time: time,
                            dosage: schedule.doseDescription,
                            daysOfWeek: schedule.daysOfWeek ?? [0, 1, 2, 3, 4, 5, 6],
                            sortOrder: index
                        )
                    }
                } else {
                    entries = []
                }

                if !entries.isEmpty {
                    let sortedEntries = entries.sorted { $0.sortOrder < $1.sortOrder }
                    draft.timeRows = sortedEntries.map { entry in
                        var row = TimeDosageRow()
                        row.time = dateFromTimeString(entry.time)
                        row.dosage = entry.dosage ?? ""
                        return row
                    }
                    if let days = sortedEntries.first?.daysOfWeek, !days.isEmpty {
                        draft.selectedDays = days
                    }
                }

                if let scheduleEndDate = schedule.endDate {
                    draft.showEndDate = true
                    draft.endDate = scheduleEndDate
                }

                return draft
            }

            if !drafts.isEmpty {
                scheduleDrafts = drafts
            }
        } catch {
            // Leave defaults on error.
        }
    }

    // MARK: - Save

    private func saveMedication() async {
        guard let account = appState.currentAccount else { return }

        isLoading = true
        errorMessage = nil

        // Create updated medication
        var updatedMedication = medication
        updatedMedication.name = name
        updatedMedication.strength = combinedStrength
        updatedMedication.form = form.isBlank ? nil : form
        updatedMedication.reason = reason.isBlank ? nil : reason
        updatedMedication.notes = notes.isBlank ? nil : notes
        updatedMedication.intakeInstruction = intakeInstruction

        // Handle photo changes - upload to Supabase Storage
        if let image = selectedImage {
            do {
                let photoURL = try await ImageUploadService.shared.uploadMedicationPhoto(image: image, medicationId: medication.id)
                updatedMedication.imageUrl = photoURL
            } catch {
                #if DEBUG
                print("Failed to upload medication photo: \(error)")
                #endif
            }
        } else if removePhoto {
            // User explicitly removed the photo
            if medication.imageUrl != nil {
                let storagePath = "medications/\(medication.id.uuidString)/photo.jpg"
                try? await ImageUploadService.shared.deleteImage(bucket: SupabaseConfig.medicationPhotosBucket, path: storagePath)
            }
            updatedMedication.imageUrl = nil
        }

        do {
            let savedMedication = try await appState.medicationRepository.updateMedication(updatedMedication)

            let existingSchedules = try await appState.medicationRepository.getSchedules(medicationId: medication.id)

            if scheduleType == .scheduled {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"

                // Only drafts with at least one time row are persisted.
                let drafts = scheduleDrafts.filter { !$0.timeRows.isEmpty }

                // Delete any existing schedules whose draft was removed in the editor.
                let keepIds = Set(drafts.compactMap { $0.existingScheduleId })
                for existing in existingSchedules where !keepIds.contains(existing.id) {
                    try await appState.medicationRepository.deleteSchedule(id: existing.id)
                }

                var allEntries: [ScheduleEntry] = []

                for draft in drafts {
                    let sortedDays = draft.selectedDays.sorted()
                    let entries = sortedTimeRows(for: draft).enumerated().map { index, row in
                        ScheduleEntry(
                            time: formatter.string(from: row.time),
                            dosage: row.dosage.isBlank ? nil : row.dosage,
                            daysOfWeek: sortedDays,
                            durationValue: nil,
                            durationUnit: .days,
                            sortOrder: index
                        )
                    }
                    allEntries.append(contentsOf: entries)

                    let resolvedEndDate: Date?
                    if draft.useDuration {
                        resolvedEndDate = computedEndDate(for: draft)
                    } else if draft.showEndDate {
                        resolvedEndDate = draft.endDate
                    } else {
                        resolvedEndDate = nil
                    }

                    // Update an existing schedule when this draft maps to one, otherwise insert.
                    if let existingId = draft.existingScheduleId,
                       var existingSchedule = existingSchedules.first(where: { $0.id == existingId }) {
                        existingSchedule.scheduleType = scheduleType
                        existingSchedule.scheduleEntries = entries
                        existingSchedule.startDate = draft.startDate
                        existingSchedule.endDate = resolvedEndDate
                        existingSchedule.doseDescription = nil
                        _ = try await appState.medicationRepository.updateSchedule(existingSchedule)
                    } else {
                        let scheduleInsert = MedicationScheduleInsert(
                            accountId: account.id,
                            medicationId: medication.id,
                            scheduleType: scheduleType,
                            startDate: draft.startDate,
                            endDate: resolvedEndDate,
                            scheduleEntries: entries,
                            doseDescription: nil
                        )
                        _ = try await appState.medicationRepository.createSchedule(scheduleInsert)
                    }
                }

                // Schedule notifications across all entries from all schedules.
                for entry in allEntries {
                    if let scheduledTime = timeStringToDate(entry.time) {
                        await NotificationService.shared.scheduleMedicationReminder(
                            medicationId: medication.id,
                            medicationName: savedMedication.name,
                            scheduledTime: scheduledTime,
                            doseDescription: entry.dosage
                        )
                    }
                }
            } else if scheduleType == .asNeeded {
                // Replace any existing schedules with a single as-needed schedule.
                for existing in existingSchedules {
                    try await appState.medicationRepository.deleteSchedule(id: existing.id)
                }
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

            // Notify other views that medications have changed
            NotificationCenter.default.post(name: .medicationsDidChange, object: nil)

            onSave(savedMedication)
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

    private func deleteMedication() async {
        isLoading = true

        do {
            // Delete photo from Supabase Storage if exists
            if medication.imageUrl != nil {
                let storagePath = "medications/\(medication.id.uuidString)/photo.jpg"
                try? await ImageUploadService.shared.deleteImage(bucket: SupabaseConfig.medicationPhotosBucket, path: storagePath)
            }

            try await appState.medicationRepository.deleteMedication(id: medication.id)
            NotificationCenter.default.post(name: .medicationsDidChange, object: nil)
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
            .environmentObject(AppState.forPreview())
    }
}
