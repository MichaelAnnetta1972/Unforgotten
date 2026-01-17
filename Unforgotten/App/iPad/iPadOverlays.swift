//
//  iPadOverlays.swift
//  Unforgotten
//
//  iPad overlay components including floating add button, add menu, and side panel
//

import SwiftUI
import SwiftData

// MARK: - iPad Floating Add Button Overlay
/// Floating add button with gradient fade for iPad right panel
struct iPadFloatingAddButtonOverlay: View {
    @Binding var showAddMenu: Bool
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var isPressed = false

    var body: some View {
        VStack {
            Spacer()

            ZStack(alignment: .bottomTrailing) {
                // Gradient background that fades to match page background
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
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

                // Floating add button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showAddMenu.toggle()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.black)
                        .rotationEffect(.degrees(showAddMenu ? 45 : 0))
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(appAccentColor)
                                .shadow(color: appAccentColor.opacity(0.4), radius: isPressed ? 6 : 12, y: isPressed ? 3 : 6)
                        )
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 28)
                .padding(.bottom, 28)
                .hoverEffect(.lift)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isPressed = true
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isPressed = false
                            }
                        }
                )
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - iPad Add Menu Overlay
/// Full-screen overlay with add menu popup for iPad
struct iPadAddMenuOverlay: View {
    @Binding var showAddMenu: Bool
    var isLimitedAccess: Bool
    var onAddProfile: () -> Void
    var onAddMedication: () -> Void
    var onAddAppointment: () -> Void
    var onAddContact: () -> Void
    var onAddToDoList: () -> Void
    var onAddNote: () -> Void
    var onAddStickyReminder: () -> Void
    var onAddCountdown: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor
    @State private var isVisible = false

    var body: some View {
        ZStack {
            // Dark overlay - tap to dismiss (full screen)
            Color.black.opacity(isVisible ? 0.7 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissMenu()
                }
                .animation(.easeOut(duration: 0.25), value: isVisible)

            // Full-width bottom gradient - positioned at bottom
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

            // Menu popup positioned in bottom trailing
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if isVisible {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            Text("Add a new")
                                .font(.appCardTitle)
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 16)

                            Divider()
                                .background(Color.white.opacity(0.1))

                            // Menu items - limited for Helper/Viewer roles
                            if !isLimitedAccess {
                                iPadAddMenuRow(icon: "person.2", title: "Family or Friend") {
                                    dismissAndExecute { onAddProfile() }
                                }
                            }

                            iPadAddMenuRow(icon: "pill", title: "Medication") {
                                dismissAndExecute { onAddMedication() }
                            }

                            iPadAddMenuRow(icon: "calendar", title: "Appointment") {
                                dismissAndExecute { onAddAppointment() }
                            }

                            iPadAddMenuRow(icon: "phone", title: "Contact") {
                                dismissAndExecute { onAddContact() }
                            }

                            if !isLimitedAccess {
                                iPadAddMenuRow(icon: "checklist", title: "To Do List") {
                                    dismissAndExecute { onAddToDoList() }
                                }

                                iPadAddMenuRow(icon: "note.text", title: "Note") {
                                    dismissAndExecute { onAddNote() }
                                }

                                iPadAddMenuRow(icon: "bell.badge", title: "Sticky Reminder") {
                                    dismissAndExecute { onAddStickyReminder() }
                                }

                                iPadAddMenuRow(icon: "clock.badge.checkmark", title: "Countdown") {
                                    dismissAndExecute { onAddCountdown() }
                                }
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .background(Color.cardBackgroundLight.opacity(0.95))
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85, anchor: .bottomTrailing)
                                .combined(with: .opacity)
                                .combined(with: .offset(x: 20, y: 20)),
                            removal: .scale(scale: 0.85, anchor: .bottomTrailing)
                                .combined(with: .opacity)
                                .combined(with: .offset(x: 20, y: 20))
                        ))
                    }
                }
                .padding(.trailing, 28)
                .padding(.bottom, 110)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isVisible = true
            }
        }
    }

    private func dismissMenu() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showAddMenu = false
        }
    }

    private func dismissAndExecute(_ action: @escaping () -> Void) {
        // Execute action immediately (navigation + set panel state)
        action()

        // Then animate the menu out
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showAddMenu = false
        }
    }
}

// MARK: - iPad Add Menu Row
struct iPadAddMenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(appAccentColor)
                    .frame(width: 24)

                Text(title)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - iPad Side Panel Overlay
/// Single overlay that handles all side panel presentations with slide-in from right animation
struct iPadSidePanelOverlay: View {
    @Binding var showAddProfile: Bool
    @Binding var showAddMedication: Bool
    @Binding var showAddAppointment: Bool
    @Binding var showAddContact: Bool
    @Binding var showAddNote: Bool
    @Binding var showEditNote: Bool
    @Binding var noteToEdit: LocalNote?
    @Binding var showAddToDoList: Bool
    @Binding var showAddStickyReminder: Bool
    @Binding var showEditStickyReminder: Bool
    @Binding var stickyReminderToEdit: StickyReminder?
    @Binding var showViewStickyReminder: Bool
    @Binding var stickyReminderToView: StickyReminder?
    @Binding var showViewToDoList: Bool
    @Binding var toDoListToView: ToDoList?
    @Binding var showEditProfile: Bool
    @Binding var profileToEdit: Profile?
    @Binding var showEditMedication: Bool
    @Binding var medicationToEdit: Medication?
    @Binding var showEditAppointment: Bool
    @Binding var appointmentToEdit: Appointment?
    @Binding var showEditUsefulContact: Bool
    @Binding var usefulContactToEdit: UsefulContact?
    @Binding var showEditImportantAccount: Bool
    @Binding var importantAccountToEdit: ImportantAccount?
    @Binding var importantAccountProfile: Profile?
    @Binding var showAddImportantAccount: Bool
    @Binding var addImportantAccountProfile: Profile?
    @Binding var showAddMedicalCondition: Bool
    @Binding var addMedicalConditionProfile: Profile?
    @Binding var showAddGiftIdea: Bool
    @Binding var addGiftIdeaProfile: Profile?
    @Binding var showEditGiftIdea: Bool
    @Binding var editGiftIdeaDetail: ProfileDetail?
    @Binding var showAddClothingSize: Bool
    @Binding var addClothingSizeProfile: Profile?
    @Binding var showEditClothingSize: Bool
    @Binding var editClothingSizeDetail: ProfileDetail?
    @Binding var showAddHobbySection: Bool
    @Binding var addHobbySectionProfile: Profile?
    @Binding var showAddActivitySection: Bool
    @Binding var addActivitySectionProfile: Profile?
    @Binding var showAddHobbyItem: Bool
    @Binding var addHobbyItemProfile: Profile?
    @Binding var addHobbyItemSection: String?
    @Binding var showAddActivityItem: Bool
    @Binding var addActivityItemProfile: Profile?
    @Binding var addActivityItemSection: String?
    @Binding var showSettingsInviteMember: Bool
    @Binding var showSettingsManageMembers: Bool
    @Binding var showSettingsJoinAccount: Bool
    @Binding var showSettingsMoodHistory: Bool
    @Binding var showSettingsAppearance: Bool
    @Binding var showSettingsFeatureVisibility: Bool
    @Binding var showSettingsSwitchAccount: Bool
    @Binding var showSettingsEditAccountName: Bool
    @Binding var showSettingsAdminPanel: Bool
    @Binding var showSettingsUpgrade: Bool
    @Binding var showAddCountdown: Bool
    @Binding var showEditCountdown: Bool
    @Binding var countdownToEdit: Countdown?
    @ObservedObject var toDoListsViewModel: ToDoListsViewModel
    var appState: AppState
    var toDoDetailTypeSelectorAction: ((ToDoListDetailViewModel, Binding<String?>, @escaping () -> Void) -> Void)?

    /// Check if any panel is showing
    private var isAnyPanelShowing: Bool {
        showAddProfile || showAddMedication || showAddAppointment ||
        showAddContact || showAddNote || showEditNote || showAddToDoList || showAddStickyReminder || showEditStickyReminder || showViewStickyReminder || showViewToDoList ||
        showEditProfile || showEditMedication || showEditAppointment || showEditUsefulContact ||
        showEditImportantAccount || showAddImportantAccount || showAddMedicalCondition || showAddGiftIdea || showEditGiftIdea || showAddClothingSize || showEditClothingSize ||
        showAddHobbySection || showAddActivitySection || showAddHobbyItem || showAddActivityItem ||
        showSettingsInviteMember || showSettingsManageMembers || showSettingsJoinAccount || showSettingsMoodHistory ||
        showSettingsAppearance || showSettingsFeatureVisibility || showSettingsSwitchAccount || showSettingsEditAccountName ||
        showSettingsAdminPanel || showSettingsUpgrade || showAddCountdown || showEditCountdown
    }

    /// Dismiss action for side panel environment
    private var panelDismissAction: SidePanelDismissAction {
        SidePanelDismissAction {
            dismissAll()
        }
    }

    /// Dismiss all panels
    private func dismissAll() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showAddProfile = false
            showAddMedication = false
            showAddAppointment = false
            showAddContact = false
            showAddNote = false
            showEditNote = false
            noteToEdit = nil
            showAddToDoList = false
            showAddStickyReminder = false
            showEditStickyReminder = false
            stickyReminderToEdit = nil
            showViewStickyReminder = false
            stickyReminderToView = nil
            showViewToDoList = false
            toDoListToView = nil
            showEditProfile = false
            profileToEdit = nil
            showEditMedication = false
            medicationToEdit = nil
            showEditAppointment = false
            appointmentToEdit = nil
            showEditUsefulContact = false
            usefulContactToEdit = nil
            showEditImportantAccount = false
            importantAccountToEdit = nil
            importantAccountProfile = nil
            showAddImportantAccount = false
            addImportantAccountProfile = nil
            showAddMedicalCondition = false
            addMedicalConditionProfile = nil
            showAddGiftIdea = false
            addGiftIdeaProfile = nil
            showEditGiftIdea = false
            editGiftIdeaDetail = nil
            showAddClothingSize = false
            addClothingSizeProfile = nil
            showEditClothingSize = false
            editClothingSizeDetail = nil
            showAddHobbySection = false
            addHobbySectionProfile = nil
            showAddActivitySection = false
            addActivitySectionProfile = nil
            showAddHobbyItem = false
            addHobbyItemProfile = nil
            addHobbyItemSection = nil
            showAddActivityItem = false
            addActivityItemProfile = nil
            addActivityItemSection = nil
            showSettingsInviteMember = false
            showSettingsManageMembers = false
            showSettingsJoinAccount = false
            showSettingsMoodHistory = false
            showSettingsAppearance = false
            showSettingsFeatureVisibility = false
            showSettingsSwitchAccount = false
            showSettingsEditAccountName = false
            showSettingsAdminPanel = false
            showSettingsUpgrade = false
            showAddCountdown = false
            showEditCountdown = false
            countdownToEdit = nil
        }
    }

    var body: some View {
        ZStack {
            // Dimmed background
            if isAnyPanelShowing {
                Color.cardBackground.opacity(0.80)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissAll()
                    }
                    .transition(.opacity)
            }

            // Panel content - aligned to right
            GeometryReader { geometry in
                let isNotePanel = showAddNote || showEditNote
                let panelWidth = isNotePanel
                    ? geometry.size.width * 0.6
                    : min(max(500, geometry.size.width * 0.45), 600)

                HStack {
                    Spacer()

                    if isAnyPanelShowing {
                        panelContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .frame(width: panelWidth, height: geometry.size.height)
                            .background {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .fill(Color.cardBackgroundLight.opacity(0.85))
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.3), radius: 20, x: -5, y: 0)
                            .padding(.top, 0)
                            .padding(.trailing, 20)
                            .padding(.bottom, 0)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isAnyPanelShowing)
        .task(id: showAddToDoList) {
            if showAddToDoList {
                await toDoListsViewModel.loadData(appState: appState)
            }
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        if showAddProfile {
            AddProfileView(
                onDismiss: { dismissAll() },
                onSave: { _ in
                    dismissAll()
                    NotificationCenter.default.post(name: .profilesDidChange, object: nil)
                }
            )
            .environmentObject(appState)
        } else if showAddMedication {
            AddMedicationView(
                onDismiss: { dismissAll() }
            ) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .medicationsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showAddAppointment {
            AddAppointmentView(
                onDismiss: { dismissAll() }
            ) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .appointmentsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showAddContact {
            AddUsefulContactView(
                onDismiss: { dismissAll() }
            ) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .contactsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showAddNote {
            // New note - NoteEditorView handles its own UI including close button
            AddNoteSheetWrapper(onDismiss: { dismissAll() }, accountId: appState.currentAccount?.id)
                .environmentObject(appState)
        } else if showEditNote, let note = noteToEdit {
            // Edit existing note - NoteEditorView handles its own UI
            EditNoteSheetWrapper(note: note, onDismiss: { dismissAll() })
                .environmentObject(appState)
        } else if showAddToDoList {
            AddToDoListSheet(
                viewModel: toDoListsViewModel,
                onDismiss: { dismissAll() }
            ) { _ in
                dismissAll()
            }
            .environmentObject(appState)
        } else if showAddStickyReminder {
            AddStickyReminderView(
                onSave: { _ in
                    dismissAll()
                    NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
                },
                onDismiss: { dismissAll() }
            )
            .environmentObject(appState)
        } else if showEditStickyReminder, let reminder = stickyReminderToEdit {
            AddStickyReminderView(
                editingReminder: reminder,
                onSave: { _ in
                    dismissAll()
                    NotificationCenter.default.post(name: .stickyRemindersDidChange, object: nil)
                },
                onDismiss: { dismissAll() }
            )
            .environmentObject(appState)
        } else if showViewStickyReminder, let reminder = stickyReminderToView {
            iPadStickyReminderDetailView(
                reminder: reminder,
                onClose: { dismissAll() },
                onUpdate: { updatedReminder in
                    stickyReminderToView = updatedReminder
                },
                onEdit: { reminderToEdit in
                    // Switch from viewing to editing - close view panel and open edit panel
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showViewStickyReminder = false
                        stickyReminderToView = nil
                        stickyReminderToEdit = reminderToEdit
                        showEditStickyReminder = true
                    }
                }
            )
            .environmentObject(appState)
        } else if showViewToDoList, let list = toDoListToView {
            iPadToDoListDetailView(
                list: list,
                onClose: { dismissAll() },
                onDelete: {
                    toDoListsViewModel.lists.removeAll { $0.id == list.id }
                    dismissAll()
                }
            )
            .environment(\.iPadToDoDetailTypeSelectorAction, toDoDetailTypeSelectorAction)
            .environmentObject(appState)
        } else if showEditProfile, let profile = profileToEdit {
            EditProfileView(profile: profile, onDismiss: { dismissAll() }) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .profilesDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showEditMedication, let medication = medicationToEdit {
            EditMedicationView(medication: medication, onDismiss: { dismissAll() }) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .medicationsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showEditAppointment, let appointment = appointmentToEdit {
            EditAppointmentView(appointment: appointment, onDismiss: { dismissAll() }) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .appointmentsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showEditUsefulContact, let contact = usefulContactToEdit {
            EditUsefulContactView(contact: contact, onDismiss: { dismissAll() }) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .contactsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showEditImportantAccount, let account = importantAccountToEdit, let profile = importantAccountProfile {
            AddEditImportantAccountView(
                profile: profile,
                mode: .edit(account),
                onDismiss: { dismissAll() },
                onSave: { _ in
                    dismissAll()
                    // Note: AddEditImportantAccountView.saveAccount() already posts .importantAccountsDidChange
                }
            )
            .environmentObject(appState)
        } else if showAddImportantAccount, let profile = addImportantAccountProfile {
            AddEditImportantAccountView(
                profile: profile,
                mode: .add,
                onDismiss: { dismissAll() },
                onSave: { _ in
                    dismissAll()
                    // Note: AddEditImportantAccountView.saveAccount() already posts .importantAccountsDidChange
                }
            )
            .environmentObject(appState)
        } else if showAddMedicalCondition, let profile = addMedicalConditionProfile {
            AddProfileDetailView(
                profile: profile,
                category: .medical,
                onDismiss: { dismissAll() },
                onSave: { _ in
                    dismissAll()
                    // Note: AddProfileDetailView.saveDetail() already posts .profileDetailsDidChange
                }
            )
            .environmentObject(appState)
        } else if showAddGiftIdea, let profile = addGiftIdeaProfile {
            AddProfileDetailView(
                profile: profile,
                category: .gifts,
                onDismiss: { dismissAll() },
                onSave: { _ in
                    dismissAll()
                    // Note: AddProfileDetailView.saveDetail() already posts .profileDetailsDidChange
                }
            )
            .environmentObject(appState)
        } else if showEditGiftIdea, let detail = editGiftIdeaDetail {
            EditGiftDetailView(
                detail: detail,
                onDismiss: { dismissAll() },
                onSave: { updatedDetail in
                    dismissAll()
                    NotificationCenter.default.post(name: .profileDetailsDidChange, object: nil, userInfo: ["profileId": updatedDetail.profileId])
                }
            )
            .environmentObject(appState)
        } else if showAddClothingSize, let profile = addClothingSizeProfile {
            AddProfileDetailView(
                profile: profile,
                category: .clothing,
                onDismiss: { dismissAll() },
                onSave: { _ in
                    dismissAll()
                    // Note: AddProfileDetailView.saveDetail() already posts .profileDetailsDidChange
                }
            )
            .environmentObject(appState)
        } else if showEditClothingSize, let detail = editClothingSizeDetail {
            EditClothingDetailView(
                detail: detail,
                onDismiss: { dismissAll() },
                onSave: { updatedDetail in
                    dismissAll()
                    NotificationCenter.default.post(name: .profileDetailsDidChange, object: nil, userInfo: ["profileId": updatedDetail.profileId])
                }
            )
            .environmentObject(appState)
        } else if showAddHobbySection, let profile = addHobbySectionProfile {
            AddSectionView(
                profile: profile,
                category: .hobbies,
                existingSections: [],
                onDismiss: { dismissAll() },
                onSectionAdded: { sectionName in
                    // Switch to add item mode
                    addHobbyItemProfile = profile
                    addHobbyItemSection = sectionName
                    showAddHobbySection = false
                    showAddHobbyItem = true
                }
            )
            .environmentObject(appState)
        } else if showAddActivitySection, let profile = addActivitySectionProfile {
            AddSectionView(
                profile: profile,
                category: .activities,
                existingSections: [],
                onDismiss: { dismissAll() },
                onSectionAdded: { sectionName in
                    // Switch to add item mode
                    addActivityItemProfile = profile
                    addActivityItemSection = sectionName
                    showAddActivitySection = false
                    showAddActivityItem = true
                }
            )
            .environmentObject(appState)
        } else if showAddHobbyItem, let profile = addHobbyItemProfile, let section = addHobbyItemSection {
            AddSectionItemView(
                profile: profile,
                category: .hobbies,
                sectionName: section,
                onDismiss: { dismissAll() },
                onItemAdded: { _ in
                    // Item added, notification will trigger refresh
                }
            )
            .environmentObject(appState)
        } else if showAddActivityItem, let profile = addActivityItemProfile, let section = addActivityItemSection {
            AddSectionItemView(
                profile: profile,
                category: .activities,
                sectionName: section,
                onDismiss: { dismissAll() },
                onItemAdded: { _ in
                    // Item added, notification will trigger refresh
                }
            )
            .environmentObject(appState)
        } else if showSettingsInviteMember {
            InviteMemberView()
                .environmentObject(appState)
                .environment(\.sidePanelDismiss, panelDismissAction)
        } else if showSettingsManageMembers {
            ManageMembersView()
                .environmentObject(appState)
                .environment(\.sidePanelDismiss, panelDismissAction)
        } else if showSettingsJoinAccount {
            JoinAccountView()
                .environmentObject(appState)
                .environment(\.sidePanelDismiss, panelDismissAction)
        } else if showSettingsMoodHistory {
            MoodHistoryView()
                .environmentObject(appState)
                .environment(\.sidePanelDismiss, panelDismissAction)
        } else if showSettingsAppearance {
            AppearanceSettingsView()
                .environmentObject(appState)
                .environment(\.sidePanelDismiss, panelDismissAction)
        } else if showSettingsFeatureVisibility {
            FeatureVisibilityView()
                .environmentObject(appState)
                .environment(\.sidePanelDismiss, panelDismissAction)
        } else if showSettingsSwitchAccount {
            SwitchAccountView()
                .environmentObject(appState)
                .environment(\.sidePanelDismiss, panelDismissAction)
        } else if showSettingsEditAccountName {
            EditAccountNameView()
                .environmentObject(appState)
                .environment(\.sidePanelDismiss, panelDismissAction)
        } else if showSettingsAdminPanel {
            AdminPanelView()
                .environmentObject(appState)
                .environment(\.sidePanelDismiss, panelDismissAction)
        } else if showSettingsUpgrade {
            UpgradeView(isEmbedded: true)
                .environmentObject(appState)
                .environment(\.sidePanelDismiss, panelDismissAction)
        } else if showAddCountdown {
            AddCountdownView(
                onDismiss: { dismissAll() }
            ) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .countdownsDidChange, object: nil)
            }
            .environmentObject(appState)
        } else if showEditCountdown, let countdown = countdownToEdit {
            EditCountdownView(
                countdown: countdown,
                onDismiss: { dismissAll() }
            ) { _ in
                dismissAll()
                NotificationCenter.default.post(name: .countdownsDidChange, object: nil)
            }
            .environmentObject(appState)
        }
    }
}

// MARK: - Add Note Sheet Wrapper
/// Wrapper for creating a new note in side panel - delegates to NoteEditorView
struct AddNoteSheetWrapper: View {
    let onDismiss: () -> Void
    let accountId: UUID?
    @Environment(\.modelContext) private var modelContext
    @StateObject private var syncService = NotesSyncService()

    @State private var note: LocalNote?

    var body: some View {
        Group {
            if let note = note {
                NoteEditorView(
                    note: note,
                    isNewNote: true,
                    onDelete: {
                        // Delete note if it was saved and synced
                        if let noteToDelete = self.note {
                            // Delete from Supabase if synced
                            if let remoteId = noteToDelete.supabaseId {
                                Task {
                                    try? await syncService.deleteRemote(id: remoteId)
                                }
                            }
                            modelContext.delete(noteToDelete)
                            try? modelContext.save()  // Persist deletion immediately
                        }
                        onDismiss()
                    },
                    onSave: {
                        // Insert into context when saved
                        if let noteToSave = self.note {
                            modelContext.insert(noteToSave)
                            try? modelContext.save()  // Persist insertion immediately
                        }
                        onDismiss()
                    },
                    onClose: onDismiss
                )
            } else {
                ProgressView()
                    .onAppear {
                        note = LocalNote(title: "", theme: .standard, accountId: accountId)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Note: Uses shared modelContainer from iPadRootView
    }
}

// MARK: - Edit Note Sheet Wrapper
/// Wrapper for editing an existing note in side panel
struct EditNoteSheetWrapper: View {
    let note: LocalNote
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext
    @StateObject private var syncService = NotesSyncService()

    var body: some View {
        NoteEditorView(
            note: note,
            isNewNote: false,
            onDelete: {
                // Delete from Supabase if synced
                if let remoteId = note.supabaseId {
                    Task {
                        try? await syncService.deleteRemote(id: remoteId)
                    }
                }
                modelContext.delete(note)
                try? modelContext.save()  // Persist deletion immediately
                onDismiss()
            },
            onClose: onDismiss
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Note: Uses shared modelContainer from iPadRootView
    }
}
