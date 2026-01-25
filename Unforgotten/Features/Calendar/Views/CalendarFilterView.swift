import SwiftUI

// MARK: - Calendar Filter View (Event Type Filter Only)
struct CalendarFilterView: View {
    @Binding var selectedFilters: Set<CalendarEventFilter>
    @Binding var isPresented: Bool

    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var offsetX: CGFloat = 320
    @State private var opacity: Double = 0

    /// Panel width - slightly wider on iPad
    private var panelWidth: CGFloat {
        horizontalSizeClass == .regular ? 320 : 280
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
                }
                .padding(AppDimensions.cardPadding)
                .frame(width: panelWidth)
                .background(Color.cardBackgroundLight)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius))
                .shadow(color: .black.opacity(0.3), radius: 12, x: -4, y: 0)
                .offset(x: offsetX)
                .opacity(opacity)
                .padding(.trailing, 20)
            }
            .frame(maxHeight: .infinity, alignment: .center)
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
}

// MARK: - Filter Option Row Style
enum FilterOptionRowStyle {
    case filled      // Default: solid background
    case outlined    // No background, border instead
}

// MARK: - Filter Option Row (Event Types)
struct FilterOptionRow: View {
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
                    .foregroundColor(isSelected ? accentColor : .textSecondary)
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
            isPresented: .constant(true)
        )
    }
}
