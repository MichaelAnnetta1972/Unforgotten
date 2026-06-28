import SwiftUI

// MARK: - Onboarding Motivation View
/// Screen after Theme Selection: Ask why the user is here, then show a tailored
/// reassuring response with feature tiles relevant to their motivation.
struct OnboardingMotivationView: View {
    let accentColor: Color
    let onContinue: () -> Void

    @State private var selection: Motivation? = nil
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: isRegularWidth ? 80 : 60)

                if let selection {
                    responseContent(for: selection, geometry: geometry)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    questionContent(geometry: geometry)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.appBackground)
        .onAppear {
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation { hasAppeared = true }
            }
        }
    }

    // MARK: - Question Content

    @ViewBuilder
    private func questionContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("What brings you to Unforgotten?")
                    .font(.appLargeTitle)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 15)

                Text("Choose the option that best describes you.")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 15)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .animation(
                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                value: hasAppeared
            )

            Spacer()
                .frame(height: isRegularWidth ? 40 : 32)

            VStack(spacing: 12) {
                ForEach(Array(Motivation.allCases.enumerated()), id: \.element.id) { index, motivation in
                    MotivationOptionRow(
                        motivation: motivation,
                        accentColor: accentColor,
                        onSelect: { select(motivation) }
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.06),
                        value: hasAppeared
                    )
                }
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .frame(maxWidth: isRegularWidth ? 500 : .infinity)

            Spacer()
        }
    }

    // MARK: - Response Content

    @ViewBuilder
    private func responseContent(for motivation: Motivation, geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Choose again - in case the user picked the wrong option
            Button(action: chooseAgain) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .medium))
                    Text("Choose again")
                        .font(.appCaption)
                }
                .foregroundColor(accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(accentColor.opacity(0.12))
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose a different option")
            .padding(.bottom, 16)

            VStack(spacing: 12) {
                Text(motivation.responseTitle)
                    .font(.appLargeTitle)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Text(motivation.responseBody)
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 520)
            }
            .padding(.horizontal, AppDimensions.screenPadding)

            Spacer()
                .frame(height: isRegularWidth ? 40 : 32)

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: isRegularWidth ? 160 : 140), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(Array(motivation.tiles.enumerated()), id: \.element.id) { index, tile in
                        MotivationTileView(
                            tile: tile,
                            accentColor: accentColor,
                            isUnified: motivation == .everythingInOnePlace
                        )
                        .opacity(hasAppeared ? 1 : 0)
                        .scaleEffect(hasAppeared ? 1 : 0.9)
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.1 + Double(index) * 0.05),
                            value: hasAppeared
                        )
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 4)
                .frame(maxWidth: isRegularWidth ? 600 : .infinity)
            }

            Spacer()
                .frame(height: isRegularWidth ? 24 : 16)

            Button(action: onContinue) {
                Text("Continue")
                    .font(.appBodyMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDimensions.buttonHeight)
                    .background(accentColor)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
            }
            .frame(maxWidth: isRegularWidth ? 400 : .infinity)
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.bottom, geometry.safeAreaInsets.bottom + (isRegularWidth ? 48 : 32))
        }
    }

    // MARK: - Selection

    private func select(_ motivation: Motivation) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        if reduceMotion {
            selection = motivation
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                selection = motivation
            }
        }
    }

    private func chooseAgain() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        if reduceMotion {
            selection = nil
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                selection = nil
            }
        }
    }
}

// MARK: - Motivation

enum Motivation: String, CaseIterable, Identifiable {
    case stayOrganised
    case rememberThings
    case helpLovedOne
    case everythingInOnePlace

    var id: String { rawValue }

    var optionTitle: String {
        switch self {
        case .stayOrganised: return "I want help staying organised"
        case .rememberThings: return "I need help remembering important things"
        case .helpLovedOne: return "I want to help a loved one stay organised"
        case .everythingInOnePlace: return "I want one app for everything"
        }
    }

    var optionIcon: String {
        switch self {
        case .stayOrganised: return "checklist"
        case .rememberThings: return "brain.head.profile"
        case .helpLovedOne: return "person.2.fill"
        case .everythingInOnePlace: return "square.grid.2x2.fill"
        }
    }

    var responseTitle: String {
        switch self {
        case .stayOrganised: return "You're in the right place"
        case .rememberThings: return "Life gets easier when everything is in one place"
        case .helpLovedOne: return "Support the people who matter most"
        case .everythingInOnePlace: return "Stop juggling multiple apps"
        }
    }

    var responseBody: String {
        switch self {
        case .stayOrganised:
            return "Unforgotten helps you manage appointments, reminders, notes, events, calendars and tasks — all in one simple app. It even comes with a meal planner!"
        case .rememberThings:
            return "Track medications, appointments, birthdays, reminders and important notes without relying on memory alone."
        case .helpLovedOne:
            return "Invite family members or carers to help manage reminders, appointments, medications and calendars together."
        case .everythingInOnePlace:
            return "No more switching between calendars, notes apps, reminder apps and medication trackers. Unforgotten keeps everything together so life feels simpler."
        }
    }

    var tiles: [MotivationTile] {
        switch self {
        case .stayOrganised:
            return [
                MotivationTile(title: "Calendar", icon: "calendar"),
                MotivationTile(title: "To Do", icon: "checklist"),
                MotivationTile(title: "Appointments", icon: "clock.fill"),
                MotivationTile(title: "Sticky Reminders", icon: "note.text"),
                MotivationTile(title: "Events", icon: "star.fill"),
                MotivationTile(title: "Meal Planner", icon: "fork.knife")
            ]
        case .rememberThings:
            return [
                MotivationTile(title: "Medications", icon: "pills.fill"),
                MotivationTile(title: "Appointments", icon: "clock.fill"),
                MotivationTile(title: "Daily Summary", icon: "sun.max.fill"),
                MotivationTile(title: "Birthdays", icon: "gift.fill"),
                MotivationTile(title: "Events", icon: "star.fill"),
                MotivationTile(title: "Contacts", icon: "person.crop.circle.fill")
            ]
        case .helpLovedOne:
            return [
                MotivationTile(title: "Shared Family Calendar", icon: "calendar.badge.plus"),
                MotivationTile(title: "Shared Profiles", icon: "person.2.fill"),
                MotivationTile(title: "Shared Reminders", icon: "bell.badge.fill"),
                MotivationTile(title: "Helper Access", icon: "person.badge.key.fill")
            ]
        case .everythingInOnePlace:
            return [
                MotivationTile(title: "Calendar", icon: "calendar"),
                MotivationTile(title: "Notes", icon: "note.text"),
                MotivationTile(title: "Reminders", icon: "bell.fill"),
                MotivationTile(title: "Contacts", icon: "person.crop.circle.fill"),
                MotivationTile(title: "Appointments", icon: "clock.fill"),
                MotivationTile(title: "All in Unforgotten", icon: "sparkles", assetName: "unforgotten-icon")
            ]
        }
    }
}

// MARK: - Motivation Tile Model

struct MotivationTile: Identifiable {
    let title: String
    let icon: String
    /// Optional named image asset to use instead of the SF Symbol icon.
    var assetName: String? = nil
    var id: String { title }
}

// MARK: - Motivation Option Row

private struct MotivationOptionRow: View {
    let motivation: Motivation
    let accentColor: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: motivation.optionIcon)
                    .font(.system(size: 22))
                    .foregroundColor(accentColor)
                    .frame(width: 36)

                Text(motivation.optionTitle)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(motivation.optionTitle)
        .accessibilityHint("Double tap to select")
    }
}

// MARK: - Motivation Tile View

private struct MotivationTileView: View {
    let tile: MotivationTile
    let accentColor: Color
    let isUnified: Bool

    private var isHighlighted: Bool {
        isUnified && tile.title == "All in Unforgotten"
    }

    var body: some View {
        VStack(spacing: 10) {
            iconBadge

            Text(tile.title)
                .font(.appCaption)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    @ViewBuilder
    private var iconBadge: some View {
        if let assetName = tile.assetName {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isHighlighted ? accentColor : accentColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: tile.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isHighlighted ? .white : accentColor)
            }
        }
    }
}

// MARK: - Preview
#Preview("Question") {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingMotivationView(
            accentColor: Color(hex: "FFC93A"),
            onContinue: {}
        )
    }
}

#Preview("Blue Theme") {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingMotivationView(
            accentColor: Color(hex: "7BA4B5"),
            onContinue: {}
        )
    }
}
