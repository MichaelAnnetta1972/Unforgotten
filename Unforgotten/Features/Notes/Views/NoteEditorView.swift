import SwiftUI
import SwiftData

// MARK: - Note Editor View
/// Full-screen editor for creating and editing notes with rich text formatting like Apple Notes
struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let note: LocalNote
    let isNewNote: Bool
    var onDelete: (() -> Void)?
    var onSave: (() -> Void)?
    var onClose: (() -> Void)?  // Optional close action for side panel presentation

    // Sync service for Supabase sync
    @StateObject private var syncService = NotesSyncService()

    // Formatting actions for inline toolbar on iPad
    @StateObject private var formattingActions = RichTextFormattingActions()

    @State private var title: String = ""
    @State private var attributedContent: NSAttributedString = NSAttributedString()
    @State private var selectedTheme: NoteTheme = .standard
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isPinned: Bool = false
    @State private var didSave: Bool = false
    @State private var syncTask: Task<Void, Never>?

    @FocusState private var isTitleFocused: Bool

    /// Check if we're in iPad mode (for inline toolbar)
    private var isiPad: Bool {
        horizontalSizeClass == .regular
    }

    /// Header height - full height on iPad, 50% on iPhone
    private var noteHeaderHeight: CGFloat {
        isiPad ? AppDimensions.headerHeight : AppDimensions.headerHeight / 2
    }

    // Store original values to detect changes
    private let originalTitle: String
    private let originalContent: NSAttributedString
    private let originalTheme: NoteTheme
    private let originalIsPinned: Bool
    

    init(note: LocalNote, isNewNote: Bool = false, onDelete: (() -> Void)? = nil, onSave: (() -> Void)? = nil, onClose: (() -> Void)? = nil) {
        self.note = note
        self.isNewNote = isNewNote
        self.onDelete = onDelete
        self.onSave = onSave
        self.onClose = onClose

        // Store original values
        self.originalTitle = note.title
        self.originalContent = note.getAttributedContent()
        self.originalTheme = note.noteTheme
        self.originalIsPinned = note.isPinned

        _title = State(initialValue: note.title)
        _attributedContent = State(initialValue: note.getAttributedContent())
        _selectedTheme = State(initialValue: note.noteTheme)
        _isPinned = State(initialValue: note.isPinned)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                // Main content with fixed header and editor
                VStack(spacing: 0) {
                    // Fixed theme-based header image (50% height)
                    noteHeaderSection

                    // Content area
                    VStack(alignment: .leading, spacing: 0) {
                        // iPad inline formatting toolbar (above title)
                        if isiPad {
                            InlineFormattingToolbar(
                                formattingActions: formattingActions,
                                accentColor: appAccentColor
                            )
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                        }

                        // Title field
                        TextField("Title", text: $title)
                            .font(.appLargeTitle)
                            .foregroundColor(.textPrimary)
                            .focused($isTitleFocused)
                            .submitLabel(.next)
                            .padding(.horizontal, 24)
                            .padding(.top, isiPad ? 12 : 20)

                        // Rich text editor (formatting applied immediately like Apple Notes)
                        RichTextEditor(
                            attributedText: $attributedContent,
                            accentColor: appAccentColor,
                            placeholder: "Start writing...",
                            onTextChange: {
                                // Content changed - auto-save will handle this on dismiss
                            },
                            hideKeyboardToolbar: isiPad,
                            formattingActions: formattingActions
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                // Custom toolbar with proper spacing from top
                HStack {
                    // Close button (only shown when onClose is provided)
                    if onClose != nil {
                        Button {
                            // Save changes before closing
                            if hasUnsavedChanges && hasContent {
                                saveNote()
                                didSave = true
                                onSave?()  // Trigger insert for new notes
                            }
                            onClose?()
                        } label: {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    HStack(alignment: .center, spacing: 12) {
                        // Theme picker (36x36 circle)
                        CompactThemePicker(selectedTheme: $selectedTheme)

                        // Share button
                        Button {
                            showShareSheet = true
                        } label: {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                )
                        }
                        .buttonStyle(.plain)

                        // Save button (checkmark)
                        Button {
                            saveAndDismiss()
                        } label: {
                            Circle()
                                .fill(appAccentColor)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                if isNewNote {
                    // New notes start with title focused
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isTitleFocused = true
                    }
                }
            }
            .onDisappear {
                // Cancel any pending sync tasks to prevent accessing invalid context
                syncTask?.cancel()
                syncTask = nil
                syncService.cancelPendingSync()

                // Auto-save on dismiss if there are unsaved changes
                if !didSave && hasUnsavedChanges {
                    if isNewNote {
                        // Only save new notes that have content
                        if hasContent {
                            // Update local SwiftData properties
                            note.title = title
                            note.setContent(attributedContent)
                            note.noteTheme = selectedTheme
                            note.isPinned = isPinned
                            note.updatedAt = Date()
                            note.isSynced = false
                            onSave?()

                            // Trigger immediate sync to Supabase (no debounce since view is disappearing)
                            let noteToSync = note
                            let syncServiceRef = syncService
                            Task.detached { @MainActor in
                                do {
                                    try await syncServiceRef.syncImmediately(noteToSync)
                                } catch {
                                    #if DEBUG
                                    print("Failed to sync note on disappear: \(error)")
                                    #endif
                                }
                            }
                        }
                    } else {
                        // Update local SwiftData properties
                        note.title = title
                        note.setContent(attributedContent)
                        note.noteTheme = selectedTheme
                        note.isPinned = isPinned
                        note.updatedAt = Date()
                        note.isSynced = false

                        // Trigger immediate sync to Supabase (no debounce since view is disappearing)
                        let noteToSync = note
                        let syncServiceRef = syncService
                        Task.detached { @MainActor in
                            do {
                                try await syncServiceRef.syncImmediately(noteToSync)
                            } catch {
                                #if DEBUG
                                print("Failed to sync note on disappear: \(error)")
                                #endif
                            }
                        }
                    }
                }
            }
            .alert("Delete Note", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteNote()
                }
            } message: {
                Text("Are you sure you want to delete this note? This action cannot be undone.")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareText])
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.clear, for: .navigationBar)
        .containerBackground(.clear, for: .navigation)
    }

    // MARK: - Header Section

    private var noteHeaderSection: some View {
        ZStack {
            // Theme-based header image - use GeometryReader to constrain fill properly
            GeometryReader { geometry in
                noteHeaderBackground
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(height: noteHeaderHeight)
            .clipped()

            // Top gradient overlay for icon visibility
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.4), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: noteHeaderHeight * 0.4)

                Spacer()
            }

            // Bottom gradient overlay for text readability
            VStack {
                Spacer()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: noteHeaderHeight * 0.4)
            }
        }
        .frame(height: noteHeaderHeight)
    }

    @ViewBuilder
    private var noteHeaderBackground: some View {
        // Use independent note theme header images (not tied to app style)
        if let uiImage = UIImage(named: selectedTheme.headerImageName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .transition(.opacity)
                .id(selectedTheme.rawValue) // Force view refresh on theme change
        } else {
            // Fallback gradient if image not found
            LinearGradient(
                colors: selectedTheme.headerGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Computed Properties

    /// Plain text content for search/preview
    private var plainTextContent: String {
        attributedContent.string
    }

    /// Whether the note has any content (title or body)
    private var hasContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !plainTextContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Whether any changes have been made since opening
    private var hasUnsavedChanges: Bool {
        title != originalTitle ||
        attributedContent.string != originalContent.string ||
        selectedTheme != originalTheme ||
        isPinned != originalIsPinned
    }

    private var shareText: String {
        var text = title.isEmpty ? "Untitled Note" : title
        if !plainTextContent.isEmpty {
            text += "\n\n" + plainTextContent
        }
        return text
    }

    // MARK: - Actions

    private func saveNote() {
        // Update the note properties directly
        // SwiftData will auto-save changes
        note.title = title
        note.setContent(attributedContent)
        note.noteTheme = selectedTheme
        note.isPinned = isPinned
        note.updatedAt = Date()
        note.isSynced = false

        // Cancel any existing sync task
        syncTask?.cancel()

        // Sync to Supabase - call synchronously on main actor
        // The sync service will handle debouncing and captures data immediately
        // to avoid accessing the SwiftData model after view dismissal
        syncTask = Task { @MainActor in
            do {
                try await syncService.sync(note)
            } catch {
                if !Task.isCancelled {
                    #if DEBUG
                    print("Failed to sync note: \(error)")
                    #endif
                }
            }
        }
    }

    private func saveAndDismiss() {
        // Only save if there are changes and it's not an empty new note
        if !(isNewNote && title.isEmpty && plainTextContent.isEmpty) {
            saveNote()
            didSave = true
            onSave?()
        }
        // On iPad side panels, use onClose; otherwise use dismiss
        if let onClose = onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    /// Returns whether this note was explicitly saved by the user
    var wasSaved: Bool {
        didSave
    }

    private func deleteNote() {
        onDelete?()
        dismiss()
    }
}

// Note: ShareSheet is defined in SettingsView.swift

// MARK: - Inline Formatting Toolbar (iPad)
/// SwiftUI formatting toolbar for iPad - positioned inside the note view
struct InlineFormattingToolbar: View {
    @ObservedObject var formattingActions: RichTextFormattingActions
    let accentColor: Color

    var body: some View {
        HStack(spacing: 4) {
            FormatButton(icon: "bold", action: formattingActions.bold, accentColor: accentColor)
            FormatButton(icon: "italic", action: formattingActions.italic, accentColor: accentColor)
            FormatButton(icon: "underline", action: formattingActions.underline, accentColor: accentColor)

            Divider()
                .frame(height: 24)
                .padding(.horizontal, 8)

            FormatButton(icon: "list.bullet", action: formattingActions.bulletList, accentColor: accentColor)
            FormatButton(icon: "list.number", action: formattingActions.numberedList, accentColor: accentColor)
            FormatButton(icon: "textformat.size.larger", action: formattingActions.heading, accentColor: accentColor)

            Spacer()

            Button {
                formattingActions.dismissKeyboard()
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cardBackgroundSoft)
        )
    }
}

/// Individual formatting button
private struct FormatButton: View {
    let icon: String
    let action: () -> Void
    let accentColor: Color

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.textPrimary)
                .frame(width: 36, height: 36)
                .background(Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview("Note Editor") {
    let container = try! NotesContainerConfiguration.createPreviewContainer()
    let context = container.mainContext

    let note = LocalNote(title: "Gift Ideas for Mom", theme: .festive)
    note.setPlainTextContent("""
    Thinking about getting her a nice scarf this year.

    Ideas:
    • Cashmere scarf (blue or gray)
    • New cookbook
    • Spa gift card
    • Photo album of grandkids
    """)
    context.insert(note)

    return NoteEditorView(note: note, isNewNote: false)
        .modelContainer(container)
}

#Preview("New Note") {
    let container = try! NotesContainerConfiguration.createPreviewContainer()
    let context = container.mainContext

    let note = LocalNote(title: "", theme: .standard)
    context.insert(note)

    return NoteEditorView(note: note, isNewNote: true)
        .modelContainer(container)
}
