import SwiftUI
import UIKit

// MARK: - Attributed Text Editor
/// UITextView wrapper for rich text editing
struct AttributedTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var attributedText: NSAttributedString
    let theme: NoteTheme
    var placeholder: String = "Start writing..."
    var onTextChange: ((String) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.textColor = UIColor.label
        textView.tintColor = UIColor(theme.accentColor)
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainerInset = UIEdgeInsets(
            top: NoteSpacing.editorTopPadding,
            left: NoteSpacing.editorHorizontalPadding - 5,
            bottom: 100,
            right: NoteSpacing.editorHorizontalPadding - 5
        )

        // Accessibility
        textView.accessibilityLabel = "Note content"

        // Setup placeholder
        context.coordinator.setupPlaceholder(in: textView, placeholder: placeholder)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Update text if changed externally
        if textView.text != text && !context.coordinator.isEditing {
            textView.text = text
            context.coordinator.updatePlaceholder(in: textView, isEmpty: text.isEmpty)
        }

        // Update tint color
        textView.tintColor = UIColor(theme.accentColor)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AttributedTextEditor
        var isEditing = false
        private var placeholderLabel: UILabel?

        init(_ parent: AttributedTextEditor) {
            self.parent = parent
        }

        func setupPlaceholder(in textView: UITextView, placeholder: String) {
            let label = UILabel()
            label.text = placeholder
            label.font = UIFont.systemFont(ofSize: 17)
            label.textColor = UIColor.placeholderText
            label.translatesAutoresizingMaskIntoConstraints = false
            textView.addSubview(label)

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(
                    equalTo: textView.topAnchor,
                    constant: textView.textContainerInset.top
                ),
                label.leadingAnchor.constraint(
                    equalTo: textView.leadingAnchor,
                    constant: textView.textContainerInset.left + 5
                )
            ])

            placeholderLabel = label
            label.isHidden = !textView.text.isEmpty
        }

        func updatePlaceholder(in textView: UITextView, isEmpty: Bool) {
            placeholderLabel?.isHidden = !isEmpty
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange?(textView.text)
            updatePlaceholder(in: textView, isEmpty: textView.text.isEmpty)
        }
    }
}

// MARK: - Simple Text Editor
/// Simplified text editor for basic plain text
struct SimpleNoteEditor: View {
    @Binding var text: String
    let theme: NoteTheme
    var placeholder: String = "Start writing..."
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .font(NoteTypography.body)
                    .foregroundColor(.noteTertiaryText)
                    .padding(.horizontal, NoteSpacing.editorHorizontalPadding)
                    .padding(.top, NoteSpacing.editorTopPadding)
                    .allowsHitTesting(false)
            }

            // Text editor
            TextEditor(text: $text)
                .font(NoteTypography.body)
                .foregroundColor(.notePrimaryText)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .padding(.horizontal, NoteSpacing.editorHorizontalPadding - 5)
                .padding(.top, NoteSpacing.editorTopPadding - 8)
                .focused($isFocused)
                .tint(theme.accentColor)
        }
    }
}

// MARK: - Checkbox List Helper
/// Utility for managing checkbox lists in notes
struct CheckboxListHelper {
    /// Toggle a checkbox at the given position
    static func toggleCheckbox(in text: inout String, at position: Int) {
        let lines = text.components(separatedBy: "\n")
        var currentPosition = 0

        for (index, line) in lines.enumerated() {
            let lineEnd = currentPosition + line.count

            if position >= currentPosition && position <= lineEnd {
                // Found the line
                var newLines = lines
                if line.hasPrefix("☐ ") {
                    newLines[index] = "☑ " + String(line.dropFirst(2))
                } else if line.hasPrefix("☑ ") {
                    newLines[index] = "☐ " + String(line.dropFirst(2))
                }
                text = newLines.joined(separator: "\n")
                return
            }

            currentPosition = lineEnd + 1 // +1 for newline
        }
    }

    /// Count completed and total checkboxes
    static func countCheckboxes(in text: String) -> (completed: Int, total: Int) {
        let lines = text.components(separatedBy: "\n")
        var completed = 0
        var total = 0

        for line in lines {
            if line.hasPrefix("☐ ") {
                total += 1
            } else if line.hasPrefix("☑ ") {
                completed += 1
                total += 1
            }
        }

        return (completed, total)
    }

    /// Check if text contains any checkboxes
    static func hasCheckboxes(in text: String) -> Bool {
        text.contains("☐ ") || text.contains("☑ ")
    }
}

// MARK: - Preview
#Preview("Attributed Text Editor") {
    struct PreviewWrapper: View {
        @State private var text = "Sample note content\n\n☐ Task one\n☑ Task two\n• Bullet point"
        @State private var attributedText = NSAttributedString()
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                SimpleNoteEditor(
                    text: $text,
                    theme: .festive,
                    isFocused: $isFocused
                )
                .frame(height: 300)
                .background(Color.noteSecondaryBackground)
                .cornerRadius(12)
                .padding()
            }
        }
    }

    return PreviewWrapper()
}
