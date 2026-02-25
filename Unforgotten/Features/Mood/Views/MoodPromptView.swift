import SwiftUI

// MARK: - Mood Prompt View
struct MoodPromptView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    /// Pass an existing entry to enable edit mode
    var existingEntry: MoodEntry? = nil

    @State private var selectedRating: Int? = nil
    @State private var note = ""
    @State private var showNoteField = false
    @State private var isSubmitting = false

    private var isEditing: Bool { existingEntry != nil }

    private let moods: [(emoji: String, label: String, rating: Int)] = [
        ("😢", "Sad", 1),
        ("😕", "Not Great", 2),
        ("😐", "Okay", 3),
        ("🙂", "Good", 4),
        ("😊", "Great", 5)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Question
                    VStack(spacing: 12) {
                        Text(isEditing ? "Update your mood" : "How are you feeling today?")
                            .font(.appTitle)
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(isEditing ? "Change your mood or note below" : "Track your mood to see patterns over time")
                            .font(.appBody)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Mood options
                    HStack(spacing: 16) {
                        ForEach(moods, id: \.rating) { mood in
                            MoodButton(
                                emoji: mood.emoji,
                                label: mood.label,
                                isSelected: selectedRating == mood.rating
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedRating = mood.rating
                                }
                            }
                        }
                    }
                    
                    // Optional note field
                    if showNoteField {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add a note (optional)")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                            
                            TextField("What's on your mind?", text: $note, axis: .vertical)
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                                .padding()
                                .frame(minHeight: 80, alignment: .topLeading)
                                .background(Color.cardBackgroundSoft)
                                .cornerRadius(AppDimensions.cardCornerRadius)
                                .lineLimit(3...6)
                        }
                        .padding(.horizontal, AppDimensions.screenPadding)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    Spacer()
                    
                    // Actions
                    VStack(spacing: 12) {
                        if selectedRating != nil && !showNoteField {
                            Button {
                                withAnimation {
                                    showNoteField = true
                                }
                            } label: {
                                Text(isEditing ? "Edit note" : "Add a note")
                                    .font(.appBody)
                                    .foregroundColor(.accentYellow)
                            }
                        }

                        PrimaryButton(
                            title: isEditing ? "Update" : "Save",
                            isLoading: isSubmitting
                        ) {
                            Task { await saveMood() }
                        }
                        .disabled(selectedRating == nil)

                        Button {
                            dismiss()
                        } label: {
                            Text(isEditing ? "Cancel" : "Skip for now")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .onAppear {
                if let entry = existingEntry {
                    selectedRating = entry.rating
                    if let existingNote = entry.note, !existingNote.isEmpty {
                        note = existingNote
                        showNoteField = true
                    }
                }
            }
        }
    }
    
    private func saveMood() async {
        guard let rating = selectedRating else { return }
        
        isSubmitting = true
        await appState.recordMood(rating: rating, note: note.isBlank ? nil : note)
        isSubmitting = false
        dismiss()
    }
}

// MARK: - Mood Button
struct MoodButton: View {
    let emoji: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 40))
                
                Text(label)
                    .font(.appCaptionSmall)
                    .foregroundColor(isSelected ? .accentYellow : .textSecondary)
            }
            .frame(width: 60)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentYellow.opacity(0.15) : Color.clear)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(isSelected ? Color.accentYellow : Color.clear, lineWidth: 2)
            )
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
    }
}

// MARK: - Preview
#Preview {
    MoodPromptView()
        .environmentObject(AppState.forPreview())
}
