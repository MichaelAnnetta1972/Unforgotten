import SwiftUI

// MARK: - Calendar Member Filter View
/// A separate filter panel for filtering events by invited family members
struct CalendarMemberFilterView: View {
    @Binding var selectedMemberFilters: Set<UUID>
    @Binding var isPresented: Bool
    let membersWithEvents: [AccountMemberWithUser]

    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var offsetX: CGFloat = 350
    @State private var opacity: Double = 0

    /// Fixed panel width
    private let panelWidth: CGFloat = 350

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
                        Text("Filter by Member")
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

                    // Family Members Section
                    if membersWithEvents.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.textSecondary)

                            Text("No members with events")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)

                            Text("Events must be linked to profiles that are associated with invited family members.")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 24)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {

                            ForEach(membersWithEvents) { member in
                                MemberFilterRow(
                                    member: member,
                                    isSelected: selectedMemberFilters.contains(member.userId),
                                    accentColor: appAccentColor
                                ) {
                                    toggleMemberFilter(member.userId)
                                }
                            }

                            // Quick actions
                            HStack(spacing: 12) {
                                Button {
                                    selectedMemberFilters = Set(membersWithEvents.map { $0.userId })
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
                                    selectedMemberFilters = []
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

                            // Hint text
                            VStack(alignment: .leading, spacing: 4) {
                                Text("When no members selected, all events are shown")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textSecondary)
                                    .italic()

                                Text("Shows events shared by or with selected members")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textSecondary)
                                    .italic()
                            }
                        }
                    }

                    // Done button
                 //   Button {
                 //       dismissPanel()
                 //   } label: {
                 //       Text("Done")
                 //           .font(.appCardTitle)
                 //           .foregroundColor(.black)
                 //           .frame(maxWidth: .infinity)
                 //           .padding(.vertical, 16)
                 //           .background(appAccentColor)
                 //           .cornerRadius(AppDimensions.cardCornerRadius)
                 //   }
                 //   .padding(.top, 8)
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

    private func toggleMemberFilter(_ userId: UUID) {
        if selectedMemberFilters.contains(userId) {
            selectedMemberFilters.remove(userId)
        } else {
            selectedMemberFilters.insert(userId)
        }
    }
}

// MARK: - Member Filter Row Style
enum MemberFilterRowStyle {
    case filled      // Default: solid background
    case outlined    // No background, border instead
}

// MARK: - Member Filter Row
struct MemberFilterRow: View {
    let member: AccountMemberWithUser
    let isSelected: Bool
    let accentColor: Color
    var style: MemberFilterRowStyle = .filled
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Member avatar with initials
                MemberAvatarView(member: member, size: 32)

                // Name and email
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Text(member.email)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }

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

// MARK: - Member Avatar View
private struct MemberAvatarView: View {
    let member: AccountMemberWithUser
    let size: CGFloat
    @Environment(\.appAccentColor) private var appAccentColor

    private var initials: String {
        let words = member.displayName.split(separator: " ")
        let result = words.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }
        return result.isEmpty ? "?" : result.joined()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(appAccentColor.opacity(0.2))

            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(appAccentColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackgroundLight.ignoresSafeArea()

        CalendarMemberFilterView(
            selectedMemberFilters: .constant([]),
            isPresented: .constant(true),
            membersWithEvents: []
        )
    }
}
