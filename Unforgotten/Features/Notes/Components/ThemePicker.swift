import SwiftUI

// MARK: - Theme Picker
/// Horizontal picker for selecting note theme
struct ThemePicker: View {
    @Binding var selectedTheme: NoteTheme
    var onThemeChange: ((NoteTheme) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(NoteTheme.allCases) { theme in
                    ThemePickerItem(
                        theme: theme,
                        isSelected: selectedTheme == theme
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTheme = theme
                        }
                        onThemeChange?(theme)
                    }
                }
            }
            .padding(.horizontal, NoteSpacing.editorHorizontalPadding)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Theme Picker Item
struct ThemePickerItem: View {
    let theme: NoteTheme
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Theme color circle
                ZStack {
                    Circle()
                        .fill(theme.accentColor.opacity(0.2))
                        .frame(width: 56, height: 56)

                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: theme.icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                        )

                    // Selection ring
                    if isSelected {
                        Circle()
                            .stroke(theme.accentColor, lineWidth: 3)
                            .frame(width: 56, height: 56)
                    }

                    // Checkmark overlay
                    if isSelected {
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(theme.accentColor)
                            )
                            .offset(x: 18, y: 18)
                    }
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)

                // Theme name
                Text(theme.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? theme.accentColor : .noteSecondaryText)
            }
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
        .accessibilityLabel("\(theme.displayName) theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Compact Theme Picker
/// Small inline theme picker for navigation bar
struct CompactThemePicker: View {
    @Binding var selectedTheme: NoteTheme
    @State private var showingPicker = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            Circle()
                .fill(selectedTheme.accentColor)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "paintpalette")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                )
        }
        .accessibilityLabel("Change theme")
        .popover(isPresented: $showingPicker) {
            ThemePickerPopover(selectedTheme: $selectedTheme)
                .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Theme Picker Popover
struct ThemePickerPopover: View {
    @Binding var selectedTheme: NoteTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Choose Theme")
                .font(.headline)
                .padding(.top, 16)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(NoteTheme.allCases) { theme in
                    Button {
                        withAnimation {
                            selectedTheme = theme
                        }
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                // Theme icon - rounded rectangle 48x48
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(theme.accentColor)
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Image(systemName: theme.icon)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                    )

                                // Selection ring - 56x56
                                if selectedTheme == theme {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(theme.accentColor, lineWidth: 2)
                                        .frame(width: 64, height: 64)
                                }

                                // Checkmark overlay - larger
                                if selectedTheme == theme {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.white)
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(theme.accentColor)
                                        )
                                        .offset(x: 20, y: 20)
                                }
                            }
                            .frame(width: 64, height: 64)

                            Text(theme.displayName)
                                .font(.caption)
                                .foregroundColor(selectedTheme == theme ? theme.accentColor : .noteSecondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 300)
    }
}

// MARK: - Preview
#Preview("Theme Picker") {
    struct PreviewWrapper: View {
        @State private var theme: NoteTheme = .standard

        var body: some View {
            VStack(spacing: 32) {
                ThemePicker(selectedTheme: $theme)

                Divider()

                HStack {
                    Text("Compact:")
                    CompactThemePicker(selectedTheme: $theme)
                }

                Text("Selected: \(theme.displayName)")
                    .foregroundColor(theme.accentColor)
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
