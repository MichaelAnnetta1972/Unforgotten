import SwiftUI
import PhotosUI

// MARK: - Appearance Settings View
struct AppearanceSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @Environment(HeaderStyleManager.self) private var headerStyleManager

    /// Computed effective accent color (respects hasCustomAccentColor flag)
    private var effectiveAccentColor: Color {
        if userPreferences.hasCustomAccentColor {
            return userPreferences.accentColor
        } else {
            return headerStyleManager.defaultAccentColor
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 50))
                                .foregroundColor(effectiveAccentColor)

                            Text("Appearance")
                                .font(.appLargeTitle)
                                .foregroundColor(.textPrimary)

                            Text("Personalize how Unforgotten looks")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.top, 24)

                        // Header Style Section
                        HeaderStylePicker()
                            .padding(.horizontal, AppDimensions.screenPadding)

                        // Accent Color Section
                        AccentColorPickerWithReset()
                            .padding(.horizontal, AppDimensions.screenPadding)

                        // Custom Headers Section
                        CustomHeadersSection()
                            .padding(.horizontal, AppDimensions.screenPadding)

                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(effectiveAccentColor)
                }
            }
        }
    }
}

// MARK: - Accent Color Picker With Reset
/// Accent color picker that includes a "Reset to Style Default" button
struct AccentColorPickerWithReset: View {
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(HeaderStyleManager.self) private var headerStyleManager

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    /// The effective accent color based on custom setting or style default
    private var effectiveAccentColor: Color {
        if userPreferences.hasCustomAccentColor {
            return userPreferences.accentColor
        } else {
            return headerStyleManager.defaultAccentColor
        }
    }

    /// The name of the effective accent color
    private var effectiveColorName: String {
        if userPreferences.hasCustomAccentColor {
            return userPreferences.selectedAccentColor.name
        } else {
            return "Style Default (\(headerStyleManager.currentStyle.name))"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("Accent Color")
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Text("Choose a color for buttons and highlights")
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            // Color grid
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(AccentColorOption.allCases) { option in
                    AccentColorButton(
                        option: option,
                        isSelected: userPreferences.hasCustomAccentColor && userPreferences.selectedAccentColor == option,
                        action: {
                            userPreferences.selectColor(option)
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    )
                }
            }

            // Selected color name
            HStack {
                Circle()
                    .fill(effectiveAccentColor)
                    .frame(width: 16, height: 16)

                Text("Selected: \(effectiveColorName)")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.top, 8)

            // Reset to style default button
            if userPreferences.hasCustomAccentColor {
                Button {
                    userPreferences.resetToStyleDefault()
                    // Haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Style Default")
                    }
                    .font(.appBody)
                    .foregroundColor(effectiveAccentColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.smallCornerRadius)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Custom Headers Section
struct CustomHeadersSection: View {
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @State private var showClearAllConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("Custom Header Images")
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            Text("Tap the camera icon on any page header to set a custom background image")
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            // List of pages with custom headers
            if !headerOverrides.pagesWithCustomHeaders.isEmpty {
                VStack(spacing: 12) {
                    ForEach(headerOverrides.pagesWithCustomHeaders) { page in
                        CustomHeaderRow(page: page)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 24))
                        .foregroundColor(.textSecondary)

                    Text("No custom headers set")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.smallCornerRadius)
            }

            // Clear all button (only show if there are custom headers)
            if !headerOverrides.pagesWithCustomHeaders.isEmpty {
                Button {
                    showClearAllConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Custom Headers")
                    }
                    .font(.appBody)
                    .foregroundColor(.medicalRed)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.smallCornerRadius)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .alert("Clear All Headers?", isPresented: $showClearAllConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                withAnimation {
                    headerOverrides.clearAllImages()
                }
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } message: {
            Text("This will remove all custom header images and restore the defaults.")
        }
    }
}

// MARK: - Custom Header Row
struct CustomHeaderRow: View {
    let page: PageIdentifier
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @State private var showRemoveConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            // Preview thumbnail
            if let image = headerOverrides.swiftUIImage(for: page) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 40)
                    .cornerRadius(6)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.cardBackgroundSoft)
                    .frame(width: 60, height: 40)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.textSecondary)
                    )
            }

            // Page name
            VStack(alignment: .leading, spacing: 2) {
                Text(page.displayName)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                Text("Custom image set")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Remove button
            Button {
                showRemoveConfirm = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.textSecondary)
                    .font(.title3)
            }
        }
        .padding(12)
        .background(Color.cardBackgroundSoft)
        .cornerRadius(AppDimensions.smallCornerRadius)
        .alert("Remove Custom Header?", isPresented: $showRemoveConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                withAnimation {
                    headerOverrides.clearImage(for: page)
                }
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        } message: {
            Text("Remove the custom header image for \(page.displayName)?")
        }
    }
}

// MARK: - Preview
#Preview {
    AppearanceSettingsView()
        .environment(UserPreferences())
        .environment(UserHeaderOverrides())
        .environment(HeaderStyleManager())
}
