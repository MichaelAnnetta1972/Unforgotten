import SwiftUI

// MARK: - Formatting Toolbar
/// Floating toolbar for rich text formatting
struct FormattingToolbar: View {
    @Binding var content: String
    let accentColor: Color
    var onBold: (() -> Void)?
    var onItalic: (() -> Void)?

    @State private var showTextStylePicker = false

    var body: some View {
        HStack(spacing: 0) {
            // Text style picker
            ToolbarButton(
                icon: "textformat.size",
                label: "Aa",
                isTextLabel: true,
                accentColor: accentColor
            ) {
                showTextStylePicker = true
            }
            .popover(isPresented: $showTextStylePicker) {
                TextStylePicker(
                    content: $content,
                    accentColor: accentColor
                )
                .presentationCompactAdaptation(.popover)
            }

            ToolbarDivider()

            // Bold
            ToolbarButton(
                icon: "bold",
                accentColor: accentColor,
                action: onBold ?? {}
            )

            // Italic
            ToolbarButton(
                icon: "italic",
                accentColor: accentColor,
                action: onItalic ?? {}
            )

            ToolbarDivider()

            // Bullet list
            ToolbarButton(
                icon: "list.bullet",
                accentColor: accentColor
            ) {
                insertBulletPoint()
            }

            // Numbered list
            ToolbarButton(
                icon: "list.number",
                accentColor: accentColor
            ) {
                insertNumberedItem()
            }

            // Checklist
            ToolbarButton(
                icon: "checklist",
                accentColor: accentColor
            ) {
                insertChecklist()
            }

            ToolbarDivider()

            // Indent
            ToolbarButton(
                icon: "increase.indent",
                accentColor: accentColor
            ) {
                indentLine()
            }

            // Outdent
            ToolbarButton(
                icon: "decrease.indent",
                accentColor: accentColor
            ) {
                outdentLine()
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        )
        .padding(.horizontal, 8)
    }

    // MARK: - Formatting Actions

    private func insertChecklist() {
        if content.isEmpty || content.hasSuffix("\n") {
            content += "☐ "
        } else {
            content += "\n☐ "
        }
    }

    private func insertBulletPoint() {
        if content.isEmpty || content.hasSuffix("\n") {
            content += "• "
        } else {
            content += "\n• "
        }
    }

    private func insertNumberedItem() {
        let lines = content.components(separatedBy: "\n")
        var lastNumber = 0

        for line in lines.reversed() {
            if let match = line.range(of: #"^(\d+)\."#, options: .regularExpression) {
                if let num = Int(line[match].dropLast()) {
                    lastNumber = num
                    break
                }
            }
        }

        let nextNumber = lastNumber + 1

        if content.isEmpty || content.hasSuffix("\n") {
            content += "\(nextNumber). "
        } else {
            content += "\n\(nextNumber). "
        }
    }

    private func indentLine() {
        content += "    "
    }

    private func outdentLine() {
        if content.hasSuffix("    ") {
            content = String(content.dropLast(4))
        } else if content.hasSuffix("\t") {
            content = String(content.dropLast(1))
        }
    }
}

// MARK: - Toolbar Button
struct ToolbarButton: View {
    let icon: String
    var label: String?
    var isTextLabel: Bool = false
    var isActive: Bool = false
    let accentColor: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Group {
                if isTextLabel, let label = label {
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                }
            }
            .foregroundColor(isActive ? accentColor : .notePrimaryText)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed || isActive ? accentColor.opacity(0.15) : .clear)
            )
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
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
        .accessibilityLabel(label ?? icon)
    }
}

// MARK: - Toolbar Divider
struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.noteDivider)
            .frame(width: 1, height: 24)
            .padding(.horizontal, 4)
    }
}

// MARK: - Text Style Picker
struct TextStylePicker: View {
    @Binding var content: String
    let accentColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Text Style")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(TextStyle.allCases) { style in
                Button {
                    applyStyle(style)
                    dismiss()
                } label: {
                    HStack {
                        Text(style.displayName)
                            .font(style.previewFont)
                            .foregroundColor(.notePrimaryText)

                        Spacer()

                        Text(style.shortcut)
                            .font(.caption)
                            .foregroundColor(.noteSecondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                }
                .buttonStyle(.plain)

                if style != TextStyle.allCases.last {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
        .frame(width: 200)
        .padding(.bottom, 8)
    }

    private func applyStyle(_ style: TextStyle) {
        // For plain text, we just add markdown-style prefixes
        // A full implementation would use NSAttributedString
        switch style {
        case .title:
            if !content.isEmpty && !content.hasSuffix("\n") {
                content += "\n"
            }
            content += "# "
        case .heading:
            if !content.isEmpty && !content.hasSuffix("\n") {
                content += "\n"
            }
            content += "## "
        case .body:
            break // Default style
        case .monospace:
            content += "`"
        }
    }
}

// MARK: - Text Style
enum TextStyle: String, CaseIterable, Identifiable {
    case title
    case heading
    case body
    case monospace

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .title: return "Title"
        case .heading: return "Heading"
        case .body: return "Body"
        case .monospace: return "Monospace"
        }
    }

    var shortcut: String {
        switch self {
        case .title: return "⌘⇧T"
        case .heading: return "⌘⇧H"
        case .body: return "⌘⇧B"
        case .monospace: return "⌘⇧M"
        }
    }

    var previewFont: Font {
        switch self {
        case .title: return .system(size: 28, weight: .bold)
        case .heading: return .system(size: 22, weight: .bold)
        case .body: return .system(size: 17, weight: .regular)
        case .monospace: return .system(size: 15, weight: .regular, design: .monospaced)
        }
    }
}

// MARK: - Keyboard Toolbar
/// Toolbar that appears above the keyboard
struct KeyboardToolbar: View {
    @Binding var content: String
    let accentColor: Color
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            FormattingToolbar(
                content: $content,
                accentColor: accentColor
            )

            Spacer()

            Button("Done") {
                onDismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(accentColor)
            .padding(.trailing, 8)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Preview
#Preview("Formatting Toolbar") {
    struct PreviewWrapper: View {
        @State private var content = "Sample text content"

        var body: some View {
            VStack {
                Spacer()

                Text(content)
                    .padding()

                FormattingToolbar(
                    content: $content,
                    accentColor: .blue
                )
                .padding(.bottom, 20)
            }
        }
    }

    return PreviewWrapper()
}
