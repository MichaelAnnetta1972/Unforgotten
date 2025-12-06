import SwiftUI

// MARK: - Navigation Card (Home screen large cards)
struct NavigationCard: View {
    let title: String
    let icon: String?
    let showChevron: Bool
    let action: () -> Void
    
    init(
        title: String,
        icon: String? = nil,
        showChevron: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.showChevron = showChevron
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.textPrimary)
                }
                
                Text(title)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Profile List Card
struct ProfileListCard: View {
    let name: String
    let subtitle: String?
    let photoUrl: String?
    let action: (() -> Void)?

    init(name: String, subtitle: String? = nil, photoUrl: String? = nil, action: (() -> Void)? = nil) {
        self.name = name
        self.subtitle = subtitle
        self.photoUrl = photoUrl
        self.action = action
    }

    var body: some View {
        let content = HStack(spacing: 12) {
            // Profile photo
            AsyncProfileImage(url: photoUrl, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundColor(.textSecondary)
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)

        if let action = action {
            Button(action: action) {
                content
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            content
        }
    }
}

// MARK: - Detail Item Card (Key Information items)
struct DetailItemCard: View {
    let label: String
    let value: String
    let showChevron: Bool
    let action: (() -> Void)?
    
    init(
        label: String,
        value: String,
        showChevron: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.label = label
        self.value = value
        self.showChevron = showChevron
        self.action = action
    }
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent
            }
        }
    }
    
    private var cardContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                
                Text(value)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Value Pill Card (Clothing sizes with pill value)
struct ValuePillCard: View {
    let category: String
    let label: String
    let value: String
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    init(
        category: String,
        label: String,
        value: String,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.category = category
        self.label = label
        self.value = value
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                Text(label)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            Text(value)
                .font(.appValuePill)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.pillCornerRadius)

            // Ellipsis menu
            if onEdit != nil || onDelete != nil {
                Menu {
                    if let onEdit = onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }

                    if let onDelete = onDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(90))
                }
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Gift Item Card (with status indicator)
struct GiftItemCard: View {
    let label: String
    let status: GiftStatus
    let onStatusChange: ((GiftStatus) -> Void)?
    let onDelete: (() -> Void)?

    @State private var showMenu = false

    enum GiftStatus: String {
        case idea = "idea"
        case bought = "bought"
        case given = "given"

        var displayName: String {
            switch self {
            case .idea: return "Idea"
            case .bought: return "Bought"
            case .given: return "Given"
            }
        }

        var color: Color {
            switch self {
            case .idea: return .badgeGrey
            case .bought: return .badgeGreen
            case .given: return .accentYellow
            }
        }

        var textColor: Color {
            switch self {
            case .idea: return .white
            case .bought: return .white
            case .given: return .black
            }
        }
    }

    init(label: String, status: GiftStatus = .idea, onStatusChange: ((GiftStatus) -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.label = label
        self.status = status
        self.onStatusChange = onStatusChange
        self.onDelete = onDelete
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gift")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                Text(label)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            // Status badge - tappable to toggle to Bought
            Button {
                if status == .idea {
                    onStatusChange?(.bought)
                }
            } label: {
                Text(status.displayName)
                    .font(.appCaption)
                    .fontWeight(.medium)
                    .foregroundColor(status.textColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(status.color)
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())

            // Ellipsis menu
            Menu {
                Button {
                    onStatusChange?(.idea)
                } label: {
                    Label("Not bought", systemImage: "tag")
                }

                Button {
                    onStatusChange?(.given)
                } label: {
                    Label("Given", systemImage: "gift")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(90))
            }
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Medical Condition Card
struct MedicalConditionCard: View {
    let type: String
    let condition: String
    let action: (() -> Void)?
    
    init(type: String, condition: String, action: (() -> Void)? = nil) {
        self.type = type
        self.condition = condition
        self.action = action
    }
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent
            }
        }
    }
    
    private var cardContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(type)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                
                Text(condition)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
            }
            
            Spacer()
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Category Card (Medical, Gift Ideas, Clothing Sizes)
struct CategoryCard: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let iconBackgroundColor: Color?
    let action: () -> Void
    
    init(
        title: String,
        icon: String,
        backgroundColor: Color,
        iconBackgroundColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.iconBackgroundColor = iconBackgroundColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    if let bgColor = iconBackgroundColor {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(bgColor)
                            .frame(width: 50, height: 50)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.appCaption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(width: AppDimensions.categoryCardWidth, height: AppDimensions.categoryCardHeight)
            .background(backgroundColor)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Header Spacer (allows touches to pass through to header behind)
struct HeaderSpacer: View {
    var body: some View {
        Color.clear
            .frame(height: AppDimensions.headerContentSpacing)
            .allowsHitTesting(false)
    }
}

// MARK: - Bottom Fade Gradient
struct BottomFadeGradient: View {
    var height: CGFloat = 200

    var body: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [.clear, Color.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Floating Button Container (with fade effect)
struct FloatingButtonContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            BottomFadeGradient()

            VStack {
                Spacer()
                content
                    .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Nav Destination for programmatic navigation
enum NavDestination: Hashable {
    case home
    case profiles
    case appointments
    case medications
    case other  // For pages without a nav bar icon (My Card, Birthdays, Contacts, Mood)
}

// MARK: - Bottom Nav Bar (4 icons in container + add button with popup menu)
struct BottomNavBar: View {
    let currentPage: NavDestination
    let isAtHomeRoot: Bool
    let onNavigate: (NavDestination) -> Void

    let onAddProfile: (() -> Void)?
    let onAddMedication: (() -> Void)?
    let onAddAppointment: (() -> Void)?
    let onAddContact: (() -> Void)?
    let onAddConnection: (() -> Void)?

    @State private var showAddMenu = false

    init(
        currentPage: NavDestination = .home,
        isAtHomeRoot: Bool = true,
        onNavigate: @escaping (NavDestination) -> Void,
        onAddProfile: (() -> Void)? = nil,
        onAddMedication: (() -> Void)? = nil,
        onAddAppointment: (() -> Void)? = nil,
        onAddContact: (() -> Void)? = nil,
        onAddConnection: (() -> Void)? = nil
    ) {
        self.currentPage = currentPage
        self.isAtHomeRoot = isAtHomeRoot
        self.onNavigate = onNavigate
        self.onAddProfile = onAddProfile
        self.onAddMedication = onAddMedication
        self.onAddAppointment = onAddAppointment
        self.onAddContact = onAddContact
        self.onAddConnection = onAddConnection
    }

    var body: some View {
        ZStack {
            // Dark overlay when menu is open
            if showAddMenu {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showAddMenu = false
                        }
                    }
            }

            // Bottom fade gradient (only when menu is closed)
            if !showAddMenu {
                BottomFadeGradient()
            }

            VStack {
                Spacer()

                ZStack(alignment: .bottomTrailing) {
                    // Add menu popup
                    if showAddMenu {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            Text("Add a new")
                                .font(.appCardTitle)
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 14)

                            Divider()
                                .background(Color.cardBackgroundSoft)

                            // Menu items
                            AddMenuRow(icon: "person.2", title: "Family or Friend") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showAddMenu = false
                                }
                                onAddProfile?()
                            }

                            AddMenuRow(icon: "pill", title: "Medication") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showAddMenu = false
                                }
                                onAddMedication?()
                            }

                            AddMenuRow(icon: "calendar", title: "Appointment") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showAddMenu = false
                                }
                                onAddAppointment?()
                            }

                            AddMenuRow(icon: "phone", title: "Contact") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showAddMenu = false
                                }
                                onAddContact?()
                            }

                            AddMenuRow(icon: "link", title: "Connection") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showAddMenu = false
                                }
                                onAddConnection?()
                            }
                        }
                        .background(Color.cardBackgroundLight.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                                .stroke(Color.cardBackgroundLight, lineWidth: 1)
                        )
                        .cornerRadius(AppDimensions.cardCornerRadius)
                        .shadow(color: .black.opacity(0.3), radius: 20, y: -5)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.trailing, AppDimensions.screenPadding)
                        .padding(.bottom, 100)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity),
                            removal: .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity)
                        ))
                    }

                    // Nav bar
                    HStack(spacing: 12) {
                        // Container for 4 nav icons
                        HStack(spacing: 0) {
                            // Home button - active only when on home tab AND at root
                            NavBarButton(
                                icon: "house.fill",
                                isActive: currentPage == .home && isAtHomeRoot
                            ) {
                                onNavigate(.home)
                            }

                            // Family & Friends button
                            NavBarButton(
                                icon: "person.2.fill",
                                isActive: currentPage == .profiles
                            ) {
                                onNavigate(.profiles)
                            }

                            // Medications button
                            NavBarButton(
                                icon: "pill.fill",
                                isActive: currentPage == .medications
                            ) {
                                onNavigate(.medications)
                            }

                            // Appointments button
                            NavBarButton(
                                icon: "calendar",
                                isActive: currentPage == .appointments
                            ) {
                                onNavigate(.appointments)
                            }

                        }
                        .background(Color.cardBackgroundLight.opacity(0.5))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.cardBackgroundLight, lineWidth: 1)
                        )

                        // Add button
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showAddMenu.toggle()
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                                .rotationEffect(.degrees(showAddMenu ? 45 : 0))
                                .frame(width: 60, height: 60)
                                .background(Color.accentYellow)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

// MARK: - Nav Bar Button
struct NavBarButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button {
            if !isActive {
                action()
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isActive ? .accentYellow : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
        }
        .disabled(isActive)
    }
}

// MARK: - Add Menu Row
struct AddMenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.accentYellow)
                    .frame(width: 24)

                Text(title)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Floating Nav Bar (Settings left, Home right) - DEPRECATED
struct FloatingNavBar: View {
    let onSettings: () -> Void
    let onHome: () -> Void

    var body: some View {
        HStack {
            // Settings button (left)
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Home button (right)
            Button(action: onHome) {
                Image(systemName: "house")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, AppDimensions.screenPadding + 8)
        .padding(.bottom, 50)
    }
}

// MARK: - Floating Nav Container (with fade and nav bar) - DEPRECATED
struct FloatingNavContainer<Content: View>: View {
    let showNavBar: Bool
    let onSettings: (() -> Void)?
    let onHome: (() -> Void)?
    let content: Content

    init(
        showNavBar: Bool = true,
        onSettings: (() -> Void)? = nil,
        onHome: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.showNavBar = showNavBar
        self.onSettings = onSettings
        self.onHome = onHome
        self.content = content()
    }

    var body: some View {
        ZStack {
            BottomFadeGradient()

            VStack(spacing: 0) {
                Spacer()

                // Optional centered content (like add button)
                content
                    .padding(.bottom, showNavBar ? 16 : 50)

                // Nav bar
                if showNavBar, let onSettings = onSettings, let onHome = onHome {
                    FloatingNavBar(onSettings: onSettings, onHome: onHome)
                }
            }
        }
    }
}

// MARK: - Floating Add Button
struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.black)
                .frame(width: AppDimensions.floatingButtonSize, height: AppDimensions.floatingButtonSize)
                .background(Color.accentYellow)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
    }
}

// MARK: - Floating Edit Button
struct FloatingEditButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.black)
                .frame(width: AppDimensions.floatingButtonSize, height: AppDimensions.floatingButtonSize)
                .background(Color.accentYellow)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
    }
}

// MARK: - Floating Settings Button
struct FloatingSettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.black)
                .frame(width: AppDimensions.floatingButtonSize, height: AppDimensions.floatingButtonSize)
                .background(Color.accentYellow)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
    }
}

// MARK: - Section Header Card (Clothing Sizes, Gift Ideas headers)
struct SectionHeaderCard: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.appTitle2)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(AppDimensions.cardPadding)
        .background(backgroundColor)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Header Image View
struct HeaderImageView: View {
    let imageName: String?
    let photoUrl: String?
    let title: String
    let subtitle: String?
    let showBackButton: Bool
    let backAction: (() -> Void)?
    // Deprecated - kept for backwards compatibility but no longer displayed
    let showHomeButton: Bool
    let homeAction: (() -> Void)?
    let showEditButton: Bool
    let editAction: (() -> Void)?
    let showSettingsButton: Bool
    let settingsAction: (() -> Void)?
    // Custom action button (bottom right)
    let customActionIcon: String?
    let customActionColor: Color?
    let customAction: (() -> Void)?

    init(
        imageName: String? = nil,
        photoUrl: String? = nil,
        title: String,
        subtitle: String? = nil,
        showBackButton: Bool = false,
        backAction: (() -> Void)? = nil,
        showHomeButton: Bool = false,
        homeAction: (() -> Void)? = nil,
        showEditButton: Bool = false,
        editAction: (() -> Void)? = nil,
        showSettingsButton: Bool = false,
        settingsAction: (() -> Void)? = nil,
        customActionIcon: String? = nil,
        customActionColor: Color? = nil,
        customAction: (() -> Void)? = nil
    ) {
        self.imageName = imageName
        self.photoUrl = photoUrl
        self.title = title
        self.subtitle = subtitle
        self.showBackButton = showBackButton
        self.backAction = backAction
        self.showHomeButton = showHomeButton
        self.homeAction = homeAction
        self.showEditButton = showEditButton
        self.editAction = editAction
        self.showSettingsButton = showSettingsButton
        self.settingsAction = settingsAction
        self.customActionIcon = customActionIcon
        self.customActionColor = customActionColor
        self.customAction = customAction
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Background image: remote URL, local image, or gradient fallback
                if let urlString = photoUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        case .failure, .empty:
                            fallbackImage(imageName: imageName, width: geometry.size.width, height: geometry.size.height)
                        @unknown default:
                            fallbackImage(imageName: imageName, width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                } else if let imageName = imageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    LinearGradient.headerGradient
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }

                // Gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                // Content overlay
                VStack(alignment: .leading, spacing: 4) {
                    // Top row with back button and edit button
                    HStack {
                        if showBackButton, let backAction = backAction {
                            Button(action: backAction) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.25))
                                    .clipShape(Circle())
                            }
                        }

                        Spacer()

                        if showEditButton, let editAction = editAction {
                            Button(action: editAction) {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Edit")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.appBackground)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.accentYellow)
                                .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    // Bottom row with title and settings button
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let subtitle = subtitle {
                                Text(subtitle)
                                    .font(.appCaption)
                                    .foregroundColor(.accentYellow)
                            }

                            Text(title)
                                .font(.appLargeTitle)
                                .foregroundColor(.white)
                        }

                        Spacer()

                        if showSettingsButton, let settingsAction = settingsAction {
                            Button(action: settingsAction) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.25))
                                    .clipShape(Circle())
                            }
                        }

                        if let icon = customActionIcon, let action = customAction {
                            Button(action: action) {
                                Image(systemName: icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(customActionColor ?? .white)
                                    .frame(width: 36, height: 36)
                                    .background((customActionColor ?? .white).opacity(0.25))
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding + 8)
                .padding(.vertical, AppDimensions.screenPadding + 12)
            }
        }
        .frame(height: AppDimensions.headerHeight)
        .background(Color.appBackground)
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private func fallbackImage(imageName: String?, width: CGFloat, height: CGFloat) -> some View {
        if let imageName = imageName {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
        } else {
            LinearGradient.headerGradient
                .frame(width: width, height: height)
        }
    }
}

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    init(title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                } else {
                    Text(title)
                        .font(.appButtonText)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppDimensions.buttonHeight)
            .background(Color.accentYellow)
            .foregroundColor(.black)
            .cornerRadius(AppDimensions.buttonCornerRadius)
        }
        .disabled(isLoading)
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appButtonText)
                .frame(maxWidth: .infinity)
                .frame(height: AppDimensions.buttonHeight)
                .background(Color.clear)
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                        .stroke(Color.white, lineWidth: 1)
                )
        }
    }
}

// MARK: - App Text Field
struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
            }
        }
        .font(.appBody)
        .foregroundColor(.textPrimary)
        .padding()
        .frame(height: AppDimensions.textFieldHeight)
        .background(Color.cardBackgroundSoft)
        .cornerRadius(AppDimensions.buttonCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String?
    let buttonAction: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.textSecondary)
            
            Text(title)
                .font(.appTitle)
                .foregroundColor(.textPrimary)
            
            Text(message)
                .font(.appBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            
            if let buttonTitle = buttonTitle, let action = buttonAction {
                PrimaryButton(title: buttonTitle, action: action)
                    .frame(width: 200)
                    .padding(.top, 8)
            }
        }
        .padding(AppDimensions.screenPadding)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    let message: String
    
    init(message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentYellow))
                .scaleEffect(1.5)
            
            Text(message)
                .font(.appBody)
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Preview Provider
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            NavigationCard(title: "Family and Friends", icon: "person.2.fill") {}
            
            ProfileListCard(name: "Michael Annetta", subtitle: "Son") {}
            
            DetailItemCard(label: "Relationship", value: "Son")
            
            ValuePillCard(category: "Clothing", label: "Jackets", value: "42 R")
            
            GiftItemCard(label: "New Computer", status: .idea)
            
            MedicalConditionCard(type: "Allergy", condition: "Peanuts")
            
            HStack(spacing: 12) {
                CategoryCard(
                    title: "Medical",
                    icon: "cross.fill",
                    backgroundColor: .medicalRed,
                    iconBackgroundColor: .white.opacity(0.2)
                ) {}
                
                CategoryCard(
                    title: "Gift Ideas",
                    icon: "gift.fill",
                    backgroundColor: .giftPurple
                ) {}
            }
            
            SectionHeaderCard(
                title: "Clothing Sizes",
                icon: "tshirt.fill",
                backgroundColor: .clothingBlue
            )
            
            PrimaryButton(title: "Continue") {}
            
            SecondaryButton(title: "Skip") {}
            
            AppTextField(placeholder: "Email", text: .constant(""))
            
            FloatingAddButton {}
        }
        .padding()
    }
    .background(Color.appBackground)
}
