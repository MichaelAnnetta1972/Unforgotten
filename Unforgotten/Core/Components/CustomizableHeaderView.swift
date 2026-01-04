import SwiftUI
import PhotosUI

// MARK: - Customizable Header View
/// A header view that supports custom user-selected background images
/// Falls back to style-based video/image assets if no custom image is set
struct CustomizableHeaderView: View {
    // Required
    let pageIdentifier: PageIdentifier
    let title: String

    // Optional content - these override style-based assets if provided
    var subtitle: String? = nil
    var videoName: String? = nil
    var videoExtension: String = "mp4"
    var fallbackImageName: String? = nil

    // Navigation buttons
    var showBackButton: Bool = false
    var backAction: (() -> Void)? = nil
    var showHomeButton: Bool = false
    var homeAction: (() -> Void)? = nil
    var showAccountSwitcherButton: Bool = false
    var accountSwitcherAction: (() -> Void)? = nil
    var showSettingsButton: Bool = false
    var settingsAction: (() -> Void)? = nil
    var showEditButton: Bool = false
    var editAction: (() -> Void)? = nil
    var editButtonPosition: HeaderButtonPosition = .topRight
    var showAddButton: Bool = false
    var addAction: (() -> Void)? = nil
    var showReorderButton: Bool = false
    var isReordering: Bool = false
    var reorderAction: (() -> Void)? = nil

    // Customization
    var showCustomizeButton: Bool = true
    var roundedTopRightCorner: Bool = false
    var roundedTopLeftCorner: Bool = false
    var useLogo: Bool = false
    var logoImageName: String? = nil

    // Environment
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(HeaderStyleManager.self) private var headerStyleManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.iPadHomeAction) private var iPadHomeAction

    // State
    @State private var showImagePicker = false
    @State private var showImageOptions = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var customImage: UIImage?
    @State private var isLoadingImage = false
    @State private var settingsButtonPressed = false

    /// The current style's asset for this page
    private var styleAsset: HeaderAsset {
        headerStyleManager.asset(for: pageIdentifier)
    }

    /// Effective accent color (respects hasCustomAccentColor flag)
    private var effectiveAccentColor: Color {
        if userPreferences.hasCustomAccentColor {
            return userPreferences.accentColor
        } else {
            return headerStyleManager.defaultAccentColor
        }
    }

    /// Determine which corners should be rounded
    private var headerRoundedCorners: UIRectCorner {
        var corners: UIRectCorner = []
        if roundedTopRightCorner {
            corners.insert(.topRight)
        }
        // Auto-apply top-left corner on iPad content area (when iPadHomeAction is available)
        if roundedTopLeftCorner || iPadHomeAction != nil {
            corners.insert(.topLeft)
        }
        return corners
    }

    /// Corner radius for header
    private var headerCornerRadius: CGFloat {
        headerRoundedCorners.isEmpty ? 0 : 24
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background layer - use GeometryReader to constrain fill properly
            // Use id modifier to force recreation when style changes
            GeometryReader { geometry in
                backgroundView
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(height: AppDimensions.headerHeight)
            .clipped()
            .id(headerStyleManager.currentStyle.id)

            // Gradient overlay for text readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content overlay
            VStack {
                // Top row - Home/Back/AccountSwitcher button, customize button, and other top buttons
                HStack {
                    if showHomeButton, let homeAction = homeAction {
                        // Home button for iPad navigation
                        HeaderActionButton(icon: "house.fill", action: homeAction)
                    } else if showBackButton, let backAction = backAction {
                        HeaderActionButton(icon: "chevron.left", action: backAction)
                    } else if showAccountSwitcherButton, let accountSwitcherAction = accountSwitcherAction {
                        // Account switcher button
                        HeaderActionButton(icon: "person.2", action: accountSwitcherAction)
                    }

                    Spacer()

                    // Top right buttons
                    HStack(spacing: 12) {
                        // Customize/camera button
                        if showCustomizeButton {
                            CustomizeHeaderButton(
                                hasCustomImage: headerOverrides.hasCustomImage(for: pageIdentifier),
                                onTap: { showImageOptions = true }
                            )
                        }

                        if showEditButton && editButtonPosition == .topRight, let editAction = editAction {
                            HeaderActionButton(icon: "pencil", action: editAction)
                        }
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.top, horizontalSizeClass == .regular ? 40 : 60)

                Spacer()

                // Bottom row - Title and bottom-right buttons
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let subtitle = subtitle {
                            Text(subtitle.uppercased())
                                .font(.appCaption)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        if useLogo, let logoName = logoImageName, let logoImage = UIImage(named: logoName) {
                            Image(uiImage: logoImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 100)
                        } else {
                            Text(title)
                                .font(.appLargeTitle)
                                .foregroundColor(.white)
                        }
                    }

                    Spacer()

                    // Bottom right buttons
                    HStack(spacing: 12) {
                        if showReorderButton, let reorderAction = reorderAction {
                            Button {
                                reorderAction()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                                    Text(isReordering ? "Done" : "Reorder")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isReordering ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isReordering ? effectiveAccentColor : Color.white.opacity(0.2))
                                .cornerRadius(16)
                            }
                        }

                        if showAddButton, let addAction = addAction {
                            HeaderBottomActionButton(icon: "plus", label: nil, action: addAction)
                        }

                        if showEditButton && editButtonPosition == .bottomRight, let editAction = editAction {
                            HeaderBottomActionButton(icon: "pencil", label: "Edit", action: editAction)
                        }

                        if showSettingsButton, let settingsAction = settingsAction {
                            Button {
                                settingsAction()
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                                    .scaleEffect(settingsButtonPressed ? 0.9 : 1.0)
                                    .opacity(settingsButtonPressed ? 0.8 : 1.0)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: settingsButtonPressed)
                            }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in settingsButtonPressed = true }
                                    .onEnded { _ in settingsButtonPressed = false }
                            )
                        }
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.bottom, AppDimensions.screenPadding)
            }

            // Loading overlay
            if isLoadingImage {
                Color.black.opacity(0.5)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .frame(height: AppDimensions.headerHeight)
        .clipShape(
            RoundedCorner(
                radius: headerCornerRadius,
                corners: headerRoundedCorners
            )
        )
        .onAppear {
            // Load custom image if exists
            customImage = headerOverrides.image(for: pageIdentifier)
        }
        .confirmationDialog("Header Image", isPresented: $showImageOptions, titleVisibility: .visible) {
            Button("Choose Photo") {
                showImagePicker = true
            }

            if headerOverrides.hasCustomImage(for: pageIdentifier) {
                Button("Remove Custom Image", role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        headerOverrides.clearImage(for: pageIdentifier)
                        customImage = nil
                    }
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            }

            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            if let item = newValue {
                loadImage(from: item)
            }
        }
    }

    // MARK: - Background View

    @ViewBuilder
    private var backgroundView: some View {
        if let image = customImage {
            // Priority 1: Custom user image (highest priority)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .transition(.opacity)
        } else if let videoName = videoName {
            // Priority 2: Explicitly provided video name (for backwards compatibility)
            LoopingVideoPlayerView(
                videoName: videoName,
                videoExtension: videoExtension,
                isMuted: true,
                shouldLoop: true,
                gravity: .resizeAspectFill
            )
        } else if let imageName = fallbackImageName {
            // Priority 3: Explicitly provided image name (for backwards compatibility)
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Priority 4: Style-based asset (videos for home, images for other pages)
            styleBasedAssetView
        }
    }

    /// View for displaying the current style's asset (video or image)
    @ViewBuilder
    private var styleBasedAssetView: some View {
        switch styleAsset.type {
        case .video:
            LoopingVideoPlayerView(
                videoName: styleAsset.fileName,
                videoExtension: styleAsset.fileExtension,
                isMuted: true,
                shouldLoop: true,
                gravity: .resizeAspectFill
            )
        case .image:
            if let uiImage = UIImage(named: styleAsset.fileName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Fallback gradient if image not found
                LinearGradient(
                    colors: [effectiveAccentColor.opacity(0.8), effectiveAccentColor.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    // MARK: - Image Loading

    private func loadImage(from item: PhotosPickerItem) {
        isLoadingImage = true

        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    // Save to header overrides
                    headerOverrides.setImage(uiImage, for: pageIdentifier)

                    // Update local state with animation
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            customImage = headerOverrides.image(for: pageIdentifier)
                            isLoadingImage = false
                        }

                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                } else {
                    await MainActor.run {
                        isLoadingImage = false
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingImage = false
                }
                print("Failed to load image: \(error)")
            }
        }

        // Clear selection
        selectedPhotoItem = nil
    }
}

// MARK: - Customize Header Button
struct CustomizeHeaderButton: View {
    let hasCustomImage: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)

                Image(systemName: hasCustomImage ? "photo.fill" : "camera.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Rounded Corner Shape
/// A shape that allows rounding specific corners
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview
#Preview("Customizable Header") {
    VStack {
        CustomizableHeaderView(
            pageIdentifier: .birthdays,
            title: "Birthdays",
            showBackButton: true,
            backAction: {},
            showAddButton: true,
            addAction: {}
        )

        Spacer()
    }
    .background(Color.appBackground)
    .environment(UserHeaderOverrides())
    .environment(UserPreferences())
    .environment(HeaderStyleManager())
}
