import SwiftUI
import SwiftData

// MARK: - Notes List View
/// Main list view displaying all notes with header and card styling matching other pages
struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @Environment(\.iPadHomeAction) private var iPadHomeAction
    @Environment(\.iPadAddNoteAction) private var iPadAddNoteAction
    @Environment(\.iPadEditNoteAction) private var iPadEditNoteAction
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appAccentColor) private var appAccentColor

    // SwiftData query
    @Query(sort: \LocalNote.updatedAt, order: .reverse)
    private var allNotes: [LocalNote]

    // Sync service for Supabase sync
    @StateObject private var syncService = NotesSyncService()

    @State private var selectedNote: LocalNote?
    @State private var newNote: LocalNote?
    @State private var noteToDelete: LocalNote?
    @State private var showDeleteConfirmation = false
    @State private var showUpgradePrompt = false
    @State private var searchText = ""
    @State private var listContentHeight: CGFloat = 0
    @State private var newNoteSaved = false
    @FocusState private var isSearchFocused: Bool

    /// Check if we're in iPad mode (regular size class)
    private var isiPad: Bool {
        horizontalSizeClass == .regular
    }

    /// Count of notes for the current account
    private var accountNoteCount: Int {
        guard let accountId = appState.currentAccount?.id else { return 0 }
        return allNotes.filter { $0.accountId == accountId }.count
    }

    /// Check if user can add more notes
    private var canAddNote: Bool {
        PremiumLimitsManager.shared.canCreateNote(
            appState: appState,
            currentCount: accountNoteCount
        )
    }

    var body: some View {
        ZStack {
            Color.appBackgroundLight.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header with default style-based image
                    CustomizableHeaderView(
                        pageIdentifier: .notes,
                        title: "Notes",
                        showBackButton: iPadHomeAction == nil,
                        backAction: { dismiss() },
                        showHomeButton: iPadHomeAction != nil,
                        homeAction: iPadHomeAction,
                        showAddButton: true,
                        addAction: {
                            guard canAddNote else {
                                showUpgradePrompt = true
                                return
                            }
                            // On iPad, use the centralized add note action (same as bottom + icon)
                            if isiPad, let addNoteAction = iPadAddNoteAction {
                                addNoteAction()
                            } else {
                                createNewNote()
                            }
                        }
                    )

                // Content
                VStack(spacing: AppDimensions.cardSpacing) {
                    // Search bar - only show if there are notes for this account
                    if accountNoteCount > 0 {
                        searchBar
                    }

                    if accountNoteCount == 0 {
                        // Empty state - no notes for this account
                        EmptyStateView(
                            icon: "note.text",
                            title: "No Notes",
                            message: "Create notes to keep track of important information",
                            buttonTitle: "Create Note",
                            buttonAction: {
                                guard canAddNote else {
                                    showUpgradePrompt = true
                                    return
                                }
                                // On iPad, use the centralized add note action
                                if isiPad, let addNoteAction = iPadAddNoteAction {
                                    addNoteAction()
                                } else {
                                    createNewNote()
                                }
                            }
                        )
                        .padding(.top, 40)
                    } else if displayedNotes.isEmpty {
                        // No search results (has notes but searched to nothing)
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.textSecondary)
                            Text("No notes found")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.top, 40)
                    } else {
                        // Notes list
                        List {
                            ForEach(displayedNotes) { note in
                                NoteListCard(
                                    note: note,
                                    onTap: {
                                        // On iPad, use the centralized edit note action
                                        if isiPad, let editNoteAction = iPadEditNoteAction {
                                            editNoteAction(note)
                                        } else {
                                            selectedNote = note
                                        }
                                    },
                                    onTogglePin: {
                                        note.isPinned.toggle()
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        noteToDelete = note
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
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
                        .onChange(of: displayedNotes.count) { _, count in
                            let rowHeight: CGFloat = 76
                            let spacing: CGFloat = AppDimensions.cardSpacing
                            listContentHeight = CGFloat(count) * (rowHeight + spacing)
                        }
                        .onAppear {
                            let rowHeight: CGFloat = 76
                            let spacing: CGFloat = AppDimensions.cardSpacing
                            listContentHeight = CGFloat(displayedNotes.count) * (rowHeight + spacing)
                        }

                        // Premium limit reached banner
                        if !displayedNotes.isEmpty && !canAddNote {
                            PremiumFeatureLockBanner(
                                feature: .notes,
                                onUpgrade: { showUpgradePrompt = true }
                            )
                        }
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
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeView()
        }
        // iPhone: Use sheets for note editing (iPad uses centralized side panel)
        .sheet(item: isiPad ? .constant(nil) : $selectedNote, onDismiss: handleSheetDismiss) { note in
            NoteEditorView(note: note, isNewNote: false, onDelete: {
                noteToDelete = note
            })
        }
        .sheet(item: isiPad ? .constant(nil) : $newNote, onDismiss: handleNewNoteDismiss) { note in
            NoteEditorView(note: note, isNewNote: true, onDelete: {
                noteToDelete = note
            }, onSave: {
                // Insert the note into context only when user explicitly saves
                modelContext.insert(note)
                newNoteSaved = true
            })
        }
        .alert("Delete Note", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    // Delete from Supabase if synced
                    if let remoteId = note.supabaseId {
                        Task {
                            try? await syncService.deleteRemote(id: remoteId)
                        }
                    }
                    modelContext.delete(note)
                    noteToDelete = nil
                }
            }
        } message: {
            if let note = noteToDelete {
                Text("Are you sure you want to delete \"\(note.displayTitle)\"?")
            }
        }
        .task {
            // Fetch remote changes on appear
            await fetchRemoteChanges()
            // Sync any pending local notes
            await syncPendingNotes()
        }
        .refreshable {
            await fetchRemoteChanges()
        }
        .onReceive(NotificationCenter.default.publisher(for: .notesDidChange)) { _ in
            Task { await fetchRemoteChanges() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDidChange)) { _ in
            Task { await fetchRemoteChanges() }
        }
    }

    // MARK: - Sync Methods

    private func fetchRemoteChanges() async {
        guard let accountId = appState.currentAccount?.id else {
            #if DEBUG
            print("No current account for syncing notes")
            #endif
            return
        }

        do {
            let remoteNotes = try await syncService.fetchRemoteChanges(since: syncService.lastSyncDate, accountId: accountId)
            if !remoteNotes.isEmpty {
                try await syncService.mergeRemoteNotes(remoteNotes, into: modelContext)
            }
        } catch {
            #if DEBUG
            print("Failed to fetch remote notes: \(error)")
            #endif
        }
    }

    private func syncPendingNotes() async {
        let pendingNotes = allNotes.filter { !$0.isSynced }
        if !pendingNotes.isEmpty {
            do {
                try await syncService.syncPendingNotes(pendingNotes)
            } catch {
                #if DEBUG
                print("Failed to sync pending notes: \(error)")
                #endif
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)

            TextField("Search notes", text: $searchText)
                .font(.appBody)
                .foregroundColor(.textPrimary)
                .focused($isSearchFocused)

            // Show confirm button when typing, X button when focused or has text
            if !searchText.isEmpty && isSearchFocused {
                // Confirm search (dismiss keyboard but keep search)
                Button {
                    isSearchFocused = false
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentYellow)
                }
            }

            if !searchText.isEmpty || isSearchFocused {
                // Clear search and dismiss keyboard
                Button {
                    searchText = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Filtered Notes

    private var displayedNotes: [LocalNote] {
        var notes = allNotes

        // Filter by account
        if let accountId = appState.currentAccount?.id {
            notes = notes.filter { $0.accountId == accountId }
        }

        // Filter by search text
        if !searchText.isEmpty {
            notes = notes.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.contentPlainText.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort: pinned first
        return notes.sorted { $0.isPinned && !$1.isPinned }
    }

    // MARK: - Actions

    private func createNewNote() {
        // On iPad, this is called only on iPhone since iPad uses iPadAddNoteAction
        // Create note but DON'T insert into context yet
        // It will only be inserted when the user explicitly saves
        newNoteSaved = false
        let note = LocalNote(
            title: "",
            accountId: appState.currentAccount?.id
        )
        newNote = note
    }

    private func handleSheetDismiss() {
        if let note = noteToDelete {
            modelContext.delete(note)
            noteToDelete = nil
        }
    }

    private func handleNewNoteDismiss() {
        if let note = noteToDelete, newNoteSaved {
            // User explicitly requested deletion after saving
            modelContext.delete(note)
            noteToDelete = nil
        }
        // If not saved, the note was never inserted, so nothing to delete
        newNote = nil
        newNoteSaved = false
    }
}

// MARK: - Note List Card
/// Card component for displaying a note in the list, styled like ProfileListCard
struct NoteListCard: View {
    let note: LocalNote
    var onTap: () -> Void = {}
    var onTogglePin: () -> Void = {}

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                // Note icon - rounded square, aligned to top
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(appAccentColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "note.text")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(appAccentColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 6) {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(appAccentColor)
                                .padding(.top, 4)
                        }

                        Text(note.displayTitle)
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.leading)
                    }

                    Text(note.formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary.opacity(0.7))
                }

                Spacer()

                // Pin/Unpin button
                Button {
                    onTogglePin()
                } label: {
                    Image(systemName: note.isPinned ? "pin.slash.fill" : "pin.fill")
                        .font(.system(size: 16))
                        .foregroundColor(note.isPinned ? appAccentColor : .textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview("Notes List") {
    NavigationStack {
        NotesListView()
    }
    .modelContainer(for: LocalNote.self)
    .environmentObject(AppState.forPreview())
    .environment(UserHeaderOverrides())
    .environment(UserPreferences())
    .environment(HeaderStyleManager())
}
