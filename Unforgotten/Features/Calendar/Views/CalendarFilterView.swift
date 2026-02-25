import SwiftUI

// MARK: - Calendar Filter View (Event Type Filter Only)
struct CalendarFilterView: View {
    @Binding var selectedFilters: Set<CalendarEventFilter>
    @Binding var selectedCountdownTypes: Set<CountdownType>
    @Binding var selectedCustomTypeNames: Set<String>
    @Binding var isPresented: Bool

    /// Standard countdown types that are in use
    var availableCountdownTypes: [CountdownType]
    /// Custom type names that are in use
    var availableCustomTypeNames: [String]

    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var offsetX: CGFloat = 320
    @State private var opacity: Double = 0

    /// Panel width - slightly wider on iPad
    private var panelWidth: CGFloat {
        horizontalSizeClass == .regular ? 320 : 280
    }

    private var hasCountdownSubTypes: Bool {
        !availableCountdownTypes.isEmpty || !availableCustomTypeNames.isEmpty
    }

    var body: some View {
        ZStack {
            // Dimmed background - covers entire screen
            Color.cardBackground.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPanel()
                }

            // Side panel from right - centered vertically, fit content height
            HStack {
                Spacer()

                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        HStack {
                            Text("Event Type")
                                .font(.appTitle)
                                .foregroundColor(.textPrimary)

                            Spacer()

                            Button {
                                dismissPanel()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.textSecondary)
                            }
                        }

                        // Event Type Section
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(CalendarEventFilter.allCases) { filter in
                                FilterOptionRow(
                                    filter: filter,
                                    isSelected: selectedFilters.contains(filter),
                                    accentColor: appAccentColor
                                ) {
                                    toggleFilter(filter)
                                }
                            }

                            // Quick actions for event types
                            HStack(spacing: 12) {
                                Button {
                                    selectedFilters = Set(CalendarEventFilter.allCases)
                                    selectAllCountdownSubTypes()
                                } label: {
                                    Text("Select All")
                                        .font(.appCaption)
                                        .foregroundColor(.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.cardBackgroundSoft)
                                        .cornerRadius(AppDimensions.cardCornerRadius)
                                }

                                Button {
                                    selectedFilters = []
                                    clearAllCountdownSubTypes()
                                } label: {
                                    Text("Clear")
                                        .font(.appCaption)
                                        .foregroundColor(.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.cardBackgroundSoft)
                                        .cornerRadius(AppDimensions.cardCornerRadius)
                                }
                            }
                        }

                        // Countdown Sub-Type Section
                        if selectedFilters.contains(.countdowns), hasCountdownSubTypes {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Event Types")
                                    .font(.appCardTitle)
                                    .foregroundColor(.textSecondary)
                                    .padding(.top, 4)

                                // Standard countdown types in use
                                ForEach(availableCountdownTypes) { type in
                                    CountdownTypeFilterRow(
                                        icon: type.icon,
                                        color: type.color,
                                        name: type.displayName,
                                        isSelected: selectedCountdownTypes.contains(type),
                                        accentColor: appAccentColor
                                    ) {
                                        toggleCountdownType(type)
                                    }
                                }

                                // Custom type names in use
                                ForEach(availableCustomTypeNames, id: \.self) { name in
                                    CountdownTypeFilterRow(
                                        icon: CountdownType.custom.icon,
                                        color: CountdownType.custom.color,
                                        name: name,
                                        isSelected: selectedCustomTypeNames.contains(name),
                                        accentColor: appAccentColor
                                    ) {
                                        toggleCustomTypeName(name)
                                    }
                                }
                            }
                        }
                    }
                    .padding(AppDimensions.cardPadding)
                }
                .frame(width: panelWidth)
                .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
                .background(Color.cardBackgroundLight)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius))
                .shadow(color: .black.opacity(0.3), radius: 12, x: -4, y: 0)
                .offset(x: offsetX)
                .opacity(opacity)
                .padding(.trailing, 20)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 80)
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                offsetX = 0
                opacity = 1.0
            }
        }
    }

    private func dismissPanel() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offsetX = panelWidth + 40
            opacity = 0
        }
        // Delay the actual dismissal to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
        }
    }

    private func toggleFilter(_ filter: CalendarEventFilter) {
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
        } else {
            selectedFilters.insert(filter)
        }
    }

    private func toggleCountdownType(_ type: CountdownType) {
        if selectedCountdownTypes.contains(type) {
            selectedCountdownTypes.remove(type)
        } else {
            selectedCountdownTypes.insert(type)
        }
    }

    private func toggleCustomTypeName(_ name: String) {
        if selectedCustomTypeNames.contains(name) {
            selectedCustomTypeNames.remove(name)
        } else {
            selectedCustomTypeNames.insert(name)
        }
    }

    private func selectAllCountdownSubTypes() {
        selectedCountdownTypes = Set(CountdownType.allCases)
        selectedCustomTypeNames = Set(availableCustomTypeNames)
    }

    private func clearAllCountdownSubTypes() {
        selectedCountdownTypes = []
        selectedCustomTypeNames = []
    }
}

// MARK: - Countdown Type Filter Row
struct CountdownTypeFilterRow: View {
    @Environment(\.appAccentColor) private var appAccentColor

    let icon: String
    let color: Color
    let name: String
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Color indicator
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.2))
                    .cornerRadius(6)

                // Label
                Text(name)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? appAccentColor : .textSecondary)
            }
            .padding(.horizontal, AppDimensions.cardPadding)
            .padding(.vertical, 10)
            .background(Color.cardBackgroundSoft.opacity(0.3))
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Filter Option Row Style
enum FilterOptionRowStyle {
    case filled      // Default: solid background
    case outlined    // No background, border instead
}

// MARK: - Filter Option Row (Event Types)
struct FilterOptionRow: View {
    @Environment(\.appAccentColor) private var appAccentColor

    let filter: CalendarEventFilter
    let isSelected: Bool
    let accentColor: Color
    var style: FilterOptionRowStyle = .filled
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Color indicator
                Image(systemName: filter.icon)
                    .font(.system(size: 16))
                    .foregroundColor(filter.color)
                    .frame(width: 32, height: 32)
                    .background(filter.color.opacity(0.2))
                    .cornerRadius(8)

                // Label
                Text(filter.displayName)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? appAccentColor : .textSecondary)
            }
            .padding(AppDimensions.cardPadding)
            .background(style == .filled ? Color.cardBackgroundSoft.opacity(0.4) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(style == .outlined ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackgroundLight.ignoresSafeArea()

        CalendarFilterView(
            selectedFilters: .constant(Set(CalendarEventFilter.allCases)),
            selectedCountdownTypes: .constant(Set(CountdownType.allCases)),
            selectedCustomTypeNames: .constant(["Wedding", "Reunion"]),
            isPresented: .constant(true),
            availableCountdownTypes: [.anniversary, .holiday, .event, .countdown],
            availableCustomTypeNames: ["Wedding", "Reunion"]
        )
    }
}
