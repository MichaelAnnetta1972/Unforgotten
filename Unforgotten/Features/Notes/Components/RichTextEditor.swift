import SwiftUI
import UIKit

// MARK: - Rich Text Formatting Actions
/// Observable object that exposes formatting actions to SwiftUI
class RichTextFormattingActions: ObservableObject {
    weak var coordinator: RichTextEditor.Coordinator?

    func bold() { coordinator?.boldTapped() }
    func italic() { coordinator?.italicTapped() }
    func underline() { coordinator?.underlineTapped() }
    func bulletList() { coordinator?.bulletTapped() }
    func numberedList() { coordinator?.numberedTapped() }
    func heading() { coordinator?.headingTapped() }
    func dismissKeyboard() { coordinator?.doneTapped() }
}

// MARK: - Rich Text Editor
/// A UITextView wrapper that supports immediate rich text formatting like Apple Notes
struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var accentColor: Color
    var placeholder: String = "Start writing..."
    var onTextChange: (() -> Void)?
    var hideKeyboardToolbar: Bool = false  // When true, don't show keyboard accessory (for iPad inline toolbar)
    var formattingActions: RichTextFormattingActions?  // Optional reference to expose formatting actions

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 17)
        textView.textColor = UIColor.label
        textView.tintColor = UIColor(accentColor)
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsEditingTextAttributes = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive

        // Set initial attributed text
        if attributedText.length > 0 {
            textView.attributedText = attributedText
        }

        // Create input accessory view (formatting toolbar) - only if not hidden
        if !hideKeyboardToolbar {
            textView.inputAccessoryView = context.coordinator.createToolbar(accentColor: accentColor)
        }

        // Setup placeholder
        context.coordinator.setupPlaceholder(in: textView, placeholder: placeholder)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update if the text actually changed and we're not currently editing
        if !context.coordinator.isEditing {
            if textView.attributedText != attributedText {
                let selectedRange = textView.selectedRange
                textView.attributedText = attributedText
                // Restore selection if valid
                if selectedRange.location + selectedRange.length <= textView.attributedText.length {
                    textView.selectedRange = selectedRange
                }
            }
        }

        // Update tint color
        textView.tintColor = UIColor(accentColor)

        // Update toolbar tint
        if let toolbar = textView.inputAccessoryView as? UIToolbar {
            toolbar.tintColor = UIColor(accentColor)
            for item in toolbar.items ?? [] {
                if item.style == .done {
                    item.tintColor = UIColor(accentColor)
                }
            }
        }

        // Update placeholder visibility
        context.coordinator.updatePlaceholder(isEmpty: textView.attributedText.length == 0)
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        // Link formatting actions if provided
        formattingActions?.coordinator = coordinator
        return coordinator
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var isEditing = false
        weak var textView: UITextView?
        private var placeholderLabel: UILabel?

        // Default typing attributes
        private var defaultAttributes: [NSAttributedString.Key: Any] {
            [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label
            ]
        }

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func setupPlaceholder(in textView: UITextView, placeholder: String) {
            self.textView = textView

            let label = UILabel()
            label.text = placeholder
            label.font = UIFont.systemFont(ofSize: 17)
            label.textColor = UIColor.placeholderText
            label.translatesAutoresizingMaskIntoConstraints = false
            textView.addSubview(label)

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: textView.topAnchor, constant: textView.textContainerInset.top),
                label.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: textView.textContainerInset.left)
            ])

            placeholderLabel = label
            label.isHidden = textView.attributedText.length > 0
        }

        func updatePlaceholder(isEmpty: Bool) {
            placeholderLabel?.isHidden = !isEmpty
        }

        // MARK: - Toolbar Creation
        func createToolbar(accentColor: Color) -> UIToolbar {
            // Create a standard 44pt toolbar - iOS handles positioning above keyboard
            // On iPad with hardware keyboard, this sits at the bottom of the input area
            let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
            toolbar.barStyle = .default
            toolbar.isTranslucent = true
            toolbar.tintColor = UIColor(accentColor)
            toolbar.sizeToFit()

            // Create compact buttons with reduced spacing
            let buttonSize: CGFloat = 32

            func makeButton(systemName: String, action: Selector) -> UIBarButtonItem {
                let button = UIButton(type: .system)
                button.setImage(UIImage(systemName: systemName), for: .normal)
                button.tintColor = UIColor(accentColor)
                button.addTarget(self, action: action, for: .touchUpInside)
                button.frame = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)
                return UIBarButtonItem(customView: button)
            }

            let boldButton = makeButton(systemName: "bold", action: #selector(boldTapped))
            let italicButton = makeButton(systemName: "italic", action: #selector(italicTapped))
            let underlineButton = makeButton(systemName: "underline", action: #selector(underlineTapped))
            let bulletButton = makeButton(systemName: "list.bullet", action: #selector(bulletTapped))
            let numberedButton = makeButton(systemName: "list.number", action: #selector(numberedTapped))
            let headingButton = makeButton(systemName: "textformat.size.larger", action: #selector(headingTapped))

            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

            let doneButton = UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(doneTapped)
            )
            doneButton.tintColor = UIColor(accentColor)

            // All formatting buttons in one continuous group with tight spacing
            toolbar.items = [
                boldButton, italicButton, underlineButton,
                bulletButton, numberedButton, headingButton,
                flexSpace,
                doneButton
            ]

            return toolbar
        }

        // MARK: - UITextViewDelegate
        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            // Set default typing attributes if at an empty location
            if textView.typingAttributes[.font] == nil {
                textView.typingAttributes = defaultAttributes
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
        }

        func textViewDidChange(_ textView: UITextView) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.attributedText = textView.attributedText
                self?.parent.onTextChange?()
                self?.updatePlaceholder(isEmpty: textView.attributedText.length == 0)
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // Update typing attributes based on current selection
            // This ensures newly typed text inherits formatting from cursor position
        }

        // MARK: - Formatting Actions
        @objc func boldTapped() {
            applyFontTrait(.traitBold)
        }

        @objc func italicTapped() {
            applyFontTrait(.traitItalic)
        }

        @objc func underlineTapped() {
            toggleAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue)
        }

        @objc func bulletTapped() {
            insertListPrefix("•  ")
        }

        @objc func numberedTapped() {
            insertNumberedListItem()
        }

        @objc func headingTapped() {
            applyHeadingStyle()
        }

        @objc func doneTapped() {
            textView?.resignFirstResponder()
        }

        // MARK: - Formatting Helpers

        /// Apply or remove a font trait (bold/italic)
        private func applyFontTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
            guard let textView = textView else { return }

            let range = textView.selectedRange

            if range.length > 0 {
                // Apply to selection
                let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)

                mutableAttr.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                    guard let currentFont = value as? UIFont else { return }

                    var newTraits = currentFont.fontDescriptor.symbolicTraits

                    // Toggle the trait
                    if newTraits.contains(trait) {
                        newTraits.remove(trait)
                    } else {
                        newTraits.insert(trait)
                    }

                    if let newDescriptor = currentFont.fontDescriptor.withSymbolicTraits(newTraits) {
                        let newFont = UIFont(descriptor: newDescriptor, size: currentFont.pointSize)
                        mutableAttr.addAttribute(.font, value: newFont, range: subRange)
                    }
                }

                textView.attributedText = mutableAttr
                textView.selectedRange = range

                DispatchQueue.main.async { [weak self] in
                    self?.parent.attributedText = textView.attributedText
                    self?.parent.onTextChange?()
                }
            } else {
                // No selection - update typing attributes for next input
                var typingAttrs = textView.typingAttributes
                let currentFont = typingAttrs[.font] as? UIFont ?? UIFont.systemFont(ofSize: 17)
                var newTraits = currentFont.fontDescriptor.symbolicTraits

                if newTraits.contains(trait) {
                    newTraits.remove(trait)
                } else {
                    newTraits.insert(trait)
                }

                if let newDescriptor = currentFont.fontDescriptor.withSymbolicTraits(newTraits) {
                    let newFont = UIFont(descriptor: newDescriptor, size: currentFont.pointSize)
                    typingAttrs[.font] = newFont
                    textView.typingAttributes = typingAttrs
                }
            }
        }

        /// Toggle an attribute (like underline)
        private func toggleAttribute(_ key: NSAttributedString.Key, value: Any) {
            guard let textView = textView else { return }

            let range = textView.selectedRange

            if range.length > 0 {
                let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)

                // Check if attribute exists in range
                var hasAttribute = false
                mutableAttr.enumerateAttribute(key, in: range, options: []) { existingValue, _, stop in
                    if existingValue != nil {
                        hasAttribute = true
                        stop.pointee = true
                    }
                }

                if hasAttribute {
                    mutableAttr.removeAttribute(key, range: range)
                } else {
                    mutableAttr.addAttribute(key, value: value, range: range)
                }

                textView.attributedText = mutableAttr
                textView.selectedRange = range

                DispatchQueue.main.async { [weak self] in
                    self?.parent.attributedText = textView.attributedText
                    self?.parent.onTextChange?()
                }
            } else {
                // Update typing attributes
                var typingAttrs = textView.typingAttributes
                if typingAttrs[key] != nil {
                    typingAttrs.removeValue(forKey: key)
                } else {
                    typingAttrs[key] = value
                }
                textView.typingAttributes = typingAttrs
            }
        }

        /// Insert a bullet point at the current line
        private func insertListPrefix(_ prefix: String) {
            guard let textView = textView else { return }

            let text = textView.text ?? ""
            let nsText = text as NSString
            let cursorPosition = textView.selectedRange.location

            // Find start of current line
            var lineStart = cursorPosition
            while lineStart > 0 && nsText.character(at: lineStart - 1) != unichar(10) { // 10 = newline
                lineStart -= 1
            }

            // Check if line already has this prefix
            let lineEnd = nsText.range(of: "\n", options: [], range: NSRange(location: lineStart, length: nsText.length - lineStart)).location
            let actualLineEnd = lineEnd == NSNotFound ? nsText.length : lineEnd
            let currentLine = nsText.substring(with: NSRange(location: lineStart, length: actualLineEnd - lineStart))

            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)

            if currentLine.hasPrefix(prefix) {
                // Remove prefix
                mutableAttr.deleteCharacters(in: NSRange(location: lineStart, length: prefix.count))
                textView.attributedText = mutableAttr
                textView.selectedRange = NSRange(location: max(0, cursorPosition - prefix.count), length: 0)
            } else {
                // Add prefix with default formatting
                let prefixAttr = NSAttributedString(string: prefix, attributes: defaultAttributes)
                mutableAttr.insert(prefixAttr, at: lineStart)
                textView.attributedText = mutableAttr
                textView.selectedRange = NSRange(location: cursorPosition + prefix.count, length: 0)
            }

            DispatchQueue.main.async { [weak self] in
                self?.parent.attributedText = textView.attributedText
                self?.parent.onTextChange?()
            }
        }

        /// Insert a numbered list item
        private func insertNumberedListItem() {
            guard let textView = textView else { return }

            let text = textView.text ?? ""
            let nsText = text as NSString
            let cursorPosition = textView.selectedRange.location

            // Find the current line number by counting previous numbered items
            var lineStart = cursorPosition
            while lineStart > 0 && nsText.character(at: lineStart - 1) != unichar(10) {
                lineStart -= 1
            }

            // Find the last number used before this line
            let textBefore = nsText.substring(to: lineStart)
            let lines = textBefore.components(separatedBy: "\n")
            var lastNumber = 0

            for line in lines.reversed() {
                if let match = line.range(of: #"^(\d+)\.\s"#, options: .regularExpression) {
                    if let num = Int(line[match].dropLast(2)) {
                        lastNumber = num
                        break
                    }
                }
            }

            let nextNumber = lastNumber + 1
            let prefix = "\(nextNumber). "

            insertListPrefix(prefix)
        }

        /// Apply heading style (larger, bold)
        private func applyHeadingStyle() {
            guard let textView = textView else { return }

            let range = textView.selectedRange

            // Find current line range
            let text = textView.text ?? ""
            let nsText = text as NSString
            let cursorPosition = range.location

            var lineStart = cursorPosition
            while lineStart > 0 && nsText.character(at: lineStart - 1) != unichar(10) {
                lineStart -= 1
            }

            let lineEnd = nsText.range(of: "\n", options: [], range: NSRange(location: lineStart, length: nsText.length - lineStart)).location
            let actualLineEnd = lineEnd == NSNotFound ? nsText.length : lineEnd
            let lineRange = NSRange(location: lineStart, length: actualLineEnd - lineStart)

            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)

            // Check if already a heading (font size > 17)
            var isHeading = false
            if lineRange.length > 0 {
                mutableAttr.enumerateAttribute(.font, in: lineRange, options: []) { value, _, stop in
                    if let font = value as? UIFont, font.pointSize > 18 {
                        isHeading = true
                        stop.pointee = true
                    }
                }
            }

            if isHeading {
                // Remove heading - set to normal
                let normalFont = UIFont.systemFont(ofSize: 17)
                mutableAttr.addAttribute(.font, value: normalFont, range: lineRange)
            } else {
                // Apply heading - larger and bold
                let headingFont = UIFont.boldSystemFont(ofSize: 22)
                mutableAttr.addAttribute(.font, value: headingFont, range: lineRange)
            }

            textView.attributedText = mutableAttr
            textView.selectedRange = range

            DispatchQueue.main.async { [weak self] in
                self?.parent.attributedText = textView.attributedText
                self?.parent.onTextChange?()
            }
        }
    }
}

// MARK: - Preview
#Preview("Rich Text Editor") {
    struct PreviewWrapper: View {
        @State private var attributedText: NSAttributedString = {
            let attr = NSMutableAttributedString()
            attr.append(NSAttributedString(string: "Welcome to Notes\n", attributes: [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.label
            ]))
            attr.append(NSAttributedString(string: "\nThis is ", attributes: [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label
            ]))
            attr.append(NSAttributedString(string: "bold", attributes: [
                .font: UIFont.boldSystemFont(ofSize: 17),
                .foregroundColor: UIColor.label
            ]))
            attr.append(NSAttributedString(string: " and ", attributes: [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label
            ]))
            attr.append(NSAttributedString(string: "italic", attributes: [
                .font: UIFont.italicSystemFont(ofSize: 17),
                .foregroundColor: UIColor.label
            ]))
            attr.append(NSAttributedString(string: " text.\n\n•  First item\n•  Second item", attributes: [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label
            ]))
            return attr
        }()

        var body: some View {
            VStack {
                RichTextEditor(
                    attributedText: $attributedText,
                    accentColor: .orange
                )
                .frame(height: 400)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding()
            }
            .background(Color(.secondarySystemBackground))
        }
    }

    return PreviewWrapper()
}
