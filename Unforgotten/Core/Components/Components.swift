import SwiftUI

// MARK: - Navigation Card (Home screen large cards)
struct NavigationCard: View {
    let title: String
    let icon: String?
    let showChevron: Bool
    let action: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

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
                        .foregroundColor(appAccentColor)
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
    let isSynced: Bool
    let sourceName: String?
    let action: (() -> Void)?

    init(
        label: String,
        value: String,
        showChevron: Bool = false,
        isSynced: Bool = false,
        sourceName: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.label = label
        self.value = value
        self.showChevron = showChevron
        self.isSynced = isSynced
        self.sourceName = sourceName
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
                HStack(spacing: 6) {
                    Text(label)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    if isSynced, let name = sourceName {
                        SyncIndicator(sourceName: name)
                    }
                }

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

    @Environment(\.appAccentColor) private var appAccentColor
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

        func color(accent: Color) -> Color {
            switch self {
            case .idea: return .badgeGrey
            case .bought: return .badgeGreen
            case .given: return accent
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
                    .background(status.color(accent: appAccentColor))
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
                    .frame(width: 60, height: 60)
                    .contentShape(Rectangle())
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
    let isSynced: Bool
    let sourceName: String?
    let action: (() -> Void)?
    let onDelete: (() -> Void)?

    init(type: String, condition: String, isSynced: Bool = false, sourceName: String? = nil, action: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.type = type
        self.condition = condition
        self.isSynced = isSynced
        self.sourceName = sourceName
        self.action = action
        self.onDelete = onDelete
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
                HStack(spacing: 6) {
                    Text(type)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    if isSynced, let name = sourceName {
                        SyncIndicator(sourceName: name)
                    }
                }

                Text(condition)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

    private var cardWidth: CGFloat {
        AppDimensions.categoryCardMinWidth(for: horizontalSizeClass)
    }

    private var cardHeight: CGFloat {
        horizontalSizeClass == .regular ? 185 : 165
    }

    private var iconSize: CGFloat {
        horizontalSizeClass == .regular ? 56 : 50
    }

    private var iconFontSize: CGFloat {
        horizontalSizeClass == .regular ? 32 : 28
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    if let bgColor = iconBackgroundColor {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(bgColor)
                            .frame(width: iconSize, height: iconSize)
                    }

                    Image(systemName: icon)
                        .font(.system(size: iconFontSize))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.appCaption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(minWidth: cardWidth, minHeight: cardHeight)
            .frame(maxWidth: .infinity, maxHeight: cardHeight)
            .background(backgroundColor)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .hoverEffect(.lift)
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
    case myCard  // For limited access users (Helper/Viewer) - now also used as "About Me" in nav
    case appointments
    case medications
    case calendar
    case settings
    case other  // For pages without a nav bar icon (Birthdays, Contacts, Mood)
}

// MARK: - Bottom Nav Bar (4 icons in container + add button with popup menu)
struct BottomNavBar: View {
    let currentPage: NavDestination
    let isAtHomeRoot: Bool
    let isLimitedAccess: Bool
    let onNavigate: (NavDestination) -> Void

    let onAddProfile: (() -> Void)?
    let onAddMedication: (() -> Void)?
    let onAddAppointment: (() -> Void)?
    let onAddContact: (() -> Void)?
    let onAddToDoList: (() -> Void)?
    let onAddNote: (() -> Void)?
    let onAddStickyReminder: (() -> Void)?
    let onAddCountdown: (() -> Void)?

    @Environment(\.appAccentColor) private var appAccentColor
    @State private var showAddMenu = false

    init(
        currentPage: NavDestination = .home,
        isAtHomeRoot: Bool = true,
        isLimitedAccess: Bool = false,
        onNavigate: @escaping (NavDestination) -> Void,
        onAddProfile: (() -> Void)? = nil,
        onAddMedication: (() -> Void)? = nil,
        onAddAppointment: (() -> Void)? = nil,
        onAddContact: (() -> Void)? = nil,
        onAddToDoList: (() -> Void)? = nil,
        onAddNote: (() -> Void)? = nil,
        onAddStickyReminder: (() -> Void)? = nil,
        onAddCountdown: (() -> Void)? = nil
    ) {
        self.currentPage = currentPage
        self.isAtHomeRoot = isAtHomeRoot
        self.isLimitedAccess = isLimitedAccess
        self.onNavigate = onNavigate
        self.onAddProfile = onAddProfile
        self.onAddMedication = onAddMedication
        self.onAddAppointment = onAddAppointment
        self.onAddContact = onAddContact
        self.onAddToDoList = onAddToDoList
        self.onAddNote = onAddNote
        self.onAddStickyReminder = onAddStickyReminder
        self.onAddCountdown = onAddCountdown
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

                            // Menu items - limited for Helper/Viewer roles
                            if !isLimitedAccess {
                                AddMenuRow(icon: "person.2", title: "Family or Friend") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showAddMenu = false
                                    }
                                    onAddProfile?()
                                }
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

                            if !isLimitedAccess {
                                AddMenuRow(icon: "checklist", title: "To Do List") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showAddMenu = false
                                    }
                                    onAddToDoList?()
                                }

                                AddMenuRow(icon: "note.text", title: "Note") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showAddMenu = false
                                    }
                                    onAddNote?()
                                }

                                AddMenuRow(icon: "pin.fill", title: "Sticky Reminder") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showAddMenu = false
                                    }
                                    onAddStickyReminder?()
                                }

                                AddMenuRow(icon: "clock.badge.checkmark", title: "Event") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showAddMenu = false
                                    }
                                    onAddCountdown?()
                                }
                            }
                        }
                        .background(Color.cardBackgroundLight)
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
                        // Container for 4 nav icons with glass effect
                        GeometryReader { geometry in
                            let buttonWidth = geometry.size.width / 4
                            let activeIndex = activeButtonIndex(for: currentPage, isAtHomeRoot: isAtHomeRoot)
                            let indicatorPadding: CGFloat = 8
                            let indicatorWidth = buttonWidth - indicatorPadding
                            // Calculate offset from leading edge
                            let indicatorOffset = CGFloat(activeIndex) * buttonWidth + (indicatorPadding / 2)

                            ZStack(alignment: .leading) {
                                // Sliding indicator background
                                Capsule()
                                    .fill(appAccentColor.opacity(0.25))
                                    .frame(width: indicatorWidth, height: 52)
                                    .offset(x: indicatorOffset)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: activeIndex)

                                // Nav buttons
                                HStack(spacing: 0) {
                                    // Home button - active only when on home tab AND at root
                                    NavBarButton(
                                        icon: "house.fill",
                                        isActive: currentPage == .home && isAtHomeRoot
                                    ) {
                                        onNavigate(.home)
                                    }

                                    // About Me (My Card) button
                                    NavBarButton(
                                        icon: "person.crop.circle.fill",
                                        isActive: currentPage == .myCard
                                    ) {
                                        onNavigate(.myCard)
                                    }

                                    // Calendar button
                                    NavBarButton(
                                        icon: "calendar",
                                        isActive: currentPage == .calendar
                                    ) {
                                        onNavigate(.calendar)
                                    }

                                    // Settings button
                                    NavBarButton(
                                        icon: "gearshape.fill",
                                        isActive: currentPage == .settings
                                    ) {
                                        onNavigate(.settings)
                                    }
                                }
                            }
                        }
                        .frame(height: 60)
                        .background(.ultraThinMaterial.opacity(0.8))
                        .background(Color.cardBackgroundLight.opacity(0.3))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)

                        // Add button with press animation
                        AddNavButton(showAddMenu: $showAddMenu)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    // Helper function to get the index of the active button
    private func activeButtonIndex(for page: NavDestination, isAtHomeRoot: Bool) -> Int {
        switch page {
        case .home:
            return 0
        case .myCard:
            return 1
        case .calendar:
            return 2
        case .settings:
            return 3
        case .profiles, .medications, .appointments, .other:
            return 0 // Default to home for pages not in bottom nav
        }
    }
}

// MARK: - Nav Bar Button
struct NavBarButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor
    @State private var isPressed = false

    var body: some View {
        Button {
            if !isActive {
                action()
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isActive ? appAccentColor : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .scaleEffect(isPressed ? 0.85 : 1.0)
                .opacity(isPressed ? 0.7 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .disabled(isActive)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isActive && !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Add Nav Button (with press animation)
struct AddNavButton: View {
    @Binding var showAddMenu: Bool
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var isPressed = false

    var body: some View {
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
                .background(
                    Circle()
                        .fill(appAccentColor)
                        .shadow(color: appAccentColor.opacity(0.4), radius: isPressed ? 5 : 10, y: isPressed ? 2 : 5)
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Add Menu Row
struct AddMenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(appAccentColor)
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
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.black)
                .frame(width: AppDimensions.floatingButtonSize, height: AppDimensions.floatingButtonSize)
                .background(appAccentColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
    }
}

// MARK: - Floating Edit Button
struct FloatingEditButton: View {
    let action: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.black)
                .frame(width: AppDimensions.floatingButtonSize, height: AppDimensions.floatingButtonSize)
                .background(appAccentColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
    }
}

// MARK: - Floating Settings Button
struct FloatingSettingsButton: View {
    let action: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.black)
                .frame(width: AppDimensions.floatingButtonSize, height: AppDimensions.floatingButtonSize)
                .background(appAccentColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
    }
}

// MARK: - Section Header Card (Clothing Sizes, Gift Ideas headers)
struct SectionHeaderCard: View {
    let title: String
    let icon: String
    var backgroundColor: Color? = nil // Optional - if nil, uses accent color
    @Environment(\.appAccentColor) private var appAccentColor

    private var effectiveBackgroundColor: Color {
        backgroundColor ?? appAccentColor
    }

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
        .background(effectiveBackgroundColor)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Header Action Button (with press animation)
struct HeaderActionButton: View {
    let icon: String
    let color: Color
    let backgroundColor: Color
    let action: () -> Void

    @State private var isPressed = false

    init(
        icon: String,
        color: Color = .white,
        backgroundColor: Color = Color.white.opacity(0.25),
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.color = color
        self.backgroundColor = backgroundColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(backgroundColor)
                .clipShape(Circle())
                .scaleEffect(isPressed ? 0.85 : 1.0)
                .opacity(isPressed ? 0.7 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Header Edit Button (capsule style with press animation)
struct HeaderEditButton: View {
    let action: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                Text("Edit")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.appBackground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(appAccentColor)
            .clipShape(Capsule())
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Header Bottom Action Button (larger semi-transparent style for bottom-right positioning)
struct HeaderBottomActionButton: View {
    let icon: String
    let label: String?
    let action: () -> Void

    @State private var isPressed = false

    init(icon: String, label: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                if let label = label {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, label != nil ? 16 : 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.25))
            .clipShape(Capsule())
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Header Button Position
enum HeaderButtonPosition {
    case topRight
    case bottomRight
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
    let editButtonPosition: HeaderButtonPosition
    let showSettingsButton: Bool
    let settingsAction: (() -> Void)?
    // Custom action button (bottom right)
    let customActionIcon: String?
    let customActionColor: Color?
    let customAction: (() -> Void)?
    // Bottom-right add button
    let showAddButton: Bool
    let addAction: (() -> Void)?
    // Reorder button
    let showReorderButton: Bool
    let isReordering: Bool
    let reorderAction: (() -> Void)?

    @Environment(\.appAccentColor) private var appAccentColor

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
        editButtonPosition: HeaderButtonPosition = .topRight,
        showSettingsButton: Bool = false,
        settingsAction: (() -> Void)? = nil,
        customActionIcon: String? = nil,
        customActionColor: Color? = nil,
        customAction: (() -> Void)? = nil,
        showAddButton: Bool = false,
        addAction: (() -> Void)? = nil,
        showReorderButton: Bool = false,
        isReordering: Bool = false,
        reorderAction: (() -> Void)? = nil
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
        self.editButtonPosition = editButtonPosition
        self.showSettingsButton = showSettingsButton
        self.settingsAction = settingsAction
        self.customActionIcon = customActionIcon
        self.customActionColor = customActionColor
        self.customAction = customAction
        self.showAddButton = showAddButton
        self.addAction = addAction
        self.showReorderButton = showReorderButton
        self.isReordering = isReordering
        self.reorderAction = reorderAction
    }

    var body: some View {
        GeometryReader { geometry in
            let safeAreaTop = geometry.safeAreaInsets.top

            ZStack(alignment: .bottomLeading) {
                // Background image: remote URL, local image, or gradient fallback
                Group {
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
                }
                .allowsHitTesting(false)

                // Gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                // Content overlay - only buttons receive touches
                VStack(alignment: .leading, spacing: 4) {
                    // Top row with back button and edit/reorder buttons (when positioned top-right)
                    HStack {
                        if showBackButton, let backAction = backAction {
                            HeaderActionButton(
                                icon: "chevron.left",
                                action: backAction
                            )
                        }

                        Spacer()
                            .allowsHitTesting(false)

                        HStack(spacing: 12) {
                            if showEditButton && editButtonPosition == .topRight, let editAction = editAction {
                                HeaderEditButton(action: editAction)
                            }
                        }
                    }
                    .padding(.top, safeAreaTop)
                    .allowsHitTesting(showBackButton || (showEditButton && editButtonPosition == .topRight))

                    Spacer()
                        .allowsHitTesting(false)

                    // Bottom row with title and action buttons
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let subtitle = subtitle {
                                Text(subtitle)
                                    .font(.appCaption)
                                    .foregroundColor(appAccentColor)
                            }

                            Text(title)
                                .font(.appLargeTitle)
                                .foregroundColor(.white)
                        }
                        .allowsHitTesting(false)

                        Spacer()
                            .allowsHitTesting(false)

                        if showSettingsButton, let settingsAction = settingsAction {
                            HeaderActionButton(
                                icon: "gearshape.fill",
                                action: settingsAction
                            )
                        }

                        if let icon = customActionIcon, let action = customAction {
                            HeaderActionButton(
                                icon: icon,
                                color: customActionColor ?? .white,
                                backgroundColor: (customActionColor ?? .white).opacity(0.25),
                                action: action
                            )
                        }

                        // Reorder button (bottom-right)
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
                                .background(isReordering ? appAccentColor : Color.white.opacity(0.2))
                                .cornerRadius(16)
                            }
                        }

                        // Edit button (when positioned bottom-right)
                        if showEditButton && editButtonPosition == .bottomRight, let editAction = editAction {
                            HeaderBottomActionButton(
                                icon: "pencil",
                                label: "Edit",
                                action: editAction
                            )
                        }

                        // Add button (bottom-right)
                        if showAddButton, let addAction = addAction {
                            HeaderBottomActionButton(
                                icon: "plus",
                                action: addAction
                            )
                        }
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding + 8)
                .padding(.vertical, AppDimensions.screenPadding + 12)
            }
        }
        .frame(height: AppDimensions.headerHeight)
        .background(Color.appBackground.allowsHitTesting(false))
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
    let backgroundColor: Color?
    let action: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    init(
        title: String,
        isLoading: Bool = false,
        backgroundColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.backgroundColor = backgroundColor
        self.action = action
    }

    /// The effective background color (custom or environment accent)
    private var effectiveBackgroundColor: Color {
        backgroundColor ?? appAccentColor
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
            .background(effectiveBackgroundColor)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let icon: String
    let title: String
    let message: String
    let buttonTitle: String?
    let buttonAction: (() -> Void)?

    /// Check if we're in iPad mode (regular size class)
    private var isiPad: Bool {
        horizontalSizeClass == .regular
    }

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
        .frame(maxWidth: isiPad ? 400 : .infinity)
        .padding(AppDimensions.screenPadding)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    let message: String

    @Environment(\.appAccentColor) private var appAccentColor

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: appAccentColor))
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
